package Persist::Source;

use 5.008;
use strict;
use warnings;

use Carp;

use Getargs::Mixed;

use Persist::Join;
use Persist::Table;

our ( $VERSION ) = '$Revision: 1.11 $' =~ /\$Revision:\s+([^\s]+)/;

our $AUTOLOAD;

=head1 NAME

Persist::Source - Main class used for accessing Persist data

=head1 SYNOPSIS

  use Persist qw(:constants);
  use Persist::Source;

  $source = new Persist::Source(...);

  $source->new_table('folks', {
              folkid        => [ AUTONUMBER ],
              name          => [ VARCHAR, 20 ],
              age           => [ INTEGER ] }, [
              [ PRIMARY, [ 'folkid' ] ],
              [ UNIQUE, [ 'name' ] ] ]);

  $source->new_table('favorites', {
              favid         => [ AUTONUMER ],
              folkid        => [ INTEGER ],
              color         => [ VARCHAR, 20 ] }, [
              [ PRIMARY, [ 'favid' ] ],
              [ UNIQUE, [ 'folkid', 'color' ] ],
              [ LINK, [ 'folkid' ], 'folks', [ 'folkid' ] ] ]);

  $table = $source->folks;
  $join = $source->join([ 'folks', 'favorites' ]);
  $join2 = $source->join(
              [ 'folks', 'favorites' ]
			  "folks.fid = favorites.fid");

=head1 DESCRIPTION

This abstraction is the core of the Persist framework. This provides an easy
way to access persistent data.

=over

=item $source = new Persist::Source($driver, @args)

This connects to a Persist data source using the driver named C<$driver>. The
C<@args> argument is a special case to the mixed parameter passing syntax use by
Persist. Instead of being a literal argument, C<@args> is a set of named
(not mixed) arguments that are passed directly to the drivers.

=cut

sub new {
	my ($class, %args) = parameters('self', [qw(driver *)], @_);
	my $driver = $args{driver};

	delete $args{driver};
	$args{"-$_"} = delete $args{$_} for (keys %args);
	
	my $self = bless {}, ref $class || $class;

	croak "No driver specified." unless $driver;
	croak "Illegal driver package '$driver'."
			unless $driver =~ /^[a-z_][a-z0-9_]+(::[a-z_][a-z0-9_]+)*$/i;
	eval "package Persist::_firesafe; use $driver";
	$self->{-driver} = $driver->new(%args);

	$self;
}

=item $test = $source-E<gt>is_dba

Returns true if this object is permitted to use the C<create_source> and
C<delete_source> methods.

=cut

sub is_dba {
	my $self = shift;
	$self->{-driver}->is_dba;
}

=item @conn_args = $source-E<gt>new_source(@args)

Creates a new persistent source and returns the arguments required to pass to
the driver to access the new source. See driver documentation for the arguments
required.

The C<@args> list is a special case to the mixed argument syntax of Persist.
These are required to be named arguments as they are passed directly on to the
driver itself.

=cut

sub new_source {
	my ($self, @args) = @_;
	$self->{-driver}->new_source(@args);
}

=item $source-E<gt>delete_source(@args)

Deletes a persistent source. See driver documentation for the arguments
required.

The C<@args> list is a special case to the mixed argument syntax of Persist.
These are required to be named arguments as they are passed directly on to the
driver itself.

=cut

sub delete_source {
	my ($self, @args) = @_;
	$self->{-driver}->delete_source(@args);
}

=item $source-E<gt>new_table($table, \%columns, \@indexes)

Creates a new table in the persistent source. The C<$table> is the name of the
table to create. The C<%columns> is a hash where the keys are the column names
and the values are the types. The types are specified as an array reference
with the first element being the type constant and the rest arguments to that
type constant.

The C<@indexes> is an array of array references to each index definition. The
first element in an index definition is the index type constant and the rest
are arguments to the index definition.

See L<Persist> for information on type and index arguments.

=cut

sub new_table {
	my ($self, %args) = parameters('self', [qw(table columns indexes)], @_);
	my ($table, $columns, $indexes) = @args{qw(table columns indexes)};
	$columns = [ %$columns ] if ref $columns eq 'HASH';
	$self->{-driver}->create_table(
		-table => $table,
		-columns => $columns,
		-indexes => $indexes);
}

=item $source-E<gt>delete_table($table)

Delete the table naemd by C<$table>.

=cut

sub delete_table {
	my ($self, %args) = parameters('self', [qw(table)], @_);
	my $table = $args{table};
	$self->{-driver}->delete_table(-table => $table);
}

=item @tables = $source-E<gt>tables

Returns the names of all available tables in the database.

=cut

sub tables {
	my $self = shift;
	$self->{-driver}->tables;
}

=item $join = $source-E<gt>join(\@tables [, $on, $filter, \@order, $offset, $limit ] )

Returns a reference to a L<Persist::Join> object which may be used to access
columns of the joined tables. C<$tables> is a list of tables to join and
C<$filter> is a list of filters to apply to the tables, respectively.

