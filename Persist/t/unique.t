# vim: set ft=perl :

use Test::More tests => 1;
use Persist ':constants';

ok(defined(UNIQUE), "UNIQUE constant.");
