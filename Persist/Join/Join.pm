package Persist::Join;

use 5.008;
use strict;
use warnings;

use Persist::Tabular;

our @ISA = qw(Persist::Tabular);

our $AUTOLOAD;
our ( $VERSION ) = '$Revision: 1.4 $' =~ /\$Revision:\s+([^\s]+)/;

=head1 NAME

Persist::Join - Data abstraction representing the joining of multiple tables

=head1 SYNOPSIS

  use Persist::Source;

  # For joins where a FOREIGN KEY may be used to perform the join implicitly
  $source = new Persist::Source(...);
  $join = $source->join([ 'Folks', 'Favorites' ], 
                        [ undef, "color = 'Blue'" ]);

  print "Folks with whose favorite color is Blue:\n";
  while ($join->next) {
	  print $join->name, "\n";
  }

  # For explicit joins where there is no FOREIGN KEY, or implicit joining is
  # undesirable
  $join = $source->explicit_join(
                        { O => 'Folks', A => 'Favorites' },
                        [ "O.fid = A.fid" ], "A.color = 'Blue'");

=head1 DESCRIPTION

This abstraction allows for easy access to multiple joined tables. It is an
extension of L<Persist::Tabular> and most of the functionality available is
documented there.

=over

=item $join = $source->join($tables, $filters)

See L<Persist::Source> for details.

=cut

sub new {
	my ($class, $driver, $tables, $filter) = @_;

	my $self = bless {}, ref $class || $class;
	$self->{-driver} = $driver;
	$self->{-tables} = $tables;
	$self->{-filter} = $filter;

	$self;
}

=item $join = $source->explicit_join($tables, $as_exprs, $filter)

See L<Persist::Source> for details.

=cut

sub new_explicit {
	my ($class, $driver, $tables, $as_exprs, $filter) = @_;

	my $self = bless {}, ref $class || $class;
	$self->{-explicit} = 1;
	$self->{-driver} = $driver;
	$self->{-tables} = $tables;
	$self->{-as_exprs} = (ref $as_exprs ? $as_exprs : [ $as_exprs ]);
	$self->{-filter} = $filter;

	$self;
}

# =item $self-E<gt>_open($reset)
#
# Tells the driver to open a join or an explicit join.
#
sub _open {
	my ($self, $reset) = @_;

	if ($reset or not $self->{-handle}) {
		if ($self->{-explicit}) {
			$self->{-handle} = $self->{-driver}->open_explicit_join
					($self->{-tables}, $self->{-as_exprs}, $self->{-filter})
		} else {
			$self->{-handle} = $self->{-driver}->open_join
					($self->{-tables}, $self->{-filter});
		}
	}
}

=back

=head1 SEE ALSO

L<Persist::Tabular>, L<Persist::Source>

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
    * Neither the name of the Contentment nor the names of its 
      contributors may be used to endorse or promote products derived 
      from this software without specific prior written permission.

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
