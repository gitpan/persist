use 5.008;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME			=> 'Persist::Filter',
    VERSION_FROM	=> 'Filter.pm',
    PREREQ_PM		=> { 'Parse::RecDescent' => 1.80 },
    AUTHOR			=> 'Andrew Sterling Hanenkamp <hanenkamp@users.sourceforge.net>',
);
