package Persist::Filter;

use 5.008;
use strict;
use warnings;

use Carp;
use Parse::RecDescent;

use Getargs::Mixed;

# TODO Add a direct date syntax instead of using the rather klugey
# string-magically-becomes-a-date-when-needed semantics.

=head1 NAME

Persist::Filter - Function for parsing filters

=head1 SYNOPSIS

  use Persist::Filter;
  $tree = parse_filter($filter);

  $tree->remap(sub { ... });
  $tree->remap_on('Persist::Filter::Comparison', sub { ... });

  $stringified = $tree->unparse;

=head1 DESCRIPTION

This package provides help for dealing with L<Persist> filters. Filters are
query strings similar in format to the expressions used in a SQL C<WHERE>
clause. This type of query language was chosen as it is familiar to those used
to SQL programming (such as myself), makes translation into SQL extremely
straightforward--SQL being the query language used for the first important
L<Persist> drivers, and it is a simple and powerful language.

This package provides a few methods for parsing filter strings, walking the
parse trees for modification or examination, and for turning parse trees back
to AST. First, let's examine the format of L<Persist> filters.

=head2 FILTERS

Filters are simple boolean expressions similar to the SQL C<WHERE> clause. Each
filter is made up of one or more comparison expressions that are separated by
either of the boolean operators C<AND> or C<OR>. Each comparison expression
may be preceded by the boolean operator C<NOT> to invert the result as well.
Parentheses may be used to group tests together.

=head3 COMPARISON OPERATORS

The comparison operators available are:

  * Equivalence (=)
  * Non-Equivalence (<>)
  * Less-Than (<)
  * Less-Than-Or-Equal (<=)
  * Greater-Than (>)
  * Greater-Than-Or-Equal (>=)
  * Case-Sensitive Similarity (LIKE)
  * Case-Insensitive Similarity (ILIKE)

In the case of C<LIKE> and C<ILIKE>, the literal value in the comparison may
contain the meta characters ``%'' or ``_''. The ``%'' matches zero or more of
any character and the ``_'' matches exactly one of any character. All operators
but C<LIKE> and C<ILIKE> are commutative. C<LIKE> and C<ILIKE> treat the right
side of the expression as a match expression and the left as a literal string.
Not all drivers may implement C<LIKE> and C<ILIKE> with the capability of using
a column name as a matching expression.

=head3 PLACEHOLDERS

As an alternative to literal values a question mark (?) may be used as a place
holder for a literal value. This may only be done when the method the filter is
passed to also accepts a reference to an array of bindings. Each element of the
binding will be used to replace the question mark place holder in order of
appearance.

For example, given the filter:

  foo = ? AND bar = ?

and the array:

  ('hello', 'world')

we effectively have:

  foo = 'hello' AND bar = 'world'

This should be obvious to anyone familiar with most SQL database APIs like
L<DBI>.

=head3 IDENTIFIERS

Identifiers may be in either C<name> or C<name.name> format. Usually, the former
is preferred, but the latter may be required where C<name> is ambiguous. (This
happens when filtering on a table join where two of the joined tables have
columns with the same name.) When the C<name.name> format is used, the first
name identifies the table and the second identifies the column.

Table identifiers are either the name of the table (as given to the appropriate
method), a number for the index the name (as given), or the name of the table
and number of that table's occurance. That is, if C<[ 'A', 'B', 'A' ]> were
passed as the tables to a method using a filter, then a table name of "1"
identifies the first occurance of "A", "2" identifies the "B" table, and "3"
identifies the third "A". Or, "A" is an ambiguous table name, so it cannot be
used and "B" identifies the "B" table. Or, "A1" identifies the first "A", "B1"
identifies the "B" table, and "A2" identifies the second "A" table. Each of
these nomenclatures can be mixed as needed or desired.

=head2 HELPER METHODS

Here is the list of methods provided by this package for working with filter
strings.

=over

=item $ast = parse_filter($filter)

This function accepts a single argument: a string containing a filter. This
function either returns C<undef> when the filter is invalid or an abstract
syntax tree (AST) representing the parsed filter.

The AST basically has this form:

  [ operand, operator, operand ]

