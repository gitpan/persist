use 5.8.0;
use ExtUtils::MakeMaker;

# Setup version information. The only time this is really important is for a
# release. When a release occurs it will be tagged so we can take the version
# from the tag. Otherwise, we just use the CVS revision which isn't really the
# version, but let's us create distributions anyway.
#
# This is used by ../Makefile.PL for version information for the entire
# package and for the PPD.
our $VERSION_TAG = '$Name: persist-0_3_2 $';
our $VERSION_REV = '$Revision: 1.7 $';
our $VERSION;

if ($VERSION_TAG =~ /\$Name:\s+persist-(\d+)_(\d+)_(\d+)(\S*)/i) {
	$VERSION = "$1.$2.$3$4";
} else {
	( $VERSION ) = '$Revision: 1.7 $' =~ /\$Revision:\s+(\S+)/;
	$VERSION .= '-nr';
}

# Take out our custom configuration directives to keep MakeMaker from whining
# (and so we can use them).
my %VARS;
my @NAMES = qw(PGTESTCONN PGTESTUSER PGTESTPASS);
for ($i = $#ARGV; $i >= 0; --$i) {
	$_ = $ARGV[$i];

	for $NAME (@NAMES) {
		if (/^$NAME=/) {
			s/^$NAME=//;
			$VARS{$NAME} = $_;
			splice @ARGV, $i, 1;
			last;
		}
	}
}

WriteMakefile(
    NAME			=> 'persist',
	VERSION			=> $VERSION,
	ABSTRACT        => 'Data persistence library allowing for a write-once/run-anywhere approach.',
);

# Remember our custom constants
sub MY::const_config {
	my $inherited = shift->MM::const_config(@_);
	$inherited .= qq(
# --- Contentment custom constants
PGTESTCONN = $VARS{PGTESTCONN}
PGTESTUSER = $VARS{PGTESTUSER}
PGTESTPASS = $VARS{PGTESTPASS}
);
}

# A custom extension to create some test configuration files
sub MY::processPL {
	my $inherited = shift->MM::const_config(@_);
	$inherited .= q(
# --- Contentment custom processPL section
all :: blib/lib/testsetup
	@$(NOOP)
);
}

# Generate our test configuration files
sub MY::postamble {
q(
# -- Contentment custom postamble
blib/lib/testsetup :: testsetup.PL
	PGTESTCONN="$(PGTESTCONN)" PGTESTUSER="$(PGTESTUSER)" PGTESTPASS="$(PGTESTPASS)" \
	$(PERLRUNINST) testsetup.PL blib/lib/testsetup
);
}
