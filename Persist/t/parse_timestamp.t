# vim: set ft=perl :

use Test::More tests => 1;
use Persist ':constants';

is_deeply([ Persist->parse_timestamp(
	'120030617084056-0600'
		 ) ], ['1','20','03','06','17','08','40','56','-0600'], 'parse_timestamp');
