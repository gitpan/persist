# vim: set ft=perl :

use Test::More;

use lib "$ENV{PWD}";
require 'testsetup';

plan tests => 6 unless $skippg;
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

	$sth = $driver->open_join([ 'folks', 'favorites' ], [ "age > 40" ]);
	$row = $driver->next($sth);
	ok($row->{name} eq 'Gregg' and $row->{color} eq 'blue', 'Record test.');
	$row = $driver->next($sth);
	ok($row->{name} eq 'Rhonda' and $row->{color} eq 'red', 'Record test.');
	$row = $driver->next($sth);
	ok(!$row, 'Record test.');

	$sth = $driver->open_explicit_join(
					[ 'o', 'folks', 'a', 'favorites' ], 
					[ "o.fid = a.fid" ],
					"o.age > 40");
	$row = $driver->next($sth);
	ok($row->{name} eq 'Gregg' and $row->{color} eq 'blue', 'Record test.');
	$row = $driver->next($sth);
	ok($row->{name} eq 'Rhonda' and $row->{color} eq 'red', 'Record test.');
	$row = $driver->next($sth);
	ok(!$row, 'Record test.');
};

if ($@) {
	diag("Test error. Attempting cleanup: $@");
}

require 't/pgcleanup';
