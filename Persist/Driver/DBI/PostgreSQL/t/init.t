# vim: set ft=perl :

use Test::More;

use lib "$ENV{PWD}";
require 'testsetup';

plan tests => 1 unless $skippg;
plan skip_all => $skippg if $skippg;

@conn = &pgconn(); shift @conn;
$driver = new Persist::Driver::DBI::PostgreSQL(@conn);

is(ref $driver, 'Persist::Driver::DBI::PostgreSQL', 'new Driver');

