# vim: set ft=perl :

use Test::More;
use Persist::Filter;

@the_filters = (
	"a <> b",
	"(a ILIKE 'a\%b\\'_')",
	"not a = +40.1183e-108",
	"o.age > 40 and (a.color = 'blue' and not a.color = 'green')",
);

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

@nonconforming_filters = (
	"(o->name =~ /Bob.*/)",
	"(& (name = 'Bob') (age > 40) (color = 'red'))",
);

@nonconforming_asts = (
	$comp->new($id->new('o->name'), '=~', $str->new('/Bob.*/')),
	$junc->new('&', $comp->new($id->new('name'),'=', $str->new("'Bob'")),
					$comp->new($id->new('age'),'>',$num->new('40')),
					$comp->new($id->new('color'),'=',$str->new("'red'"))),
);

plan tests => scalar(@the_filters)*2 + scalar(@nonconforming_filters);

for $i (0 .. $#the_filters) {
	$ast = parse_filter($the_filters[$i]);
	is_deeply($ast, $the_asts[$i]);

	$filter = unparse_filter($the_asts[$i]);
	$ast = parse_filter($filter);
	is_deeply($ast, $the_asts[$i]);
}

for $i (0 .. $#nonconforming_filters) {
	$filter = unparse_filter($nonconforming_asts[$i]);
	is($filter, $nonconforming_filters[$i]);
}
