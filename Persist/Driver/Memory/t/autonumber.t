# vim: set ft=perl :

use Test::More tests => 6;
require 'testsetup';

$driver = new Persist::Driver::Memory;

$driver->create_table(@folks);

$i = 1;
for $folk (@folks_data) {
	$driver->insert(-table => 'folks', -values => { name => $folk->{name}, age => $folk->{age} });
	$fid = $driver->sequence_value(-table => 'folks', -column => 'fid');
	ok($fid == $i++, 'Sequence test.');
}
