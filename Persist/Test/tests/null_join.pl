# vim: set ft=perl :

use English;
use Test::More tests => 1;
use Persist::Test ':driver';

my $driver = init;

create($driver, 'folks');
create($driver, 'favorites');

eval {
	$sth = $driver->open_join(-tables => [ 'folks', 'favorites' ]);
	$row = $driver->next(-handle => $sth);
	ok(!$row, 'Record test.');
};

if ($EVAL_ERROR) {
	diag("Test error. Attempting cleanup: $EVAL_ERROR");
}

drop_all($driver);
