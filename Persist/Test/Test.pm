package Persist::Test;

use 5.008;
use strict;
use warnings;

use Carp;
use File::Spec;
use Test::Harness;

use Getargs::Mixed;

require Exporter;

use Persist ':constants';
use Persist::Test::Config;

our @EXPORT = qw( %sources );

our %EXPORT_TAGS = (
	driver => [ qw( 
		@folks @favorites @folks_data %options
		create drop drop_all create_n_fill init
	) ]
);

our @EXPORT_OK = @{$EXPORT_TAGS{driver}};

our @ISA = qw( Exporter );
our ($VERSION) = '$Revision: 1.1 $' =~ /\$Revision:\s(\S+)/;

=head1 NAME

Persist::Test - Persist helper for testing drivers

=head1 SYNOPSIS

  use Persist::Test;

  while (my ($name, $source) = each %source) {
	  # create your tables and run your code
	  # don't bother cleaning up, this will be done for you
  }

=head1 DESCRIPTION

This tool provides a standard set of tests for testing the standards compliance
of Persist drivers and for testing user code against all installed database
systems.

As far as the typical user need know the standards compliance testing happens
automatically when C<make test> is called. However, If you are interested in
writing a driver, then you'll just have to examine the guts of existing drivers
as there is no documentation on how to use this system to test your code--it's
pretty simple to hack.

=head2 TESTING USER CODE

If you use Persist and would like to make certain that you code will work
against all configured drivers--as each driver may vary slightly, here is the
plan: (1) write your code, (2) write each unit test using the shell given in the
L<SYNOPSIS|/SYNOPSIS>, (3) run your tests. Easy.

You don't even need to clean-up--assuming that all your work is done in tables
you created during the test. Any table created during the test will be dropped
when the test exits. There is always a chance this will fail, but if it does the
system will complain to the user exactly what has happened and what appears to
be required to fix it.

B<WARNING:> At this time, the testing system is not yet able to cleanup after
newly created sources. This is a feature we'd like to have, but it simply isn't
feasible right now. Therefore, you must clean up any sources you create
yourself--creating sources is itself would be a challenge since each driver
manages sources differently and you can't (easily) tell which driver you are
using. At this time, it is recommended that you don't mess with creating and
deleting sources during tests, unless you do so by some other method than this
test framework.

=cut

package Persist::Test::Source;

# This is a wrapper around a real source. All operations are passed on as-is,
# but we watch the new_source, new_table, delete_source, and delete_table to
# keep track of the stuff they add. Then, when it comes time to be DESTROYed, we
# tell the source to wax anything they've left.
my $init = sub {
	my $self = shift;
	my ($package, @options) = @{$$self{-options}};
	unless (defined $$self{-source}) {
		eval "package Persist::Test::_safe; use $package";
		if ($@) {
			die "Could not load $package: $@";
		}
		$$self{-source} = $package->new(@options);
	}
};

sub new {
	my $class = shift;
	return bless {
		-options => [ @_ ],
	}, $class;
}

sub new_table {
	my ($self, %args) = parameters('self', [qw(table columns indexes)], @_);

	&$init($self);
	my $result = $$self{-source}->new_table(
		-table   => $args{table},
		-columns => $args{columns},
		-indexes => $args{indexes},
	);
	$$self{-tables}{$args{table}} = 1;
	return $result;
}

sub delete_table {
	my ($self, %args) = parameters('self', [qw(table)], @_);

	&$init($self);
	my $result = $$self{-source}->delete_table(-table => $args{table});
	delete $$self{-tables}{$args{table}};
	return $result;
}

our $AUTOLOAD;
sub AUTOLOAD {
	my ($self, @args) = @_;
	&$init($self);
	my ($sub) = $AUTOLOAD =~ /([^:]+)$/;
	no strict 'subs';
	$$self{-source}->$sub(@args);
}

sub DESTROY {
	my $self = shift;
	for (keys %{$$self{-tables}}) {
		$$self{-source}->delete_table($_);
	}
}

package Persist::Test;

