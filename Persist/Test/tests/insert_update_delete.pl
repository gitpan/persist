# vim: set ft=perl :

use English;
use Test::More tests => 5;
use Persist::Test ':driver';

my $driver = init;

create_n_fill($driver);

eval {
	$sth = $driver->open_table(-table => 'folks', -filter => 'age < 22');
	$i = 0;
	$row = $driver->next(-handle => $sth);
	is_deeply([ $row->{name}, $row->{age} ], [ 'James', 21 ], 'Record test.');
	$row = $driver->next(-handle => $sth);
	is_deeply([ $row->{name}, $row->{age} ], [ 'Laura', 15 ], 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

	$driver->update(-table => 'folks', -set => { age => 18 }, -filter => "name = 'James'");
	$driver->delete(-table => 'folks', -filter => "name = 'Laura'");

	$row = $driver->first(-handle => $sth);
	is_deeply([ $row->{name}, $row->{age} ], [ 'James', 18 ], 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');
};

if ($EVAL_ERROR) {
	diag("Test error. Attempting cleanup: $EVAL_ERROR");
}

drop_all($driver);
