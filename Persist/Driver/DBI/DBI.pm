package Persist::Driver::DBI;

use 5.008;
use strict;
use warnings;

use Persist qw(:constants :driver_help);
use Persist::Driver;
use Persist::Filter;

our @ISA = qw(Persist::Driver);

our ( $VERSION ) = '$Revision: 1.10 $' =~ /\$Revision:\s+([^\s]+)/;

=head1 NAME

Persist::Driver::DBI - Base class for Persist DBI drivers

=head1 SYNOPSIS

  package Some::Driver;

  use strict;
  use warnings;

  use Persist qw(:constants);

  use base 'Persist::Driver::DBI';

  sub new { ... }
  sub is_dba { ... }
  sub new_source { ... }
  sub delete_source { ... }
  sub new_table { ... }
  sub delete_table { ... }
  sub columns { ... }
  sub indexes { ... }
  sub sequence_value { ... }

=head1 DESCRIPTION

This is a base class for drivers that implement L<DBI> based database access.
This provides some basic functionality that should be fairly common to most
L<DBI> drivers.

This POD document is intended for use by driver developers and shouldn't
(generally) be relevent to developers just using the library. However, for
those interested in internals, feel free to read on.

=over

=item $driver = new Persist::Driver::DBI(%args)

After connecting to the database in it's new method, the implementor should
pass the reference to the L<DBI> handle to this new method to instantiate the
class. The handle will be stored in the ``-database'' key of the blessed hash
for the object--however, it should be accessed through C<handle>.

The arguments C<%args> accepted are:

=over

=item $database

A DBI database handle.

=back

=cut

# FIXME Throughout this code all tables and field names should be double quoted
# to make sure names are compatible everywhere.

sub new {
	my ($class, %args) = @_;

	my $self = bless {}, ref $class || $class;
	$self->{-database} = $args{-database};

	$self;
}

=item $dbh = $driver->handle

This method provides access to the L<DBI> dabatase connection handle.

=cut

sub handle {
	my $self = shift;
	$self->{-database};
}

=item @tables = $driver-E<gt>tables

Uses the L<DBI> C<tables> method to fetch the tables in the current schema.

=cut

sub tables {
	my $self = shift;
	$self->handle->tables(undef, undef, '', 'TABLE');
}

=item $pp_filter = $driver-E<gt>preprocess_filter(%args)

Processes a filter to turn it into a proper WHERE clause for the DBI
driver.  The default implementation returns the string unchanged or raises an
exception if it is not parsable by L<Persist::Filter/parse_filter>.
Implementations that need to process a filter should look into using
L<Persist::Filter> as an aid.

This method is called whenever a filter is used in an SQL query.

The arguments C<%args> accepted are:

=over

=item $aliases

The C<$aliases> argument is a hash reference of tables and aliases. Each key is
an alias to the table the key points to. This allows the preprocessor to perform
processing based upon the structure of the tables. If the tables aren't aliased,
then the table names will be both the key and value.

=item $filter

The filter to process.

=back

Returns the processed filter.

=cut

sub preprocess_filter { 
	my ($self, %args) = @_;
	if (defined parse_filter($args{filter})) { $args{filter} } 
	else { croak "invalid filter $args{filter}" }
}

=item $handle = $driver-E<gt>open_table(%args)

Returns a two element array reference. The first element of this reference is
another array reference containing the name of the table opened. The second
element is a reference to a L<DBI> statement handle. The filter will be
processed via C<preprocess_filter> prior to being inserted as the C<WHERE>
clause of the SQL statement.

See L<Persist::Driver> for a description of the arguments.

=cut

sub open_table {
	my ($self, %args) = @_;
	
	my ($table, $filter) = @args{qw(-table -filter)};

	my $pp_filter;
	$pp_filter = $self->preprocess_filter(-aliases => {$table => $table}, -filter => $filter) 
			if $filter;
#debug#	print STDERR $pp_filter,"\n";

	my $sql = "SELECT * FROM $table";
	$sql .= " WHERE $pp_filter" if $filter;
	
	my $sth = $self->handle->prepare($sql);
	$sth->execute;
	[ [ $table ], $sth ];
}

=item $handle = $driver-E<gt>open_join(%args)

Returns a two element array of the same form returned by C<open_table>, except
that the first element is an array reference containing the names of all tables
joined. The tables are joined using an C<INNER JOIN> expression in the C<FROM>
clause based upon the information returned by C<indexes>. The filters will be
joined together with an C<AND> operator and then processed by
C<preprocess_filter>.

The C<ON> clauses of the joins are not currently run through
C<preprocess_filter>, this is not yet considered a bug, but will be if such
preprocessing is needed by a derived driver in the future. (The C<ON> clauses
are simple enough that it is probably reasonable to assume that such
preprocessing is only likely to add overhead rather than utility.)

