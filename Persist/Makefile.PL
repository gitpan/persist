use 5.008;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME			=> 'Persist',
	VERSION_FROM	=> 'Persist.pm',
	AUTHOR			=> 'Andrew Sterling Hanenkamp <hanenkamp@users.sourceforge.net>',
    MAN3PODS        => { 'Overview.pod' => '$(INST_MAN3DIR)/Persist::Overview.3pm' },
    PM              => { 
		'Overview.pod' => '$(INST_LIBDIR)/Persist/Overview.pod',
		'Persist.pm'   => '$(INST_LIBDIR)/Persist.pm'
	},
);
