# vim: set ft=perl :

use Test::More tests => 1;
use Persist ':constants';

is(Persist->timestamp_from_time(1058449565),
   '120030617134605+0000', 'timestamp_from_time');
