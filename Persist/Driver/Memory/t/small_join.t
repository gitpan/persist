# vim: set ft=perl :

use Test::More tests => 2;
use Persist ':constants';
require 'testsetup';

$driver = new Persist::Driver::Memory;

@favorites = (
	-table => 'favorites',
	-columns =>
	[	favid	=> [ AUTONUMBER ],
		fid		=> [ INTEGER ],
		name	=> [ VARCHAR, 10 ] ],
	-indexes =>
	[	[ PRIMARY, [ 'favid' ] ],
		[ UNIQUE, [ 'fid', 'color' ] ],
		[ LINK, [ 'fid' ], 'folks', [ 'fid' ] ] ]
);

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
		-filter => [ "name = 'Sterling'", "name = 'green'" ]);
$row = $driver->next(-handle => $sth);
ok($row->{o_name} eq 'Sterling' and $row->{a_name} eq 'green', 'Record test.');
$row = $driver->next(-handle => $sth);
ok(!$row, 'Record test.');
