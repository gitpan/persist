package Persist::Driver::DBI::PostgreSQL;

use 5.008;
use strict;
use warnings;

use DBI;

use DateTime;
use DateTime::Format::Pg;

use Persist qw(:constants :driver_help);
use Persist::Driver::DBI;
use Persist::Filter;

our @ISA = qw(Persist::Driver::DBI);

our ( $VERSION ) = '$Revision: 1.19 $' =~ /\$Revision:\s+([^\s]+)/;

use constant TYPES => [ 
	qw( varchar int4 serial bool float8 timestamp )
];

=head1 NAME

Persist::Driver::DBI::PostgreSQL - Persist driver for DBD::Pg

=head1 SYNOPSIS

  use Persist::Source;

  $source = new Persist::Source('Persist::Driver::DBI::PostgreSQL',
                    'dbname=foo', 'foo', 'bar');

  @conn = $source->new_source('newfoo', 'newbar');
  $source->delete_source('newfoo');

  # Use other Persist::Source methods ...

=head1 DESCRIPTION

This is a concrete driver for accessing a PostgreSQL database via L<DBI> using
the L<DBD::Pg> driver. This class shouldn't be used directly, but only through
a L<Persist::Source>.

The rest of this POD document describes some of the capabilities and
limitations of this driver.

=over

=cut

# =item $parsed = _parse_conn($conn)
#
# Breaks the PostgreSQL connection string into it's constituent parts and
# returns the parsed bits as a hash reference.
#
sub _parse_conn {
	my $conn = shift;

	my %parsed = map { split /=/, $_ } split /;/, $conn;
	my %permitted = (dbname=>1,host=>1,port=>1,options=>1,tty=>1);

	return undef unless $parsed{dbname};
	
	for my $key (keys %parsed) {
		return undef unless $permitted{$key};
	}

	\%parsed;
}

=item $driver = new Persist::Driver::DBI::PostgreSQL(%args)

Creates a new L<DBI> connection.  The connection is created with AutoCommit set,
PrintError unset, and RaiseError set.

These arguments C<%args> are accepted: 

=over

=item $uri (optional)

The connection string to connect to PostgreSQL with. If not set, it will be
created using other arguments.

=item $database (optional)

The name of the database to connect to. This option and C<$uri> are mutually
exclusive.

=item $host (optional)

The host name to connect to. This option and C<$uri> are mutually exclusive.

=item $port (optional)

The port to connect to. This option and C<$uri> are mutually exclusive.

=item $tty (optional)

The tty option to pass to the PostgreSQL driver. This option and C<$uri> are
mutually exclusive.

=item $options (optional)

Other options to pass to the PostgreSQL driver. This option and C<$uri> are
mutually exclusive.

=item $username

The username to use when connecting to the database. If neither C<$uri> or
C<$database> are given, then this will also be used as the database name.

=item $password (optional)

The password to connect with.

=back

=cut

sub new {
	my ($class, %args) = @_;
	
	my ($conn, $user, $pass, $database, $host, $port, $tty, $options) = 
		@args{qw(-uri -username -password -database -host -port -tty -options)};

	if (defined $conn and (defined $database or
						   defined $host or
						   defined $port or
						   defined $tty or
						   defined $options)) {
		croak "The -uri option cannot be given with any of -database, -host, -port, -tty, or -options.";
	}

	croak "No username given for connection." unless defined $user;

	my $parsed_conn;
	if (defined $conn) {
		$parsed_conn = _parse_conn($conn);
		croak "Illegal connection string $conn." unless $parsed_conn;
	} else {
		$database ||= $user;
		$parsed_conn->{dbname} = $database;
		$conn = "dbname=$database";
		$conn .= ":host=$host" and $parsed_conn->{host} = $host if defined $host;
		$conn .= ":port=$port" and $parsed_conn->{port} = $port if defined $port;
		$conn .= ":tty=$tty" and $parsed_conn->{tty} = $tty if defined $tty;
		$conn .= ":options=$options" and $parsed_conn->{$options} = $options if defined $options;
	}

	my $self = $class->SUPER::new(
		-database => DBI->connect
			("dbi:Pg:$conn", $user, $pass, {
					AutoCommit => 1,
					PrintError => 0,
					RaiseError => 1,
			}));
	$self->{-conn} = $conn;
	$self->{-parsedconn} = $parsed_conn;
	$self->{-user} = $user;

	$self;
}

=item $driver->preprocess_filter(%args)

