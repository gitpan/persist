package Persist::Driver::DBI;

use 5.008;
use strict;
use warnings;

use Persist qw(:constants :driver_help);
use Persist::Driver;
use Persist::Filter;

our @ISA = qw(Persist::Driver);

our ( $VERSION ) = '$Revision: 1.14 $' =~ /\$Revision:\s+([^\s]+)/;

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
	
	my ($table, $filter, $order, $offset, $limit) = 
		@args{qw(-table -filter -order -offset -limit)};

	my $pp_filter;
	$pp_filter = $self->preprocess_filter(-aliases => [ $table ], -filter => $filter) 
			if $filter;
#debug#	print STDERR $pp_filter,"\n";

	my $sql = "SELECT * FROM $table";
	$sql .= " WHERE $pp_filter" if defined $filter;

	if (defined $order) {
		my @columns;
		for (my $i = 0; $i < @$order; ++$i) {
			my $column = $$order[$i];
			if ($i < $#$order and ($$order[$i] == ASCENDING or $$order[$i] == DESCENDING)) {
				push @columns, $column.' '.($$order[++$i] == ASCENDING ? 'ASC' : 'DESC');
			} else {
				push @columns, $column;
			}
		}

		$sql .= " ORDER BY ".join(', ', @columns);
	}

	$sql .= " OFFSET ".$offset if defined $offset;
	$sql .= " LIMIT ".$limit if defined $limit;
	
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

# determines if there is a path from $x to $y
sub _has_path {
	my ($self, $g, $x, $y) = @_;
	
	my %seen = ( $x => 1 );
	my @traverse = ( $g->successors($x) );
	while (@traverse) {
		my $vertex = shift @traverse;
		
		return 1 if $vertex eq $y;
		
		next if $seen{$vertex};
		
		$seen{$vertex}++;
		push @traverse, $g->successors($vertex);
	}

	return 0;
}

sub _rewrite_filter {
	my ($self, $columns, $filter) = @_;

	# We need to parse the filter
	my $ast = parse_filter($filter);

	# Walk the tree and convert any identifiers to the appropriate columns and
	# change each comparison operator to the appropriate type.
	$ast->remap_on('Persist::Filter::Comparison', sub {
		(my $a, local $_, my $b) = @{$_[0]};

		for my $id ($a, $b) {
			if ($id->isa('Persist::Filter::Identifier')) {
				croak "Use of unknown column name $$id in filter" unless exists $$columns{$$id};
				croak "Use of ambiguous column name $$id in filter" unless defined $$columns{$$id};
				$$id = $$columns{$$id};
			}
		}

	});

	return $ast->unparse;
}

