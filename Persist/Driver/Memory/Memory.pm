package Persist::Driver::Memory;

use 5.008;
use strict;
use warnings;

use DateTime;
use DateTime::Format::ISO8601;

use Tree::BPTree;

use Persist qw(:constants :driver_help);
use Persist::Filter;
use Persist::Driver;

our ( $VERSION ) = '$Revision: 1.17 $' =~ /\$Revision:\s+(\S+)/;
our @ISA = qw( Persist::Driver );

# TODO When creating temporary indexes used during open_* operations when $order
# is present, we should make the references to those weak, so that they
# disappear when no more cursors refer to them.

=head1 NAME

Persist::Driver::Memory - Persist driver for an in Memory source

=head1 SYNOPSIS

  use Persist::Source;

  $source = new Persist::Source('Persist::Driver::Memory');

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
and C<indexes> methods. Also, empty hash indexes are created for each index
given in C<indexes>.

=cut

sub _numeric_column {
	my ($self, $name, $column) = @_;
	my %columns = $self->columns(-table => $name);
	my $type = $columns{$column}[0];
	return($type == AUTONUMBER
		or $type == INTEGER
		or $type == BOOLEAN
		or $type == REAL);
}

use constant STRING     => 0;
use constant NUMERIC    => 1;

sub _type_flag {
	my ($self, $name, $column) = @_;
	my %columns = $self->columns(-table => $name);
	if ($self->_numeric_column($name, $column)) {
		return NUMERIC;
	} elsif ($columns{$column}[0] == TIMESTAMP) {
		return TIMESTAMP;
	} else {
		return STRING;
	}
}

sub _find_or_build_index {
	my ($self, $table, $unique, @columns) = @_;

	# We're going to be doing numeric comparisons on strings and that's what we
	# really want.
	no warnings 'numeric';
	
	my @names;
	my @exprs;
	my @just_columns;
	my $key_index = 0;
	for (my $i = 0; $i < @columns; ++$i) {
		my $column = $columns[$i];
		push @just_columns, $column;

		my $direction =
			$i < $#columns && ($columns[$i + 1] == DESCENDING 
						   ||  $columns[$i + 1] == ASCENDING) ? $columns[++$i]
															  : ASCENDING;
	
		my $expr = $self->_numeric_column($table, $column) 
				? "\$_[0][$key_index] <=> \$_[1][$key_index]"
				: "\$_[0][$key_index] cmp \$_[1][$key_index]";
		++$key_index;

		if ($direction == DESCENDING) {
			$column = "-$column";
			$expr = "-($expr)";
		}
															
		push @exprs, $expr;
		push @names, $column;
	}
	my $columns = join ':', @names;

	my $code = 
		'sub { no warnings "uninitialized"; '.
			join(' or ', @exprs).
		' }';
	my $keycmp = eval $code;
	if ($@) {
		croak "Error compiling key comparer for index $columns [$code]: $@";
	}

	# TODO Add a case for when there is an existing index in the reverse order
	# and create a new one by cloning it and then reversing.

	if ($self->{-tables}{$table}{-indexes}{$columns}) {
		return $self->{-tables}{$table}{-indexes}{$columns};
	} else {
		my $index = $self->{-tables}{$table}{-indexes}{$columns} =
			Tree::BPTree->new(
				-unique => $unique,
				-keycmp => $keycmp,
			);

		my $data = $self->{-tables}{$table}{-data};
		my $cursor = $data->new_cursor;
		while (my ($oid, $row) = $cursor->next) {
			my @key = @$row{@just_columns};
			$index->insert(\@key, $oid);
		}

		return $index;
	}
}