Each C<operand> is either a scalar reference (for identifiers or values) or
another AST.  The C<operator> is always a string representation of an operator.

As an example, this filter:

  o.age > 40 and (a.color = 'blue' and not a.color = 'green')

would result in almost this AST:

  [ [ 'o.age', '>', '40' ], 'and', [ [ 'a.color', '=', "'blue'" ], 'and',
                                   [ 'not', [ 'a.color', '=', "'green'" ] ] ] ]

"Almost" because each operand shown as a scalar here would actually be a
reference to a variable containing that string. Furthermore, every reference is
then blessed into a class to identify the objects type. Therefore, a more
correct representation of the tree would be this (as output from
L<Data::Dumper>):

  bless( [
           bless( [
                    bless( do{\(my $o = 'o.age')}, 'Persist::Filter::Identifier' ),
                    '>',
                    bless( do{\(my $o = '40')}, 'Persist::Filter::Number' )
                  ], 'Persist::Filter::Comparison' ),
           'and',
           bless( [
                    bless( [
                             bless( do{\(my $o = 'a.color')}, 'Persist::Filter::Identifier' ),
                             '=',
                             bless( do{\(my $o = '\'blue\'')}, 'Persist::Filter::String' )
                           ], 'Persist::Filter::Comparison' ),
                    'and',
                    bless( [
                             'not',
                             bless( [
                                      bless( do{\(my $o = 'a.color')}, 'Persist::Filter::Identifier' ),
                                      '=',
                                      bless( do{\(my $o = '\'green\'')}, 'Persist::Filter::String' )
                                    ], 'Persist::Filter::Comparison' )
                           ], 'Persist::Filter::Not' )
                  ], 'Persist::Filter::Junction' )
         ], 'Persist::Filter::Junction' )

Obviously, this isn't quite as simple to digest as the previous example, but it
really is easy to process with Perl.

It should be noted that operator names and numeric literals are always
converted to lowercase. The classes that each of these are blessed into are
part of a rich inheritance tree to allow for easy tree walking--as we shall see
later on.

=item $filter = unparse_filter($ast)

This method performs the exact opposite of C<parse_filter>. This will construct
a filter string from an AST. The given AST and resulting filter do not need
to strictly adhere to the normal filter syntax--and can actually deviate quite
far from it, if necessary. The tree is basically pretty printed according to
some simple rules that do not depend on the tree being in filter format. This
is so that complicated transformations of the tree into driver dependent query
languages have an easier time of stringifying the AST.

The rules are as follows:

=over

=item 1.

References are dereferenced and ignored. The classes they are blessed into,
if any, are also ignored. References to references have no defined semantics
during pretty printing.

=item 2.

Arrays (or references to them) have their contents printed by adding space
between internal elements and surrounding contents with parenthesis.

=item 3.

Scalars (or references to them) are printed as is.

=item 4.

Data of any other type have no defined semantics during pretty printing--that
is, we haven't really defined what will happen, but you can bet it probably won't
be good.

=back

Here are some samples.

This AST:

  [ [ 'o.age', '>', '40' ], 'and', [ [ 'a.color', '=', "'blue'" ], 'and',
                                   [ 'not', [ 'a.color', '=', "'green'" ] ] ] ]

would become:

  ((o.age > 40) and ((a.color = 'blue') and (not (a.color = 'green'))))

and this AST:

  [ 'o->name', '=~', '/Bob.*/' ]

would become:

  (o->name =~ /Bob.*/)

and this AST:

  [ '&',[ 'name','=',"'Bob'" ],[ 'age','>','40' ],[ 'color','=',"'red'" ] ]

would become:

  (& (name = 'Bob') (age > 40) (color = 'red'))

Obviously, this is very flexible. It allows us to build strings that are
parseable in most query languages.

=back

=cut

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(
	parse_filter unparse_filter
);

our ($VERSION) = '$Revision: 1.11 $' =~ /\$Revision:\s+(\S+)/;

=head2 AST CLASS HEIRARCHY

Each AST object returned from C<parse_filter> is blessed as one of these
classes:

=over

=item Persist::Filter::AST

Every AST object is a Persist::Filter::AST object as all inherit from it. This
class isn't used directly. It provides three methods for every AST object.