This method changes boolean values to literal strings 'true' and 'false'.

=cut

sub preprocess_filter {
	my ($self, %args) = @_;
	my ($tables, $filter) = @args{qw(-aliases -filter)};

	my ($preprocess_boolean);
	my $process_ast = sub { 
		my ($a, $o, $b) = @{$_[0]};
		if ($a->isa('Persist::Filter::Identifier') and
				$b->isa('Persist::Filter::Number')) {
			&$preprocess_boolean($a, $b);
		} elsif ($a->isa('Persist::Filter::Number') and
				$b->isa('Persist::Filter::Identifier')) {
			&$preprocess_boolean($b, $a);
		}
	};
	
	my $ast = parse_filter($filter);

	my $cols;
	my %seen;
	for my $i (0 .. $#$tables) {
		my $name = $$tables[$i];
		my %columns = $self->columns(-table => $name);
		my $table_num = ++$seen{$name};
		for my $column (keys %columns) {
			for my $prefix ('', ($i + 1).".", "$name.", "$name$table_num.") {
				$$cols{"$prefix$column"} = $columns{$column};
			}
		}
	}

	$preprocess_boolean = sub {
		my ($id, $lit) = @_;
		if ($$cols{$$id}[0] == BOOLEAN && defined $$lit) {
			$$lit = $$lit == 0 ? "'false'" : "'true'";
		}
	};

	$ast->remap_on('Persist::Filter::Comparison', $process_ast);

	$ast->unparse;
}

=item $rows = $driver-E<gt>insert(%args)

This is a wrapper for the C<insert> method of L<Persist::Driver::DBI> which
converts L<Persist> style dates to PostgreSQL style and boolean values to
literal strings 'true' and 'false'.

=cut

sub insert {
	my ($self, %args) = @_;
	my ($name, $values) = @args{qw(-table -values)};

	my %columns = $self->columns(-table => $name);
	while (my ($k, $v) = each %columns) {
		if ($v->[0] == TIMESTAMP and defined($values->{$k})
								 and ref $values->{$k} eq 'DateTime') {
			$values->{$k} = DateTime::Format::Pg->format_timestamp($values->{$k});
		} elsif ($v->[0] == BOOLEAN and defined($values->{$k})) {
			$values->{$k} = ($values->{$k} ? 'true' : 'false');
		}
	}

	$self->SUPER::insert(-table => $name, -values => $values);
}

=item $rows = $driver-E<gt>update(%args)

This is a wrapper for the C<update> method of L<Persist::Driver::DBI> which
converts L<Persist> style dates to PostgreSQL style and boolean values to
literal strings 'true' and 'false'.

=cut

sub update {
	my ($self, %args) = @_;
	my ($name, $set, $filter, $bindings) = @args{qw(-table -set -filter -bindings)};

	my %columns = $self->columns(-table => $name);
	while (my ($k, $v) = each %columns) {
		if ($v->[0] == TIMESTAMP and defined($set->{$k})
								 and ref $set->{$k} eq 'DateTime') {
			$set->{$k} = DateTime::Format::Pg->format_timestamp($set->{$k});
		} elsif ($v->[0] == BOOLEAN and defined($set->{$k})) {
			$set->{$k} = ($set->{$k} ? 'true' : 'false');
		}
	}

	$self->SUPER::update(-table => $name, -set => $set, -filter => $filter, -bindings => $bindings);
}

=item $driver->first(%args)

This is a wrapper for the C<first> method of L<Persist::Driver::DBI> and
converts PostgreSQL style dates to L<Persist> style timestamps.

=cut

sub first {
	my ($self, %args) = @_;
	my ($handle, $bytable) = @args{qw(-handle -bytable)};
	my $tables = $handle->[0];

	my $results = $self->SUPER::first(-handle => $handle);

	if (defined $results) {
		if ($bytable and @$tables > 1) {
			for my $i (0 .. $#$tables) {
				my $name = $$tables[$i];
				my %columns = $self->columns(-table => $name);
				while (my ($k, $v) = each %columns) {
					if ($v->[0] == TIMESTAMP and defined($results->[$i]{$k})) {
						$results->[$i]{$k} = DateTime::Format::Pg->parse_timestamp($results->[$i]{$k});
					}
				}
			}
		} else {
			for my $name (@$tables) {
				my %columns = $self->columns(-table => $name);
				while (my ($k, $v) = each %columns) {
					if ($v->[0] == TIMESTAMP and defined($results->{$k})) {
						$results->{$k} = DateTime::Format::Pg->parse_timestamp($results->{$k});
					}
				}
			}
		}
	}

	$results;
}

