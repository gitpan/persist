# vim: set ft=perl :

use Test::More tests => 40;
require 'testsetup';

$driver = new Persist::Driver::Memory;

$driver->create_table(@folks);

for $folk (@folks_data) {
	$driver->insert('folks', { name => $folk->{name}, age => $folk->{age} });
}

$sth = $driver->open_table('folks', "name < 'Laura'");
$row = $driver->next($sth);
ok($row->{name} eq 'Gregg', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'James', 'Record test.');
$row = $driver->next($sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table('folks', "name > 'Laura'");
$row = $driver->next($sth);
ok($row->{name} eq 'Sterling', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Terri', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Rhonda', 'Record test.');
$row = $driver->next($sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table('folks', "name <= 'Laura'");
$row = $driver->next($sth);
ok($row->{name} eq 'Gregg', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'James', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Laura', 'Record test.');
$row = $driver->next($sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table('folks', "name >= 'Laura'");
$row = $driver->next($sth);
ok($row->{name} eq 'Sterling', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Terri', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Rhonda', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Laura', 'Record test.');
$row = $driver->next($sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table('folks', "name <> 'Laura'");
$row = $driver->next($sth);
ok($row->{name} eq 'Sterling', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Terri', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Gregg', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Rhonda', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'James', 'Record test.');
$row = $driver->next($sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table('folks', "name = 'Laura'");
$row = $driver->next($sth);
ok($row->{name} eq 'Laura', 'Record test.');
$row = $driver->next($sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table('folks', "name LIKE '\%er\%'");
$row = $driver->next($sth);
ok($row->{name} eq 'Sterling', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Terri', 'Record test.');
$row = $driver->next($sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table('folks', "name NOT LIKE '\%er\%'");
$row = $driver->next($sth);
ok($row->{name} eq 'Gregg', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Rhonda', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'James', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Laura', 'Record test.');
$row = $driver->next($sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table('folks', "name ILIKE '\%L_\%'");
$row = $driver->next($sth);
ok($row->{name} eq 'Sterling', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Laura', 'Record test.');
$row = $driver->next($sth);
ok(!$row, 'Record test.');

$sth = $driver->open_table('folks', "name NOT ILIKE '\%L_\%'");
$row = $driver->next($sth);
ok($row->{name} eq 'Terri', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Gregg', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'Rhonda', 'Record test.');
$row = $driver->next($sth);
ok($row->{name} eq 'James', 'Record test.');
$row = $driver->next($sth);
ok(!$row, 'Record test.');


