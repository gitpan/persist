package Persist::Driver;

use 5.008;
use strict;
use warnings;

our ( $VERSION ) = '$Revision: 1.3 $' =~ /\$Revision:\s+([^\s]+)/;

=head1 NAME

Persist::Driver - Base class for Persist drivers

=head1 SYNOPSIS

  package Some::Driver;

  use Persist qw(:constants);
  use Persist::Driver;
  @ISA = qw( Persist::Driver );

  sub new { ... }
  sub is_dba { ... }
  sub new_source { ... }
  sub delete_source { ... }
  sub new_table { ... }
  sub delete_table { ... }
  sub tables { ... }
  sub open_table { ... }
  sub open_join { ... }
  sub open_explicit_join { ... }
  sub insert { ... }
  sub update { ... }
  sub delete { ... }
  sub columns { ... }
  sub indexes { ... }
  sub first { ... }
  sub next { ... }
  sub sequence_value { ... }

=head1 DESCRIPTION

This module defines the functionality required for all Persist drivers. The
interface is meant to be independent of the backing store architecture. It
should be able to relatively easily provide access to SQL database, LDAP
directories, memory structures, file structures, etc.

Implementors should never call the C<SUPER> version of any method in this
package as they are all defined to die with an error message.

=over

=item $driver = new Persist::Driver(@construct_args)

The implementation may define any arguments it likes to be passed to the
constructor. What the constructor does is completely up to the implementation.

=cut

sub new {
	die "Must be implemented by driver.";
}

=item $test = $driver-E<gt>is_dba

Returns whether the connection is for a DBA/sysadmin user. This basically tells
us whether or not a call to C<new_source> and C<delete_source> can succeed.

=cut

sub is_dba {
	die "Must be implemented by driver.";
}

=item @connect_args = $driver-E<gt>new_source(@create_args)

Creates a new data source if the current user is capable. It returns the
arguments required to connect to this new database. The arguments that must be
passed to the driver to create a connection are driver dependent.

=cut

sub new_source {
	die "Must be implemented by driver.";
}

=item $success = $driver-E<gt>delete_source(@delete_args)

Deletes an existing data source if the current user is capable. It returns true
upon success. The arguments that must be passed to delete the source are driver
dependent.

=cut

sub delete_source {
	die "Must be implemented by driver.";
}

# TODO We need an API to allow for the discovery of what parameters are
# necessary for creating/deleting/connecting to sources. Perhaps something
# similar to a table definition to take advantage of our metadata system.

=item $success = $driver-E<gt>create_table($name, \@columns, \@indexes)

Creates a new ``table'' in the data source. Even if the data source is
not relational, the closest approximation to a table should be used.
The implementation should provide the columns presented in this
definition with lenient typing--that is, a column should be able to
hold all values of the type given, but isn't required to restrict the
values to only that type. The indexes are provided as a general
guideline, but are not required to be enforced. In general, though,
enforcing at least the C<PRIMARY> index is recommended.

Even though a driver is not required to enforce them. It must, however,
remember the settings for the purposes of the C<indexes> method and for
providing functionality for joining tables. 

The method returns true on successful table creation.

=cut

sub create_table {
	die "Must be implemented by driver.";
}

=item $success = $driver-E<gt>delete_table($name)

Deletes the table named by C<$name>. Returns true upon successful deletion of
the table (or equivalent object in the store). This should effectively
annihilate the description of the table and all data associated with it.

=cut

sub delete_table {
	die "Must be implemented by driver.";
}

=item @tables = $driver-E<gt>tables

Returns a list of all the table names in the data source. This may return tables
that were not created by the source (such as preexisting data), but should not
return system tables or the equivalent.
=cut

sub tables {
	die "Must be implemented by driver.";
}

=item $handle = $driver-E<gt>open_table($table [, $filter ] )

Returns a handle which may be used to fetch information out of a single table
in the database. The name of the table is specified in the C<$table> argument.
The optional C<$filter> argument may be used to narrow the results. See
L<Persist::Filter/FILTERS> for details on the format of C<$filter>.

=cut

sub open_table {
	die "Must be implemented by driver.";
}

=item $handle = $driver-E<gt>open_join(\@tables [, \@filters ] )

Returns a handle which may be used to fetch information out of a group of tables
that are joined according to their C<LINK> indexes. The array C<@tables> is a
list of table names to join. If the list of tables contains a circular set of
C<LINK> constraints, then latter tables will not be completely joined.
Otherwise, we might create a set of constraints that cannot be or can barely be
satisfied. It is possible to join two unrelated tables, but doing so will create
a cross-product of the records, which is generally undesirable for performance
reasons.

In addition to the C<LINK> constraints, the user may specify one or more
filters. The C<@filters> array contains one filter per table in C<@tables> and
the filters are matched to a table in C<@tables> respectively. It is permissible
for the filters array to be shorter than the array of tables if a filter is not
defined for all tables.  Undefined filters can be specified with the C<undef>
value.

