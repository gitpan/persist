# vim: set ft=perl :

use Test::More tests => 5;
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

$sth = $driver->open_table(-table => 'folks', -filter => 'age < 22');
$i = 0;
$row = $driver->next(-handle => $sth);
ok($row->{name} eq 'James' and $row->{age} == 21, 'Record test.');
$row = $driver->next(-handle => $sth);
ok($row->{name} eq 'Laura' and $row->{age} == 15, 'Record test.');
$row = $driver->next(-handle => $sth);
ok(!$row, 'Record test.');

$driver->update(-table => 'folks', -set => { age => 18 }, -filter => "name = 'James'");
$driver->delete(-table => 'folks', -filter => "name = 'Laura'");

$row = $driver->first(-handle => $sth);
ok($row->{name} eq 'James' and $row->{age} == 18, 'Record test.');
$row = $driver->next(-handle => $sth);
ok(!$row, 'Record test.');
