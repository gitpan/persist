use 5.8.0;
use ExtUtils::MakeMaker;

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
	VERSION			=> '0.3.3',
	PREREQ_PM		=> {
		'DBI'				=> '0',
		'Date::Calc'		=> '0',
		($PGTESTCONN ? ('DBD::Pg' => '0') : ()), # require it when they use it
		'Parse::RecDescent'	=> '1.80',
	},
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
