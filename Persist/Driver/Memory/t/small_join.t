# vim: set ft=perl :

use Test::More tests => 2;
use Persist ':constants';
require 'testsetup';

$driver = new Persist::Driver::Memory;

@favorites = ( 'favorites',
	{	favid	=> [ AUTONUMBER ],
		fid		=> [ INTEGER ],
		name	=> [ VARCHAR, 10 ] },
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
	$driver->insert('folks', { name => $folk->{name} });
	$fid = $driver->sequence_value('folks', 'fid');
	for $favorite (@{$folk->{colors}}) {
		$driver->insert('favorites', { fid => $fid, name => $favorite });
	}
}

$sth = $driver->open_join(
		[ [ 'folks', 'o' ],
		  [ 'favorites', 'a' ] ],
		[ "name = 'Sterling'", "name = 'green'" ]);
$row = $driver->next($sth);
ok($row->{o_name} eq 'Sterling' and $row->{a_name} eq 'green', 'Record test.');
$row = $driver->next($sth);
ok(!$row, 'Record test.');
