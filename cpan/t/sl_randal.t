#!/usr/bin/perl
# Copyright 2016 Jeffrey Kegler
# This file is part of Marpa::R3.  Marpa::R3 is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Marpa::R3 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Marpa::R3.  If not, see
# http://www.gnu.org/licenses/.

# CENSUS: ASIS
# Note: Converted to SLIF from randal.t

use 5.010001;
use strict;
use warnings;
use English qw( -no_match_vars );

use Test::More tests => 4;
use lib 'inc';
use Marpa::R3::Test;
use Marpa::R3;

package Test_Grammar;

my $dsl = <<'END_OF_DSL';
:default ::= action => ::undef
<perl line> ::= <leading material> <perl statements> <final material> <opt comment>
    action => show_statements
<final material> ::= <padded semicolon>
<final material> ::= <opt ws>
<final material> ::=
<leading material> ::= <opt ws>
<leading material> ::=
<opt comment> ::= <comment> action => flatten
<opt comment> ::=

<perl statements> ::= <perl statement>+
  separator => <padded semicolon> proper => 1
  action => flatten

<padded semicolon> ::= <opt ws> <semicolon> <opt ws>
<perl statement> ::= division action => flatten
<perl statement> ::= <function call> action => flatten
<perl statement> ::= <die k0> <opt ws> <string literal> action => show_die

division ::= expr <opt ws> <division sign> <opt ws> expr
    action => show_division

expr ::= <function call>
expr ::= number

<function call> ::= <unary function name> <opt ws> argument
    action => show_function_call

<function call> ::= <nullary function name>
    action => show_function_call

argument ::= <pattern match>

<die k0> ::= 'd' 'i' 'e' action => concatenate

<unary function name> ::= 's' 'i' 'n' action => concatenate
<nullary function name> ::= 's' 'i' 'n' action => concatenate
  | 't' 'i' 'm' 'e' action => concatenate

<number> ::= <number chars>
<number chars> ::= <number char>+
<number char> ::= [\d]
<semicolon> ::= ';'
<division sign> ::= [/]

<pattern match> ::= [/] <pattern match chars> [/]
<pattern match chars> ::= <pattern match char>*
<pattern match char> ::= [^/]

<comment> ::= [#] <comment content chars>
     action => show_comment
<comment content chars> ::= <comment content char>*
<comment content char> ::= [^\r\n]

<string literal> ::= '"' <string literal chars> '"'
<string literal chars> ::= <string literal char>*
<string literal char> ::= [^"]

<opt ws> ::= <ws piece>*
<ws piece> ::= [\s]

END_OF_DSL

package main;

my @test_data = (
    [
        'sin',
        q{sin  / 25 ; # / ; die "this dies!"},
        [ 'division:0-9, comment:12-34', 'sin0-15, die:18-34' ],
    ],
    [
        'time',
        q{time  / 25 ; # / ; die "this dies!"},
        ['division:0-10, comment:13-35']
    ]
);

my $g = Marpa::R3::Scanless::G->new( { source => \$dsl } );

TEST: for my $test_data (@test_data) {

    my ( $test_name, $test_input, $test_results ) = @{$test_data};

    my $recce = Marpa::R3::Scanless::R->new(
        { grammar => $g, semantics_package => 'main' } );

    $recce->read( \$test_input );

    # say STDERR $recce->show_progress(0, -1) if $test_name eq 'sin';

    my @parses;
    while ( defined( my $value_ref = $recce->value() ) ) {
        push @parses, ${$value_ref};
    }
    my $expected_parse_count = scalar @{$test_results};
    my $parse_count          = scalar @parses;
    Marpa::R3::Test::is( $parse_count, $expected_parse_count,
        "$test_name: Parse count" );

    my $expected = join "\n", sort @{$test_results};
    my $actual   = join "\n", sort @parses;
    Marpa::R3::Test::is( $actual, $expected, "$test_name: Parse match" );

} ## end TEST: for my $test_data (@test_data)

sub concatenate {
    shift;
    return join q{}, grep { defined } @_;
}

sub flatten {
    shift;
    my @children = ();
  CHILD: for my $child (@_) {
        next CHILD if not defined $child;
        if ( ref $child eq 'ARRAY' ) {
            push @children, @{$child};
            next CHILD;
        }
        push @children, $child;
    }
    return \@children;
}

sub show_comment {
    return 'comment:' . join q{-}, Marpa::R3::Context::g1_range();
}

sub show_statements {
    my $statements = flatten(@_);
    return join q{, }, @{$statements};
}

sub show_die {
    return 'die:' . join q{-}, Marpa::R3::Context::g1_range();
}

sub show_division {
    return 'division:' . join q{-}, Marpa::R3::Context::g1_range();
}

sub show_function_call {
    return $_[1] . join q{-}, Marpa::R3::Context::g1_range();
}

# vim: expandtab shiftwidth=4:
