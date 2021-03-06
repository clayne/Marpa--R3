#!perl
# Marpa::R3 is Copyright (C) 2018, Jeffrey Kegler.
#
# This module is free software; you can redistribute it and/or modify it
# under the same terms as Perl 5.10.1. For more details, see the full text
# of the licenses in the directory LICENSES.
#
# This program is distributed in the hope that it will be
# useful, but it is provided "as is" and without any express
# or implied warranties. For details, see the full text of
# of the licenses in the directory LICENSES.

# Converted to SLIF from Marpa::R2 minus.t

use 5.010001;


use strict;
use warnings;
use POSIX qw(setlocale LC_ALL);

POSIX::setlocale(LC_ALL, "C");

use Test::More tests => 10;

use lib 'inc';
use Marpa::R3::Test;
use Marpa::R3;

# The inefficiency (at least some of it) is deliberate.
# Passing up a duples of [ string, value ] and then
# assembling a final string at the top would be better
# than assembling the string then taking it
# apart at each step.  But I wanted to test having
# a start symbol that appears repeatedly on the RHS.

## no critic (Subroutines::RequireArgUnpacking)

sub subtraction {
    my (undef, $values) = @_;
    my ( $right_string, $right_value ) = ( $values->[2] =~ /^(.*)==(.*)$/xms );
    my ( $left_string,  $left_value )  = ( $values->[0] =~ /^(.*)==(.*)$/xms );
    my $value = $left_value - $right_value;
    return '(' . $left_string . q{-} . $right_string . ')==' . $value;
} ## end sub subtraction

sub postfix_decr {
    my (undef, $values) = @_;
    my ( $string, $value ) = ( $values->[0] =~ /^(.*)==(.*)$/xms );
    return '(' . $string . q{--} . ')==' . $value--;
}

sub prefix_decr {
    my (undef, $values) = @_;
    my ( $string, $value ) = ( $values->[1] =~ /^(.*)==(.*)$/xms );
    return '(' . q{--} . $string . ')==' . --$value;
}

sub negation {
    my (undef, $values) = @_;
    my ( $string, $value ) = ( $values->[1] =~ /^(.*)==(.*)$/xms );
    return '(' . q{-} . $string . ')==' . -$value;
}

sub number {
    my (undef, $values) = @_;
    my $value = $values->[0];
    return "$value==$value";
}

sub minusminus {
    return q{--};
}

sub default_action {
    my (undef, $values) = @_;
    return q{} if not defined $values;
    return $values->[0] if scalar @{$values} == 1;
    return '(' . join( q{;}, @{$values} ) . ')';
} ## end sub default_action

## use critic

my $grammar = Marpa::R3::Grammar->new(
    {
        semantics_package => 'main',
        source            => \<<'END_OF_DSL',
:default ::= action => default_action
E ::= E Minus E action => subtraction
E ::= E MinusMinus action => postfix_decr
E ::= MinusMinus E action => prefix_decr
E ::= Minus E action => negation
E ::= Number action => number
MinusMinus ::= Minus Minus action => minusminus
Minus ~ '-'
Number ~ [\d]+
END_OF_DSL
    }
);

my $recce = Marpa::R3::Recognizer->new(
    {
        grammar => $grammar
    }
);

Marpa::R3::Test::is( $grammar->productions_show(),
    <<'END_RULES', 'Minuses Equation Rules' );
R1 [:start:] ::= E
R2 E ::= MinusMinus E
R3 E ::= Minus E
R4 E ::= Number
R5 MinusMinus ::= Minus Minus
R6 E ::= E Minus E
R7 E ::= E MinusMinus
R8 [:lex_start:] ~ [:target:]
R9 [:target:] ~ Minus
R10 [:target:] ~ Number
R11 Minus ~ [\-]
R12 Number ~ [\d] +
END_RULES

Marpa::R3::Test::is( $grammar->ahms_show(),
    <<'END_AHMS', 'Minuses Equation AHMs' );
AHM 0: dot=0; nulls=0
    E ::= . E Minus E
AHM 1: dot=1; nulls=0
    E ::= E . Minus E
AHM 2: dot=2; nulls=0
    E ::= E Minus . E
AHM 3: completion; dot=3; nulls=0
    E ::= E Minus E .
AHM 4: dot=0; nulls=0
    E ::= . E MinusMinus
AHM 5: dot=1; nulls=0
    E ::= E . MinusMinus
AHM 6: completion; dot=2; nulls=0
    E ::= E MinusMinus .
AHM 7: dot=0; nulls=0
    E ::= . MinusMinus E
AHM 8: dot=1; nulls=0
    E ::= MinusMinus . E
AHM 9: completion; dot=2; nulls=0
    E ::= MinusMinus E .
AHM 10: dot=0; nulls=0
    E ::= . Minus E
AHM 11: dot=1; nulls=0
    E ::= Minus . E
AHM 12: completion; dot=2; nulls=0
    E ::= Minus E .
AHM 13: dot=0; nulls=0
    E ::= . Number
AHM 14: completion; dot=1; nulls=0
    E ::= Number .
AHM 15: dot=0; nulls=0
    MinusMinus ::= . Minus Minus
AHM 16: dot=1; nulls=0
    MinusMinus ::= Minus . Minus
AHM 17: completion; dot=2; nulls=0
    MinusMinus ::= Minus Minus .
AHM 18: dot=0; nulls=0
    [:start:] ::= . E
AHM 19: completion; dot=1; nulls=0
    [:start:] ::= E .
END_AHMS

my %expected = map { ( $_ => 1 ) } (
    #<<< no perltidy
    '(((6--)--)-1)==5',
    '((6--)-(--1))==6',
    '((6--)-(-(-1)))==5',
    '(6-(--(--1)))==7',
    '(6-(--(-(-1))))==6',
    '(6-(-(--(-1))))==4',
    '(6-(-(-(--1))))==6',
    '(6-(-(-(-(-1)))))==5',
    #>>>
);

$recce->read( \q{6-----1} );

# Set max_parses to 20 in case there's an infinite loop.
# This is for debugging, after all
my $valuer = Marpa::R3::Valuer->new(
    {
        recognizer => $recce,
        max_parses => 20
    }
);
while ( my $value_ref = $valuer->value() ) {
    my $value = $value_ref ? ${$value_ref} : 'No parse';
    if ( defined $expected{$value} ) {
        delete $expected{$value};
        Test::More::pass("Expected Value $value");
    }
    else {
        Test::More::fail("Unexpected Value $value");
    }
}

# vim: expandtab shiftwidth=4:
