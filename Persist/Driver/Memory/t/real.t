# vim: set ft=perl :

use Test::More tests => 16;
require 'testsetup';

$driver = new Persist::Driver::Memory;

$driver->create_table(@folks);

for $folk (@folks_data) {
	$driver->insert('folks', { name => $folk->{name}, r_age => $folk->{r_age} });
}

$sth = $driver->open_table('folks', "r_age < 22.1");
$row = $driver->next($sth);
ok($row->{name} eq 'James', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Laura', 'Record test.');
$row = $driver->next($sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table('folks', "r_age > 22.1");
$row = $driver->next($sth);
ok($row->{name} eq 'Sterling', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Gregg', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Rhonda', 'Record test.');
$row = $driver->next($sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table('folks', "r_age <= 22.1");
$row = $driver->next($sth);
ok($row->{name} eq 'Terri', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'James', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Laura', 'Record test.');
$row = $driver->next($sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table('folks', "r_age >= 22.1");
$row = $driver->next($sth);
ok($row->{name} eq 'Sterling', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Terri', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Gregg', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Rhonda', 'Record test.');
$row = $driver->next($sth);
ok(!$row, 'Record test.');
