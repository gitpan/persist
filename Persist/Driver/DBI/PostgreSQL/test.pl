#!/usr/bin/perl

use Persist::Test;

$tester = Persist::Test->new('Persist::Driver::DBI::PostgreSQL');
$tester->run;
