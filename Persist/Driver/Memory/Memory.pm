package Persist::Driver::Memory;

use 5.008;
use strict;
use warnings;

use Persist qw(:constants :driver_help);
use Persist::Filter;
use Persist::Driver;

our ( $VERSION ) = '$Revision: 1.11 $' =~ /\$Revision:\s+(\S+)/;
our @ISA = qw( Persist::Driver );

# FIXME Because of the nature of the way it is represented in string format,
# values of type TIMESTAMP may not always be sorted correctly--specifically
# dates in the BC epoch.

=head1 NAME

Persist::Driver::Memory - Persist driver for an in Memory source

=head1 SYNOPSIS

  use Persist::Source;

  $source = new Persist::Source('Persist::Driver::Memory');

  @conn = $source->new_source('newfoo', 'newbar');
  $source->delete_source('newfoot');

  # Use other Persist::Source methods ...

=head1 DESCRIPTION

This driver provides access to a memory database. This class shouldn't be used
directly, but through L<Persist::Source>. It should be noted that this driver
is mostly intended for testing and doesn't really provide any kind of
persistent data store. The database is always blank upon creation or
connection.

It should also be noted that no form of constraint checking is performed. Any
field may contain any type of data. Again, this driver is, at this time, only
provided for testing purposes.

=over 

=item $driver = new Persist::Driver::Memory

Creates a new empty database. Requires no arguments. All connections are DBA
connections--this only makes sense since it's just an in memory database.

=cut

sub new {
	my ($class) = @_;
	bless {}, ref $class || $class;
}

=item $test = $driver-E<gt>is_dba

Always returns true.

=cut

sub is_dba { 1 }

=item @conn = $driver-E<gt>new_source

The return value doesn't matter since each instance of the memory driver
creates a new blank data source. There are no arguments required to connect to
or create a database.

=cut

sub new_source { ("IT DON'T MATTER NOTTA ONE!") }

=item $driver-E<gt>delete_source

Doesn't do anything but return true. Memory databases are deleted by the
garbage collector when the last reference to it is removed.

=cut

sub delete_source { 1 }

=item $driver-E<gt>create_table($name, $columns, $indexes)

Records the schema and returns success. None of the given constraints will be
enforced, but are remembered for later reference by the C<tables>, C<columns>,
and C<indexes> methods.

=cut

sub create_table {
	my ($self, $name, @spec) = @_;
	$self->{-tables}{$name} = [ @spec ];
	1
}

=item $driver-E<gt>delete_table($name)

Forgets the schema and data and returns success. 

=cut

sub delete_table {
	my ($self, $name) = @_;
	delete $self->{-tables}{$name};
	delete $self->{-data}{$name};
	1
}

=item $driver-E<gt>tables

Returns the names of all the tables that have been created since connection.

=cut

sub tables {
	my $self = shift;
	keys(%{$self->{-tables}});
}

# =item $regex = _rewrite_regex($re, $flags)
#
# This subroutine rewrites LIKE and ILIKE expressions into Perl regular
# expressions. That is, each '%' is turned into '.*' and each '_' into '.'. All
# characters in the strings that might be interpreted within a regular
# expression are appropriately escaped.
#
# The C<$flags> argument are appended to the end to add modifiers like 'i' to
# the expression.
#
sub _rewrite_regex {
	my ($re, $flags) = @_;
	$$re = substr $$re, 1, length($$re)-2;
	$$re =~ s/(\$|\^|\*|\(|\)|\-|\+|\{|\[|\}|\]|\|\.|\?|\/|\\)/\\$1/g;
	$$re =~ s/%/.*/g;
	$$re =~ s/_/./g;
#debug#	print STDERR "Rewritten regex: /$$re/$flags\n";
	$$re = "/$$re/$flags";
}

