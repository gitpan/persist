# vim: set ft=perl :

use Test::More;

use lib "$ENV{PWD}";
require 'testsetup';

plan tests => 5 unless $skippg;
plan skip_all => $skippg if $skippg;

eval {
	@conn = &pgconn(); shift @conn;
	$driver = new Persist::Driver::DBI::PostgreSQL(@conn);

	$driver->create_table(@folks);
	$driver->create_table(@favorites);

	for $folk (@folks_data) {
		$driver->insert('folks', { name => $folk->{name}, age => $folk->{age} });
		$fid = $driver->sequence_value('folks', 'fid');
		for $favorite (@{$folk->{colors}}) {
			$driver->insert('favorites', { fid => $fid, color => $favorite });
		}
	}

	$sth = $driver->open_table('folks', 'age < 22');
	$i = 0;
	$row = $driver->next($sth);
	ok($row->{name} eq 'James' and $row->{age} == 21, 'Record test.');
	$row = $driver->next($sth);
	ok($row->{name} eq 'Laura' and $row->{age} == 15, 'Record test.');
	$row = $driver->next($sth);
	ok(!$row, 'Record test.');

	$driver->update('folks', { age => 18 }, "name = 'James'");
	$driver->delete('folks', "name = 'Laura'");

	$row = $driver->first($sth);
	ok($row->{name} eq 'James' and $row->{age} == 18, 'Record test.');
	$row = $driver->next($sth);
	ok(!$row, 'Record test.');
};

if ($@) {
	diag("Test error. Attempting cleanup: $@");
}

require 't/pgcleanup';