=over

=cut

package Persist::Filter::AST;

use Getargs::Mixed;

# =item $ast = Persist::Filter::AST->new(@args)
#
# Creates an AST object containing a blessed array referencing the given array
# of values.
#
sub new {
	my ($class, @args) = @_;
	bless [ @args ], ref $class || $class;
}

=item $ast->remap(\&code)

This is the most fundamental of the tree-walking functions. It calls the given
subroutine on every node in the tree, including the current node. Each time it
is called the subroutine C<&code> is passed a reference to the node as the
argument.

This method performs the tree-walking operation using a non-recursive algorithm
so it should be relatively efficient.

=cut

sub remap {
	my ($ast, %args) = parameters('self', [qw(code)], @_);
	my $code = $args{code};

	my @stack = ( $ast );
	while (@stack) {
		my $node = shift @stack;
		&$code($node);

		if (ref $node eq 'ARRAY' or
				(UNIVERSAL::isa($node, 'Persist::Filter::AST') and
				not UNIVERSAL::isa($node, 'Persist::Filter::Operand'))) {
			unshift @stack, @$node;
		}
	}
}

=item $ast->remap_on($type, \&code)

This method does essentially the same thing as C<remap> but only calls the
given subroutine on code that is equal to or a decendent of the given C<$type>.
That is, C<UNIVERSAL::isa> is called on each AST object and C<$type> to
determine when C<&code> should be called.

This is performed with a non-recursive algorithm for efficiency.

=cut

sub remap_on {
	my ($ast, %args) = parameters('self', [qw(type code)], @_);
	my ($type, $code) = @args{qw(type code)};

	my @stack = ( $ast );
	while (@stack > 0) {
		my $node = shift @stack;
		if (ref $node && $node->isa($type)) {
			&$code($node);
		}

		if (ref $node eq 'ARRAY' or
				(UNIVERSAL::isa($node, 'Persist::Filter::AST') and
				not UNIVERSAL::isa($node, 'Persist::Filter::Operand'))) {
			unshift @stack, @$node;
		}
	}
}

=item $filter = $ast->unparse(@args)

This is just a shorthand for:

  $filter = unparse_filter(@args);

See C<unparse_filter> for details are arguments passed.

=back

=cut

sub unparse {
	my ($ast) = @_;

	Persist::Filter::unparse_filter($ast);
}

=item Persist::Filter::Logical

All logic operations are subclassed from C<Persist::Filter::Logical>. This
includes C<Persist::Filter::Junction> and C<Persist::Filter::Not>. All
subclasses of this class are blessed array references.

=cut

package Persist::Filter::Logical;
our @ISA = qw( Persist::Filter::AST );

=item Persist::Filter::Junction

Binary logical operations are blessed into this class. This includes
conjunction (AND) and disjunction (OR). These are blessed array references.

=cut

package Persist::Filter::Junction;
our @ISA = qw( Persist::Filter::Logical );

=item Persist::Filter::Not

Unary logical negation (NOT) operations are blessed into this class. These
are blessed array references.

=cut

package Persist::Filter::Not;
our @ISA = qw( Persist::Filter::Logical );

=item Persist::Filter::Not

All of the binary comparison operations (i.e., =, <>, <, >, <=, >=, LIKE, ILIKE,
NOT LIKE, NOT ILIKE) are blessed into this class. These are blessed array
references.

=cut

package Persist::Filter::Comparison;
our @ISA = qw( Persist::Filter::AST );

=item Persist::Filter::Operand

All operands are blessed into subclasses of this class. All subclasses of this
type are blessed scalars.

=cut

package Persist::Filter::Operand;
our @ISA = qw( Persist::Filter::AST );

# =item $ast = Persist::Filter::Operand->new($arg)
#
# This alters the operation of C<Persist::Filter::AST::new> to create classes
# containing a blessed scalar reference rather than blessed array references.
#
sub new {
	my ($class, $arg) = @_;
	bless \$arg, ref $class || $class;
}

=item Persist::Filter::Identifier

Identifiers are blessed into this class.

=cut

package Persist::Filter::Identifier;
our @ISA = qw( Persist::Filter::Operand );

=item Persist::Filter::Literal

