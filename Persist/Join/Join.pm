package Persist::Join;

use 5.008;
use strict;
use warnings;

use Getargs::Mixed;

use Persist ':driver_help';
use Persist::Tabular;

our @ISA = qw(Persist::Tabular);

our ( $VERSION ) = '$Revision: 1.8 $' =~ /\$Revision:\s+([^\s]+)/;

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

	my %names;
	my %seen;
	for my $i (0 .. $#$tables) {
		my $name = $tables->[$i];
		my $num  = ++$seen{$name};

		if ($num > 1) {
			$names{$name} = -1; # ambiguous
		} else {
			$names{$name} = $i;
		}

		$names{$i + 1}      = $i;
		$names{"$name$num"} = $i;
	}
	$self->{names}   = \%names;

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

=item $row = $join-E<gt>table($table)

When C<first> or C<next> have been passed the C<$bytable> option set to true,
you must use this method to retrieve data from each table. Essentially, the
current row is packed with data from multiple tables instead of retrieving the
joined information as if it were combined into a single table.

The C<$table> argument may be any valid table identifier that could be used in a
table. That is, given a join on tables C<['A', 'B', 'A']>, you could pass a
value of C<1> to retrieve data for the first "A" table, C<2> to retrieve data
for the "B" table, or C<3> to retrieve data for the second "A" table. You could
pass "B" to retrieve data for the "B" table. Finally, you could pass "A1", "B1",
and "A2" to access each of these tables, respectively. Using an a name that
is ambiguous (like "A" in this example) will result in an error.

=cut

package Persist::Join::Table;

use Getargs::Mixed;

sub new {
	my ($class, $data) = @_;
	return bless { -data => $data }, $class;
}

sub value {
	my ($self, %args) = parameters('self', [qw(column)], @_);
	my $key = $args{column};

	return $self->{-data}{$key};
}

our $AUTOLOAD;
sub AUTOLOAD {
	my ($self) = @_;

	my ($key) = $AUTOLOAD =~ /::([^:]+)$/;
	$self->value($key);
}

package Persist::Join;

sub table {
	my ($self, %args) = parameters('self', [qw(table)], @_);
	my $i = $self->{names}{$args{table}};
	
	croak "Attempting to retrieve data by table when the bytable option was not given."
		if ref $self->{-data} ne 'ARRAY';
	
	croak "Unknown table name $args{table} given." unless defined $i;
	croak "Ambiguous table name $args{table} given." if $i == -1;

	Persist::Join::Table->new($self->{-data}[$i]);
}

=item $tabular-E<gt>I<E<lt>tableE<gt>>

Shortcut for of C<table> that returns the data found in the given table.  This
is only available when the C<$bytable> option was passed to the last call to
C<first> or C<next>. Otherwise, it is assumed that this is a column name rather
than a table.

See L<I<E<lt>columnE<gt>>|Persist::Tabular>.

=cut

our $AUTOLOAD;
sub AUTOLOAD {
	my ($self) = @_;

	my ($key) = $AUTOLOAD =~ /::([^:]+)$/;
	if (ref $self->{-data} eq 'ARRAY') {
		return $self->table($key);
	} else {
		return $self->value($key);
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
