# vim: set ft=perl :

use Test::More;

use lib "$ENV{PWD}";
require 'testsetup';

plan tests => 10 unless $skippg;
plan skip_all => $skippg if $skippg;

eval {
	@conn = &pgconn(); shift @conn;
	$driver = new Persist::Driver::DBI::PostgreSQL(@conn);

	ok($driver->create_table(@folks), 'Create a table.');
	ok($driver->create_table(@favorites), 'Create a table.');

	%tables = map { $_ => 1 } $driver->tables;
	ok($tables{folks}, 'Folks exists.');
	ok($tables{favorites}, 'Favorites exists.');

	%results = $driver->columns(-table => 'folks');
	is_deeply(\%results, +{ @{$folks[3]} }, 'Correct column structure.');
	%results = $driver->columns(-table => 'favorites');
	is_deeply(\%results, +{ @{$favorites[3]} }, 'Correct column structure.');

	@results = $driver->indexes(-table => 'folks');
	is_deeply(\@results, $folks[5], 'Correct index structure.');
	@results = $driver->indexes(-table => 'favorites');
	is_deeply(\@results, $favorites[5], 'Correct index structure.');

	ok($driver->delete_table(-table => 'favorites'), 'Delete a table.');
	ok($driver->delete_table(-table => 'folks'), 'Delete a table.');

};

if ($@) {
	diag("Test error. Attempting cleanup: $@");
}

require 't/pgcleanup';
