# vim: set ft=perl :

use Test::More;

use lib "$ENV{PWD}";
require "testsetup";

use Persist::Join;

@sources = &all_sources();
plan tests => scalar(@sources) * 8;

for $src (@sources) {

	eval {

		$src->new_table(@folks);
		$src->new_table(@favorites);

		$folks = $src->folks;
		$favorites = $src->favorites;
		for my $folk (@folks_data) {
			$folks->insert_now({ name => $folk->{name}, age => $folk->{age} });
			my $fid = $folks->last_fid;
			for my $favorite (@{$folk->{colors}}) {
				$favorites->insert_now({ fid => $fid, color => $favorite });
			}
		}

		ok(our $join = $src->explicit_join(
					[ o => 'folks', a => 'favorites' ],
					'o.fid = a.fid',
					"a.color = 'green'"), 'Join.');

		$join->next;
		is($join->name, 'Sterling', 'Sterling likes green.');
		$join->next;
		is($join->name, 'Terri', 'Terri likes green.');
		ok(!$join->next, 'No more records.');

		$join->first;
		is($join->name, 'Sterling', 'Sterling likes green again.');

		$join->filter('o.age > 40');
		$join->next;
		is($join->name, 'Gregg', 'Gregg is over 40.');
		$join->next;
		is($join->name, 'Rhonda', 'Rhonda is over 40.');
		ok(!$join->next, 'No more records.');

	}; if ($@) {
		diag("Error in tests. Attempting cleanup: $@");
	}

	eval {
		$src->delete_table('favorites');
	}; if ($@) {
		diag("Could not clean up favorites table: $@");
	}

	eval {
		$src->delete_table('folks');
	}; if ($@) {
		diag("Could not clean up folks table: $@");
	}

}
