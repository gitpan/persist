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
	$pgconn = q/sub pgconn { ('Persist::Driver::DBI::PostgreSQL', -uri => '@PGTESTCONN@', -username => '@PGTESTUSER@', -password => '@PGTESTPASS@') }/;
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

@folks = ( 
	-table => 'folks',
	-columns =>
	[	fid 	=> [ AUTONUMBER ],
		name	=> [ VARCHAR, 20 ],
		age		=> [ INTEGER ],
		male	=> [ BOOLEAN ], 
		r_age	=> [ REAL ], 
		dob		=> [ TIMESTAMP ], ],
	-indexes =>
	[ 	[ PRIMARY, [ 'fid' ] ],
		[ UNIQUE, [ 'name'] ] ]
);

@favorites = ( 
	-table => 'favorites',
	-columns =>
	[	favid	=> [ AUTONUMBER ],
		fid		=> [ INTEGER ],
		color	=> [ VARCHAR, 10 ] ],
	-indexes =>
	[	[ PRIMARY, [ 'favid' ] ],
		[ UNIQUE, [ 'fid', 'color' ] ],
		[ LINK, [ 'fid' ], 'folks', [ 'fid' ] ] ]
);

@folks_data = (
    { name => 'Sterling', age => 24,  male => 1, r_age => 24.7,	  dob => '1975-01-01T12:21:33Z', colors => [ 'green', 'blue' ] },
    { name => 'Terri',    age => 22,  male => 0, r_age => 22.1,	  dob => '1975-01-01T18:21:34+06:00', colors => [ 'purple', 'green' ] },
    { name => 'Gregg',    age => 46,  male => 1, r_age => 46.18,  dob => '0500-03-20T00:00:00Z', colors => [ 'blue' ] },
    { name => 'Rhonda',   age => 45,  male => 0, r_age => 45.04,  dob => '0001-10-16T14:15:16Z', colors => [ 'red' ] },
	{ name => 'James',    age => 21,  male => 1, r_age => 21.119, dob => '0001-10-16T14:15:16Z', colors => [ 'yellow', 'purple'] },
	{ name => 'Laura',    age => 15,  male => 0, r_age => 15.9,	  dob => '1996-10-31T23:59:59-12:00', colors => [] }
);

1

/;

close $out;
