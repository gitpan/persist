package Persist;

# TODO For this documentation (or somewhere) list those keywords that should
# be avoided because they are a part of ANSI SQL or a specific driver's
# implementation--that is, they shouldn't be used for table or column names.

use 5.008;
use strict;
use warnings;

use Date::Calc 'Days_in_Month';

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'constants' => [ qw(
	VARCHAR INTEGER AUTONUMBER BOOLEAN REAL TIMESTAMP
	PRIMARY UNIQUE LINK
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'constants'} } );

# Setup version information. The only time this is really important is for a
# release. When a release occurs it will be tagged so we can take the version
# from the tag. Otherwise, we just use the CVS revision which isn't really the
# version, but let's us create distributions anyway.
#
# This is used by ../Makefile.PL for version information for the entire
# package and for the PPD.
our $VERSION_TAG = '$Name: persist-0_3_1 $';
our $VERSION_REV = '$Revision: 1.10 $';
our $VERSION;

if ($VERSION_TAG =~ /\$Name:\s+persist-(\d+)_(\d+)_(\d+)(\S*)/i) {
	$VERSION = "$1.$2.$3$4";
} else {
	( $VERSION ) = '$Revision: 1.10 $' =~ /\$Revision:\s+(\S+)/;
	$VERSION .= '-nr';
}

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

A date/time value. This should store a date and time value accurate to the
second (there's no need to note leap seconds). This should be able to store as
wide of a date range as reasonble. Accuracy of dates is a very difficult
prospect whenever moving more than a century in any direction, so very little
standardization can realistically be expected. Values of this type are
represented in Perl as a string in the format ECCYYMMDDhhmmssTTTTT where all
fields are completely padded with zeros (0).

The fields are: 

=over

=item E is the epoch and is either '1' for AD or '0' for BC;

=item CC is the century minus one (21st century is 20, duh);

=item YY is the century year (note that 00 is an invalid year in the first
century of either epoch);

=item MM is the month index based at 0 (0 is January, 11 is December);

=item DD is the day of month based at 1 (the last day of the month in January is
31);

=item hh is the hour of the day ranging from 0 to 23;

=item mm is the minute of the hour ranging from 0 to 59;

=item ss is the second of the minute ranging from 0 to 59; and

=item TTTTT is the timezone where the first character is either '+' or '-' to
mark the direction of change from UTC and other four characters are a value
between 0000 and 1200 to mark the number of whole minutes difference from
UTC--UTC may be specified as either "-0000" or "+0000". A date with a time
zone of UTC will be said to be "normalize".

=back

It is probably safe to assume that dates for any modern time are according to
the Gregorian calendar, but may belong to a related calendar when dates are
listed from more than a few centuries past. (For information on the history of
calendars and how they have been manipulated beyond all comprehension, I
suggestion seeing L<http://astro.nmsu.edu/~lhuber/leaphist.html>.)

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

=head2 HELPER FUNCTIONS

The helper functions include the following:

=over

=item @date = Persist->parse_timestamp($date)

Given a timestamp string, this function will parse the date into it's parts. The
output array will contain 9 fields. The fields, in order, are:

  0 - Epoch (either '0' or '1')
  1 - Century (a value from '00' to '40')
  2 - Year (a value from '00' to '99')
  3 - Month (a value from '00' to '11')
  4 - Day (a value with varying range but always in '01' and '31')
  5 - Hour (a value from '00' to '23')
  6 - Minute (a value from '00' to '59')
  7 - Second (a value from '00' to '59')
  8 - Timezone (a value from '-1200' to '+1200')

=cut

sub parse_timestamp {
	my ($class, $date) = @_;

	my @result;
	$result[0]  = substr $date, 0,  1;
	$result[1]  = substr $date, 1,  2;
	$result[2]  = substr $date, 3,  2;
	$result[3]  = substr $date, 5,  2;
	$result[4]  = substr $date, 7,  2;
	$result[5]  = substr $date, 9,  2;
	$result[6]  = substr $date, 11, 2;
	$result[7]  = substr $date, 13, 2;
	$result[8]  = substr $date, 15, 5;

	@result;
}

=item $date = Persist->format_timestamp(@date)

Taking an array structured in the same way as the date returned by
C<Persist->parse_timestamp>, returns a string formatted as described in the
section about the C<TIMESTAMP> data type.

=cut

sub format_timestamp {
	my ($class, @date) = @_;
	sprintf '%s%02d%02d%02d%02d%02d%02d%02d%s', @date;
}

=item $date = Persist->timestamp_from_time([ $time ])

Taking a time as returned from the perl function L<perlfunc/time>, creates
a date formatted for a Persist source. If the time argument is left out
then the current time is used.

=cut

sub timestamp_from_time {
	my ($class, $time) = @_;

	$time = time unless defined $time;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
			gmtime($time);

	sprintf '%s%02d%02d%02d%02d%02d%02d%02d+0000',
			($year + 1900 < 0 ? '0' : '1'), 19 + $year/100, $year % 100,
			$mon, $mday, $hour, $min, $sec;
}

=item $ts_norm = Persist->normalize_timestamp($timestamp)

This method takes the given timestamp and transforms it such that the timestamp
uses UTC as it's timezone (as "+0000"). If an absolute time comparison is
needed, the timestamp may now be compared using the lexigraphic comparison
operators (eq, ne, le, ge, lt, gt, cmp).

This method assumes that timezones aren't a relevent fact of dates in B.C.
That is, it will not properly handle timezone normalization if trying to
adjust them for a date in the previous epoch.

=cut

sub normalize_timestamp {
	my ($class, $time) = @_;

	my @times = $class->parse_timestamp($time);
	my $tzs = $times[8] =~ /\+/ ? -1 : 1;
	my $tzh = int(substr $times[8], 1, 2);
	my $tzm = int(substr $times[8], 3, 2);

	$times[5] += $tzs * $tzh;
	$times[6] += $tzs * $tzm;

	# Check for minutes roll-over
	if ($times[6] < 0) {
		$times[6] += 60;
		--$times[5];
	} elsif ($times[6] > 60) {
		$times[6] -= 60;
		++$times[5];
	}

	# Check for hours roll-over
	if ($times[5] < 0) {
		$times[5] += 24;
		--$times[4];
	} elsif ($times[5] > 23) {
		$times[5] -= 24;
		++$times[4];
	}

	# Check for days, months, and years roll-over
	if ($times[4] < 1) {
		$times[3] = $times[3] == 0 ? 11 : $times[3] - 1;
		$times[4] = Days_in_Month($times[1].$times[2], $times[3]+1);
		--$times[2] if $times[3] == 11;
		if ($times[2] < 0) {
			--$times[1];
			$times[2] += 100;
		}
	} elsif ($times[4] > Days_in_Month($times[1].$times[2], $times[3]+1)) {
		$times[4] = 1;
		$times[3] = $times[3] == 11 ? 0 : $times[3] + 1;
		++$times[2] if $times[3] == 0;
		if ($times[2] > 99) {
			++$times[1];
			$times[2] -= 100;
		}
	}

	sprintf '%s%02d%02d%02d%02d%02d%02d%02d+0000', @times;
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
