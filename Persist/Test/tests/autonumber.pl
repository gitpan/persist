# vim: set ft=perl :

use English;
use Test::More tests => 6;
use Persist::Test ':driver';

my $driver = init;
	
create($driver, 'folks');

eval {
	$i = 1;
	for $folk (@folks_data) {
		$driver->insert(-table => 'folks', -values => { name => $folk->{name}, age => $folk->{age} });
		$fid = $driver->sequence_value(-table => 'folks', -column => 'fid');
		is($fid, $i++, 'Sequence test.');
	}

};

if ($EVAL_ERROR) {
	diag("Test error. Attempting cleanup: $EVAL_ERROR");
}

drop_all($driver);
