# vim: set ft=perl :

use Test::More;
use Persist::Test qw(@folks @favorites @folks_data next_source count_sources);
use Persist::Join;

plan tests => 8 * count_sources;

while (my ($name, $src) = next_source) {
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

		ok(our $join = $src->join([ 'folks', 'favorites' ], 
								  -filter => "color = 'green'"), 'Join.');

		$join->next(1);
		is($join->folks->name, 'Sterling', 'Sterling likes green.');
		$join->next(1);
		is($join->folks1->name, 'Terri', 'Terri likes green.');
		ok(!$join->next, 'No more records.');

		$join->first(1);
		is($join->table(1)->name, 'Sterling', 'Sterling likes green again.');

		$join->filter('age > 40');
		$join->next(1);
		is($join->table("folks")->name, 'Gregg', 'Gregg is over 40.');
		$join->next(1);
		is($join->table("folks1")->name, 'Rhonda', 'Rhonda is over 40.');
		ok(!$join->next(1), 'No more records.');

	};
	
	if ($@) {
		diag("Error in tests [$name]: $@");
	}
}
