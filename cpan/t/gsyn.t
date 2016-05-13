#!/usr/bin/perl
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

# Synopsis for Scannerless version of Stuizand interface

use 5.010001;
use strict;
use warnings;
use Test::More tests => 5;
use English qw( -no_match_vars );

use lib 'inc';
use Marpa::R3::Test;

## no critic (ErrorHandling::RequireCarping);

# Marpa::R3::Display
# name: Scanless grammar synopsis

use Marpa::R3;

my $grammar = Marpa::R3::Scanless::G->new(
    {   
        source          => \(<<'END_OF_SOURCE'),
:default ::= action => do_first_arg
:start ::= Script
Script ::= Expression+ separator => comma action => do_script
comma ~ [,]
Expression ::=
    Number
    | '(' Expression ')' action => do_parens assoc => group
   || Expression '**' Expression action => do_pow assoc => right
   || Expression '*' Expression action => do_multiply
    | Expression '/' Expression action => do_divide
   || Expression '+' Expression action => do_add
    | Expression '-' Expression action => do_subtract
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

my $input = '42 * 1 + 7';
my $value_ref = $grammar->parse( \$input, 'My_Actions' );

# Marpa::R3::Display::End

Marpa::R3::Test::is( ${$value_ref}, 49, 'Synopsis value test');

my $show_rules_output = $grammar->show_rules();
$show_rules_output .= $grammar->l0_show_rules(1);

Marpa::R3::Test::is( $show_rules_output,
    <<'END_OF_SHOW_RULES_OUTPUT', 'Scanless show_rules()' );
G1 R0 Script ::= Expression +
G1 R1 Expression ::= Expression
G1 R2 Expression ::= Expression
G1 R3 Expression ::= Expression
G1 R4 Expression ::= Expression
G1 R5 Expression ::= Number
G1 R6 Expression ::= '(' Expression ')'
G1 R7 Expression ::= Expression '**' Expression
G1 R8 Expression ::= Expression '*' Expression
G1 R9 Expression ::= Expression '/' Expression
G1 R10 Expression ::= Expression '+' Expression
G1 R11 Expression ::= Expression '-' Expression
G1 R12 [:start] ::= Script
L0 R0 comma ::= [,]
L0 R1 '(' ::= [\(]
L0 R2 ')' ::= [\)]
L0 R3 '**' ::= [\*] [\*]
L0 R4 '*' ::= [\*]
L0 R5 '/' ::= [\/]
L0 R6 '+' ::= [\+]
L0 R7 '-' ::= [\-]
L0 R8 Number ::= [\d] +
L0 R9 [:discard] ::= whitespace
L0 R10 whitespace ::= [\s] +
L0 R11 [:discard] ::= <hash comment>
L0 R12 <hash comment> ::= <terminated hash comment>
L0 R13 <hash comment> ::= <unterminated final hash comment>
L0 R14 <terminated hash comment> ::= [\#] <hash comment body> <vertical space char>
L0 R15 <unterminated final hash comment> ::= [\#] <hash comment body>
L0 R16 <hash comment body> ::= <hash comment char> *
L0 R17 <vertical space char> ::= [\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
L0 R18 <hash comment char> ::= [^\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
L0 R19 [:start_lex] ::= Number
L0 R20 [:start_lex] ::= [:discard]
L0 R21 [:start_lex] ::= '('
L0 R22 [:start_lex] ::= ')'
L0 R23 [:start_lex] ::= '**'
L0 R24 [:start_lex] ::= '*'
L0 R25 [:start_lex] ::= '/'
L0 R26 [:start_lex] ::= '+'
L0 R27 [:start_lex] ::= '-'
L0 R28 [:start_lex] ::= comma
END_OF_SHOW_RULES_OUTPUT

sub my_parser {
    my ( $grammar, $p_input_string ) = @_;

# Marpa::R3::Display
# name: Scanless recognizer synopsis

    my $recce = Marpa::R3::Scanless::R->new( {
        grammar => $grammar,
        semantics_package => 'My_Actions'
        } );
    my $self = bless { grammar => $grammar }, 'My_Actions';
    $self->{recce} = $recce;

    if ( not defined eval { $recce->read($p_input_string); 1 }
        )
    {
        ## Add last expression found, and rethrow
        my $eval_error = $EVAL_ERROR;
        chomp $eval_error;
        die $self->show_last_expression(), "\n", $eval_error, "\n";
    } ## end if ( not defined eval { $event_count = $recce->read...})

    my $value_ref = $recce->value( $self );
    if ( not defined $value_ref ) {
        die $self->show_last_expression(), "\n",
            "No parse was found, after reading the entire input\n";
    }

# Marpa::R3::Display::End

    return ${$value_ref};

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
    my $value = my_parser( $grammar, \$input );
    Test::More::like( $value, $output_re, 'Value of scannerless parse' );
}

# Marpa::R3::Display
# name: Scanless recognizer semantics

package My_Actions;

sub do_parens    { return $_[1]->[1] }
sub do_add       { return $_[1]->[0] + $_[1]->[2] }
sub do_subtract  { return $_[1]->[0] - $_[1]->[2] }
sub do_multiply  { return $_[1]->[0] * $_[1]->[2] }
sub do_divide    { return $_[1]->[0] / $_[1]->[2] }
sub do_pow       { return $_[1]->[0]**$_[1]->[2] }
sub do_first_arg { return $_[1]->[0] }
sub do_script    { return join q{ }, @{$_[1]} }

# Marpa::R3::Display::End

# Marpa::R3::Display
# name: Scanless recognizer diagnostics

sub show_last_expression {
    my ($self) = @_;
    my $recce = $self->{recce};
    my ( $g1_start, $g1_length ) = $recce->last_completed('Expression');
    return 'No expression was successfully parsed' if not defined $g1_start;
    my $last_expression = $recce->g1_literal( $g1_start, $g1_length );
    return "Last expression successfully parsed was: $last_expression";
} ## end sub show_last_expression

# Marpa::R3::Display::End

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