If the C<@on> parameter is specified, then the tables will be joined
accordinging to user preference. If C<@on> is missing, the driver will attempt
to automatically join the given tables. Automatic joining only works when no
tables are repeated in the C<@tables> list (repeating tables will require the
user to use the C<@on> option.

Automatic joins are performed based upon each table's C<LINK> indexes.  This is
process is done as intelligently as I know how. It will use the first index it
finds between two tables to join them and will not use more than one index
during a join. Once all tables have been joined according to the indexes found,
the database operation is performed. Automatic joining works well when there
is only one index linking two tables. However, if multiple indexes join two
tables, the driver may not pick the index you want, so use C<@on> instead.

=over

=item @tables

This is the list of tables to draw records from.

=item $filter (optional)

This is a single filter to apply to the tables. Since a join might include two
tables with columns of the same name, you need to make sure you use unambiguous
column names. This is done by prepending a table identifier to the column. The
table identifier can be the name of the table (when the same table is not used
twice), the numeric index of the table in C<@tables> plus one, or the name of
the table with the occurance number on the end. The table identifier should be
separated from the column identifier by a period.

For example, if C<@tables> were set to C<[ 'A', 'B', 'A' ]>, these would all
be identical filters:

  "1.x = 2.x and 1.x = 3.y"
  "1.x = B1.x and 1.x = 3.y"
  "A1.x = B.x and A1.x = A2.y"
  "A1.x = 2.x and A1.x = A2.y"

=item @order (optional)

A list of columns that will be used for ordering. The list may also contain the
C<ASCENDING> or C<DESCENDING> constants following a column name to specify the
direction of the ordering. Without these constants the default is C<ASCENDING>.
(Note that C<ASC> and C<DESC>, respectively, are aliases to these constants.) In
this way, it may be convenient to use hash notation to make these a little more
explicit.

=item $offset (optional)

This is the number of records to skip before returning a result. If this causes
every matching row to be skipped, then no rows will be returned. No records are
skipped if this is unspecified.

=item $limit (optional)

This is the number of records to be returned. Once C<next> has been called
C<$limit> times on the table, C<next> will return no more records. All records
returned until the end of the table is reached if this is either unspecified or
set to 0--i.e., you cannot tell the join to return 0 records.

=back

=cut

sub join {
	my ($self, %args) = parameters('self', [qw(tables; on filter order offset limit)], @_);
	new Persist::Join($self->{-driver}, @args{qw(tables on filter order offset limit)});
}

=item $table = $source-E<gt>table($table [, $filter, \@order, $offset, $limit ])

Returns a reference to a L<Persist::Table> object which may be used to access
columns of the table.

=over

=item $table

The name of the table to retrieve information about.

=item $filter (optional)

The filter to use to pick out which records the table object will contain.

=item @order (optional)

A list of columns that will be used for ordering. The list may also contain the
C<ASCENDING> or C<DESCENDING> constants following a column name to specify the
direction of the ordering. Without these constants the default is C<ASCENDING>.
(Note that C<ASC> and C<DESC>, respectively, are aliases to these constants.) In
this way, it may be convenient to use hash notation to make these a little more
explicit. For example:

  -order => [ rank => DESCENDING, lastname => ASCENDING, firstname => ASCENDING ]

=item $offset (optional)

This is the (0-based) index of the first record to include in the results. If
this index points to an index after the last record that would be returned, the
table will be empty.

=item $limit (optional)

This is the number of records to be returned. Once C<next> has been called
C<$limit> times on the table, C<next> will return no more records.

=back

=cut

# FIXME An exception should occur in table when the given table doesn't exist.
sub table {
	my ($self, %args) = parameters('self', [qw(table; filter order offset limit)], @_);
	new Persist::Table($self->{-driver}, @args{qw(table filter order offset limit)});
}

=item $table = $source-E<gt>E<lt>I<table>E<gt>( [ $filter ] ) 

A shortcut to C<$source-E<gt>table('E<lt>tableE<gt>')>.

=cut

sub AUTOLOAD {
	my ($self, %args) = parameters('self', [qw(;filter order offset limit)], @_);
	my ($table) = $AUTOLOAD =~ /::([^:]+)$/;
	$self->table($table, @args{qw(filter order offset limit)});
}

sub DESTROY {
	# prevent AUTOLOAD from hooking
}

=item $source-E<gt>delete($table [, $filter ])

Deletes all records matching the given filter.

B<WARNING:> An undefined filter will delete all rows from the table.

Returns the number of rows deleted.

=cut

sub delete {
	my ($self, %args) = parameters('self', [qw(table; filter)], @_);
	my ($table, $filter) = @args{qw(table filter)};
	$self->{-driver}->delete(-table => $table, -filter => $filter);
}

=item $source-E<gt>insert($table, \%values)

Inserts a new row into the table named C<$table> with the values given in
\%values.

Returns 1 on success.

=cut

sub insert {
	my ($self, %args) = parameters('self', [qw(table values)], @_);
	my ($table, $values) = @args{qw(table values)};
	$self->{-driver}->insert(-table => $table, -values => $values);
}

=item $rows = $source-E<gt>update($table, \%set [, $filter ] )

Updates one or more rows in the table named C<$table>. Only rows matching
firlster will be updated and will be set to the values in C<%set>.

B<WARNING:> An undefined filter will update all rows.

Returns the number of rows altered.

=cut

sub update {
	my ($self, %args) = parameters('self', [qw(table set; filter)], @_);
	my ($table, $set, $filter) = @args{qw(table set filter)};
	$self->{-driver}->update(-table => $table, -set => $set, -filter => $filter);
}

=back

=head1 SEE ALSO

L<Persist>, L<Persist::Join>, L<Persist::Driver>, L<Persist::Table>

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