See L<Persist::Driver> for a description of the arguments.

=cut

sub open_join {
	my ($self, %args) = @_;
	my ($tables, $filter) = @args{qw(-tables -filter)};

	# Setup SELECT and column name prefixes
	my $sql = "SELECT ";
	my @aliased;
	my %table_name;
	my $i = 0;
	my @table_schema_names;
	for my $table (@$tables) {
		if (ref $table) {
			my ($name, $prefix) = @$table;
			push @table_schema_names, $name;
			$table_name{$name} = "t$i";
			my %flds = $self->columns(-table => $name);
			push @aliased, map { "t$i.$_ as ${prefix}_$_" } keys(%flds);
		} else {
			push @table_schema_names, $table;
			$table_name{$table} = "t$i";
			push @aliased, "t$i.*";
		}
		++$i;
	}

	# Setup FROM and JOINs; if the columns have circular references, then we
	# will not "close the loop" when joining tables together
	$sql .= join(',', @aliased) . " FROM ";

	my %joined;
	for my $table (@$tables) {
		my $name = ref $table ? $table->[0] : $table;
		
		my @indexes = $self->indexes(-table => $name);
		for my $index (@indexes) {
			if ($index->[0] == LINK) {
				my $lflds = $index->[1];
				my $fname = $index->[2];
				my $rflds = $index->[3];
				# make sure the foreign table is to be joined
				if ($table_name{$fname}) {
					if (not ($joined{$name} or $joined{$fname})) {
						$sql .=
							("$name $table_name{$name} INNER JOIN ".
							"$fname $table_name{$fname} ON ".
							join(' AND ', 
								map { "$table_name{$name}.$lflds->[$_] = $table_name{$fname}.$rflds->[$_]" }
									0 .. $#$lflds));
						$joined{$name} = 1;
						$joined{$fname} = 1;
					} elsif (not $joined{$name} and $joined{$fname}) {
						$sql .=
							(" INNER JOIN $name $table_name{$name} ON ".
							join(' AND ',
								map { "$table_name{$name}.$lflds->[$_] = $table_name{$fname}.$rflds->[$_]" }
									0 .. $#$lflds));
						$joined{$name} = 1;
					} elsif ($joined{$name} and not $joined{$fname}) {
						$sql .=
							(" INNER JOIN $fname $table_name{$fname} ON ".
							join(' AND ',
								map { "$table_name{$name}.$lflds->[$_] = $table_name{$fname}.$rflds->[$_]" }
									0 .. $#$lflds));
						$joined{$fname} = 1;
					} # else ignore
				}
			}
		}
	}

	# Catch any remaining tables that aren't directly JOINED--which should
	# be used cautiously as this performs cross-product relational 
	# multiplication
	for my $table (@$tables) {
		my $name = ref $table ? $table->[0] : $table;
		unless ($joined{$name}) {
			$sql .= ',' if %joined;
			$sql .= "$name $table_name{$name}";
			$joined{$name} = 1;
		}
	}

	# At this point we are SELECTed and FROMed. Now, we see if there is a 
	# filter for WHEREing.
	if ($filter) {
		for ($i = 0; $i < @$filter; ++$i) {
			if (defined $filter->[$i]) {
				my $ast = parse_filter($filter->[$i]);
				my $name = ref $tables->[$i] ? $tables->[$i][0] : $tables->[$i];
				$ast->remap_on('Persist::Filter::Identifier', 
					sub { my $col = shift; $$col = "$table_name{$name}.$$col" });
				$filter->[$i] = $ast->unparse;
			}
		}
	}

	if ($filter) {
		my $where = $self->preprocess_filter(
				-aliases => { reverse(%table_name) },
				-filter => join(" AND ", map { $_ ? $_ : () } @$filter)
		);
		$sql .= " WHERE ".$where;
	}

	# And we are done.
	my $sth = $self->handle->prepare($sql);
	$sth->execute;
	[ [ @table_schema_names ], $sth ];
}

=item $handle = $driver-E<gt>open_explicit_join(%args)

Returns an array reference of the same form returned by C<open_join>.  The
tables are joined using an C<INNER JOIN> expression with the C<ON> clauses
specified by the user. The filter is processed by C<preprocess_filter> prior to
being used in the C<WHERE> clause.

As in C<open_join>, the C<ON> expressions are not preprocessed. This is, again,
not yet considered a bug, but will be if it is discovered that this behavior is
problematic. Since the C<ON> expressions are specified by the user rather than
by this package definition, it is much more likely that this will have
problems, but since C<ON> filters are still, generally, very simple, such
problems aren't expected.

See L<Persist::Driver> for a description of the arguments.

=cut

sub open_explicit_join {
	my ($self, %args) = @_;
	
	my ($tables, $on_exprs, $filter) = @args{qw(-tables -on_exprs -filter)};

	# Setup SELECT and column name prefixes
	my $sql = "SELECT ";
	my @aliased;
	my %alias_name;
	my @table_schema_names;
	for (my $i = 0; $i < @$tables; $i += 2) {
		my $alias = $tables->[$i];
		if (ref $tables->[$i+1]) {
			my ($name, $prefix) = @{$tables->[$i+1]};
			push @table_schema_names, $name;
			$alias_name{$name} = $alias;
			my %flds = $self->columns(-table => $name);
			push @aliased, map { "$alias.$_ as ${prefix}_$_" } keys(%flds);
		} else {
			push @table_schema_names, $tables->[$i+1];
			$alias_name{$tables->[$i+1]} = $alias;
			push @aliased, "$alias.*";
		}
	}

	$sql .= join(',', @aliased) . " FROM ";

	my $i = 2;
	$sql .= $tables->[1].' '.$tables->[0];
	for my $on_expr (@$on_exprs) {
		$sql .= ' INNER JOIN '.$tables->[$i+1].' '.$tables->[$i].' ON ';
		$sql .= $on_expr;
	}

	# At this point we are SELECTed and FROMed. Now, we see if there is a 
	# filter for WHEREing.
	$sql .= " WHERE ".($self->preprocess_filter(
							-aliases => { reverse(%alias_name) }, -filter => $filter)) if $filter;

	# And we are done.
	my $sth = $self->handle->prepare($sql);
	$sth->execute;
	[ [ @table_schema_names ], $sth ];
}

=item $rows = $driver-E<gt>insert(%args)

See L<Persist::Driver> for a description of this method..

=cut

sub insert {
	my ($self, %args) = @_;
	
	my ($name, $values) = @args{qw(-table -values)};

	my $sql = "INSERT INTO $name (".join(",",keys(%$values)).") ".
			  "VALUES (".join(",",("?") x scalar(keys(%$values))).")";
#debug#	print STDERR $sql,"\n";
	my $sth = $self->handle->prepare($sql);
	$sth->execute(values(%$values));
}

=item $rows = $driver-E<gt>update(%args)

Updates zero or more rows. The filter is processed by C<preprocess_filter>
prior to use in the C<WHERE> clause.

=cut

sub update {
	my ($self, %args) = @_;
	
	my ($name, $set, $filter, $bindings) = @args{qw(-table -set -filter -bindings)};

	my $sql = "UPDATE $name SET ".join(",", map { "$_ = ?" } keys(%$set));
	if ($filter) {
		$sql .= " WHERE ".($self->preprocess_filter(-aliases => {$name=>$name}, -filter => $filter));
	}

#debug#	print STDERR "update SQL: $sql\n";

	my $sth = $self->handle->prepare($sql);
	$sth->execute(values(%$set), $bindings ? @$bindings : ());
}

=item $rows = $driver-E<gt>delete(%args)

Delets zero or more rows. The filter is processed by C<preprocess_filter> prior
to use in the C<WHERE> clause.

=cut

sub delete {
	my ($self, %args) = @_;
	
	my ($name, $filter, $bindings) = @args{qw(-table -filter -bindings)};

	my $sql = "DELETE FROM $name";
	if ($filter) {
		$sql .= " WHERE $filter";
	}
	my $sth = $self->handle->prepare($sql);
	$sth->execute($bindings ? @$bindings : ());
}

=item $row = $driver-E<gt>first($handle)

In accordance with the C<DBI> specification, the C<finish> method is called on
the handle to clean up the statement handle, then execute is called again and
the first row is fetched. This method probably has much higher overhead than a
simple C<next> call.

=cut 

# QUESTION Can we know if fetchrow_hashref hasn't been called? If so, wouldn't
# it be better to call next rather than finish, execute, fetchrow_hashref in
# the case that the handle is already at the first row?
sub first {
	my ($self, %args) = @_;
	my $handle = $args{-handle};

	my $sth = $handle->[1];
	$sth->finish;
	$sth->execute;
	$sth->fetchrow_hashref;
}

=item $row = $driver-E<gt>next($handle)

Fetches the next row.

=cut

sub next {
	my ($self, %args) = @_;
	my $handle = $args{-handle};

	my $sth = $handle->[1];
	$sth->fetchrow_hashref;
}

=item $driver-E<gt>DESTROY

Disconnects from the database. If a derived driver needs to override C<DESTROY>
it is important that the driver make a call to C<SUPER::DESTROY> to disconnect
from the database as some L<DBD> drivers don't like to reach C<DESTROY> without
seeing a C<disconnect> first.

=cut

sub DESTROY {
	my $self = shift;
	$self->handle->disconnect if $self->handle;
}

=back

=head1 SEE ALSO

L<Persist>, L<Persist::Driver>, L<DBI>

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