# =item $perlex = $self-E<gt>_rewrite_filter(\@tables, $filter, $i)
#
# Rewrites the given filter as a Perl expression for the generation of a
# closure.
#
sub _rewrite_filter {
	my ($self, $tables, $filter, $i) = @_;

#debug#	croak "Bad instance." unless ref $self;

	my (%columns, %lookup);
	if (defined $i) {
		my $name = ref $$tables[$i] ? $$tables[$i][0] : $$tables[$i];
		my %tc = $self->columns($name);
		my $number = $i + 1;
		while (my ($k,$v) = each %tc) {
			$columns{"$name.$k"} = $columns{$k} = $v;
			$lookup{"$name.$k"} = $lookup{$k} = "\$t$number\->{$k}";
		}
	} else {
		for ($i = 1; $i < @$tables; $i+=2) {
			my $name = ref $$tables[$i] ? $$tables[$i][0] : $$tables[$i];
			my $alias = $$tables[$i-1];
			my %tc = $self->columns($name);
			my $number = ($i + 1)/2;
			while (my ($k,$v) = each %tc) {
				$columns{"$alias.$k"} = $columns{$k} = $v;
				$lookup{"$alias.$k"} = $lookup{$k} = "\$t$number\->{$k}";
			}
		}
	}

	my $is_numeric = sub {
		for my $operand (@_) {
			if ($operand->isa('Persist::Filter::Number')) { 1 }
			elsif ($operand->isa('Persist::Filter::Identifier')) {
				croak "Unknown column $$operand." unless defined $columns{$$operand};
				return ($columns{$$operand}[0] == REAL) ||
					($columns{$$operand}[0] == BOOLEAN) ||
					($columns{$$operand}[0] == INTEGER) ||
					($columns{$$operand}[0] == AUTONUMBER)
			}
		}

		return 0
	};

#debug#	print STDERR $filter,"\n";
	my $ast = parse_filter($filter);
	
	$ast->remap_on('Persist::Filter::Comparison', sub {
		(my $a, local $_, my $b) = @{$_[0]};

		if 	  (/^=$/) 	{ ${$_[0]}[1] = &$is_numeric($a, $b) ? '==' : 'eq' }
		elsif (/^<>$/)	{ ${$_[0]}[1] = &$is_numeric($a, $b) ? '!=' : 'ne' }
		elsif (/^<$/)	{ ${$_[0]}[1] = &$is_numeric($a, $b) ? '<' : 'lt' }
		elsif (/^<=$/)	{ ${$_[0]}[1] = &$is_numeric($a, $b) ? '<=' : 'le' }
		elsif (/^>$/)	{ ${$_[0]}[1] = &$is_numeric($a, $b) ? '>' : 'gt' }
		elsif (/^>=$/)	{ ${$_[0]}[1] = &$is_numeric($a, $b) ? '>=' : 'ge' }
		elsif (/^like$/) { ${$_[0]}[1] = '=~'; _rewrite_regex($b, '') }
		elsif (/^not\s+like$/) { ${$_[0]}[1] = '!~'; _rewrite_regex($b, '') }
		elsif (/^ilike$/) { ${$_[0]}[1] = '=~'; _rewrite_regex($b, 'i') }
		elsif (/^not\s+ilike$/) { ${$_[0]}[1] = '!~'; _rewrite_regex($b, 'i') }
		else { croak "Unknown operator '$_'." }

		if ($a->isa('Persist::Filter::Identifier')) {
#debug#			print STDERR "$$a: $lookup{$$a}\n" unless defined($lookup{$$a});
			$$a = $lookup{$$a};
		}
		if ($b->isa('Persist::Filter::Identifier')) {
#debug#			print STDERR "$$b: $lookup{$$b}\n" unless defined($lookup{$$b});
			$$b = $lookup{$$b};
		}
	});

	$ast->unparse
}

# =item $perlex = $self-E<gt>_rewrite_columns(\@tables, $filter)
#
# Performs some amount of discernment on how to combine filters and such while
# calling C<_rewrite_filter> in the appropriate places.
#
sub _rewrite_columns {
	my ($self, $tables, $filter) = @_;

	my $result;
	if (ref $filter) {
		for (my $i = 0; $i < @$filter; ++$i) {
			next unless $filter->[$i];
			$filter->[$i] = $self->_rewrite_filter($tables, $filter->[$i], $i);
		}

		$result = join(" and ", map { $_ ? $_ : () } @$filter);
	} elsif ($filter) {
		$result = $self->_rewrite_filter($tables, $filter);
	} else {
		$result = undef;
	}

#debug#	print STDERR "$result\n";
	$result;
}

