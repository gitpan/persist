# vim: set ft=perl :

use Test::More tests => 18;
BEGIN { use_ok('Persist::Driver'); }

sub is_not_implemented {
	my $sub = shift;

	eval "Persist::Driver->$sub";
	if ($@) {
		pass("$sub not implemented.");
	} else {
		fail("$sub not implemented.");
	}
}

is_not_implemented('new');
is_not_implemented('is_dba');
is_not_implemented('new_source');
is_not_implemented('delete_source');
is_not_implemented('create_table');
is_not_implemented('delete_table');
is_not_implemented('tables');
is_not_implemented('open_table');
is_not_implemented('open_join');
is_not_implemented('insert');
is_not_implemented('update');
is_not_implemented('delete');
is_not_implemented('columns');
is_not_implemented('indexes');
is_not_implemented('first');
is_not_implemented('next');
is_not_implemented('sequence_value');
