use 5.008;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME			=> 'Persist::Driver::DBI::PostgreSQL',
	VERSION_FROM	=> 'PostgreSQL.pm',
	AUTHOR			=> 'Andrew Sterling Hanenkamp <hanenkamp@users.sourceforge.net>',
);
