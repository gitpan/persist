package Persist::Driver::DBI::PostgreSQL;

use 5.8.0;
use strict;
use warnings;

use DBI;

use Persist qw(:constants :driver_help);
use Persist::Driver::DBI;
use Persist::Filter;

our @ISA = qw(Persist::Driver::DBI);

our ( $VERSION ) = '$Revision: 1.13 $' =~ /\$Revision:\s+([^\s]+)/;

use constant TYPES => [ 
	qw( varchar int4 serial bool float8 timestamptz )
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

=item $driver = new Persist::Driver::DBI::PostgreSQL($conn, $user, $pass)

Creates a new L<DBI> connection using the given connection string C<$conn>,
username C<$user>, and password C<$pass>.

The connection is created with AutoCommit set, PrintError unset, and RaiseError
set.

=cut

sub new {
	my ($class, $conn, $user, $pass) = @_;

	croak "No connection string." unless defined $conn;

	my $parsed_conn = _parse_conn($conn);
	croak "Illegal connection string $conn." unless $parsed_conn;

	my $self = $class->SUPER::new(DBI->connect
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

=item $driver->preprocess_filter($tables, $filter)

This method changes boolean values to literal strings 'true' and 'false' and
also converts L<Persist> style timestamps to PostgreSQL style dates.

=cut

sub preprocess_filter {
	my ($self, $tables, $filter) = @_;

	my ($preprocess_boolean, $preprocess_timestamp);
	my $process_ast = sub { 
		my ($a, $o, $b) = @{$_[0]};
		if ($a->isa('Persist::Filter::Identifier') and
				$b->isa('Persist::Filter::Number')) {
			&$preprocess_boolean($a, $b);
		} elsif ($a->isa('Persist::Filter::Number') and
				$b->isa('Persist::Filter::Identifier')) {
			&$preprocess_boolean($b, $a);
		} elsif ($a->isa('Persist::Filter::Identifier') and
				$b->isa('Persist::Filter::String')) {
			&$preprocess_timestamp($a, $b);
		} elsif ($a->isa('Persist::Filter::String') and
				$b->isa('Persist::Filter::Identifier')) {
			&$preprocess_timestamp($b, $a);
		}
	};
	
	my $ast = parse_filter($filter);
	if (scalar(keys %$tables) == 1) {
		my ($alias) = keys(%$tables);
		my ($name) = values(%$tables);
		my $cols = { $self->columns($name) };
		
		$preprocess_boolean = sub {
			my ($id, $lit) = @_;
			for my $col (keys %$cols) {
				if ($$cols{$col}[0] == BOOLEAN && 
						$$id =~ /(?:$alias.)?$col$/i && defined $$lit) {
					$$lit = $$lit == 0 ? "'false'" : "'true'";
				}
			}
		};

		$preprocess_timestamp = sub {
			my ($id, $lit) = @_;
			for my $col (keys %$cols) {
				if ($$cols{$col}[0] == TIMESTAMP &&
						$$id =~ /(?:$alias.)?$col$/i && defined $$lit) {
					my @ts = Persist->parse_timestamp(substr $$lit, 1, -1);
					$$lit = sprintf '\'%s%s-%s-%s %s:%s:%s%s %s\'',
									@ts[1 .. 2], $ts[3] + 1, @ts[4 .. 8],
									(int($ts[0]) ? 'AD' : 'BC');
				}
			}
		};
		
		$ast->remap_on('Persist::Filter::Comparison', $process_ast);
	} else {
		my $cols = {};
		while (my ($alias, $name) = each %$tables) { 
			$$cols{$alias} = +{ $self->columns($name) };
		}

		$preprocess_boolean = sub {
			my ($id, $lit) = @_;
			for my $alias (keys %$cols) {
				for my $col (keys %{$$cols{$alias}}) {
					if ($$cols{$alias}{$col}[0] == BOOLEAN &&
							$$id =~ /(?:$alias.)?$col$/i && defined $$lit) {
						$$lit = $$lit == 0 ? "'false'" : "'true'";
					}
				}
			}
		};

		$preprocess_timestamp = sub {
			my ($id, $lit) = @_;
			for my $alias (keys %$cols) {
				for my $col (keys %{$$cols{$alias}}) {
					if ($$cols{$alias}{$col}[0] == TIMESTAMP &&
							$$id =~ /(?:$alias.)?$col$/i && defined $$lit) {
						my @ts = Persist->parse_timestamp(substr $$lit, 1, -1);
						$$lit = sprintf '\'%s%s-%s-%s %s:%s:%s%s %s\'',
									@ts[1 .. 2], $ts[3] + 1, @ts[4 .. 8],
									(int($ts[0]) ? 'AD' : 'BC');
					}
				}
			}
		};
		
		$ast->remap_on('Persist::Filter::Comparison', $process_ast);
	}

	$ast->unparse;
}

=item $rows = $driver-E<gt>insert($name, \%values)

This is a wrapper for the C<insert> method of L<Persist::Driver::DBI> which
converts L<Persist> style dates to PostgreSQL style and boolean values to
literal strings 'true' and 'false'.

=cut

sub insert {
	my ($self, $name, $values) = @_;

	my %columns = $self->columns($name);
	while (my ($k, $v) = each %columns) {
		if ($v->[0] == TIMESTAMP and defined($values->{$k})) {
			my @ts = Persist->parse_timestamp($values->{$k});
			$values->{$k} = sprintf '%s%s-%s-%s %s:%s:%s%s %s',
					@ts[1 .. 2], $ts[3] + 1, @ts[4 .. 8],
					(int($ts[0]) ? 'AD' : 'BC');
		} elsif ($v->[0] == BOOLEAN and defined($values->{$k})) {
			$values->{$k} = ($values->{$k} ? 'true' : 'false');
		}
	}

	$self->SUPER::insert($name, $values);
}

=item $rows = $driver-E<gt>update($name, \%set [, $filter [, \@bindings ] ] )

This is a wrapper for the C<update> method of L<Persist::Driver::DBI> which
converts L<Persist> style dates to PostgreSQL style and boolean values to
literal strings 'true' and 'false'.

=cut

sub update {
	my ($self, $name, $set, $filter, $bindings) = @_;

	my %columns = $self->columns($name);
	while (my ($k, $v) = each %columns) {
		if ($v->[0] == TIMESTAMP and defined($set->{$k})) {
			my @ts = Persist->parse_timestamp($set->{$k});
			$set->{$k} = sprintf '%s%s-%s-%s %s:%s:%s%s %s',
					@ts[1 .. 2], $ts[3] + 1, @ts[4 .. 8],
					($ts[0] eq '+' ? 'AD' : 'BC');
		} elsif ($v->[0] == BOOLEAN and defined($set->{$k})) {
			$set->{$k} = ($set->{$k} ? 'true' : 'false');
		}
	}

	$self->SUPER::update($name, $set, $filter, $bindings);
}

=item $driver->first($handle)

This is a wrapper for the C<first> method of L<Persist::Driver::DBI> and
converts PostgreSQL style dates to L<Persist> style timestamps.

=cut

sub first {
	my ($self, $handle) = @_;
	my $tables = $handle->[0];

	my $results = $self->SUPER::first($handle);

	if (defined $results) {
		for my $name (@$tables) {
			my %columns = $self->columns($name);
			while (my ($k, $v) = each %columns) {
				if ($v->[0] == TIMESTAMP and defined($results->{$k})) {
					my @ts = $results->{$k} =~ /(\d+)-(\d+)-(\d+) (\d+):(\d+):(\d+)((?:\+|-)\d*)? ?((?:AD|BC)?)/;
					$results->{$k} = join '',
							(defined $ts[7] and $ts[7] eq 'BC' ? '-' : '+'),
							$ts[0], (sprintf '%02d', $ts[1] - 1), @ts[2 .. 5],
							(defined $ts[6] and length($ts[6]) == 0 ? '+0000' :
								(defined $ts[6] and length($ts[6]) == 3 ? $ts[6].'00' : $ts[6]));
				}
			}
		}
	}

	$results;
}

=item $driver->next($handle)

This is a wrapper for the C<first> method of L<Persist::Driver::DBI> and
converts PostgreSQL style dates to L<Persist> style timestamps.

=cut

# TODO Combine common code in first and next.

sub next {
	my ($self, $handle) = @_;
	my $tables = $handle->[0];

	my $results = $self->SUPER::next($handle);

	if (defined $results) {
		for my $name (@$tables) {
			my %columns = $self->columns($name);
			while (my ($k, $v) = each %columns) {
				if ($v->[0] == TIMESTAMP and defined($results->{$k})) {
					my @ts = $results->{$k} =~ /(\d+)-(\d+)-(\d+) (\d+):(\d+):(\d+)((?:\+|-)\d*)? ?((?:AD|BC)?)/;
					$results->{$k} = join '',
							(defined $ts[7] and $ts[7] eq 'BC' ? '-' : '+'),
							$ts[0], (sprintf '%02d', $ts[1] - 1), @ts[2 .. 5],
							(defined $ts[6] and length($ts[6]) == 0 ? '+0000' :
								(defined $ts[6] and length($ts[6]) == 3 ? $ts[6].'00' : $ts[6]));
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

=item @args = $driver->new_source($user, $pass)

Creates a new data source using the given username C<$user> and password
C<$pass> and returns the connection string to connect to the new database. This
will create a new PostgreSQL user with the given name and then a database of
the same name. The user will not be permitted to create databases or users.

=cut

sub new_source {
	my ($self, $user, $pass) = @_;

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
	
	(join(';', @opts), $user, $pass);
}

=item $success = $driver->delete_source($user)

Deletes the database and user associated with the username C<$user>.

=cut

sub delete_source {
	my ($self, $user) = @_;

	croak "No source specified for deletion." unless defined $user;

	$self->handle->do(qq(
		DROP DATABASE $user
	));

	$self->handle->do(qq(
		DROP USER $user
	));

	1;
}

=item $success = $driver->create_table($name, $columns, $indexes)

Creates the table as described by the arguments. All C<PRIMARY>, C<UNIQUE>, and
C<LINK> keys will be added as constraints. See L</INDEXES> for details on how
these used. See L</TYPES> for information on column types.

=cut

sub create_table {
    my ($self, $name, $columns, $indexes) = @_;

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

=item $success = $driver->delete_table($name)

Deletes the given table from the database.

=cut

sub delete_table {
	my ($self, $name) = @_;

	eval {
		$self->handle->do(qq(
			DROP TABLE $name
		));
	}; if ($@) {
		croak $@;
	}

	1;
}

=item %columns = $driver->columns($name)

Recreates the column definition used to create the table. This should work even
if the Persist driver didn't create the table, as long as it understands all
the types involved. This information is created by examining several
C<pg_catalog> tables.

See L</TYPES> for details on what types are used.

=cut

sub columns {
	my ($self, $name) = @_;

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
			/^timestamptz$/i && do {
				@type = ( TIMESTAMP );
				last SWITCH;
			};
			DEFAULT: do {
				croak "Unknown type \"$_\".";
			};
		}
		$results{$column_name} = [ @type ];
	}

	%results;
}

=item @indexes = $driver->indexes($name)

Recreates the index definition used to create the table. This should work even
if the Persist driver didn't create the table. This information is created by
examining several C<pg_catalog> tables.

See L</INDEXES> for information on how indexes are mapped.

=cut

sub indexes {
	my ($self, $name) = @_;

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

=item $value = $driver-E<gt>sequence_value($table, $column)

Returns the last C<AUTONUMBER> value used during an insert. An insert must have
been performed since the database connection was created for this method to
succeed.

=cut

sub sequence_value {
	my ($self, $table, $column) = @_;

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
  TIMESTAMP                        timestamptz

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
