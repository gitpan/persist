# vim: set ft=perl :

use Test::More;

use lib "$ENV{PWD}";
require 'testsetup';
use Persist ':constants';

plan tests => 2 unless $skippg;
plan skip_all => $skippg if $skippg;

@favorites = (
	-table => 'favorites',
	-columns =>
	[	favid	=> [ AUTONUMBER ],
		fid		=> [ INTEGER ],
		name	=> [ VARCHAR, 10 ] ],
	-indexes =>
	[	[ PRIMARY, [ 'favid' ] ],
		[ UNIQUE, [ 'fid', 'name' ] ],
		[ LINK, [ 'fid' ], 'folks', [ 'fid' ] ] ]
);

eval {
	@conn = &pgconn(); shift @conn;
	$driver = new Persist::Driver::DBI::PostgreSQL(@conn);

	@folks_data = (
		{ name => 'Sterling',  colors => [ 'green' ] },
	);

	$driver->create_table(@folks);
	$driver->create_table(@favorites);

	for $folk (@folks_data) {
		$driver->insert(-table => 'folks', -values => { name => $folk->{name} });
		$fid = $driver->sequence_value(-table => 'folks', -column => 'fid');
		for $favorite (@{$folk->{colors}}) {
			$driver->insert(-table => 'favorites', -values => { fid => $fid, name => $favorite });
		}
	}

	$sth = $driver->open_join(
			-tables => 	
			[ [ 'folks', 'o' ],
			  [ 'favorites', 'a' ] ],
			-filters => 
			[ "name = 'Sterling'", "name = 'green'" ]);
	$row = $driver->next(-handle => $sth);
	ok($row->{o_name} eq 'Sterling' and $row->{a_name} eq 'green', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

	#$sth = $driver->open_explicit_join(
	#				[ 'o', [ 'o' => 'folks' ], 'a', [ 'a' => 'favorites' ] ], 
	#				[ "o.fid = a.fid" ],
	#				"o.name = 'Sterling' and a.name = 'green'");
	#$row = $driver->next(-handle => $sth);
	#ok($row->{o_name} eq 'Sterling' and $row->{a_name} eq 'green', 'Record test.');
	#$row = $driver->next(-handle => $sth);
	#ok(!$row, 'Record test.');

};

if ($@) {
	diag("Test error. Attempting cleanup: $@");
}

require 't/pgcleanup';
