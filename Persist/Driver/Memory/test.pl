#!/usr/bin/perl

use Persist::Test;

$tester = Persist::Test->new('Persist::Driver::Memory');
$tester->run;
