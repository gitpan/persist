package Persist::Join;

use 5.008;
use strict;
use warnings;

use Persist::Tabular;

our @ISA = qw(Persist::Tabular);

our $AUTOLOAD;
our ( $VERSION ) = '$Revision: 1.7 $' =~ /\$Revision:\s+([^\s]+)/;

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

  # For explicit joins where there is no foreign key, to join a table to itself,
  # tables have multiple foreign keys between each otheror implicit joining is
  # undesirable
  $join = $source->join(-tables => [ 'Folks', 'Favorites' ],
                        -on     => [ "1.fid = 2.fid" ],
                        -filter => "Favorites.color = 'Blue'");

=head1 DESCRIPTION

This abstraction allows for easy access to multiple joined tables. It is an
extension of L<Persist::Tabular> and most of the functionality available is
documented there.

=over

=item $join = $source->join($tables [, $on, $filters, \@order, $offset, $limit ])

See L<Persist::Source> for details.

=cut

sub new {
	my ($class, $driver, $tables, $on, $filter, $order, $offset, $limit) = @_;

	my $self = bless {}, ref $class || $class;
	$self->{-driver} = $driver;
	$self->{-tables} = $tables;
	$self->{-on}     = $on;
	$self->{-filter} = $filter;
	$self->{-order}  = $order;
	$self->{-offset} = $offset;
	$self->{-limit}  = $limit;

	$self;
}

# =item $self-E<gt>_open($reset)
#
# Tells the driver to open a join.
#
sub _open {
	my ($self, $reset) = @_;

	if ($reset or not $self->{-handle}) {
		$self->{-handle} = $self->{-driver}->open_join(
			-tables		=> $self->{-tables},
			-on         => $self->{-on},
			-filter		=> $self->{-filter},
			-order		=> $self->{-order},
			-offset		=> $self->{-offset},
			-limit		=> $self->{-limit},
		);
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
