package Persist::Table;

use 5.008;
use strict;
use warnings;

use Persist qw(:constants);
use Persist::Tabular;

our @ISA = qw(Persist::Tabular);

our $AUTOLOAD;
our ( $VERSION ) = '$Revision: 1.8 $' =~ /\$Revision:\s+([^\s]+)/;

=head1 NAME

Persist::Table - Represents a persistent table object

=head1 SYNOPSIS

  use Persist::Source;

  $source = new Persist::Source(...);

  $table = $source->folks;

  print "Table name: ", $source->table_name, "\n";
  while ($table->next) {
	  print "Name: ", $table->name, "\n";
	  print "Age: ", $table->age, "\n";
  }

  $table->insert;
  $table->name('Bob');
  $table->age(45);
  $table->save;

  $table->insert({
      name => 'George',
      age => 50});
  $table->save;

  my $fid = $table->last_fid; # last autonumber inserted

  $table->first;
  $table->delete;

=head1 DESCRIPTION

Provides simplified access to a persistent table. This object may be used to
insert, update, delete, and access records in a table. Some functionality is
inherited from L<Source::Tabular>. See that documentation for more
information.

=over

=item $table = $source->table($table, $filter)

The alternative to the C<table> constructor is to use the table's name as
the constructor name directly. As in:

  $table = $source->folks($filter);

See L<Persist::Source> for details.

=cut

sub new {
	my ($class, $driver, $table, $filter) = @_;

	my $self = $class->SUPER::new($driver);
	$self->{-table} = $table;
	$self->{-filter} = $filter;
	
	for my $key ($driver->indexes($table)) {
		if ($key->[0] == PRIMARY) {
			$self->{-pk} = $key->[1];
			last;
		}
	}

	$self;
}

=item $name = $table-E<gt>table_name;

Returns the schema name for the table.

=cut

sub table_name {
	my $self = shift;
	$self->{-table};
}

# =item $self-E<gt>_open($reset)
#
# Tells the driver to open the table.
#
sub _open {
	my ($self, $reset) = @_;
	$self->{-handle} = $self->{-driver}->open_table
			($self->{-table}, $self->{-filter})
			if $reset or not $self->{-handle};
}

# =item $self-E<gt>_sync($reset)
#
# Makes sure that changes to the table are committed and then resets the table
# state.
#
sub _sync {
	my ($self, $reset) = @_;

	if (exists $self->{-changes}) {
		my $record = $self->{-changes};
		if ($self->{-new}) {
			$self->{-driver}->insert($self->{-table}, $record);
			delete $self->{-new};
		} else {
			my $filter;
			my $needand = 0;
			my @bindings;
			for my $key (@{$self->{-pk}}) {
				if ($needand) { $filter .= " and " } else { $needand = 1 }
				$filter .= "$key = ?";
				push @bindings, $self->{-data}{$key};
			}
			my @args = ($self->{-table}, $record);
			push @args, $filter if $filter;
			push @args, \@bindings if @bindings;
			$self->{-driver}->update(@args);
		}
		delete $self->{-changes};
	}

	$self->SUPER::_sync($reset);
}

=item $table-E<gt>cancel

Cancels any changes that have been made to the current record. If the current
record is new, the set values are returned to C<undef>. Changes are
automatically saved by default, so an explicit call to this function should be
made whenever saving should be prevented.

=cut

sub cancel {
	my $self = shift;
	delete $self->{-changes};
}

=item $value = $table-E<gt>value($column [, $new_value ] )

Either gets/sets a column value.

=cut

sub value {
	my ($self, $key, $new_value) = @_;

#debug#	print STDERR "$key new_value: $new_value\n" if defined $new_value;

	$self->{-changes}{$key} = $new_value if defined $new_value;
	$self->{-new} || 
		(exists $self->{-changes} && exists $self->{-changes}{$key}) ? 
			$self->{-changes}{$key} : $self->{-data}{$key};
}

=item $value = $table-E<gt>last_seq($column)

Retrieves the last sequence value assigned to the given column during an
insert operation. This call is only valid upon columns of type AUTONUMBER.
Using this method on any other column type will result in an exception.

=cut

sub last_value {
	my ($self, $key) = @_;

	$self->{-driver}->sequence_value($self->{-table}, $key);
}

=item $table-E<gt>save

Saves any changes that have been made to the current record. If the current
record is new then it is inserted. If it is an existing record it is updated.

This operation is performed automatically whenever a call to C<insert> or
C<first> or C<next> is made or whenever the table object is destroyed.

=cut

# TODO When calling save add checking to make sure such a call is legal.
sub save {
	my $self = shift;
	$self->_sync;
	$self;
}

=item $table-E<gt>insert( [ \%values ] )

Marks the current record as being a new record. And then proceeds to set the
given C<%values>. All values will default to C<undef> if not specified by
C<%values>.

=cut

sub insert {
	my ($self, $values) = @_;

	$self->_sync;
	$self->{-new} = 1;

	while (my ($k, $v) = each %$values) {
		$self->value($k, $v);
	}
}

=item $table-E<gt>insert_now(\%values)

Inserts a record immediately with the given C<%values>. This is equivalent to

  $table-E<gt>insert(\%values);
  $table-E<gt>save;

=cut

sub insert_now {
	my ($self, $values) = @_;

	$self->insert($values);
	$self->save;
}

=item $table-E<gt>delete

Deletes the current record. If the current record is marked as new, then this
call has the same effect as C<cancel>.

=cut

sub delete {
	my $self = shift;

	delete $self->{-changes};
	unless ($self->{-new}) {
		my $filter;
		my $needand = 0;
		my @bindings;
		for my $key (@{$self->{-pk}}) {
			if ($needand) { $filter .= " and " } else { $needand = 1 }
			$filter .= "$key = ?";
			push @bindings, $self->{-data}{$key};
		}
		my @args = ($self->{-table});
		push @args, $filter if $filter;
		push @args, \@bindings if @bindings;
		$self->{-driver}->delete(@args);
	}
}

=item $value = $table-E<gt>I<E<lt>columnE<gt>>( [ $new_value ] )

Gets/sets a column value. This is a shorthand for C<value>.

=item $value = $table-E<gt>last_I<E<lt>columnE<gt>>;

Retrieves the last assigned sequence value to the given AUTONUMBER typed
column. Given a non-autonumber column will result in an exception. This is a
shorthand for C<last_seq>.

=cut

sub AUTOLOAD {
	my ($self, $new_value) = @_;

	my ($key) = $AUTOLOAD =~ /::([^:]+)$/;
	if ($key =~ /^last_/) {
		$key = substr $key, 5;
		$self->last_value($key);
	} else {
		$self->value($key, $new_value);
	}
}

sub DESTROY {
	# prevent AUTOLOAD from hooking
}

=back

=head1 SEE ALSO

L<Persist>, L<Persist::Source>, L<Persist::Tabular>

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
