use English;
use Test::More tests => 8;
use Persist ':constants';
use Persist::Test ':driver';

my $driver = init;

create_n_fill($driver);

eval {
	$sth = $driver->open_table(
		-table  => 'folks', 
		-order  => [ 'name' ],
		-offset => 2,
		-limit  => 3,
	);
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Laura');
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Rhonda');
	$row = $driver->next(-handle => $sth);
	is($row->{name}, 'Sterling');
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'None left.');
	
	$sth = $driver->open_join(
		-tables => [ 'folks', 'favorites' ],
		-order  => [ 'name', DESCENDING, 'color' ],
		-offset => 2,
		-limit  => 3,
	);
	$row = $driver->next(-handle => $sth);
	is_deeply([ $row->{name}, $row->{color} ], [ 'Sterling', 'blue' ]);
	$row = $driver->next(-handle => $sth);
	is_deeply([ $row->{name}, $row->{color} ], [ 'Sterling', 'green' ]);
	$row = $driver->next(-handle => $sth);
	is_deeply([ $row->{name}, $row->{color} ], [ 'Rhonda', 'red' ]);
	$row = $driver->next(-handle => $sth);
	ok(!$row, "None left.");
};

if ($EVAL_ERROR) {
	diag("Test error. Attempting cleanup: $EVAL_ERROR");
}

drop_all($driver);