our @folks = ( 
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

our @favorites = ( 
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

our @folks_data = (
    { name => 'Sterling', age => 24, male => 1, r_age => 24.7,	 dob => '1975-01-01T12:21:33Z',      colors => [ 'green', 'blue' ] },
    { name => 'Terri',    age => 22, male => 0, r_age => 22.1,	 dob => '1975-01-01T18:21:34+06:00', colors => [ 'purple', 'green' ] },
    { name => 'Gregg',    age => 46, male => 1, r_age => 46.18,  dob => '0500-03-20T00:00:00Z',      colors => [ 'blue' ] },
    { name => 'Rhonda',   age => 45, male => 0, r_age => 45.04,  dob => '0001-10-16T14:15:16Z',      colors => [ 'red' ] },
	{ name => 'James',    age => 21, male => 1, r_age => 21.119, dob => '0001-10-16T14:15:16Z',      colors => [ 'yellow', 'purple'] },
	{ name => 'Laura',    age => 15, male => 0, r_age => 15.9,	 dob => '1996-10-31T23:59:59-12:00', colors => [] }
);

our %sources;
while (my ($name, $options) = each %options) {
	$sources{$name} = Persist::Test::Source->new(@$options);
}

sub init {
	my ($package, %options) = @{$options{$ENV{PERSIST_TEST_DRIVER}}};
	eval "use $package";
	if ($@) {
		die "Cannot load package $package: $@";
	}
	return $package->new(%options);
}

my %created;
sub create {
	my ($driver, $table) = @_;

	if ($table eq 'folks') {
		$driver->create_table(@folks);
		$created{'folks'} = 1;
	} elsif ($table eq 'favorites') {
		$driver->create_table(@favorites);
		$created{'favorites'} = 1;
	} else {
		croak "I don't know how to create '$table'.";
	}
}

sub drop {
	my ($driver, $table) = @_;

	if ($created{$table}) {
		$driver->delete_table(-table => $table);
		delete $created{$table};
	}
}

sub drop_all {
	my ($driver) = @_;

	for my $table (keys %created) {
		drop($driver, $table);
	}
}

sub create_n_fill {
	my ($driver) = @_;

	create($driver, 'folks') unless $created{'folks'};
	create($driver, 'favorites') unless $created{'favorites'};

	for my $folk (@folks_data) {
		$driver->insert(-table => 'folks', -values => {
				name  => $folk->{name},
				age   => $folk->{age},
				male  => $folk->{male},
				r_age => $folk->{r_age},
				dob   => $folk->{dob},
			});
		my $fid = $driver->sequence_value(-table => 'folks', -column => 'fid');
		for my $color (@{$folk->{colors}}) {
			$driver->insert(-table => 'favorites', -values => {
					fid   => $fid,
					color => $color,
				});
		}
	}
}

our $instance;
sub new {
	my ($class, $test) = @_;

	# Return this to tell run to simply exit if the given test isn't configured
	return $instance = bless { -stop => 1, -test => $test }, $class
		unless defined $options{$test};

	$ENV{PERSIST_TEST_DRIVER} = $test;
	return $instance = bless { -test => $test }, $class;
}

sub run {
	my $self = shift;

	if ($$self{-stop}) {
		print STDERR "Skipping tests because $$self{-test} is not configured.\n";
		return 1;
	}

	# Find the tests
	for my $inc (@INC) {
		my $glob = File::Spec->catfile($inc, 'Persist', 'Test', 'tests', '*.pl');
		my @files = glob $glob;
		if (@files) {
			return runtests(@files);
		}
	}

	croak "Could not locate Persist::Test::tests::*.pl tests.";
}

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

  Copyright (c) 2003, Andrew Sterling Hanenkamp
  All rights reserved.

  Redistribution and use in source and binary forms, with or without 
  modification, are permitted provided that the following conditions 
  are met:

    * Redistributions of source code must retain the above copyright 
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright 
      notice, this list of conditions and the following disclaimer in 
      the documentation and/or other materials provided with the 
      distribution.
    * Neither the name of the Persist nor the names of its contributors 
	  may be used to endorse or promote products derived from this
	  software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
  COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
  POSSIBILITY OF SUCH DAMAGE.

=cut

1
