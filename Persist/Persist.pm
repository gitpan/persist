package Persist;

# TODO For this documentation (or somewhere) list those keywords that should
# be avoided because they are a part of ANSI SQL or a specific driver's
# implementation--that is, they shouldn't be used for table or column names.

use 5.008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 
	'constants' => [ qw(
		VARCHAR INTEGER AUTONUMBER BOOLEAN REAL TIMESTAMP
		PRIMARY UNIQUE LINK
	) ],
	'driver_help' => [ qw(
		croak carp
	) ],
);

our @EXPORT_OK = ( 
	@{ $EXPORT_TAGS{'constants'} },
	@{ $EXPORT_TAGS{'driver_help'} },
);

our $VERSION = '0.5.1';

=head1 NAME

Persist - This class contains constants and helpers for the Persist framework

=head1 SYNOPSIS

  use Persist qw(:constants);

  # ... use 'em ...

=head1 DESCRIPTION

If you are looking for usage information related to I<Persist> the best
starting place is L<Persist::Source>.

This class contains constants and help functions for the Persist framework.
There are two sets of constants: types and indexes. The helper functions are
described below.

=head2 TYPES

The types are:

=over

=item VARCHAR

Limited length variable length string. Use of this type should be following by
a single numeric value which is the maximum number of characters that should be
used in values stored in this type of column. The maximum limit of data that
may be stored in a VARCHAR will depend greatly upon the implementation. It is
suggested that the drivers try to use a type that will allow up to 5000
characters to be stored.

=cut

use constant VARCHAR 		=> 0;

=item INTEGER

Integer value type. Takes no arguments and should store any 32-bit integer
value.

=cut

use constant INTEGER 		=> 1;

=item AUTONUMBER

Integer sequence type. This column provides a unique default value upon
insertion. It takes no arguments and should be type equivalent to C<INTEGER>.
Columns with this type should not be explicitly set during insertion or update.
The driver may choose to make such attempts exceptional.

=cut

use constant AUTONUMBER		=> 2;

=item BOOLEAN

Boolean value that is true (1) or false (0) or NULL (undef). It takes no
arguments. Some database backends will not support this directly, but it should
always be simulated by the driver.

=cut

use constant BOOLEAN		=> 3;

=item REAL

A real number value. This should be used for Perl's floating point values.  It
takes no arguments and database should try to support values up to double
precision floating point values and be at least as accurate.

=cut

use constant REAL			=> 4;

=item TIMESTAMP

A date/time value. Values of this type will be represented in Perl as an object
of the DateTime package. When represented as a string, it should be in ISO 8601
format.

See the documentation of L<DateTime> for details.

=cut

use constant TIMESTAMP		=> 5;

=back

=head2 INDEXES

The indexes are:

=over

=item PRIMARY

This is the key that is used to uniquely identify the row. Duplicates should not
be allowed and there should always be a value stored in this column (that is, it
should never be NULL/undef). All tables must exactly one primary index.

This takes an array reference naming all the columns that are in the index. For
example,

  [ PRIMARY, [ 'someid', 'name' ] ]

=cut

use constant PRIMARY		=> 0;

=item UNIQUE

This notes that the column(s) may be used to unique identify the row, but is not
the primary index.

This takes an array reference naming all the columns that are in the index. For
example,

  [ UNIQUE, [ 'someid', 'name' ] ]

=cut

use constant UNIQUE			=> 1;

=item LINK

This links two tables by one or more columns.

This index takes three arguments. The first is an array reference naming all the
local columns that reference the other table. The second is the name of the
referenced table. The third is the an array reference naming the foreign columns
that are referenced. The number of columns specified locally and foreign should
be the same.

For example,

  [ LINK, [ 'someid', 'name' ], 'another_table', [ 'anoid', 'name' ] ]

=cut

use constant LINK			=> 2;

=back

=head2 DRIVER HELPERS

This section is only of interest to driver implementors. The following helper
routines have been written to help with driver implementation. They may be
imported each by name or both by C<':driver_help'>.

These were added because the C<croak> and C<carp> methods provided by the
L<Carp> package are a little week for our needs. The L<Carp> methods will note
errors in the first caller outside of the current package in the call-stack (I
think). These, will note errors in the first caller outside of Persist
packages.

The important difference is that a driver error will be reported in user code
rather in the Persist package using the driver. A great aid to debugging.

=over

=item croak @msg

This method dies with a message and notes the package and line of the first
caller outside of the Persist framework.

=cut

sub croak(@) {
	my ($i, $package, $filename, $line);
	$i = 1;
	do {
		($package, $filename, $line) = caller $i++;
	} until ($package !~ /^Persist/);

	die @_," in $filename on line $line.\n";
}

=item carp @msg

This method warns with a message and notes the package and line of the first
caller outside of the Persist framework.

=cut

sub carp(@) {
	my ($i, $package, $filename, $line);
	$i = 1;
	do {
		($package, $filename, $line) = caller $i++;
	} until ($package !~ /^Persist/);

	warn @_," in $filename on line $line.\n";
}

=back

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
