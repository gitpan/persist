# vim: set ft=perl :

use English;
use Test::More tests => 10;
use Persist::Test ':driver';

my $driver = init;

my $folks = 0;
my $favorites = 0;
eval {
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
	$favorites = 0;
	ok($driver->delete_table(-table => 'folks'), 'Delete a table.');
	$folks = 0;

};

if ($EVAL_ERROR) {
	diag("Test error. Attempting cleanup: $EVAL_ERROR");
}

if ($favorites) {
	$driver->delete_table(-table => 'favorites');
}

if ($folks) {
	$driver->delete_table(-table => 'folks');
}
