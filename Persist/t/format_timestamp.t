# vim: set ft=perl :

use Test::More tests => 2;
use Persist ':constants';

is(Persist->format_timestamp(
	'1', '19', '55', '10', '05', '23', '59', '00', '-0700'
   ), '119551005235900-0700', 'format_timestamp');

is(Persist->format_timestamp(
	1, 19, 55, 10, 5, 23, 59, 0, '-0700'
   ), '119551005235900-0700', 'format_timestamp with numerals');
