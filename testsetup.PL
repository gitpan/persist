# vim: set ft=perl :

my $outfile = shift @ARGV;
open $out, ">$outfile" or die "Cannot open $outfile: $!";

print $out q/# THIS IS A GENERATED FILE! IT WILL BE OVERWRITTEN!
#
# See README for information on modifying these settings.

# vim: set ft=perl :

use Persist qw(:constants);
use Persist::Driver::Memory;
use Persist::Driver::DBI::PostgreSQL;
use Persist::Source;

/;

if (defined $ENV{PGTESTCONN} and $ENV{PGTESTCONN} ne '') {
	$pgconn = q/sub pgconn { ('Persist::Driver::DBI::PostgreSQL', '@PGTESTCONN@', '@PGTESTUSER@', '@PGTESTPASS@') }/;
	$pgconn =~ s/\@([^\@]+)\@/$ENV{$1}/g;
} else {
	$pgconn = q/sub pgconn { undef }/;
}

print $out $pgconn,"\n";
print $out qq/sub use_pgconn { defined pgconn }\n/;
print $out qq/sub memconn { ('Persist::Driver::Memory') }\n/;
print $out qq/sub use_memconn { 1 }\n/;

print $out q/
@USES = ( use_pgconn, use_memconn );
@CONNS = ( [ pgconn ], [ memconn ] );

sub all_conns {
	@result;
	for ($i = 0; $i < @USES; ++$i) {
		$USES[$i] and push @result, $CONNS[$i];
	}
	@result;
}

sub all_sources {
	map { Persist::Source->new(@$_) } all_conns;
}

$skippg = use_pgconn() ? 0 : 'PostgreSQL tests are not configured.';
$skipmem = use_memconn() ? 0 : 'Memory tests are not configured.';

@folks = ( 'folks',
	{	fid 	=> [ AUTONUMBER ],
		name	=> [ VARCHAR, 20 ],
		age		=> [ INTEGER ],
		male	=> [ BOOLEAN ], 
		r_age	=> [ REAL ], 
		dob		=> [ TIMESTAMP ], },
	[ 	[ PRIMARY, [ 'fid' ] ],
		[ UNIQUE, [ 'name'] ] ]
);

@favorites = ( 'favorites',
	{	favid	=> [ AUTONUMBER ],
		fid		=> [ INTEGER ],
		color	=> [ VARCHAR, 10 ] },
	[	[ PRIMARY, [ 'favid' ] ],
		[ UNIQUE, [ 'fid', 'color' ] ],
		[ LINK, [ 'fid' ], 'folks', [ 'fid' ] ] ]
);

@folks_data = (
    { name => 'Sterling', age => 24,  male => 1, r_age => 24.7,	  dob => '119750001122133+0000', colors => [ 'green', 'blue' ] },
    { name => 'Terri',    age => 22,  male => 0, r_age => 22.1,	  dob => '119750001182134+0600', colors => [ 'purple', 'green' ] },
    { name => 'Gregg',    age => 46,  male => 1, r_age => 46.18,  dob => '005000220000000+0000', colors => [ 'blue' ] },
    { name => 'Rhonda',   age => 45,  male => 0, r_age => 45.04,  dob => '000010916141516+0000', colors => [ 'red' ] },
	{ name => 'James',    age => 21,  male => 1, r_age => 21.119, dob => '100010916141516+0000', colors => [ 'yellow', 'purple'] },
	{ name => 'Laura',    age => 15,  male => 0, r_age => 15.9,	  dob => '119961131235959-1200', colors => [] }
);

1

/;

close $out;