=item $driver->next(%args)

This is a wrapper for the C<first> method of L<Persist::Driver::DBI> and
converts PostgreSQL dates to L<DateTime> objects.

=cut

# TODO Combine common code in first and next.

sub next {
	my ($self, %args) = @_;
	my ($handle, $bytable) = @args{qw(-handle -bytable)};
	my $tables = $handle->[0];

	my $results = $self->SUPER::next(-handle => $handle, -bytable => $bytable);

	if (defined $results) {
		if ($bytable and @$tables > 1) {
			for my $i (0 .. $#$tables) {
				my $name = $$tables[$i];
				my %columns = $self->columns(-table => $name);
				while (my ($k, $v) = each %columns) {
					if ($v->[0] == TIMESTAMP and defined($results->[$i]{$k})) {
						$results->[$i]{$k} = DateTime::Format::Pg->parse_timestamp($results->[$i]{$k});
					}
				}
			}
		} else {
			for my $name (@$tables) {
				my %columns = $self->columns(-table => $name);
				while (my ($k, $v) = each %columns) {
					if ($v->[0] == TIMESTAMP and defined($results->{$k})) {
						$results->{$k} = DateTime::Format::Pg->parse_timestamp($results->{$k});
					}
				}
			}
		}
	}

	$results;
}

=item $driver->is_dba

Determines if the current connection has DBA priveleges by checking the
C<pg_catalog.pg_user> table to see if the current user is able to both create
databases (C<usecreatedb>) and create users (C<usesuper>).  Such a user can be
created in C<psql> using the command:

  CREATE USER username WITH PASSWORD 'password' CREATEDB CREATEUSER;

Or the following command-line can be used from the shell:

  # createuser -a -d -P username

For such a user to be usable by this Persist driver should also have a database
created by the same name.

=cut

sub is_dba {
	my $self = shift;
	my $user = $self->{-user};
	my $users = $self->handle->selectcol_arrayref(qq(
		SELECT usesysid FROM pg_user 
		WHERE usecreatedb = 't' AND usesuper = 't' AND usename = '$user'
	));
	@$users == 1;
}

=item @args = $driver->new_source(%args)

Creates a new data source and returns the arguments required to connect to the
new database. This will create a new PostgreSQL user with the given name and
then a database of the same name. The user will not be permitted to create
databases or users.

The arguments C<%args> accepted are:

=over

=item $username

The name of the username and database to create.

=item $password

The password used to access this database.

=back

=cut

sub new_source {
	my ($self, %args) = @_;
	my ($user, $pass) = @args{qw(-username -password)};

	$self->handle->do(qq(
		CREATE USER $user PASSWORD '$pass' NOCREATEDB NOCREATEUSER
	));

	$self->handle->do(qq(
		CREATE DATABASE $user
	));

	my %conn = %{$self->{-parsedconn}};
	$conn{dbname} = $user;
	my @opts;
	while (my ($key, $value) = each %conn) {
		push @opts, "$key=$value";
	}
	
	(-uri => join(';', @opts), -username => $user, -password => $pass);
}

=item $success = $driver->delete_source(%args)

Deletes the database and user given.

The arguments C<%args> accepted are:

=over

=item $username

The name of the user and database to be dropped.

=back

=cut

sub delete_source {
	my ($self, %args) = @_;
	my $user = $args{-username};

	croak "No source specified for deletion." unless defined $user;

	$self->handle->do(qq(
		DROP DATABASE $user
	));

	$self->handle->do(qq(
		DROP USER $user
	));

	1;
}

=item $success = $driver->create_table(%args)

Creates the table as described by the arguments. All C<PRIMARY>, C<UNIQUE>, and
C<LINK> keys will be added as constraints. See L</INDEXES> for details on how
these used. See L</TYPES> for information on column types.

=cut

