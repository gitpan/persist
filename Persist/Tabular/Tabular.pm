package Persist::Tabular;

use 5.008;
use strict;
use warnings;

use Carp;

our $AUTOLOAD;
our ( $VERSION ) = '$Revision: 1.4 $' =~ /\$Revision:\s+([^\s]+)/;

=head1 NAME

Persist::Tabular - Abstract base class for Persist::Table and Persist::Join

=head1 SYNOPSIS

See L<Persist::Tabular> and L<Persist::Join> for a synopsis of the
functionality provided by Persist::Tabular.

=head1 DESCRIPTION

Provides functionality common to Persist::Table and Persist::Join.
Specifically, the iterator functionality.

=over

=cut

# =item $tabular = new Persist::Tabular($driver)
#
# Creates a new object using the given driver.
#
sub new {
	my ($class, $driver) = @_;

	my $self = bless {}, ref $class || $class;
	$self->{-driver} = $driver;

	$self;
}

# =item $self-E<gt>_open($reset)
#
# Tells the driver to open the appropriate object.
#
sub _open {
	die "Must be implemented by subclass.";
}

# =item $self-E<gt>_sync($reset)
#
# Saves any changes made since the last C<_sync>.
#
sub _sync {
	my ($self, $reset) = @_;
	$self->_open($reset);
}

=item $tabular-E<gt>first

Moves the iterator position to the first row of the data set. This method
should be used to reset the data position to the beginning.  Either this
method or C<next> must be called before data is accessed.  If there are
changes pending in the current row, then those changes are saved before moving
the iterator position.

This method should be avoided when possible as it may entail a greater
performance cost associated with resetting cursors and such in the underlying
driver.

=cut

sub first {
	my $self = shift;

	$self->_sync;
	$self->{-data} = $self->{-driver}->first($self->{-handle});
	$self->{-data} ? $self : undef;
}

=item $tabular-E<gt>next

Moves the iterator position to the next row of the data set. Either this
method or C<first> must be called before data is accessed. This is the
preferred method as it doesn't result in restarting calls which may involve
resetting cursors, etc. in the driver's store. If there are changes pending in
the current row, then those changes are saved before moving the iterator
position.

=cut

sub next {
	my $self = shift;

	$self->_sync;
	$self->{-data} = $self->{-driver}->next($self->{-handle});
	$self->{-data} ? $self : undef;
}

=item $tabular->filter($filter)

Changes the filter or filters used to filter the data set and resets the
driver handle. Either C<first> or C<next> must be called to access the data
after this call is made.

=cut

sub filter {
	my ($self, $filter) = @_;

	$self->{-filter} = $filter;
	$self->_sync(1);
	$self;
}

=item $tabular-E<gt>value($column)

Reads the data found in the given column. Either C<first> or C<next> must have
been called prior to the this.

=cut

sub value {
	my ($self, $key) = @_;

	$self->{-data}{$key};
}

=item $tabular-E<gt>I<E<lt>columnE<gt>>

Shortcut for of C<value> that reads the data found in the given column.

=cut

sub AUTOLOAD {
	my ($self) = @_;

	my ($key) = $AUTOLOAD =~ /::([^:]+)$/;
	$self->value($key);
}

sub DESTROY {
 	# prevent AUTOLOAD from hooking
}

=back

=head1 SEE ALSO

L<Persist>, L<Persist::Join>, L<Persist::Table>

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
