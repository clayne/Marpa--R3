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
# Note: This test is duplicate_parse.t and final_nonnullable.t, ...
# Note: converted to the SLIF

# Catch the case of a final non-nulling symbol at the end of a rule
# which has more than 2 proper nullables
# This is to test an untested branch of the CHAF logic.

use 5.010001;
use strict;
use warnings;

use Test::More tests => 10;

use lib 'inc';
use Marpa::R3::Test;
use Marpa::R3;

## no critic (Subroutines::RequireArgUnpacking)

sub default_action {
    shift;
    my $v_count = scalar @_;
    return q{-} if $v_count <= 0;
    my @vals = map { $_ // q{-} } @_;
    return $vals[0] if $v_count == 1;
    return '(' . join( q{;}, @vals ) . ')';
} ## end sub default_action

## use critic

my $grammar = Marpa::R3::Scanless::G->new(
    {
        source => \<<'DSL'
:default ::= action => main::default_action
S ::= p p p n
p ::= a
p ::=
n ::= a
a ~ [\d\D]
DSL
    }
);

Marpa::R3::Test::is( $grammar->show_rules(1),
    <<'END_OF_STRING', 'final nonnulling Rules' );
G1 R0 S ::= p p p n
G1 R1 p ::= a
G1 R2 p ::=
G1 R3 n ::= a
G1 R4 [:start] ::= S
END_OF_STRING

Marpa::R3::Test::is( $grammar->show_ahms,
    <<'END_OF_STRING', 'final nonnulling AHFA' );
AHM 0: postdot = "p"
    S ::= . p p S[R0:2]
AHM 1: postdot = "p"
    S ::= p . p S[R0:2]
AHM 2: postdot = "S[R0:2]"
    S ::= p p . S[R0:2]
AHM 3: completion
    S ::= p p S[R0:2] .
AHM 4: postdot = "p"
    S ::= . p p[] S[R0:2]
AHM 5: postdot = "S[R0:2]"
    S ::= p p[] . S[R0:2]
AHM 6: completion
    S ::= p p[] S[R0:2] .
AHM 7: postdot = "p"
    S ::= p[] . p S[R0:2]
AHM 8: postdot = "S[R0:2]"
    S ::= p[] p . S[R0:2]
AHM 9: completion
    S ::= p[] p S[R0:2] .
AHM 10: postdot = "S[R0:2]"
    S ::= p[] p[] . S[R0:2]
AHM 11: completion
    S ::= p[] p[] S[R0:2] .
AHM 12: postdot = "p"
    S[R0:2] ::= . p n
AHM 13: postdot = "n"
    S[R0:2] ::= p . n
AHM 14: completion
    S[R0:2] ::= p n .
AHM 15: postdot = "n"
    S[R0:2] ::= p[] . n
AHM 16: completion
    S[R0:2] ::= p[] n .
AHM 17: postdot = "a"
    p ::= . a
AHM 18: completion
    p ::= a .
AHM 19: postdot = "a"
    n ::= . a
AHM 20: completion
    n ::= a .
AHM 21: postdot = "S"
    [:start] ::= . S
AHM 22: completion
    [:start] ::= S .
AHM 23: postdot = "[:start]"
    [:start]['] ::= . [:start]
AHM 24: completion
    [:start]['] ::= [:start] .
END_OF_STRING

my @expected = map {
    +{ map { ( $_ => 1 ) } @{$_} }
    }
    [q{}],
    [qw( (-;-;-;a) )],
    [qw( (a;-;-;b) (-;-;a;b) (-;a;-;b) )],
    [qw( (a;b;-;c) (-;a;b;c) (a;-;b;c))],
    [qw( (a;b;c;d) )];

use constant SPACE => 0x60;

for my $input_length ( 1 .. 4 ) {

    # Set max at 10 just in case there's an infinite loop.
    # This is for debugging, after all
    my $recce = Marpa::R3::Scanless::R->new(
        { grammar => $grammar, max_parses => 10 } );
    my $input = substr('abcd', 0, $input_length);
    $recce->read( \$input );
    while ( my $value_ref = $recce->value() ) {
        my $value = $value_ref ? ${$value_ref} : 'No parse';
        my $expected = $expected[$input_length];
        if ( defined $expected->{$value} ) {
            delete $expected->{$value};
            Test::More::pass(qq{Expected value: "$value"});
        }
        else {
            Test::More::fail(qq{Unexpected value: "$value"});
        }
    } ## end while ( my $value_ref = $recce->value() )
} ## end for my $input_length ( 1 .. 4 )

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
