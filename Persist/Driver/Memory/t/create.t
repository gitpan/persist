# vim: set ft=perl :

use Test::More tests => 10;
require 'testsetup';

$driver = new Persist::Driver::Memory;

ok($driver->create_table(@folks), 'Create a table.');
ok($driver->create_table(@favorites), 'Create a table.');

%tables = map { $_ => 1 } $driver->tables;
ok($tables{folks}, 'Folks exists.');
ok($tables{favorites}, 'Favorites exists.');

%results = $driver->columns('folks');
is_deeply(\%results, $folks[1], 'Correct column structure.');
%results = $driver->columns('favorites');
is_deeply(\%results, $favorites[1], 'Correct column structure.');

@results = $driver->indexes('folks');
is_deeply(\@results, $folks[2], 'Correct index structure.');
@results = $driver->indexes('favorites');
is_deeply(\@results, $favorites[2], 'Correct index structure.');

ok($driver->delete_table(@favorites), 'Delete a table.');
ok($driver->delete_table(@folks), 'Delete a table.');