sub open_join {
	my ($self, %args) = @_;
	my ($tables, $filter, $on, $order, $offset, $limit) = 
		@args{qw(-tables -filter -on -order -offset -limit)};

	# Setup SELECT
	my $sql = "SELECT ";
	my @table_columns;
	my @table_aliases = map { "t$_" } (1 .. @$tables);
	my $column_count = 0;
	my $columns;
	my @select;
	my %seen;
	for my $i (0 .. $#$tables) {
		my $name = $$tables[$i];
		my $table_num = ++$seen{$name};
		my %columns = $self->columns(-table => $name);
		my @column_names = keys %columns;
		
		for my $j (0 .. $#column_names) {
			my $column = $column_names[$j];
				
			my $to = "$table_aliases[$i].$column";

			for my $prefix ('', ($i + 1).".", "$name.", "$name$table_num.") {
				if (defined $$columns{"$prefix$column"}) {
					$$columns{"$prefix$column"} = undef; # exists but not defined
					next;
				} 
				
				$$columns{"$prefix$column"} = $to;
			}
		}

		my $start = $column_count;
		push @table_columns, 
			[ \@column_names, [ $start, ($column_count += @column_names) - 1 ] ];
		push @select, map({ "$table_aliases[$i].$_" } @column_names);
	}

	# Setup FROM and JOINs; if the columns have circular references, then we
	# will not "close the loop" when joining tables together
	$sql .= join(', ', @select)." FROM ";

	if (defined $on) {
		# This join is explicit, insert each on expression given between each
		# table in the FROM clause
		$on = [ $on ] unless ref $on;
		$sql .= "$$tables[0] $table_aliases[0]";
		for my $i (1 .. $#$tables) {
			$sql .= " INNER JOIN $$tables[$i] $table_aliases[$i]";
			if (defined $$on[$i - 1]) {
				$sql .= " ON ".$self->_rewrite_filter($columns, $$on[$i - 1]);
			}
		}
	} else {
		# Let's implicitly join these suckers
		#
		# FIXME The implicit join operation should be moved up into
		# Persist::Driver as it should be essentially the same from driver to
		# driver. We just have to figure out the filters to join at the
		# Persist::Driver level and then provide them as an explicit join to
		# each implementation.
		my %joinees;
		for my $i (0 .. $#$tables) {
			croak "Cannot implicitly join a table to itself; use the -on option instead."
				if $joinees{$$tables[$i]};
			$joinees{$$tables[$i]} = $i;
		}

		my %joined;
		for my $i (0 .. $#$tables) {
			my $name = $$tables[$i];
		
			# Loop through
			my @indexes = $self->indexes(-table => $name);
			for my $index (@indexes) {
				if ($index->[0] == LINK) {
					my $lflds = $index->[1];
					my $fname = $index->[2];
					my $rflds = $index->[3];

					if (defined $joinees{$fname}) {
						my $table1  = $table_aliases[$i];
						my $table2  = $table_aliases[$joinees{$fname}];
						if (not ($joined{$name} or $joined{$fname})) {
							$sql .=
								("$name $table1 INNER JOIN ".
								"$fname $table2 ON ".
								join(' AND ', 
									map { "$table1.$$lflds[$_] = $table2.$$rflds[$_]" }
										0 .. $#$lflds));
							$joined{$name} = 1;
							$joined{$fname} = 1;
						} elsif (not $joined{$name} and $joined{$fname}) {
							$sql .=
								(" INNER JOIN $name $table1 ON ".
								join(' AND ',
									map { "$table1.$$lflds[$_] = $table2.$$rflds[$_]" }
										0 .. $#$lflds));
							$joined{$name} = 1;
						} elsif ($joined{$name} and not $joined{$fname}) {
							$sql .=
								(" INNER JOIN $fname $table2 ON ".
								join(' AND ',
									map { "$table1.$$lflds[$_] = $table2.$$rflds[$_]" }
										0 .. $#$lflds));
							$joined{$fname} = 1;
						} # else ignore
					}
				}
			}
		}

		# Catch any remaining tables that aren't directly JOINED--which should be
		# used cautiously as this performs cross-product relational multiplication
		for my $i (0 .. $#$tables) {
			my $name = $$tables[$i];
			unless ($joined{$name}) {
				$sql .= ',' if %joined;
				$sql .= "$name $table_aliases[$i]";
				$joined{$name} = 1;
			}
		}

	}

	# At this point we are SELECTed and FROMed. Now, we see if there is a 
	# filter for WHEREing.
	if (defined $filter) {
		$filter = $self->preprocess_filter(
				-aliases => [ @$tables ],
				-filter => $filter,
		);

		$filter = $self->_rewrite_filter($columns, $filter);
		
		$sql .= " WHERE ".$filter;
	}

	if (defined $order) {
		my @columns;
		for (my $i = 0; $i < @$order; ++$i) {
			my $column = $$columns{$$order[$i]};
			no warnings "numeric";
			if ($i < $#$order and ($$order[$i + 1] == ASCENDING or $$order[$i + 1] == DESCENDING)) {
				push @columns, $column.' '.($$order[++$i] == ASCENDING ? 'ASC' : 'DESC');
			} else {
				push @columns, $column;
			}
		}

		$sql .= " ORDER BY ".join(', ', @columns);
	}

	$sql .= " OFFSET ".$offset if defined $offset;
	$sql .= " LIMIT ".$limit if defined $limit;
	
	# And we are done.
	my $sth = $self->handle->prepare($sql);
	$sth->execute;
	[ [ @$tables ], $sth, \@table_columns ];
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
		$sql .= " WHERE ".($self->preprocess_filter(-aliases => [ $name ], -filter => $filter));
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
	my ($handle, $bytable) = @args{qw(-handle -bytable)};

	if ($bytable && @$handle == 3) {
		my $sth = $handle->[1];
		$sth->finish;
		$sth->execute;

		my $row = $sth->fetchrow_arrayref;
		my $table_columns = $handle->[2];
		my @data;
		for my $i (0 .. @$table_columns) {
			my %hash;
			@hash{@{$$table_columns[$i][0]}} = @$row[$$table_columns[$i][1][0] .. $$table_columns[$i][1][1]];
			push @data, \%hash;
		}

		return \@data;
	} else {
		my $sth = $handle->[1];
		$sth->finish;
		$sth->execute;
		$sth->fetchrow_hashref;
	}
}

=item $row = $driver-E<gt>next($handle)

Fetches the next row.

=cut

sub next {
	my ($self, %args) = @_;
	my ($handle, $bytable) = @args{qw(-handle -bytable)};

	if ($bytable && @$handle == 3) {
		my $sth = $handle->[1];

		my $row = $sth->fetchrow_arrayref;
		my $table_columns = $handle->[2];
		my @data;
		my %hash;
		for my $i (0 .. $#$table_columns) {
			my %hash;
			@hash{@{$$table_columns[$i][0]}} = @$row[$$table_columns[$i][1][0] .. $$table_columns[$i][1][1]];
			push @data, \%hash;
		}

		return \@data;
	} else {
		my $sth = $handle->[1];
		$sth->fetchrow_hashref;
	}
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
