use 5.008;
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

# Provide a much easier way to configure PostgreSQL tests, the other method
# will probably go away eventually.
if (!defined $VARS{PGTESTCONN}) {
	if (prompt("Do you want to test support of PostgreSQL?", "n") =~ /y/i) {
		$VARS{PGTESTCONN} = prompt("Enter the connection URI to a PostgreSQL database we can use:", "dbname=test");
		$VARS{PGTESTUSER} = prompt("Enter the PostgreSQL user to connect as:", "test");

		# Attempt to hide the password. Term::ReadKey should be almost everywhere,
		# but we'll be careful just in case.
		my $use_readkey = 0;
		eval { use Term::ReadKey; $use_readkey = 1; };
		if ($@) {
			print STDERR "Could not load Term::ReadKey: $@\n";
			print STDERR "Password prompt will not hide your password (you may not care, but I'm tellin' ya anyway).\n";
		}

		ReadMode('noecho') if $use_readkey;
		$VARS{PGTESTPASS} = prompt("Enter the PostgreSQL password to connect with:");
		ReadMode('restore') if $use_readkey;
		print "\n";
	} else {
		print "Will skip all PostgreSQL tests.\n";
	}
}

WriteMakefile(
    NAME			=> 'persist',
	VERSION_FROM	=> 'Persist/Persist.pm',
	PREREQ_PM		=> {
		'DBI'						=> '1.37',
		'DateTime'					=> '0.17',
		'DateTime::Format::ISO8601'	=> '0.03',
        'Getargs::Mixed'            => '1.03',
		# require them when they use them
		($PGTESTCONN ? (
				'DBD::Pg' 				=> '1.22',
				'DateTime::Format::Pg'	=> '0.05',
			) : ()),
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
