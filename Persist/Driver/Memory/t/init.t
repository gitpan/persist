# vim: set ft=perl :

use Test::More tests => 1;
require 'testsetup';

$driver = new Persist::Driver::Memory;

ok(ref $driver eq 'Persist::Driver::Memory', 'new Driver');

