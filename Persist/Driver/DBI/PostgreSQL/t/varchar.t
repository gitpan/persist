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
		$driver->insert(-table => 'folks', -values => { name => $folk->{name} });
	}

	$sth = $driver->open_table(-table => 'folks', -filter => "name < 'Laura'");
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Gregg', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'James', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

	$sth = $driver->open_table(-table => 'folks', -filter => "name > 'Laura'");
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Sterling', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Terri', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Rhonda', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

	$sth = $driver->open_table(-table => 'folks', -filter => "name <= 'Laura'");
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Gregg', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'James', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Laura', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

	$sth = $driver->open_table(-table => 'folks', -filter => "name >= 'Laura'");
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Sterling', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Terri', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Rhonda', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Laura', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

	$sth = $driver->open_table(-table => 'folks', -filter => "name <> 'Laura'");
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Sterling', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Terri', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Gregg', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Rhonda', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'James', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

	$sth = $driver->open_table(-table => 'folks', -filter => "name = 'Laura'");
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Laura', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

	$sth = $driver->open_table(-table => 'folks', -filter => "name LIKE '\%er\%'");
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Sterling', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Terri', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

	$sth = $driver->open_table(-table => 'folks', -filter => "name NOT LIKE '\%er\%'");
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Gregg', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Rhonda', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'James', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Laura', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

	$sth = $driver->open_table(-table => 'folks', -filter => "name ILIKE '\%L_\%'");
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Sterling', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Laura', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

	$sth = $driver->open_table(-table => 'folks', -filter => "name NOT ILIKE '\%L_\%'");
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Terri', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Gregg', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'Rhonda', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok($row->{name} eq 'James', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

};

if ($@) {
	diag("Test error. Attempting cleanup: $@");
}

require 't/pgcleanup';