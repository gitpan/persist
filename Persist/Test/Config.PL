#!/usr/bin/perl

use strict;
use warnings;

use ExtUtils::MakeMaker;
use Sys::Hostname;

my $file = shift @ARGV;

open PM, ">$file" or die "Cannot open $file";

# This script creates Persist::Test::Config for all of the included drivers. It
# will prefer to use various environment variables for configuration. If no
# environment variables are set, then it will attempt to ask the user. If there
# is no terminal present (in the case of automated installs), then we'll assume
# conservative defaults and go on.
my ($postgresql_database, $postgresql_host, $postgresql_port,
	$postgresql_username, $postgresql_password);
if (!defined $ENV{PG_DATABASE}) {
	if (prompt("Do you want to test support of PostgreSQL?", "n") =~ /y/i) {
		$postgresql_database = prompt("Enter the name of the database to connect to for testing:", "test");
		$postgresql_host     = prompt("Enter the name of the host to connect to (return for local DB):");
		$postgresql_port     = prompt("Enter the name of the port to connect to (return for local DB):");
		$postgresql_username = prompt("Enter the name of the user to connect as:", "test");

		# Attempt to hide the password. Term::ReadKey should be almost
		# everywhere, but we'll be careful just in case.
		my $use_readkey = 0;
		eval { use Term::ReadKey; $use_readkey = 1; };
		if ($@) {
			print STDERR "Could not load Term::ReadKey: $@\n";
			print STDERR "Password prompt will not hide your password (you may not care, but I'm tellin' yea anyway).\n";
		}

		ReadMode('noecho') if $use_readkey;
		$postgresql_password = prompt("Enter the PostgreSQL password to connect with:");
		ReadMode('restore') if $use_readkey;
		print "\n";
	} else {
		print "Will skip all PostgreSQL tests.\n";
	}
} else {
	$postgresql_database = $ENV{PG_DATABASE};
	$postgresql_host     = $ENV{PG_HOST};
	$postgresql_port     = $ENV{PG_PORT};
	$postgresql_username = $ENV{PG_USERNAME};
	$postgresql_password = $ENV{PG_PASSWORD};
}

my $date = localtime;
my $host = hostname;

print PM <<EOF;
# This file was automatically generated 
# on $host at $date.

package Persist::Test::Config;

use strict;
use warnings;

require Exporter;
our \@ISA = qw( Exporter );

our \@EXPORT = qw( \%options );

our \%options = (
	'Persist::Driver::Memory' => [ 'Persist::Driver::Memory' ],
EOF

if (defined $postgresql_database) {
	print PM <<EOF;
	'Persist::Driver::DBI::PostgreSQL' => [ 'Persist::Driver::DBI::PostgreSQL',
		-database => '$postgresql_database',
EOF
	print PM "\t\t-host     => '$postgresql_host',\n" if $postgresql_host;
	print PM "\t\t-port     => $postgresql_port,\n"   if $postgresql_port;
	print PM <<EOF;
		-username => '$postgresql_username',
		-password => '$postgresql_password',
	],
EOF
}

print PM <<EOF;
);

1

EOF

close PM;

exit 0;
