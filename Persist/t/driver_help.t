# vim: set ft=perl :

use Test::More tests => 1;

package Persist::Foo;
use Persist ':driver_help';

sub doit {
	croak "A bad thing!";
}

package Persist::Bar;

sub doit {
	Persist::Foo::doit;
}

package Persist::Baz;

sub doit {
	Persist::Bar::doit;
}

package main;

eval { Persist::Baz::doit };
is($@, "A bad thing! in t/driver_help.t on line 26.\n", "carp");
