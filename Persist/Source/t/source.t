# vim: set ft=perl :

use Test::More;

use Persist qw( :constants );
use Persist::Source;

require 'testsetup';

@sources = &all_sources();
plan tests => scalar(@sources) * 12;
for $source (@sources) {

	eval {
		is($source->is_dba, 1, 'Check DBA.');

		ok($source->new_source(-username => 'test', -password => 'test'), 'New source.');
		ok($source->delete_source(-username => 'test'), 'Delete source.');

		ok($source->new_table(@folks), 'New table.');
		ok($source->new_table(@favorites), 'Delete table.');

		ok(grep(/^(?:favorites|folks)$/, $source->tables) == 2, 'Tables.');

		ok(defined $source->join([ 'favorites', 'folks' ]), 'Join tables.');
		ok(defined $source->explicit_join(
						[ o => 'folks', a => 'favorites' ],
						'o.fid = a.fid',
						"a.color = 'purple'"), 'Explicitly join tables.');

		ok(defined $source->table('folks'), 'Table.');
		ok(defined $source->folks, 'Folks.');

		ok($source->delete_table('favorites'), 'Delete table.');

		ok(grep(/^(?:favorites|folks)$/, $source->tables) == 1, 'Tables.');
	
	}; if ($@) {
		diag("Error testing. Attempting cleanup: $@");
	}

	eval {
		$source->delete_table('favorites') if grep /^favorites$/, $source->tables;
	}; if ($@) {
		diag("Could not clean up favorites: $@");
	}

	eval {
		$source->delete_table('folks') if grep /^folks$/, $source->tables;
	}; if ($@) {
		diag("Could not clean up folks: $@");
	}

}