All literals are subclassed from this class.

=cut

package Persist::Filter::Literal;
our @ISA = qw( Persist::Filter::Operand );

=item Persist::Filter::String

Literal strings are blessed into this class.

=cut

package Persist::Filter::String;
our @ISA = qw( Persist::Filter::Literal );

=item Persist::Filter::Number

Literal numbers are blessed into this class.

=cut

package Persist::Filter::Number;
our @ISA = qw( Persist::Filter::Literal );

=item Persist::Filter::Placeholder

Literal placeholders (?) are blessed into this class.

=back

=cut

package Persist::Filter::Placeholder;
our @ISA = qw( Persist::Filter::Literal );

package Persist::Filter;

=head2 GRAMMAR

L<Persist::Filter> uses L<Parse::RecDescent> to parse the filters. For details
on the grammar itself, please examine the source for this package. You can use:

  perldoc -m Persist::Filter

to examine the source code after installation.

=cut

my $grammar = q(

filter:		expr eofile { $return = $item[1] }

eofile:		/^\Z/

expr:		comparison logical_op expr 
			{ $return = new Persist::Filter::Junction(@item[1..3]) }
		|	comparison
		|	/not/i expr 
			{ $return = new Persist::Filter::Not(lc($item[1]), $item[2]) }

comparison:	operand comp_op operand 
			{ $return = new Persist::Filter::Comparison(@item[1..3]) }
		|	'(' expr ')' { $return = $item[2] }

operand:	identifier
		|	literal
		|	placeholder

logical_op:	/and/i { $return = lc($item[1]) }
		|	/or/i { $return = lc($item[1]) }

comp_op:	'=' | '<>' | /<=?/ | />=?/
		|	/(?:not\s+)?i?like/i 
			{ $item[1] =~ s/\s+/ /; $return = lc($item[1]) }

identifier:	name '.' name 
			{ $return = new Persist::Filter::Identifier("$item[1].$item[3]") }
		|	integer '.' name
			{ $return = new Persist::Filter::Identifier("$item[1].$item[3]") }
		|	name
			{ $return = new Persist::Filter::Identifier($item[1]) }

literal:	string
			{ $return = new Persist::Filter::String($item[1]) }
		|	number
			{ $return = new Persist::Filter::Number($item[1]) }

placeholder: '?'
			{ $return = new Persist::Filter::Placeholder('?') }

name:		/[a-z_][a-z0-9_]*/i

string:		"'" char(s) "'" { $return = "'".(join '', @{$item[2]})."'" }

integer:	/\d+/

number:		/[+-]?[0-9]*\.[0-9]+(?:e[+-]?[0-9]+)?/i { $return = lc($item[1]) }
		|	/[+-]?[0-9]+\.?(?:e[+-]?[0-9]+)?/i { $return = lc($item[1]) }

char:		"\\\\'" { $return = "\\\\'" }
		|	/[^']/
);

#debug# $::RD_HINT = 1;
my $parse = Parse::RecDescent->new($grammar);

# Documentation is above.
sub parse_filter {
	my (%args) = parameters([qw(filter)], @_);
	my ($filter) = $args{filter};
	$parse->filter($filter)
}

# QUESTION Is this really as efficient as possible. I know unshift is
# less efficient than push, but if I use push, I will need to call reverse
# frequently which will result in a lot of copying anyway.
#
# Documentation is above.
sub unparse_filter($) {
	my (%args) = parameters([qw(ast)], @_);
	my ($ast) = $args{ast};

	my $result;
	my @stack = ('(', @$ast, ')');
	my $space = 0;
	while (@stack) {
		my $node = shift @stack;
		if (!ref $node || (ref $node && 
						   $node->isa('Persist::Filter::Operand'))) {
			$result .= ' ' if $space && $node ne ')';
			$result .= ref $node ? $$node : $node;
			$space = $node eq '(' ? 0 : 1;
		} else {
			my $result;
			unshift @stack, '(', @$node, ')';
		}
	}

#debug#	print STDERR $result,"\n";
	$result
}

=head2 EXPORT

The functions C<parse_filter> and C<unparse_filter> are always exported.

=head1 SEE ALSO

L<Parse::RecDescent>

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
