# vim: set ft=perl :

use Test::More;
use Digest::MD5;
use Persist::Filter;

my $id = 'Persist::Filter::Identifier';
my $str = 'Persist::Filter::String';
my $num = 'Persist::Filter::Number';
my $comp = 'Persist::Filter::Comparison';
my $not = 'Persist::Filter::Not';
my $junc = 'Persist::Filter::Junction';

@the_asts = (
	$comp->new($id->new('a'), '<>', $id->new('b')),
	$comp->new($id->new('a'), 'ilike', $str->new("'a\%b\\'_'")),
	$not->new('not', $comp->new($id->new('a'), '=', $num->new('+40.1183e-108'))),
	$junc->new($comp->new($id->new('o.age'), '>', $num->new('40')), 'and', 
			   $junc->new($comp->new($id->new('a.color'), '=', 
			   			  			 $str->new("'blue'")), 'and', 
						  $not->new('not', $comp->new($id->new('a.color'), '=', 
						  							  $str->new("'green'"))))),
);

@nonconforming_asts = (
	$comp->new($id->new('o->name'), '=~', $str->new('/Bob.*/')),
	$junc->new('&', $comp->new($id->new('name'),'=', $str->new("'Bob'")),
					$comp->new($id->new('age'),'>',$num->new('40')),
					$comp->new($id->new('color'),'=',$str->new("'red'"))),
);

plan tests => scalar(@the_asts) + scalar(@nonconforming_asts);

# This is *a* way I thought of to do this. I create a checksum of the objects
# while walking via my own walker and then compare the checksum result to the
# result of the Oh-fficial walkers.
sub checksum_walker {
	my $o = shift;

	if (UNIVERSAL::isa($o, 'Persist::Filter::Operand')) {
		$ctx->add($$o);
	} elsif (UNIVERSAL::isa($o, 'Persist::Filter::AST')) {
		checksum_walker($_) foreach (@$o);
	} elsif (ref $o eq 'SCALAR') {
		$ctx->add($$o);
	} elsif (ref $o eq 'ARRAY') {
		checksum_walker($_) foreach (@$o);
	} elsif (not ref $o) {
		$ctx->add($o);
	} else {
		die "What is this thing? $o"
	}
}

sub checksum {
	my $o = shift;

	if (UNIVERSAL::isa($o, 'Persist::Filter::Operand')) {
		$ctx->add($$o);
	} elsif (ref $o eq 'SCALAR') {
		$ctx->add($$o);
	} elsif (not ref $o) {
		$ctx->add($o);
	}	
}
		
@the_asts_checksums = map { $ctx = new Digest::MD5; checksum_walker($_); $ctx->hexdigest } @the_asts;
@nonconforming_asts_checksums = map { $ctx = new Digest::MD5; checksum_walker($_); $ctx->hexdigest } @nonconforming_asts;

for $i (0 .. $#the_asts) {
 	$ctx = new Digest::MD5;
	$the_asts[$i]->remap(\&checksum);
	is($the_asts_checksums[$i], $ctx->hexdigest);
}

for $i (0 .. $#nonconforming_asts) {
 	$ctx = new Digest::MD5;
	$nonconforming_asts[$i]->remap(\&checksum);
	is($nonconforming_asts_checksums[$i], $ctx->hexdigest);
}
