#!perl
# Marpa::R3 is Copyright (C) 2016, Jeffrey Kegler.
#
# This module is free software; you can redistribute it and/or modify it
# under the same terms as Perl 5.10.1. For more details, see the full text
# of the licenses in the directory LICENSES.
#
# This program is distributed in the hope that it will be
# useful, but it is provided “as is” and without any express
# or implied warranties. For details, see the full text of
# of the licenses in the directory LICENSES.

# CENSUS: ASIS
# Note: Converted to SLIF from leo.t

# The example from p. 168-169 of Leo's paper.

use 5.010001;
use strict;
use warnings;

use Test::More tests => 17;

use lib 'inc';
use Marpa::R3::Test;
use Marpa::R3;

## no critic (Subroutines::RequireArgUnpacking)

sub generate_action {
    my ($lhs) = @_;
    return sub {
        my (undef, $values) = @_;
        return q{-} if not defined $values;
        my @vals = map { $_ // q{-} } @{$values};
        return $lhs . '(' . ( join q{;}, @vals ) . ')';
        }
} ## end sub generate_action

*{My_Action::C_action} = generate_action('C');
$My_Action::C_action = 0 if 0; # prevent spurious warning
*{My_Action::S_action} = generate_action('S');
$My_Action::S_action = 0 if 0; # prevent spurious warning
*{My_Action::default_action} = generate_action(q{?});
$My_Action::default_action = 0 if 0; # prevent spurious warning

## use critic

my $dsl = <<'END_OF_DSL';
:default ::= action => My_Action::default_action;
S ::= a S action => My_Action::S_action
S ::= C action => My_Action::S_action
C ::= a C b action => My_Action::C_action
C ::=
a ~ 'a'
b ~ 'b'
END_OF_DSL

my $grammar = Marpa::R3::Scanless::G->new( { source => \$dsl } );

Marpa::R3::Test::is( $grammar->show_symbols(),
    <<'END_OF_STRING', 'Leo168 Symbols' );
G1 S0 C
G1 S1 S
G1 S2 [:start]
G1 S3 a
G1 S4 b
END_OF_STRING

Marpa::R3::Test::is( $grammar->show_rules,
    <<'END_OF_STRING', 'Leo168 Rules' );
G1 R0 S ::= a S
G1 R1 S ::= C
G1 R2 C ::= a C b
G1 R3 C ::=
G1 R4 [:start] ::= S
END_OF_STRING

Marpa::R3::Test::is( $grammar->show_ahms, <<'END_OF_STRING', 'Leo168 AHMs' );
AHM 0: postdot = "a"
    S ::= . a S
AHM 1: postdot = "S"
    S ::= a . S
AHM 2: completion
    S ::= a S .
AHM 3: postdot = "a"
    S ::= . a S[]
AHM 4: completion
    S ::= a S[] .
AHM 5: postdot = "C"
    S ::= . C
AHM 6: completion
    S ::= C .
AHM 7: postdot = "a"
    C ::= . a C b
AHM 8: postdot = "C"
    C ::= a . C b
AHM 9: postdot = "b"
    C ::= a C . b
AHM 10: completion
    C ::= a C b .
AHM 11: postdot = "a"
    C ::= . a C[] b
AHM 12: postdot = "b"
    C ::= a C[] . b
AHM 13: completion
    C ::= a C[] b .
AHM 14: postdot = "S"
    [:start] ::= . S
AHM 15: completion
    [:start] ::= S .
AHM 16: postdot = "[:start]"
    [:start]['] ::= . [:start]
AHM 17: completion
    [:start]['] ::= [:start] .
END_OF_STRING

my %expected = (
    'a'        => q{S(a;-)},
    'ab'       => q{S(C(a;-;b))},
    'aa'       => q{S(a;S(a;-))},
    'aab'      => q{S(a;S(C(a;-;b)))},
    'aabb'     => q{S(C(a;C(a;-;b);b))},
    'aaa'      => q{S(a;S(a;S(a;-)))},
    'aaab'     => q{S(a;S(a;S(C(a;-;b))))},
    'aaabb'    => q{S(a;S(C(a;C(a;-;b);b)))},
    'aaabbb'   => q{S(C(a;C(a;C(a;-;b);b);b))},
    'aaaa'     => q{S(a;S(a;S(a;S(a;-))))},
    'aaaab'    => q{S(a;S(a;S(a;S(C(a;-;b)))))},
    'aaaabb'   => q{S(a;S(a;S(C(a;C(a;-;b);b))))},
    'aaaabbb'  => q{S(a;S(C(a;C(a;C(a;-;b);b);b)))},
    'aaaabbbb' => q{S(C(a;C(a;C(a;C(a;-;b);b);b);b))},
);

for my $a_length ( 1 .. 4 ) {
    for my $b_length ( 0 .. $a_length ) {

        my $string = ( 'a' x $a_length ) . ( 'b' x $b_length );
        my $recce = Marpa::R3::Scanless::R->new(
            {   grammar  => $grammar,
            }
        );
        my $input = ('a' x $a_length) .  ('b' x $b_length);
        $recce->read( \$input );
        my $value_ref = $recce->value();
        my $value = $value_ref ? ${$value_ref} : 'No parse';
        Marpa::R3::Test::is( $value, $expected{$string}, "Parse of $string" );

    } ## end for my $b_length ( 0 .. $a_length )
} ## end for my $a_length ( 1 .. 4 )

# vim: expandtab shiftwidth=4:
