use 5.008;
use ExtUtils::MakeMaker;
use File::Basename;
use File::Spec;

my %tests;
my @tests = <tests/*.pl>;
for (@tests) {
	$tests{$_} = File::Spec->catfile('$(INST_LIBDIR)', 'Test', $_);
}

WriteMakefile(
    NAME			=> 'Persist::Test',
    VERSION_FROM	=> 'Test.pm',
	AUTHOR			=> 'Andrew Sterling Hanenkamp <hanenkamp@users.sourceforge.net>',
	PL_FILES		=> {
		'Config.PL' => '$(INST_LIBDIR)/Test/Config.pm'
	},
	PM				=> {
		'Test.pm' => '$(INST_LIBDIR)/Test.pm',
		%tests
	},
);