# =item $closure = _filter_closure($num, $filter)
#
# Creates a closure that takes C<$num> row data arguments. The C<$filter>
# argument is a stringified Perl expression. The C<$closure> returned is a
# reference to a subroutine that takes C<$num> row data arguments and
# applies those arguments to the expression defined in C<$filter>.
#
sub _filter_closure {
	my ($num, $filter) = @_;

	my $closure;
	if ($filter) {
		$closure = "sub { no warnings; ";
		for (1 .. $num) { $closure .= "my \$t$_ = shift; " }
		$closure .= $filter;
		$closure .= " }";
	} else {
		$closure = "sub { 1 }";
	}

#debug#	print STDERR "$closure\n";
	eval $closure;
}

=item $handle = $driver-E<gt>open_table($table [, $filter ])

Returns a handle for accessing the data in the table.

=cut

use constant TABLE => 0;
use constant FILTER => 1;
use constant JOIN => 2;
use constant COUNTER => 3;

sub open_table {
	my ($self, $table, $filter) = @_;
	my $closure = _filter_closure(1, 
			$self->_rewrite_columns([ $table ], [ $filter ]));
	[ $table, $closure, undef, 0 ];
}

=item $handle = $driver-E<gt>open_join($tables [, $filters ] )

Returns a handle for accessing a joined set of tables.

=cut

sub open_join {
	my ($self, $tables, $filter) = @_;
	my $filt_clos = _filter_closure(scalar(@$tables), 
			$self->_rewrite_columns($tables, $filter));
	
	my %number;
	my $i = 0;
	for my $table (@$tables) {
		my $name = ref $table ? $table->[0] : $table;
		$number{$name} = ++$i;
	}

	my $join_closure_sub = "sub { no warnings; ";
	for $i (1 .. scalar(@$tables)) { 
		$join_closure_sub .= "my \$t$i = shift; " 
	}
	
	my (@joins, %joined);
	for my $table (@$tables) {
		my $name = ref $table ? $table->[0] : $table;

		my @indexes = $self->indexes($name);
		for my $index (@indexes) {
			if ($index->[0] == LINK) {
				my $lflds = $index->[1];
				my $fname = $index->[2];
				my $rflds = $index->[3];
				if ($number{$fname} and 
						(not $joined{$name} or not $joined{$fname})) {
					my %cols = $self->columns($name);
					push @joins,
						map { 
							my $op = $cols{$$lflds[$_]}[0] == VARCHAR ? 'eq' : '==';
							"\$t$number{$name}->\{$lflds->[$_]\} $op \$t$number{$fname}->\{$rflds->[$_]\}" }
							0 .. $#$lflds;
				}
			}
		}
	}
	$join_closure_sub .= join(" and ", @joins);
	$join_closure_sub .= " }";

#debug#	print STDERR "join_closure_sub: $join_closure_sub\n";

	my $join_clos = eval $join_closure_sub;
	[ $tables, $filt_clos, $join_clos, ( 0 ) x scalar(@$tables) ];
}

=item $handle = $driver-E<gt>open_explicit_join($tables, $as_exprs [, $filter ])

Returns a handle for accessing an explicitly joined set of tables.

=cut

sub open_explicit_join {
	my ($self, $tables, $on_exprs, $filter) = @_;
	my $filt_clos = _filter_closure(scalar(@$tables)/2,
			$self->_rewrite_columns($tables, $filter, 1));

	my $join_closure_sub = "sub { no warnings; ";
	my (@tables, %aliases);
	for my $i (0 .. $#$tables) {
		push @tables, $tables->[$i] if $i % 2;
		$aliases{$tables->[$i]} = $i/2 + 1 unless $i % 2;
		
		my $n = $i/2 + 1;
		$join_closure_sub .= "my \$t$n = shift; " unless $i % 2;
	}
	
#	for my $i (0 .. $#$on_exprs) {
#		$on_exprs->[$i] =~ s/(\w+).(\w+)/\$t$aliases{$1}\->\{$2\}/g;
#	}

	my $on_expr = join(" and ", @$on_exprs);
	my $join_expr = $self->_rewrite_columns($tables, $on_expr);
	$join_closure_sub .= $join_expr . " }";
#debug#	print STDERR "$join_closure_sub\n";
	my $join_clos = eval $join_closure_sub;
	
	[ [ @tables ], $filt_clos, $join_clos, ( 0 ) x (scalar(@$tables)/2) ];
}

