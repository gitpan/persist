# vim: set ft=perl :

use Test::More;

use Persist qw( :constants );
use Persist::Table;

require "testsetup";

our @sources = &all_sources();
plan tests => scalar(@sources) * 24;
for $src (@sources) {

	eval {

		$src->new_table(@folks);

		ok(defined ($table = $src->table('folks', "name = 'James'")), "Table.");

		is($table->table_name, 'folks', 'Table name.');

		$i = 0;
		for my $folk (@folks_data) {
			$table->insert_now({name => $folk->{name}, age => $folk->{age}});

			is($table->last_value('fid'), ++$i, 'Last value.');
			is($table->last_fid, $i, 'Last value (AUTOLOAD).');
		}

		$table->first; # first must be used since we just changed the table
		is($table->name, 'James', 'James.');
		ok(!$table->next, 'No more records.');

		$table->first;
		is($table->name, 'James', 'James again.');

		$table->filter('age > 40');
		$table->next;
		is($table->name, 'Gregg', 'Gregg is over 40.');
		$table->delete;

		$table->first;
		is($table->name, 'Rhonda', 'Rhonda is over 40.');
		$table->name('Bob');
		ok(!$table->next, 'No more records.');

		$table->first;
		is($table->name, 'Bob', 'Rhonda changed her name to Bob.');
		$table->name('Carl');
		$table->cancel;
		ok(!$table->next, 'No more records.');

		$table->first;
		is($table->name, 'Bob', 'Bob changed his mind and did not want to be Carl.');
		ok(!$table->next, 'No more records.');

	}; if ($@) {
		diag("Error testing. Attempting cleanup: $@");
	}

	eval {
		$src->delete_table(@folks);
	}; if ($@) {
		diag("Error cleaning folks: $@");
	}

}
