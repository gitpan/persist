# vim: set ft=perl :

use Test::More;

use lib "$ENV{PWD}";
require 'testsetup';

plan tests => 40 unless $skippg;
plan skip_all => $skippg if $skippg;

eval {
	@conn = &pgconn(); shift @conn;
	$driver = new Persist::Driver::DBI::PostgreSQL(@conn);

	$driver->create_table(@folks);

	for $folk (@folks_data) {
		$driver->insert('folks', { name => $folk->{name} });
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

};

if ($@) {
	diag("Test error. Attempting cleanup: $@");
}

require 't/pgcleanup';