=item $rows = $driver-E<gt>insert($name, $values)

Inserts a row into the table and returns 1.

=cut

sub insert {
	my ($self, $name, $values) = @_;
	my %columns = $self->columns($name);

	while (my ($column, $type) = each %columns) {
		if ($type->[0] == AUTONUMBER) {
			$values->{$column} = ++$self->{-sequences}{$name}{$column};
		}
	}
	
	push @{$self->{-data}{$name}}, { %$values };
	1;
}

=item $rows = $driver-E<gt>update($name, $set [, $set [, $bindings ] ]
)

Updates the table rows specified by filter to the values in set.

=cut

sub update {
	my ($self, $name, $set, $filter, $bindings) = @_;
	my $rewritten = $self->_rewrite_columns([ $name ], [ $filter ]);
	if ($bindings) {
		for my $binding (@$bindings[0 .. $#$bindings]) {
			$rewritten =~ s/\?/'$binding'/;
		}
	}

	my $changed = 0;
	my $closure = _filter_closure(1, $rewritten); 

	for my $row (@{$self->{-data}{$name}}) {
		if (&$closure($row)) {
			while (my ($key, $val) = each %$set) { 
				$row->{$key} = $val;
			}
			$changed++;
		}
	}
	
	$changed;
}

=item $rows = $driver-E<gt>delete($name [, $set [, $bindings ] ])

Deletes the table rows specified by filter.

=cut

sub delete {
	my ($self, $name, $filter, $bindings) = @_;
	my $rewritten = $self->_rewrite_columns([ $name ], [ $filter ]);
	if ($bindings) {
		for my $binding (@$bindings[0 .. $#$bindings]) {
			$rewritten =~ s/\?/'$binding'/;
		}
	}

	my $closure = _filter_closure(1, $rewritten);

	my $changed;
	if (defined $self->{-data}{$name}) {
		my $orig_count = scalar(@{$self->{-data}{$name}});
		my @unmatched = grep { not &$closure($_) } @{$self->{-data}{$name}};
		$changed = $orig_count - @unmatched;
		$self->{-data}{$name} = [ @unmatched ];
	} else {
		$changed = 0;
	}
	
	$changed;
}

=item %columns = $driver-E<gt>columns($table)

Returns the column definition used to define the given table.

=cut

sub columns {
	my ($self, $table) = @_;
#debug#	croak "Table $table not found." unless defined($self->{-tables}{$table});
#debug#	croak "Bad instance." unless ref $self;
#debug#	croak "No table given." unless $table;
	%{$self->{-tables}{$table}[0]};
}

=item @indexes = $driver-E<gt>indexes($table)

Returns the index definition used to define the given table.

=cut

sub indexes {
	my ($self, $table) = @_;

	croak "Table $table is not known."
			unless defined $self->{-tables}{$table};

	@{$self->{-tables}{$table}[1]};
}

# =item $results = $self-E<gt>_join($handle)
#
# For a handle describing a table join, this subroutine performs all the
# details of finding the next available row according to C<$handle> that
# matches the criteria it specifies. Once found, it returns that row or returns
# C<undef> if no matching row exists.
#
sub _join {
	my ($self, $handle) = @_;

#debug#	croak "Join closure not valid." unless defined($handle->[JOIN]);
#debug#	croak "Filter closure not valid." unless defined($handle->[FILTER]);

	if ($handle->[COUNTER] < 0) {
		return undef;
	}

	my @data;
	my $match;
	do {
		# Fetch data from the latest row
		@data = ();
		my $i = COUNTER;
		for my $table (@{$handle->[TABLE]}) {
			my $name = ref $table ? $table->[0] : $table;

			if (not defined $self->{-data}{$name} or @{$self->{-data}{$name}} == 0) {
				# if any table has no data, no records can be returned, we're
				# done. Let's keep it that way too.
				$handle->[COUNTER] = -1;
				return undef;
			}
			
			push @data, $self->{-data}{$name}[$handle->[$i]];
			$i++;
		}

		# Update all counters, wrap counter to 0 if a roll-over occurs
		for my $table (reverse(@{$handle->[TABLE]})) {
			my $name = ref $table ? $table->[0] : $table;
			$i--;
		
			$handle->[$i]++;
			if ($handle->[$i] > $#{$self->{-data}{$name}}) {
				$handle->[$i] = 0;
			} else {
				last;
			}
		}

		# Make sure we don't fall off the end and 0 everything, if we do, mark
		# as finished
		my $found = 0;
		for my $index (@$handle[COUNTER .. $#$handle]) {
			if ($index != 0) {
				$found++;
				last;
			}
		}

		# When all counters have rolled-over to 0, tell us to STOP!
		unless ($found) {
			$handle->[COUNTER] = -1;
		}

		# See if the row matches the appropriate criteria
		$match = &{$handle->[JOIN]}(@data) && &{$handle->[FILTER]}(@data);
	} until ($match || $handle->[COUNTER] == -1);

	# Dump out if we ended the search loop on end of table rather than match
	return undef unless $match;

	my %result;
	my $i = 0;
	for my $table (@{$handle->[0]}) {
		my ($name, $alias);
		if (ref $table) {
			($name, $alias) = @$table;
			$alias .= '_';
		} else {
			$name = $table;
			$alias = '';
		}

		while (my ($key, $val) = each %{$data[$i]}) {
			$result{"$alias$key"} = $val;
		}
		$i++;
	}

	\%result;
}

# =item $results = $self-E<gt>_no_join($handle)
#
# For simple table queries, this method returns the next row matching the
# criteria described in C<$handle>. If no row matches, this method will return
# C<undef>.
#
sub _no_join {
	my ($self, $handle) = @_;

	return undef if $handle->[COUNTER] < 0;
		
	my $table = $handle->[TABLE];
	my $closure = $handle->[FILTER];
	my $i = \$handle->[COUNTER];
	my $data = $self->{-data}{$table};

#debug#	print STDERR "table : $table\n";
#debug#	print STDERR "closure : $closure\n";
#debug#	print STDERR "i : $i\n";
#debug#	print STDERR "data : $data\n";
	
	until ($$i > $#$data || &$closure($data->[$$i])) {
		$$i++;
	}

	# return reference to new value, not reference to real data
	my $result = $$i > $#$data ? undef : { %{$data->[$$i]} };
	$$i++;

	$$i = -1 if $$i > $#$data;
		
	$result;
}

=item $row = $driver-E<gt>first($handle)

Retrieves the first column matched by the handle. This method doesn't require
very much more overhead than a call to C<next>.

=cut

sub first {
	my ($self, $handle) = @_;

	if (ref $handle->[TABLE]) {
		for (COUNTER .. $#$handle) {
			$handle->[$_] = 0;
		}
		return $self->_join($handle);
	} else {
		$handle->[COUNTER] = 0;
		return $self->_no_join($handle);
	}
}

=item $row = $driver-E<gt>next($handle)

Retrieves the next column matched by the handle.

=cut

sub next {
	my ($self, $handle) = @_;

	if (ref $handle->[TABLE]) {
		my $result = $self->_join($handle);
		return $result;
	} else {
		return $self->_no_join($handle);
	}
}

=item $num = $driver->sequence($name, $column)

Retrieves the last numeric value for the autonumber column specified.

=cut

sub sequence_value {
	my ($self, $table, $column) = @_;

	$self->{-sequences}{$table}{$column};
}

=back

=head1 SEE ALSO

L<Persist>, L<Persist::Driver>, L<Persist::Source>

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
