# vim: set ft=perl :

use Test::More;

use lib "$ENV{PWD}";
require 'testsetup';

plan tests => 3 unless $skippg;
plan skip_all => $skippg if $skippg;

eval {
	@conn = &pgconn(); shift @conn;
	$driver = new Persist::Driver::DBI::PostgreSQL(@conn);

	if ($driver->is_dba) {
		@args = $driver->new_source(-username => 'test', -password => 'test');
		ok(scalar(@args), 'New source.');
		
		$tmp_drv = new Persist::Driver::DBI::PostgreSQL(@args);
		is(ref $driver, 'Persist::Driver::DBI::PostgreSQL', 
				'Connect to new source.');
	
		$tmp_drv = undef;
		sleep 3; # give PostgreSQL time to clear the connection
		ok($driver->delete_source(-username => 'test'), 'Delete source.');
	} else {
		skip('Not a DBA connection, cannot create a new source.', 3);
	}
};

if ($@) {
	diag("Test error. Attempting cleanup: $@");
}