sub create_table {
	my ($self, %args) = @_;
	my ($name, $columns, $indexes) = @args{qw(-table -columns -indexes)};
	$columns = { @$columns }; # the internal representation is a hash
	$self->{-tables}{$name}{-structure} = [ $columns, $indexes ];

	# Add a special index for the internal OID column
	$self->{-tables}{$name}{-oid} = 0;
	$self->{-tables}{$name}{-data} = Tree::BPTree->new(
		-unique => 1, 
		-keycmp => sub { $_[0] <=> $_[1] },
		-valuecmp => sub { 0 }, # forces deletion of all values in a bucket
	);

	# Precreate indexes for indexed columns
	for my $index (@$indexes) {
		my @columns = @{$$index[1]};
		$self->_find_or_build_index(
			$name, 
			$$index[0] == PRIMARY || $$index[0] == UNIQUE,
			@columns,
		);
	}

	# For each AUTONUMBER column, create a sequence and initialize it to 0
	for my $column (keys %$columns) {
		$self->{-tables}{$name}{-sequences}{$column} = 0;
	}
	
	1
}

=item $driver-E<gt>delete_table($name)

Forgets the schema and data and returns success. 

=cut

sub delete_table {
	my ($self, %args) = @_;
	my $name = $args{-table};
	delete $self->{-tables}{$name};
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

# =item $perlex = $self-E<gt>_rewrite_filter(\%columns, $filter)
#
# Rewrites the given filter as a Perl expression for the generation of a closure
# the given C<%columns> tell the method how to rewrite the columns. Each key is
# the name of a column name that needs to be rewritten to a Perl variable. The
# value of the key is a two element list. The first element is the constant
# NUMERIC, STRING, or TIMESTAMP to determine which operators should be used
# against it and the second element is the name of the Perl variable to replace
# the column with.
#
use constant TYPEFLAG   => 0;
use constant PERLNAME   => 1;
use constant TABLENUM   => 2;

sub _rewrite_filter {
	my ($self, $columns, $filter) = @_;

	# This closure is used as a shortcut
	my $is_numeric = sub {
		my ($a, $b) = @_;
		for my $id ($a, $b) {
			return 1 if 
					$id->isa('Persist::Filter::Identifier')
				and defined $$columns{$$id} 
				and @{$$columns{$$id}} > 0 
				and $$columns{$$id}[TYPEFLAG] == NUMERIC;
		}
		return 0;
	};

	# We need to parse the filter to make it easy to process
	my $ast = parse_filter($filter);

	# Walk the tree and convert any identifiers to the appropriate columns and
	# change each comparison operator to the appropriate type.
	$ast->remap_on('Persist::Filter::Comparison', sub {
		(my $a, local $_, my $b) = @{$_[0]};

		# Convert date strings to DateTime
		for my $ids ([$a, $b], [$b, $a]) {
			my ($a, $b) = @$ids;
			if ($a->isa('Persist::Filter::Identifier')
					and $$columns{$$a}[TYPEFLAG] == TIMESTAMP
					and $b->isa('Persist::Filter::String')) {
				# TODO This is bad, we don't want to parse the date at every use!
				$$b = "DateTime::Format::ISO8601->parse_datetime($$b)"
			}
		}

		# FIXME Memory driver cannot handle filters where an identifier is used
		# as the right side of a LIKE expression.

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

		for my $id ($a, $b) {
			if ($id->isa('Persist::Filter::Identifier')) {
				croak "Use of unknown column name $$id in filter" unless defined $$columns{$$id};
				croak "Use of ambiguous column name $$id in filter" if @{$$columns{$$id}} == 0;
				$$id = $$columns{$$id}[PERLNAME];
			}
		}

	});

	return $ast->unparse;
}

=item $handle = $driver-E<gt>open_table($table [, $filter ])

Returns a handle for accessing the data in the table.

=cut

sub open_table {
	my ($self, %args) = @_;
	my ($table, $filter, $order, $offset, $limit) = 
		@args{qw(-table -filter -order -offset -limit)};
	$offset = 0 unless defined $offset;
	$limit  = 0 unless defined $limit;

	# Setup the cursor. If a specific ordering is given, then we need to have an
	# index based upon that order. If no ordering is given, use the -data index
	# from oids to rows.
	my $cursor;
	if (defined $order) {
		$cursor = $self->_find_or_build_index($table, 0, @$order)->new_cursor;
	} else {
		$cursor = $$self{-tables}{$table}{-data}->new_cursor;
	}

	# Rewrites the filter or skips the process altogether if no filter is given
	my $closure;
	if (defined $filter) {
		# We prepare the hash reference to decide how each column should be
		# rewritten.
		my %columns = $self->columns(-table => $table);
		my $columns;
		for my $k (keys %columns) {
			$$columns{$k} = [
				$self->_type_flag($table, $k),
				"\$_[0]{$k}",
			];
		}

		# Rewrite the filter to a Perl expression, turn it into a subroutine,
		# and compile it.
		$closure = eval (
			'sub { no warnings "uninitialized"; '. 
				$self->_rewrite_filter($columns, $filter).
			' }'
		);
	}

	# Return the handle
	{ 
		TABLE          => $table, 
		FILTER         => $closure, 
		OFFSET         => $offset, 
		LIMIT          => $limit, 
		CURRENT_OFFSET => 0, 
		CURRENT_LIMIT  => 0, 
		CURSOR         => $cursor,
	}
}

=item $handle = $driver-E<gt>open_join(%args)

Returns a handle for accessing a joined set of tables.

=cut

sub _get_order_runs {
	my ($self, $tables, $columns, $order) = @_;

	# They have given us an order, we must gather the order columns into "runs".
	# Each run contains columns from the same table in the order specified. The
	# runs will be kept in the order given. Each run will have a cursor
	# associated with it. The tables that have zero runs in the order list, will
	# use the default oid->row cursor, which will be appended to the end (in no
	# particular order).
	
	# Find the runs by constructing an array of arrays. The first element of
	# each child array is the index into the passed tables array.  The rest of
	# the elements are the list of columns for that table in the same format as
	# $order.
	my $last_table = -1;
	my @runs;
	my %seen_tables;
	for (my $i = 0; $i < @$order; ++$i) {
		my $spec = $$columns{$$order[$i]};
		croak "Use of unknown column name $$order[$i] in order"
			unless defined $spec;
		croak "Use of ambiguous column name $$order[$i] in order"
			if @$spec == 0;

		if ($$spec[TABLENUM] ne $last_table) {
			++$seen_tables{$last_table = $$spec[TABLENUM]};
			push @runs, [ $last_table ];
		}

		no warnings "numeric";
		push @{$runs[$#runs]}, $$order[$i];
		push @{$runs[$#runs]}, $$order[++$i] 
			if $i < $#$order and ($$order[$i + 1] == ASCENDING or $$order[$i + 1] == DESCENDING);
	}

	# Find any tables which remain and stick them on the end
	for my $i (0 .. $#$tables) {
		unless ($seen_tables{$i}) {
			push @runs, [ $i ];
		}
	}

	return @runs;
}

# determines if there is a path from $x to $y
sub _has_path {
	my ($self, $g, $x, $y) = @_;
	
	my %seen = ( $x => 1 );
	my @traverse = ( $g->successors($x) );
	while (@traverse) {
		my $vertex = shift @traverse;
		
		return 1 if $vertex eq $y;
		
		next if $seen{$vertex};
		
		$seen{$vertex}++;
		push @traverse, $g->successors($vertex);
	}

	return 0;
}
	
sub open_join {
	my ($self, %args) = @_;
	my ($tables, $on, $filter, $order, $offset, $limit) = 
		@args{qw(-tables -on -filter -order -offset -limit)};
	$offset = 0 unless defined $offset;
	$limit  = 0 unless defined $limit;

	# We want to create an initial version of this columns hash as it will be
	# reused by different parts of this method. Ordering may change it. We also
	# setup ambiguity checking by setting column specs that appear twice to an
	# empty column spec. If these columns are used later, croaking will
	# commence--some of this may be temporarily undone when constructing
	# filters.
	my $columns;
	my %seen_tables;
	for my $i (0 .. $#$tables) {
		my $name = $$tables[$i];
		my $table_num = ++$seen_tables{$name};
		
		my %columns = $self->columns(-table => $$tables[$i]);
		my @column_names = keys %columns;
		for my $j (0 .. $#column_names) {
			my $column = $column_names[$j];
				
			my $numeric = $self->_type_flag($name, $column);
			my $to = "\$_[$i]{$column}";

			for my $prefix ('', ($i + 1).".", "$name.", "$name$table_num.") {
				if (defined $$columns{"$prefix$column"}) {
					$$columns{"$prefix$column"} = [];
					next;
				} 
				
				$$columns{"$prefix$column"} = [ $numeric, $to, $i ];
			}
		}
	}

	# If they have given us an order, we need to process that to discover our
	# cursors. Otherwise, we use the default oid->row cursors.
	my (@cursors, @exprs);
	if (defined $order) {
		my @runs = $self->_get_order_runs($tables, $columns, $order);

		# We now have a list of runs, so let's find the cursors and create the
		# combiner expressions our inter-table joins.
		my %seen_tables;
		my %numbers;
		for (my $i = 0; $i < @runs; ++$i) {
			my $table = shift @{$runs[$i]};
			my $cols  = $runs[$i];
		
			if (defined $seen_tables{$table}) {
				# There is another run for this table. We must prepend all the
				# columns of the previous run(s), add a join expression so that
				# we guarantee that all the values that are found in both runs
				# of the ordered values are always the same.
			
				# The index of the cursor previously inserted for this table
				# will be found in $prev_cursor.
				my $prev_cursor = pop @{$seen_tables{$table}};
		
				# For each of the columns add an equality expression to the list
				# of joins
				for my $column (@{$seen_tables{$table}}) {
					my $op = $$columns{$column}[TYPEFLAG] == NUMERIC ? '==' : 'eq';
					push @exprs, "\$_[$prev_cursor]{$column} $op \$_[$i]{$column}";
				}

				# Add the current columns to the seen list in case there's
				# another run for the same table after this one
				push @{$seen_tables{$table}}, @$columns;
				push @{$seen_tables{$table}}, $i;
			} else {
				# Add the current columns to the seen list in case there's a run
				# for the same table later
				$seen_tables{$table} = [ @$cols, $i ];
			}
			
			if (@$cols == 0) {
				# In this case, it's one of the unordered tables at the end
				push @cursors, $self->{-tables}{$$tables[$table]}{-data}->new_cursor;
			} else {
				# Here, we need to find a matching index for an ordered column
				# list
				push @cursors, $self->_find_or_build_index($$tables[$table], 0, @$cols)->new_cursor;
			}

			# We also should adjust the elements of $columns to reflect the
			# actual cursor positions--which may now differ from the order given
			# in $tables.
			my $name = $$tables[$table];
			my $table_num = ++$numbers{$name};
			my %columns = $self->columns(-table => $name);
			my @column_names = keys %columns;
			for my $j (0 .. $#column_names) {
				my $column = $column_names[$j];
				for my $prefix ('', ($table + 1).".", "$name.", "$name$table_num.") {
					if (@{$$columns{"$prefix$column"}} != 0) {
						my $to = "\$_[$i]{$column}";
						$$columns{"$prefix$column"}[PERLNAME] = $to;
					}
				}
			}
		}
	} else {
		@cursors = map { $$self{-tables}{$_}{-data}->new_cursor } @$tables;
	}

	# Let's not do any work at all if they haven't given us a filter.
	push @exprs, $self->_rewrite_filter($columns, $filter)
		if defined $filter;

	if (defined $on) {
		# This join is explicit, just join according to their expressions
		$on = [ $on ] unless ref $on;
		push @exprs, map { defined $_ ? $self->_rewrite_filter($columns, $_) : () } @$on;
	} else {
		# This is an implicit join, so we figure out how to join the tables
		# together.
		my %joinees;
		for my $i (1 .. @$tables) {
			croak "Cannot implicitly join a table to itself; use the -on option instead."
				if $joinees{$$tables[$i - 1]};
			$joinees{$$tables[$i - 1]} = $i;
		}

		my %joined;
		for my $i (0 .. $#$tables) {
			my $name = $$tables[$i];
			
			# Loop through the indexes and connect any tables that haven't been
			# joined 
			my @indexes = $self->indexes(-table => $name);
			for my $index (@indexes) {
				if ($index->[0] == LINK) {
					my $lflds = $index->[1];
					my $fname = $index->[2];
					my $rflds = $index->[3];

					# Join only if one, the other, or both have not yet been
					# joined
					unless ($joined{$name} and $joined{$fname}) {
						for my $j (0 .. $#$lflds) {
							my $first  = $$columns{($i + 1).".$$lflds[$j]"}[PERLNAME];
							my $op     = $$columns{($i + 1).".$$lflds[$j]"}[TYPEFLAG] == NUMERIC ? '==' : 'eq';
							my $second = $$columns{$joinees{$fname}.".$$rflds[$j]"}[PERLNAME];
							push @exprs, "($first $op $second)";
						}
						$joined{$name}  = 1;
						$joined{$fname} = 1;
					}
				}
			}
		}
	}

	my $closure;
	if (@exprs) {
		my $code = 
			'sub { no warnings "uninitialized"; '.
				join(' and ', @exprs).
			' }';
		$closure = eval $code;
	}

	{
		TABLE          => $tables, 
		FILTER         => $closure, 
		OFFSET         => $offset, 
		LIMIT          => $limit, 
		CURRENT_OFFSET => 0, 
		CURRENT_LIMIT  => 0, 
		CURSORS        => [ @cursors ],
	}
}

=item $rows = $driver-E<gt>insert(%args)

Inserts a row into the table and returns 1.

=cut

# FIXME Perform rudimentary checking on insert to make certain that the user
# doesn't attempt to insert non-scalars.
sub insert {
	my ($self, %args) = @_;
	my ($name, $values) = @args{qw(-table -values)};
	my %columns = $self->columns(-table => $name);
	my $table = $self->{-tables}{$name};

	# Make sure columns are setup properly
	while (my ($column, $type) = each %columns) {
		if ($type->[0] == AUTONUMBER) {
			$values->{$column} = ++$table->{-sequences}{$column};
		} elsif ($type->[0] == TIMESTAMP and defined $values->{$column}) {
			$values->{$column} = DateTime::Format::ISO8601->parse_datetime($values->{$column});
		}
	}
	
	# Insert new oid/row pair into oid-index
	my $oid = ++$table->{-oid};
	$table->{-data}->insert($oid, { %$values });

	# Insert column-values/oid pair into each other index
	my $indexes = $table->{-indexes};
	while (my ($columns, $oids) = each %$indexes) {
		my @columns;
		for (split /:/, $columns) {
			s/^-//;
			push @columns, $_;
		}
		my @key = @$values{@columns};
		$oids->insert(\@key, $oid);
	}
	
	1;
}

=item $rows = $driver-E<gt>update(%args)
)

Updates the table rows specified by filter to the values in set.

=cut

# FIXME Perform rudimentary checking on update to make certain that the user
# doesn't attempt to update non-scalars.
sub update {
	my ($self, %args) = @_;
	my ($name, $set, $filter, $bindings) = @args{qw(-table -set -filter -bindings)};

	# Rewrite set columns to be in proper format
	my %columns = $self->columns(-table => $name);
	my $columns;
	while (my ($column, $type) = each %columns) {
		if ($type->[0] == TIMESTAMP and defined $set->{$column}) {
			$set->{$column} = DateTime::Format::ISO8601->parse_datetime($set->{$column});
		}
		
		$$columns{$column} = [ $self->_type_flag($name, $column), "\$_[0]{$column}" ];
	}

	# Rewrite filter columns to be in proper format
	if ($bindings) {
		for my $binding (@$bindings[0 .. $#$bindings]) {
			$filter =~ s/\?/'$binding'/;
		}
	}
	
	my $closure = eval (
		'sub { no warnings "uninitialized"; '.
			$self->_rewrite_filter($columns, $filter).
		' }'
	);

	# Generate a closure to match rows with
	my $changed = 0;

	# Iterate through rows altering the table whenever we find a match to our
	# closure.
	my $rows = $self->{-tables}{$name}{-data}->new_cursor;
	while (my ($oid, $row) = $rows->each) {
		if (&$closure($row)) {
			while (my ($key, $val) = each %$set) { 
				$row->{$key} = $val;
			}
			$changed++;
		}
	}
	
	$changed;
}

=item $rows = $driver-E<gt>delete(%args)

Deletes the table rows specified by filter.

=cut

sub delete {
	my ($self, %args) = @_;
	my ($name, $filter, $bindings) = @args{qw(-table -filter -bindings)};

	my %columns = $self->columns(-table => $name);
	my $columns;
	$$columns{$_} = [ $self->_type_flag($name, $_), "\$_[0]{$_}" ] for (keys %columns);

	if ($bindings) {
		for my $binding (@$bindings[0 .. $#$bindings]) {
			$filter =~ s/\?/'$binding'/;
		}
	}
	
	my $closure = eval (
		'sub { no warnings "uninitialized"; '.
			$self->_rewrite_filter($columns, $filter).
		' }'
	);

	my $changed = 0;
	my $data = $self->{-tables}{$name}{-data}->new_cursor;
	while (my ($oid, $row) = $data->next) {
		if (&$closure($row)) {
			$data->delete;
			$changed++;
		}
	}
	
	$changed;
}

=item %columns = $driver-E<gt>columns(%args)

Returns the column definition used to define the given table.

=cut

sub columns {
	my ($self, %args) = @_;
	my $table = $args{-table};
#debug#	croak "Table $table not found." unless defined($self->{-tables}{$table});
#debug#	croak "Bad instance." unless ref $self;
#debug#	Carp::confess "No table given." unless $table;
	%{$self->{-tables}{$table}{-structure}[0]};
}

=item @indexes = $driver-E<gt>indexes(%args)

Returns the index definition used to define the given table.

=cut

sub indexes {
	my ($self, %args) = @_;
	my $table = $args{-table};

	croak "Table $table is not known."
			unless defined $self->{-tables}{$table};

	@{$self->{-tables}{$table}{-structure}[1]};
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

	# If we've reached the limit set, then we quit now
	return undef if $handle->{LIMIT} > 0 
				and $handle->{CURRENT_LIMIT} == $handle->{LIMIT};

#debug#	croak "Join closure not valid." unless defined($handle->[JOIN]);
#debug#	croak "Filter closure not valid." unless defined($handle->[FILTER]);

	my $filter = $handle->{FILTER};

#	use Data::Dumper;
#	print STDERR Dumper($self);
#	print STDERR Dumper($handle);

	# Iterate until we find a matching row
	my @data;
	while (1) {
		do {
			@data = ();

			# Iterate through all available tables to construct potential matches
			# from groups of rows
			my $last_wrapped = 1;
			my $cursors = $handle->{CURSORS};
			for my $i (reverse(0 .. $#$cursors)) {
				if ($last_wrapped) {
					if (my ($oid, $row) = $cursors->[$i]->next) {
						$data[$i] = $row;
						$last_wrapped = 0;
					} elsif ($i == 0) {
						# The first table has reached the end, so we're done
						# iterating
						return undef;
					} else {
						# if we failed before, the row should be reset
						if (my ($oid, $row) = $cursors->[$i]->next) {
							$data[$i] = $row;
							# we can leave $last_wrapped unchanged because we've
							# just wrapped
						} else {
							# Fail twice means a table is empty, we can quit
							return undef;
						}
					}
				} else {
					if (my ($oid, $row) = $cursors->[$i]->current) {
						$data[$i] = $row;
					} elsif (($oid, $row) = $cursors->[$i]->next) {
						# We're here because next has not been called since the join
						# was opened or first was called, so we have to call next
						# the very first time on this index
						$data[$i] = $row;
					} else {
						# Fail twice means a table is emtpy, we can quit
						return undef;
					}
				}
			}

			for my $i (0 .. $#data) {
				unless (ref $data[$i]) {
					$data[$i] = $$self{-tables}{$$handle{TABLE}[$i]}{-data}->find($data[$i]);
				}

#				if (defined $data[$i]{name}) {
#					print STDERR "<$data[$i]{name}>\n";
#				} else {
#					print STDERR "<$data[$i]{color}>\n";
#				}
			}

		} until (&$filter(@data));

		if ($handle->{CURRENT_OFFSET} < $handle->{OFFSET}) {
			++$handle->{CURRENT_OFFSET};
			next;
		} elsif ($handle->{LIMIT} > 0 and $handle->{CURRENT_LIMIT} < $handle->{LIMIT}) {
			++$handle->{CURRENT_LIMIT};
			last;
		} elsif ($handle->{LIMIT} > 0) {
			return undef;
		} else {
			last;
		}
	}								  

	return \@data;
}

# =item $results = $self-E<gt>_no_join($handle)
#
# For simple table queries, this method returns the next row matching the
# criteria described in C<$handle>. If no row matches, this method will return
# C<undef>.
#
sub _no_join {
	my ($self, $handle) = @_;

	# Stop now if all records to be returned have been returned
	return undef if $handle->{LIMIT} > 0
				and $handle->{CURRENT_LIMIT} == $handle->{LIMIT};

	my $cursor = $handle->{CURSOR};
	my $filter = $handle->{FILTER};
	while (my ($oid, $row) = $cursor->next) {
		++$handle->{CURRENT_LIMIT} if $handle->{CURRENT_OFFSET} == $handle->{OFFSET}
								  and $handle->{LIMIT} > 0
							  	  and $handle->{CURRENT_LIMIT} < $handle->{LIMIT};
	
		if ($handle->{CURRENT_OFFSET} < $handle->{OFFSET}) {
			++$handle->{CURRENT_OFFSET};
			next;
		}

		if ((defined $filter and &$filter($row)) or !defined $filter) {
			unless (ref $row) {
				my $value = $$self{-tables}{$$handle{TABLE}}{-data}->find($row);
				return { %{$value} };
			} else {
				return { %{$row} };
			}
		}
	}

	return undef;
}

=item $row = $driver-E<gt>first($handle)

Retrieves the first column matched by the handle. This method doesn't require
very much more overhead than a call to C<next>.

=cut

sub first {
	my ($self, %args) = @_;
	my ($handle, $bytable) = @args{qw( -handle -bytable )};

	if (ref $handle->{TABLE}) {
		for (@{$handle->{CURSORS}}) {
			$_->reset;
		}
		my $data = $self->_join($handle);
		if ($bytable) {
			return $data;
		} else {
			return +{ map { %$_ } @$data } if defined $data;
		}
	} else {
		$handle->{CURSOR}->reset;
		return $self->_no_join($handle);
	}
}

=item $row = $driver-E<gt>next(%args)

Retrieves the next column matched by the handle.

=cut

sub next {
	my ($self, %args) = @_;
	my ($handle, $bytable) = @args{qw( -handle -bytable )};

	if (ref $handle->{TABLE}) {
		my $data = $self->_join($handle);
		if ($bytable) {
			return $data;
		} else {
			return +{ map { %$_ } @$data } if defined $data;
		}
	} else {
		return $self->_no_join($handle);
	}
}

=item $num = $driver->sequence($name, $column)

Retrieves the last numeric value for the autonumber column specified.

=cut

sub sequence_value {
	my ($self, %args) = @_;
	my ($table, $column) = @args{qw(-table -column)};

	$self->{-tables}{$table}{-sequences}{$column};
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
