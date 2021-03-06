#!/usr/bin/perl
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

# Synopsis for Scannerless interface

use 5.010001;

use strict;
use warnings;
use Test::More tests => 6;
use English qw( -no_match_vars );
use Scalar::Util qw(blessed);
use POSIX qw(setlocale LC_ALL);

POSIX::setlocale(LC_ALL, "C");

use lib 'inc';
use Marpa::R3::Test;

## no critic (ErrorHandling::RequireCarping);

use Marpa::R3;

my $grammar = Marpa::R3::Grammar->new(
    {   bless_package => 'My_Nodes',
        source        => \(<<'END_OF_SOURCE'),
:default ::= action => ::array bless => ::lhs
:start ::= Script
Script ::= Expression+ separator => comma bless => script
comma ~ [,]
Expression ::=
    Number bless => primary
    | ('(') Expression (')') assoc => group bless => parens
   || Expression ('**') Expression assoc => right bless => power
   || Expression ('*') Expression bless => multiply
    | Expression ('/') Expression bless => divide
   || Expression ('+') Expression bless => add
    | Expression ('-') Expression bless => subtract
Number ~ [\d]+

:discard ~ whitespace
whitespace ~ [\s]+
# allow comments
:discard ~ <hash comment>
<hash comment> ~ <terminated hash comment> | <unterminated
   final hash comment>
<terminated hash comment> ~ '#' <hash comment body> <vertical space char>
<unterminated final hash comment> ~ '#' <hash comment body>
<hash comment body> ~ <hash comment char>*
<vertical space char> ~ [\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
<hash comment char> ~ [^\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
END_OF_SOURCE
    }
);

my $productions_show_output = $grammar->productions_show();

Marpa::R3::Test::is( $productions_show_output,
    <<'END_OF_SHOW_RULES_OUTPUT', 'Scanless productions_show()' );
R1 [:start:] ::= Script
R2 Expression ::= Expression; prec=-1
R3 Expression ::= Expression; prec=0
R4 Expression ::= Expression; prec=1
R5 Expression ::= Expression; prec=2
R6 Expression ::= Number; prec=3
R7 Expression ::= '(' Expression ')'; prec=3
R8 Expression ::= Expression '**' Expression; prec=2
R9 Expression ::= Expression '*' Expression; prec=1
R10 Expression ::= Expression '/' Expression; prec=1
R11 Expression ::= Expression '+' Expression; prec=0
R12 Expression ::= Expression '-' Expression; prec=0
R13 Script ::= Expression +
R14 [:lex_start:] ~ [:target:]
R15 [:target:] ~ Number
R16 [:target:] ~ [:discard:]
R17 [:target:] ~ '('
R18 [:target:] ~ ')'
R19 [:target:] ~ '**'
R20 [:target:] ~ '*'
R21 [:target:] ~ '/'
R22 [:target:] ~ '+'
R23 [:target:] ~ '-'
R24 [:target:] ~ comma
R25 comma ~ [,]
R26 '(' ~ [\(]
R27 ')' ~ [\)]
R28 '**' ~ [\*] [\*]
R29 '*' ~ [\*]
R30 '/' ~ [\/]
R31 '+' ~ [\+]
R32 '-' ~ [\-]
R33 Number ~ [\d] +
R34 [:discard:] ~ whitespace
R35 whitespace ~ [\s] +
R36 [:discard:] ~ <hash comment>
R37 <hash comment> ~ <terminated hash comment>
R38 <hash comment> ~ <unterminated final hash comment>
R39 <terminated hash comment> ~ [\#] <hash comment body> <vertical space char>
R40 <unterminated final hash comment> ~ [\#] <hash comment body>
R41 <hash comment body> ~ <hash comment char> *
R42 <vertical space char> ~ [\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
R43 <hash comment char> ~ [^\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
END_OF_SHOW_RULES_OUTPUT

my $rules_show_output;

$rules_show_output = $grammar->g1_rules_show();

Marpa::R3::Test::is( $rules_show_output,
    <<'END_OF_SHOW_RULES_OUTPUT', 'Scanless g1_rules_show()' );
R0 Script ::= Expression +
R1 Expression ::= Expression
R2 Expression ::= Expression
R3 Expression ::= Expression
R4 Expression ::= Expression
R5 Expression ::= Number
R6 Expression ::= '(' Expression ')'
R7 Expression ::= Expression '**' Expression
R8 Expression ::= Expression '*' Expression
R9 Expression ::= Expression '/' Expression
R10 Expression ::= Expression '+' Expression
R11 Expression ::= Expression '-' Expression
R12 [:start:] ::= Script
END_OF_SHOW_RULES_OUTPUT

$rules_show_output = $grammar->l0_rules_show( { verbose => 1 } );

Marpa::R3::Test::is( $rules_show_output,
    <<'END_OF_SHOW_RULES_OUTPUT', 'Scanless l0_rules_show()' );
R0 comma ~ [,]
R1 '(' ~ [\(]
R2 ')' ~ [\)]
R3 '**' ~ [\*] [\*]
R4 '*' ~ [\*]
R5 '/' ~ [\/]
R6 '+' ~ [\+]
R7 '-' ~ [\-]
R8 Number ~ [\d] +
R9 [:discard:] ~ whitespace
R10 whitespace ~ [\s] +
R11 [:discard:] ~ <hash comment>
R12 <hash comment> ~ <terminated hash comment>
R13 <hash comment> ~ <unterminated final hash comment>
R14 <terminated hash comment> ~ [\#] <hash comment body> <vertical space char>
R15 <unterminated final hash comment> ~ [\#] <hash comment body>
R16 <hash comment body> ~ <hash comment char> *
R17 <vertical space char> ~ [\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
R18 <hash comment char> ~ [^\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
R19 [:lex_start:] ~ [:target:]
R20 [:target:] ~ Number
R21 [:target:] ~ [:discard:]
R22 [:target:] ~ '('
R23 [:target:] ~ ')'
R24 [:target:] ~ '**'
R25 [:target:] ~ '*'
R26 [:target:] ~ '/'
R27 [:target:] ~ '+'
R28 [:target:] ~ '-'
R29 [:target:] ~ comma
END_OF_SHOW_RULES_OUTPUT

sub my_parser {
    my ( $grammar, $p_input_string ) = @_;

    my $recce = Marpa::R3::Recognizer->new( { grammar => $grammar } );

    $recce->read($p_input_string);
    my $value_ref = $recce->value();
    if ( not defined $value_ref ) {
        die "No parse was found, after reading the entire input\n";
    }
    return ${$value_ref}->doit();

} ## end sub my_parser

my @tests = (
    [   '42*2+7/3, 42*(2+7)/3, 2**7-3, 2**(7-3)' =>
            qr/\A 86[.]3\d+ \s+ 126 \s+ 125 \s+ 16\z/xms
    ],
    [   '42*3+7, 42 * 3 + 7, 42 * 3+7' => qr/ \s* 133 \s+ 133 \s+ 133 \s* /xms
    ],
    [   '15329 + 42 * 290 * 711, 42*3+7, 3*3+4* 4' =>
            qr/ \s* 8675309 \s+ 133 \s+ 25 \s* /xms
    ],
);

for my $test (@tests) {
    my ( $input, $output_re ) = @{$test};
    my $result = my_parser( $grammar, \$input );
    Test::More::like( $result, $output_re, 'Value of scannerless parse' );
}

sub My_Nodes::script::doit {
    my ($self) = @_;
    return join q{ }, map { $_->doit() } @{$self};
}

sub My_Nodes::add::doit {
    my ($self) = @_;
    my ( $a, $b ) = @{$self};
    return $a->doit() + $b->doit();
}

sub My_Nodes::subtract::doit {
    my ($self) = @_;
    my ( $a, $b ) = @{$self};
    return $a->doit() - $b->doit();
}

sub My_Nodes::multiply::doit {
    my ($self) = @_;
    my ( $a, $b ) = @{$self};
    return $a->doit() * $b->doit();
}

sub My_Nodes::divide::doit {
    my ($self) = @_;
    my ( $a, $b ) = @{$self};
    return $a->doit() / $b->doit();
}

sub My_Nodes::primary::doit { return $_[0]->[0]; }
sub My_Nodes::parens::doit  { return $_[0]->[0]->doit(); }

sub My_Nodes::power::doit {
    my ($self) = @_;
    my ( $a, $b ) = @{$self};
    return $a->doit()**$b->doit();
}

# vim: expandtab shiftwidth=4:
