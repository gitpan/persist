# vim: set ft=perl :

use English;
use Test::More tests => 2;
use Persist::Test ':driver';
use Persist ':constants';

my $driver = init;

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

@folks_data = (
	{ name => 'Sterling',  colors => [ 'green' ] },
);

create($driver, 'folks');
create($driver, 'favorites');

eval {
	for $folk (@folks_data) {
		$driver->insert(-table => 'folks', -values => { name => $folk->{name} });
		$fid = $driver->sequence_value(-table => 'folks', -column => 'fid');
		for $favorite (@{$folk->{colors}}) {
			$driver->insert(-table => 'favorites', -values => { fid => $fid, name => $favorite });
		}
	}

	$sth = $driver->open_join(
			-tables  => [ 'folks', 'favorites' ],
			-filters => "folks.name = 'Sterling' and favorites.name = 'green'");
	$row = $driver->next(-handle => $sth, -bytable => 1);
	is_deeply([ $row->[0]{name}, $row->[1]{name} ], [ 'Sterling', 'green' ], 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

};

if ($EVAL_ERROR) {
	diag("Test error. Attempting cleanup: $EVAL_ERROR");
}

drop_all($driver);
