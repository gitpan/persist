use English;
use Test::More tests => 6;
use Persist::Test ':driver';

my $driver = init;

create_n_fill($driver);

eval {
	$sth = $driver->open_join(-tables => [ 'folks', 'favorites' ], -filter => "age > 40");
	$row = $driver->next(-handle => $sth);
	is_deeply([ $row->{name}, $row->{color} ], [ 'Gregg', 'blue' ], 'Record test.');
	$row = $driver->next(-handle => $sth);
	is_deeply([ $row->{name}, $row->{color} ], [ 'Rhonda', 'red' ], 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');

	$sth = $driver->open_join(
					-tables => [ 'folks', 'favorites' ],
					-on => "folks.fid = favorites.fid",
					-filter => "age > 40");
	$row = $driver->next(-handle => $sth);
	is_deeply([ $row->{name}, $row->{color} ], [ 'Gregg', 'blue' ], 'Record test.');
	$row = $driver->next(-handle => $sth);
	is_deeply([ $row->{name}, $row->{color} ], [ 'Rhonda', 'red' ], 'Record test.');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');
};

if ($EVAL_ERROR) {
	diag("Test error. Attempting cleanup: $EVAL_ERROR");
}

drop_all($driver);
