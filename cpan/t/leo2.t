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
# Note: SLIF TEST

# Test of events and right recursion

use 5.010001;
use strict;
use warnings;

use Test::More tests => 9;

use lib 'inc';
use Marpa::R3::Test;
use Marpa::R3;

## no critic (Subroutines::RequireArgUnpacking)

sub main::default_action {
    return ( join q{}, grep {defined} @{$_[1]} );
}

## use critic

my $grammar = Marpa::R3::Scanless::G->new(
    { 
        source => \(<<'END_OF_DSL'),
:default ::= action => main::default_action
:start ::= <expression>
<expression> ::= 'x' | <assignment>
<assignment> ::= <divide assignment>
<assignment> ::= <multiply assignment>
<assignment> ::= <add assignment>
<assignment> ::= <subtract assignment>
<assignment> ::= <plain assignment>
<divide assignment> ::= 'x' '/=' <expression>
<multiply assignment> ::= 'x' '*=' <expression>
<add assignment> ::= 'x' '+=' <expression>
<subtract assignment> ::= 'x' '-=' <expression>
<plain assignment> ::= 'x' '=' <expression>
event divide = completed <divide assignment>
event multiply = completed <multiply assignment>
event subtract = completed <subtract assignment>
event add = completed <add assignment>
event plain = completed <plain assignment>
:discard ~ whitespace
whitespace ~ [\s]*
END_OF_DSL
    }
);

# Reaches closure
do_test($grammar, 'x = x += x -= x *= x /= x',
<<'END_OF_HISTORY'
plain
add plain
add plain subtract
add multiply plain subtract
add divide multiply plain subtract
END_OF_HISTORY
);

# Reaches closure and continues
do_test($grammar, 'x = x += x -= x *= x /= x = x += x -= x *= x /= x',
<<'END_OF_HISTORY'
plain
add plain
add plain subtract
add multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
END_OF_HISTORY
);

# Reaches closure and continues
my $test_slr = do_test($grammar,
'x = x += x -= x *= x /= x = x += x -= x *= x /= x
 = x = x = x = x = x = x = x = x = x = x',
<<'END_OF_HISTORY'
plain
add plain
add plain subtract
add multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
add divide multiply plain subtract
END_OF_HISTORY
);

my $show_progress_output = $test_slr->show_progress();

# Marpa::R3::Display
# name: SLIF Leo show_progress() example
# start-after-line: END_OF_OUTPUT
# end-before-line: '^END_OF_OUTPUT$'

my $expected_show_progress_output = <<'END_OF_OUTPUT';
F0 @40-41 L2c40 expression -> 'x' .
F1 x20 @0...38-41 L1c1-L2c40 expression -> assignment .
F2 x2 @8,18-41 L1c20-L2c40 assignment -> <divide assignment> .
F3 x2 @6,16-41 L1c15-L2c40 assignment -> <multiply assignment> .
F4 x2 @2,12-41 L1c5-L2c40 assignment -> <add assignment> .
F5 x2 @4,14-41 L1c10-L2c40 assignment -> <subtract assignment> .
F6 x12 @0...38-41 L1c1-L2c40 assignment -> <plain assignment> .
R7:1 @40-41 L2c40 <divide assignment> -> 'x' . '/=' expression
F7 x2 @8,18-41 L1c20-L2c40 <divide assignment> -> 'x' '/=' expression .
R8:1 @40-41 L2c40 <multiply assignment> -> 'x' . '*=' expression
F8 x2 @6,16-41 L1c15-L2c40 <multiply assignment> -> 'x' '*=' expression .
R9:1 @40-41 L2c40 <add assignment> -> 'x' . '+=' expression
F9 x2 @2,12-41 L1c5-L2c40 <add assignment> -> 'x' '+=' expression .
R10:1 @40-41 L2c40 <subtract assignment> -> 'x' . '-=' expression
F10 x2 @4,14-41 L1c10-L2c40 <subtract assignment> -> 'x' '-=' expression .
R11:1 @40-41 L2c40 <plain assignment> -> 'x' . '=' expression
F11 x12 @0...38-41 L1c1-L2c40 <plain assignment> -> 'x' '=' expression .
F12 @0-41 L1c1-L2c40 [:start] -> expression .
END_OF_OUTPUT

# Marpa::R3::Display::End

Marpa::R3::Test::is(
    $show_progress_output,
    $expected_show_progress_output,
    "SLIF Leo show_progress() example"
);

# Never reaches closure
do_test($grammar, 'x = x += x -= x = x += x -= x',
<<'END_OF_HISTORY'
plain
add plain
add plain subtract
add plain subtract
add plain subtract
add plain subtract
END_OF_HISTORY
);

sub do_test {
    my ( $grammar, $input, $expected_history ) = @_;
    my $slr = Marpa::R3::Scanless::R->new( { grammar => $grammar } );
    my @event_history;
    my $pos = $slr->read( \$input );
    READ: while (1) {
        push @event_history, join q{ }, sort map { $_->[0] } @{ $slr->events()};
        last READ if $pos >= length $input;
        $pos = $slr->resume();
    } ## end READ: while (1)
    my $value_ref = $slr->value();
    my $value = $value_ref ? ${$value_ref} : 'No parse';
    ( my $expected = $input ) =~ s/\s//gxms;
    Marpa::R3::Test::is( $value, $expected, "Leo SLIF parse of $expected" );
    my $event_history = join "\n", @event_history, q{};
    Marpa::R3::Test::is( $event_history, $expected_history, "Event history of $expected" );
    return $slr;
} ## end sub do_test

# vim: expandtab shiftwidth=4:
