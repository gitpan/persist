package Persist::Source;

use 5.008;
use strict;
use warnings;

use Carp;

use Persist::Join;
use Persist::Table;

our ( $VERSION ) = '$Revision: 1.6 $' =~ /\$Revision:\s+([^\s]+)/;

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
  $join2 = $source->explicit_join(
              [ O => 'folks', A => 'favorites' ]
			  "O.fid = A.fid");

=head1 DESCRIPTION

This abstraction is the core of the Persist framework. This provides an easy
way to access persistent data.

=over

=item $source = new Persist::Source($driver, @args)

This connects to a Persist data source using the driver named C<$driver>. The
arguments C<@args> are passed to the driver.

=cut

sub new {
	my ($class, $driver, @args) = @_;
	
	my $self = bless {}, ref $class || $class;

	croak "No driver specified." unless $driver;
	croak "Illegal driver package '$driver'."
			unless $driver =~ /[a-z_][a-z0-9_]+(::[a-z_][a-z0-9_]+)*/i;
	eval "package Persist::_firesafe; use $driver";
	$self->{-driver} = $driver->new(@args);

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

=cut

sub new_source {
	my ($self, @args) = @_;
	$self->{-driver}->new_source(@args);
}

=item $source-E<gt>delete_source(@args)

Deletes a persistent source. See driver documentation for the arguments
required.

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
	my ($self, $table, $columns, $indexes) = @_;
	$self->{-driver}->create_table($table, $columns, $indexes);
}

=item $source-E<gt>delete_table($table)

Delete the table naemd by C<$table>.

=cut

sub delete_table {
	my ($self, $table) = @_;
	$self->{-driver}->delete_table($table);
}

=item @tables = $source-E<gt>tables

Returns the names of all available tables in the database.

=cut

sub tables {
	my $self = shift;
	$self->{-driver}->tables;
}

=item $join = $source-E<gt>join($tables, $filters)

Returns a reference to a L<Persist::Join> object which may be used to access
columns of the joined tables. C<$tables> is a list of tables to join and
C<$filters> is a list of filters to apply to the tables, respectively.

This method tries to automatically join tables based upon their C<LINK>
indexes.  This is process is done as intelligently as I could divine, but
cannot join a table to itself--at least not currently. It will also use the
first indexes it finds between two tables and will not use more than one index
during a join.  Finally, it will not look for links between tables that will
result in a circular joining.

For more complicated joining, try C<explicit_join>.

=cut

sub join {
	my ($self, $join, $filter) = @_;
	new Persist::Join($self->{-driver}, $join, $filter);
}

=item $join = $source-E<gt>explicit_join($tables, $as_exprs, $filter)

This performs a more explicit form of the join operation. This allows the user
to pick the fields joined upon in the case that there is no key constraint to
guide the I<Persist> system or when such implicit joins are otherwise
inappropriate. The arguments to this method are a little more complicated than
most, but should make sense:

=over

=item $tables

This argument is an array reference with the appearance of a hash. There should
be an even number of elements in the array. The even indexed attributes are
table name aliases, which are followed by the odd attributes which are table
names. This allows a table to be explicitly joined to itself.  Here is an
example,

  [ O => 'Folks', A => 'Favorites' ]

For those that might not know, the arrow (=>) is equivalent to comma (,) except
that it causes the preceding value to be stringified (i.e., interpreted as a
string). (Wacky Perl syntactic sugar. ;)

=item $as_exprs

This is an array reference to a set of strings. There should be one expression
for each join. Joins are performed in the order they are specified in
C<$tables>. The first two tables given will be joined first by the first
expression in the first element of C<$as_exprs>. The third table will be joined
to the first two by the second element. The fourth table by the third element,
etc. The expressions should use the table name aliases given in the C<$table>
argument.

If there's only one expression, i.e. only two tables in the join, you may omit
the array reference and just include the expression as a string. If a full
cross-product (unqualified join) is desired, then the C<undef> value should be
used in place of the expression. B<WARNING: A full cross-product join can be
extremely inefficient in some contexts.>

=item $filter

This string has the same purpose as the C<$filters> argument to the other
C<join> method. However, this method is always a single string. This variable
should also use the table name aliases given in the C<$table> argument.

=back

=cut

sub explicit_join {
	my ($self, $tables, $as_exprs, $filter) = @_;
	Persist::Join->new_explicit($self->{-driver}, 
			$tables, $as_exprs, $filter);
}

=item $table = $source-E<gt>table($table, $filter)

Returns a reference to a L<Persist::Table> object which may be used to access
columns of the table.

=cut

# FIXME An exception should occur in table when the given table doesn't exist.
sub table {
	my ($self, $table, $filter) = @_;
	new Persist::Table($self->{-driver}, $table, $filter);
}

=item $table = $source-E<gt>E<lt>I<table>E<gt>( [ $filter ] ) 

A shortcut to C<$source-E<gt>table('E<lt>tableE<gt>')>.

=cut

sub AUTOLOAD {
	my ($self, $filter) = @_;
	my ($table) = $AUTOLOAD =~ /::([^:]+)$/;
	$self->table($table, $filter);
}

sub DESTROY {
	# prevent AUTOLOAD from hooking
}

=item $source-E<gt>delete($table, $filter)

Deletes all records matching the given filter.

B<WARNING:> An undefined filter will delete all rows from the table.

Returns the number of rows deleted.

=cut

sub delete {
	my ($self, $table, $filter) = @_;
	$self->{-driver}->delete($table, $filter);
}

=item $source-E<gt>insert($table, \%values)

Inserts a new row into the table named C<$table> with the values given in
\%values.

Returns 1 on success.

=cut

sub insert {
	my ($self, $table, $values) = @_;
	$self->{-driver}->insert($table, $values);
}

=item $rows = $source-E<gt>update($table, \%set [, $filter ] )

Updates one or more rows in the table named C<$table>. Only rows matching
firlster will be updated and will be set to the values in C<%set>.

B<WARNING:> An undefined filter will update all rows.

Returns the number of rows altered.

=cut

sub update {
	my ($self, $table, $set, $filter) = @_;
	$self->{-driver}->update($table, $set, $filter);
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