See L<Persist::Filter/FILTERS> for details on the format of the filters.

=cut

sub open_join {
	die "Must be implemented by driver.";
}

=item $handle = $driver-E<gt>open_explicit_join(\@tables, \@as_exprs [, $filter ] )

Returns a handle which may be used to fetch information out of a group of tables
that are joined according to the explicit information given by the user. The
array C<@tables> is a list of table name aliases followed by table names of
those tables to join. The array C<@as_exprs> contains the expressions used to
join each set of tables. Tables are joined in the order given with each
C<@as_exprs> expression in the I<n>th place joining the table in the (I<n>+1)th
with all tables prior to and including the I<n>th. The table name aliases should
be used in the expressions during join. Expressions that are set to C<undef>
should either result in an implicit join or a full cross-product of the
relations--depending upon the driver implementation.

In addition to the explicit constraints, the user may specify a filter.  The
C<$filter> string contains a filter expression and should use the table name
aliasees in C<@tables>.

See L<Persist::Filter/FILTERS> for details on the format of the filters and AS
expressions.

=cut

sub open_explicit_join {
	die "Must be implemented by driver."
}

=item $rows = $driver-E<gt>insert($name, \%values)

Inserts a new row into the table named C<$name>. The hash C<%values> maps
column names (keys) to values (values). The result is the number of rows
modified (should always be one on success).

=cut

sub insert {
	die "Must be implemented by driver.";
}

=item $rows = $driver-E<gt>update($name, \%set [, $filter [,
\@bindings ] ] )

Updates zero or more entries in the table named C<$name>. The hash C<%set> maps
column names (keys) to values (values). The optional filter specifies the
criteria by which rows will be matched to determine whether or not to update
them. The final optional bindings array is an array of bindings values.

B<WARNING:> An undefined filter will update all rows.

Returns the number of rows affected.

See L<Persist::Filter/FILTERS> for details on the format of the filter and
bindings.

=cut

# TODO Design a way for update to perform a filtered update. That is, it would
# be nifty to do something like update('table', value => sub { $_ + 1 }) or
# something similar that could be used by the back-end in the most appropriate
# way.

sub update {
	die "Must be implemented by driver.";
}

=item $rows = $driver-E<gt>delete($name [, $filter [, \@bindings ] ] )

Deletes zero or more entries from the table named C<$name>. The
optional filter specifies the criteria by which rows will be matched
for deletion. The final optional bindings argument is an array of
binding values

B<WARNING:> An undefined filter will delete all rows from the table.

Returns the number of rows affected.

See L<Persist::Filter/FILTERS> for details on the format of the filter and
bindings.

=cut

sub delete {
	die "Must be implemented by driver.";
}

=item %columns = $driver-E<gt>columns($name)

Returns the column definition used to define the table. This must work for
tables created by the driver and also for any others that are listed by
C<tables>.

=cut

sub columns {
	die "Must be implemented by driver.";
}

=item @indexes = $driver-E<gt>indexes($name)

Returns the index definition used to define the table. This must work for
tables created by the driver and also for any others that are listed by
C<tables>.

=cut

sub indexes {
	die "Must be implemented by driver.";
}

=item $row = $driver-E<gt>first($handle)

Returns the first record found according to the given C<$handle> that was
created with a call to C<open_table> or C<open_join> or C<open_explicit_join>.
The C<$row> returned is a hash reference where column names are the keys and
their values are the values. This is called as an alternative to C<next> to
reset the "cursor" position to the top of the results.

If no results are available, then this method will return C<undef>.

=cut

sub first {
	die "Must be implemented by driver.";
}

=item $row = $driver-E<gt>next($handle)

Returns the next record found according to the given C<$handle> that was
created with a call to C<open_table> or C<open_join> C<open_explicit_join>. The
C<$row> returned is a hash reference where column names are the keys and their
values are the values. This moves the "cursor" position ahead one row.

If no more results remain, then this method will return C<undef>. An exception
may be thrown if this method is called after either C<first> or C<next> has
already returned C<undef>.

=cut

sub next {
	die "Must be implemented by driver.";
}

=item $value = $driver-E<gt>sequence_value($table, $column)

In the case of C<AUTONUMBER> columns, this method returns the last inserted
numeric value into column C<$column> of table C<$table>. If no I<recent> insert
has been made or the column is not of type C<AUTONUMBER> an exception will be
thrown. Whether or not the last insert into a table is recent will depend upon
back-end. However, it should generally be safe to assume that an insertion made
since the current connection is recent.

=cut

sub sequence_value {
	die "Must be implemented by driver.";
}

=back

=head1 SEE ALSO

L<Persist>, L<Persist::Source>, L<Persist::Table>, L<Persist::Join>

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
