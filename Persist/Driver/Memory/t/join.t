# vim: set ft=perl :

use Test::More tests => 6;
require 'testsetup';

$driver = new Persist::Driver::Memory;

$driver->create_table(@folks);
$driver->create_table(@favorites);

for $folk (@folks_data) {
	$driver->insert(-table => 'folks', -values => { name => $folk->{name}, age => $folk->{age} });
	$fid = $driver->sequence_value(-table => 'folks', -column => 'fid');
	for $favorite (@{$folk->{colors}}) {
		$driver->insert(-table => 'favorites', -values => { fid => $fid, color => $favorite });
	}
}

$sth = $driver->open_join(-tables => [ 'folks', 'favorites' ], -filter => [ "age > 40" ]);
$row = $driver->next(-handle => $sth);
ok($row->{name} eq 'Gregg' and $row->{color} eq 'blue', 'Record test.');
$row = $driver->next(-handle => $sth);
ok($row->{name} eq 'Rhonda' and $row->{color} eq 'red', 'Record test.');
$row = $driver->next(-handle => $sth);
ok(!$row, 'Record test.');

$sth = $driver->open_explicit_join(
				-tables => [ 'o', 'folks', 'a', 'favorites' ], 
				-on_exprs => [ "o.fid = a.fid" ],
				-filter => "o.age > 40");
$row = $driver->next(-handle => $sth);
ok($row->{name} eq 'Gregg' and $row->{color} eq 'blue', 'Record test.');
$row = $driver->next(-handle => $sth);
ok($row->{name} eq 'Rhonda' and $row->{color} eq 'red', 'Record test.');
$row = $driver->next(-handle => $sth);
ok(!$row, 'Record test.');
