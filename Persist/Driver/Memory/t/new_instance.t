# vim: set ft=perl :

use Test::More tests => 3;
require 'testsetup';

$driver = new Persist::Driver::Memory;

if ($driver->is_dba) {
	@args = $driver->new_source('test', 'test');
	ok(scalar(@args), 'New source.');
	
	$tmp_drv = new Persist::Driver::Memory(@args);
	ok(ref $driver eq 'Persist::Driver::Memory', 
			'Connect to new source.');
	
	$tmp_drv = undef;
	ok($driver->delete_source('test', 'test'), 'Delete source.');
} else {
	skip('Not a DBA connection, cannot create a new source.', 3);
}
