# vim: set ft=perl :

use Test::More tests => 1;
use Persist ':constants';
require 'testsetup';

$driver = new Persist::Driver::Memory;

$driver->create_table(@folks);
$driver->create_table(@favorites);

$sth = $driver->open_join(-tables => [ 'folks', 'favorites' ]);
$row = $driver->next(-handle => $sth);
ok(!$row, 'Record test.');
