# vim: set ft=perl :

# This test created to test for a bug in the memory driver that occurred when
# rows are deleted from a table that contains no data.

use Test::More tests => 1;
require 'testsetup';

$driver = new Persist::Driver::Memory;

$driver->create_table(@folks);

is($driver->delete('folks', "name = 'Sterling'"), 0, 'Deleting nothing.');