sub create_table {
    my ($self, %args) = @_;
	my ($name, $columns, $indexes) = @args{qw(-table -columns -indexes)};
	
	# For now, we ignore column order (YUCK!)
	$columns = { @$columns };

    my $sql = "CREATE TABLE $name(";

    my @defs;
    while ( my ($name, $type) = each %$columns ) {
        my ($ttype, @args) = @$type;
        my $tname = TYPES->[$ttype];
        push @defs,
            ("$name $tname" . (scalar @args ?
                    '(' . (join ',', @args) . ')' : ''));
    }

    for my $index (@$indexes) {
        my ($type, @args) = @$index;

        SWITCH: {
            $type == PRIMARY && do {
				my $cols = shift @args;
                push @defs, 'PRIMARY KEY(' . (join ',', @$cols) . ')';
                last SWITCH;
            };
            $type == UNIQUE && do {
				my $cols = shift @args;
                push @defs, 'UNIQUE(' . (join ',', @$cols) . ')';
                last SWITCH;
            };
            $type == LINK && do {
                my ($locals, $ref, $remotes) = @args;
                push @defs,
                    'FOREIGN KEY(' . (join ',', @$locals) . ') ' .
                    'REFERENCES ' . $ref . '(' . (join ',', @$remotes) . ')';
                last SWITCH;
            };
            DEFAULT: do {
                $self->{-contentment}->error("Invalid index type $type.");
            };
        }
    }

    $sql .= (join ',', @defs) . ')';

    $self->handle->do($sql);

	1;
}

=item $success = $driver->delete_table(%args)

Deletes the given table from the database.

=cut

sub delete_table {
	my ($self, %args) = @_;
	my $name = $args{-table};

	eval {
		$self->handle->do(qq(
			DROP TABLE $name
		));
	}; if ($@) {
		croak $@;
	}

	1;
}

=item %columns = $driver->columns(%args)

Recreates the column definition used to create the table. This should work even
if the Persist driver didn't create the table, as long as it understands all
the types involved. This information is created by examining several
C<pg_catalog> tables.

See L</TYPES> for details on what types are used.

=cut

sub columns {
	my ($self, %args) = @_;
	my $name = $args{-table};

#	print STDERR "name: $name\n";
#	print STDERR "caller: ",join(',', caller),"\n";

	my $sth = $self->handle->column_info(undef, undef, $name, undef);
	my $rows = $sth->fetchall_arrayref({});

	my %results;
	for my $row (@$rows) {
		my $column_name = $row->{COLUMN_NAME};
		local $_ = $row->{DATA_TYPE};
		my @type;
		SWITCH: {
			/^varchar$/i && do {
				@type = ( VARCHAR, $row->{atttypmod}-4 );
				last SWITCH;
			};
			/^int4$/i && do {
				my $def_res = $self->handle->selectcol_arrayref(qq(
					SELECT d.adsrc
					FROM pg_attrdef d INNER JOIN pg_attribute a
					  ON d.adnum = a.attnum AND d.adrelid = a.attrelid
					     INNER JOIN pg_class c
					  on c.relfilenode = a.attrelid
					WHERE c.relname = '$name' and a.attname = '$column_name'
				));
				if (defined($def_res->[0]) and 
						$def_res->[0] =~ 
							/nextval\('[\w\.]*${name}_${column_name}_seq'::text\)/) {
					@type = ( AUTONUMBER );
				} else {
					@type = ( INTEGER );
				}
				last SWITCH;
			};
			/^bool$/i && do {
				@type = ( BOOLEAN );
				last SWITCH;
			};
			/^float8$/i && do {
				@type = ( REAL );
				last SWITCH;
			};
			/^timestamp$/i && do {
				@type = ( TIMESTAMP );
				last SWITCH;
			};
			DEFAULT: do {
				croak "Found $name.$column_name with unknown type \"$_\".";
			};
		}
		$results{$column_name} = [ @type ];
	}

	%results;
}

=item @indexes = $driver->indexes(%args)

Recreates the index definition used to create the table. This should work even
if the Persist driver didn't create the table. This information is created by
examining several C<pg_catalog> tables.

See L</INDEXES> for information on how indexes are mapped.

=cut

