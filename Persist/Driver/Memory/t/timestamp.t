# vim: set ft=perl :

use Test::More tests => 24;
require 'testsetup';

@conn = &memconn(); shift @conn;
$driver = new Persist::Driver::Memory(@conn);

$driver->create_table(@folks);

for $folk (@folks_data) {
	$driver->insert(-table => 'folks', -values => { name => $folk->{name}, dob => $folk->{dob} });
}

$sth = $driver->open_table(-table => 'folks', -filter => "dob < '1975-01-01T12:21:33Z'");
$row = $driver->next(-handle => $sth);
is($row->{name}, 'Gregg', 'Record test.');
$row = $driver->next(-handle => $sth);
is($row->{name}, 'Rhonda', 'Record test.');
$row = $driver->next(-handle => $sth);
is($row->{name}, 'James', 'Record test.');
$row = $driver->next(-handle => $sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table(-table => 'folks', -filter => "dob > '1975-01-01T12:21:33Z'");
$row = $driver->next(-handle => $sth);
is($row->{name}, 'Terri', 'Record test.');
$row = $driver->next(-handle => $sth);
is($row->{name}, 'Laura', 'Record test.');
$row = $driver->next(-handle => $sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table(-table => 'folks', -filter => "dob <= '1975-01-01T12:21:33Z'");
$row = $driver->next(-handle => $sth);
is($row->{name}, 'Sterling', 'Record test.');
$row = $driver->next(-handle => $sth);
is($row->{name}, 'Gregg', 'Record test.');
$row = $driver->next(-handle => $sth);
is($row->{name}, 'Rhonda', 'Record test.');
$row = $driver->next(-handle => $sth);
is($row->{name}, 'James', 'Record test.');
$row = $driver->next(-handle => $sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table(-table => 'folks', -filter => "dob >= '1975-01-01T12:21:33Z'");
$row = $driver->next(-handle => $sth);
is($row->{name}, 'Sterling', 'Record test.');
$row = $driver->next(-handle => $sth);
is($row->{name}, 'Terri', 'Record test.');
$row = $driver->next(-handle => $sth);
is($row->{name}, 'Laura', 'Record test.');
$row = $driver->next(-handle => $sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table(-table => 'folks', -filter => "dob = '1975-01-01T12:21:33Z'");
$row = $driver->next(-handle => $sth);
is($row->{name}, 'Sterling', 'Record test.');
$row = $driver->next(-handle => $sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table(-table => 'folks', -filter => "dob <> '1975-01-01T12:21:33Z'");
$row = $driver->next(-handle => $sth);
is($row->{name}, 'Terri', 'Record test.');
$row = $driver->next(-handle => $sth);
is($row->{name}, 'Gregg', 'Record test.');
$row = $driver->next(-handle => $sth);
is($row->{name}, 'Rhonda', 'Record test.');
$row = $driver->next(-handle => $sth);
is($row->{name}, 'James', 'Record test.');
$row = $driver->next(-handle => $sth);
is($row->{name}, 'Laura', 'Record test.');
$row = $driver->next(-handle => $sth);
ok(!$row, 'Record test.');

