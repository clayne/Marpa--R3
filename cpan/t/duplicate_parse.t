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

# CENSUS: REWORK
# Note: Rewrite as a test sl_gia.t?  Once rewritten, delete this.
# Note: duplicate_parse.t and final_nonnullable.t are same grammar ..
# Note: so that one replacement test should cover both

# Test of deletion of duplicate parses.

use 5.010001;
use strict;
use warnings;

use Test::More tests => 5;

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

my $grammar = Marpa::R3::Grammar->new(
    {   start => 'S',

        rules => [
            [ 'S', [qw/p p p n/], ],
            [ 'p', ['a'], ],
            [ 'p', [], ],
            [ 'n', ['a'], ],
        ],
        terminals      => ['a'],
        default_action => 'main::default_action',

    }
);

$grammar->precompute();

Marpa::R3::Test::is( $grammar->show_rules,
    <<'END_OF_STRING', 'duplicate parse Rules' );
0: S -> p p p n
1: p -> a
2: p -> /* empty !used */
3: n -> a
END_OF_STRING

Marpa::R3::Test::is( $grammar->show_ahms,
    <<'END_OF_STRING', 'duplicate parse AHMs' );
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
    S['] ::= . S
AHM 22: completion
    S['] ::= S .
END_OF_STRING

use constant SPACE => 0x60;

my $recce = Marpa::R3::Recognizer->new( { grammar => $grammar } );
my $input_length = 3;
for my $input_ix ( 1 .. $input_length ) {
    $recce->read( 'a', chr( SPACE + $input_ix ) );
}

# Set max at 10 just in case there's an infinite loop.
# This is for debugging, after all
$recce->set( { max_parses => 10 } );

my %expected = map { ( $_ => 1 ) } qw( (-;a;b;c) (a;-;b;c) (a;b;-;c) );

while ( my $value_ref = $recce->value() ) {
    my $value = $value_ref ? ${$value_ref} : 'No parse';
    if ( defined $expected{$value} ) {
        delete $expected{$value};
        Test::More::pass("Expected value: $value");
    }
    else {
        Test::More::fail("Unexpected value: $value");
    }
} ## end while ( my $value_ref = $recce->value() )

1;    # In case used as "do" file

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
