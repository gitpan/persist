use 5.008;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME			=> 'persist',
	VERSION_FROM	=> 'Persist/Persist.pm',
	PREREQ_PM		=> {
		'DBI'						=> '1.37',
		'DateTime'					=> '0.17',
		'DateTime::Format::ISO8601'	=> '0.03',
        'Getargs::Mixed'            => '1.03',
		'Tree::BPTree'				=> '1.06',
		# require them when they use them
		($PGTESTCONN ? (
				'DBD::Pg' 				=> '1.22',
				'DateTime::Format::Pg'	=> '0.05',
			) : ()),
	},
	ABSTRACT        => 'Data persistence library allowing for a write-once/run-anywhere approach.',
);
