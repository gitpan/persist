# vim: set ft=perl :

use Test::More;
use Persist::Test qw(@folks @favorites next_source count_sources);
use Persist qw( :constants );
use Persist::Source;

plan tests => 10 * count_sources;;

while (my ($name, $source) = next_source) {

	eval {
		is($source->is_dba, 1, 'Check DBA.');

#		ok($source->new_source(-username => 'test', -password => 'test'), 'New source.');
#		ok($source->delete_source(-username => 'test'), 'Delete source.');

		ok($source->new_table(@folks), 'New table.');
		ok($source->new_table(@favorites), 'Delete table.');

		ok(grep(/^(?:favorites|folks)$/, $source->tables) == 2, 'Tables.');

		ok(defined $source->join([ 'favorites', 'folks' ]), 'Join tables.');
		ok(defined $source->join(
						[ 'folks','favorites' ],
						'1.fid = 2.fid',
						"color = 'purple'"), 'Explicitly join tables.');

		ok(defined $source->table('folks'), 'Table.');
		ok(defined $source->folks, 'Folks.');

		ok($source->delete_table('favorites'), 'Delete table.');

		ok(grep(/^(?:favorites|folks)$/, $source->tables) == 1, 'Tables.');
	
	}; 
	
	if ($@) {
		diag("Error testing [$name]: $@");
	}
}
