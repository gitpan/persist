# vim: set ft=perl :

use Test::More;

use lib "$ENV{PWD}";
require 'testsetup';

plan tests => 6 unless ($skippg);
plan skip_all => $skippg if ($skippg);

eval {
	@conn = &pgconn(); shift @conn;
	$driver = new Persist::Driver::DBI::PostgreSQL(@conn);

	$driver->create_table(@folks);

	$i = 1;
	for $folk (@folks_data) {
		$driver->insert('folks', { name => $folk->{name}, age => $folk->{age} });
		$fid = $driver->sequence_value('folks', 'fid');
		ok($fid == $i++, 'Sequence test.');
	}

};

if ($@) {
	diag("Test error. Attempting cleanup: $@");
}

require 't/pgcleanup';