sub indexes {
	my ($self, %args) = @_;
	my $name = $args{-table};

	my $sth = $self->handle->primary_key_info(undef, undef, $name);
	my $rows = $sth->fetchall_arrayref({});

	my @pk = ( PRIMARY, [] );
	for my $row (@$rows) {
		push @{$pk[1]}, $row->{COLUMN_NAME};
	}

	my @results = ( [ @pk ] );

	my $keyarrays = $self->handle->selectcol_arrayref(qq(
			SELECT i.indkey
			FROM pg_index i, pg_class c
			WHERE c.relname = '$name' AND i.indrelid = c.relfilenode
			  AND i.indisprimary = 'f' AND indisunique = 't'
	));

	my $attsth = $self->handle->prepare(q(
			SELECT a.attname
			FROM pg_attribute a INNER JOIN pg_class c
			  ON a.attrelid = c.relfilenode
			WHERE c.relname = ? AND a.attnum = ?
	));

	for my $keyarray (@$keyarrays) {
		my @unique = ( UNIQUE, [] );
		for my $key (split / /, $keyarray) {
			$attsth->execute($name, $key);
			my $colname = $attsth->fetchrow_arrayref;
			push @{$unique[1]}, $colname->[0];
		}
		push @results, [ @unique ];
	}

	$sth = $self->handle->prepare(q(
			SELECT c.conkey, f.relname, c.confkey
			  FROM pg_constraint c INNER JOIN pg_class l
			    ON c.conrelid = l.relfilenode INNER JOIN pg_class f
				ON c.confrelid = f.relfilenode
			 WHERE l.relname = ? AND c.contype = 'f'
	));
	$sth->execute($name);
	my $foreignkeys = $sth->fetchall_arrayref({});
	
	for my $foreignkey (@$foreignkeys) {
		my @localcols;
		for my $key (split /[ ]/, substr($foreignkey->{conkey}, 1, length($foreignkey->{conkey})-2)) {
			$attsth->execute($name, $key);
			my $colname = $attsth->fetchrow_arrayref;
			push @localcols, $colname->[0];
		}

		my @foreigncols;
		for my $key (split /[ ]/, substr($foreignkey->{confkey}, 1, length($foreignkey->{confkey})-2)) {
			$attsth->execute($foreignkey->{relname}, $key);
			my $colname = $attsth->fetchrow_arrayref;
			push @foreigncols, $colname->[0];
		}
		
		push @results, [ LINK, [ @localcols ], $foreignkey->{relname}, 
							   [ @foreigncols ] ];
	}

	@results;
}

=item $value = $driver-E<gt>sequence_value(%args)

Returns the last C<AUTONUMBER> value used during an insert. An insert must have
been performed since the database connection was created for this method to
succeed.

=cut

sub sequence_value {
	my ($self, %args) = @_;
	my ($table, $column) = @args{qw(-table -column)};

	$self->handle->selectcol_arrayref(qq(
		SELECT CURRVAL('${table}_${column}_seq')
	))->[0]
}

=item @tables = $driver-E<gt>tables

Uses the L<DBI> C<tables> method to fetch the tables in the current schema.
This is a fix to L<Persist::Driver::DBI> for I<PostgreSQL> since some versions
want to prefix all tables with ``public.'', which is unacceptable for the
purposes of I<Persist>.

=cut

sub tables {
	my $self = shift;
	map { s/^public.//; $_ } $self->handle->tables(undef, undef, '', 'TABLE');
}
=back

=head2 TYPES

At this time, L<Persist> types are mapped as this table indicates:

  Persist Type                  PostgreSQL Type
  VARCHAR                          varchar
  INTEGER                          int4
  AUTONUMBER                       serial
  BOOLEAN                          bool
  REAL                             float8
  TIMESTAMP                        timestamp

The opposite direction isn't quite as easy as C<serial> is a pseudonym for
C<int4> with an attached sequence. When mapping in the opposite direction, any
C<int4> column is checked to see if it has an associated default value in a
sequence. If so, then it is a C<AUTONUMBER>. Otherwise, it is an C<INTEGER>.

=head2 INDEXES

The index mapping is straightforward. Indexes are mapped as described in this
table:

  Persist Index                 PostgreSQL Type
  PRIMARY                          PRIMARY KEY
  UNIQUE                           UNIQUE
  LINK                             FOREIGN KEY

The same mapping is applied in reverse.

=head1 SEE ALSO

L<Persist>, L<Persist::Driver>, L<Persist::Driver::DBI>, L<Persist::Source>,
L<DBI>, L<DBD::Pg>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

  Copyright (c) 2003, Andrew Sterling Hanenkamp
  All rights reserved.

  Redistribution and use in source and binary forms, with or without 
  modification, are permitted provided that the following conditions 
  are met:

    * Redistributions of source code must retain the above copyright 
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright 
      notice, this list of conditions and the following disclaimer in 
      the documentation and/or other materials provided with the 
      distribution.
    * Neither the name of the Contentment nor the names of its 
      contributors may be used to endorse or promote products derived 
      from this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
  COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
  POSSIBILITY OF SUCH DAMAGE.

=cut

1
