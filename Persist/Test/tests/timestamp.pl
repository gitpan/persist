# vim: set ft=perl :

use English;
use Test::More tests => 24;
use Persist::Test ':driver';

my $driver = init;
	
create_n_fill($driver);

eval {
	$sth = $driver->open_table(-table => 'folks', -filter => "dob < '1975-01-01T12:21:33Z'");
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Gregg', 'Record test.');
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Rhonda', 'Record test.');
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'James', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');
	
	$sth = $driver->open_table(-table => 'folks', -filter => "dob > '1975-01-01T12:21:33Z'");
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Terri', 'Record test.');
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Laura', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

	$sth = $driver->open_table(-table => 'folks', -filter => "dob <= '1975-01-01T12:21:33Z'");
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Sterling', 'Record test.');
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Gregg', 'Record test.');
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Rhonda', 'Record test.');
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'James', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');
	
	$sth = $driver->open_table(-table => 'folks', -filter => "dob >= '1975-01-01T12:21:33Z'");
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Sterling', 'Record test.');
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Terri', 'Record test.');
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Laura', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

	$sth = $driver->open_table(-table => 'folks', -filter => "dob = '1975-01-01T12:21:33Z'");
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Sterling', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');
	
	$sth = $driver->open_table(-table => 'folks', -filter => "dob <> '1975-01-01T12:21:33Z'");
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Terri', 'Record test.');
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Gregg', 'Record test.');
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Rhonda', 'Record test.');
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'James', 'Record test.');
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Laura', 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

};

if ($EVAL_ERROR) {
	diag("Test error. Attempting cleanup: $EVAL_ERROR");
}

drop_all($driver);
