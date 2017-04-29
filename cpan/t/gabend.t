#!perl
# Marpa::R3 is Copyright (C) 2017, Jeffrey Kegler.
#
# This module is free software; you can redistribute it and/or modify it
# under the same terms as Perl 5.10.1. For more details, see the full text
# of the licenses in the directory LICENSES.
#
# This program is distributed in the hope that it will be
# useful, but it is provided "as is" and without any express
# or implied warranties. For details, see the full text of
# of the licenses in the directory LICENSES.

# Note: Converted from gabend.t

# Test grammar exceptions -- make sure problems actually
# are detected.  These tests are for problems which are supposed
# to abend.

use 5.010001;
use strict;
use warnings;
use English qw( -no_match_vars );
use Test::More tests => 9;
use Fatal qw(open close);
use POSIX qw(setlocale LC_ALL);

POSIX::setlocale(LC_ALL, "C");

use lib 'inc';
use Marpa::R3::Test;
use Marpa::R3;

## no critic (Subroutines::RequireArgUnpacking)

sub default_action {
    shift;
    my $v_count = scalar @_;
    return q{}   if $v_count <= 0;
    return $_[0] if $v_count == 1;
    return '(' . join( q{;}, @_ ) . ')';
} ## end sub default_action

## use critic

sub test_grammar {
    my ( $test_name, $dsl, $expected_error ) = @_;
    my $trace;
    my $memory;
    my $eval_ok = eval {
        my $grammar = Marpa::R3::Scanless::G->new( { source => \$dsl } );
        1;
    };
    my $eval_error = $EVAL_ERROR;
    if ($eval_ok) {
        Test::More::fail("Failed to catch problem: $test_name");
    }
    else {
        $eval_error =~ s/ ^ Marpa::R3 \s+ exception \s+ at \s+ .* \z //xms;
        Marpa::R3::Test::is( $eval_error, $expected_error,
            "Successfully caught problem: $test_name" );
    }
    return;
}

if (1) {
    my $counted_nullable_grammar = <<'END_OF_DSL';
    S ::= Seq*
    Seq ::= A B
    A ::=
    B ::=
    A ~ [\d\D]
END_OF_DSL

    test_grammar(
        'counted nullable',
        $counted_nullable_grammar,
        qq{Nullable symbol "Seq" is on RHS of counted rule\n}
          . qq{Counted nullables confuse Marpa -- please rewrite the grammar\n}
    );
}

if (1) {
        my $duplicate_rule_grammar = <<'END_OF_DSL';
    Top ::= Dup
    Dup ::= Item
    Dup ::= Item
    Item ::= a
END_OF_DSL
        test_grammar( 'duplicate rule',
            $duplicate_rule_grammar, <<'EOS');
========= Marpa::R3 Fatal error =========
Duplicate rules:
First rule is at line 2, column 5:
  Dup ::= Item
Second rule is at line 3, column 5:
  Dup ::= Item
=========================================
EOS
}

if (1) {
        my $unique_lhs_grammar = <<'END_OF_DSL';
    Top ::= Dup
    Dup ::= Item*
    Dup ::= Item
    Item ::= a
END_OF_DSL
        test_grammar( 'unique_lhs', $unique_lhs_grammar, <<'EOS');
========= Marpa::R3 Fatal error =========
Duplicate rules:
First rule is at line 2, column 5:
  Dup ::= Item*
Second rule is at line 3, column 5:
  Dup ::= Item
=========================================
EOS
}

# Duplicate precedenced LHS: 2 precedenced rules
if (1) {
        my $unique_lhs_grammar = <<'END_OF_DSL';
    Top ::= Dup
    Dup ::= Dup '+' Dup || Dup '-' Dup || Item1
    Dup ::= Dup '*' Dup || Dup '/' Dup || Item2
    Item1 ::= a
    Item2 ::= a
    a ~ 'a'
END_OF_DSL
        test_grammar( 'dup precedenced lhs', $unique_lhs_grammar, <<'EOS');
========= Marpa::R3 Fatal error =========
Precedenced LHS not unique
First precedenced rule is at line 2, column 5:
  Dup ::= Dup '+' Dup || Dup '-' Dup || Item1
Second precedenced rule is at line 3, column 5:
  Dup ::= Dup '*' Dup || Dup '/' Dup || Item2
=========================================
EOS
}

# Duplicate precedenced LHS: precedenced, then empty
if (1) {
        my $unique_lhs_grammar = <<'END_OF_DSL';
    Top ::= Dup
    Dup ::=
    Dup ::= Dup '+' Dup || Dup '-' Dup || Item
    Item ::= a
    a ~ 'a'
END_OF_DSL
        test_grammar( 'LHS empty, then precedenced', $unique_lhs_grammar, <<'EOS');
========= Marpa::R3 Fatal error =========
Precedenced LHS not unique
First rule is at line 2, column 5:
  Dup ::=
Second precedenced rule is at line 3, column 5:
  Dup ::= Dup '+' Dup || Dup '-' Dup || Item
=========================================
EOS
}

# Duplicate precedenced LHS: precedenced, then empty
if (1) {
        my $unique_lhs_grammar = <<'END_OF_DSL';
    Top ::= Dup
    Dup ::= Dup '+' Dup || Dup '-' Dup || Item1
    Dup ::=
    Item1 ::= a
    a ~ 'a'
END_OF_DSL
        test_grammar( 'LHS precedenced, then empty', $unique_lhs_grammar, <<'EOS');
========= Marpa::R3 Fatal error =========
Precedenced LHS not unique
First precedenced rule is at line 2, column 5:
  Dup ::= Dup '+' Dup || Dup '-' Dup || Item1
Second rule is at line 3, column 5:
  Dup ::=
=========================================
EOS
}

if (1) {
    my $nulling_terminal_grammar = <<'END_OF_DSL';
    Top ::= Bad
    Top ::= Good
    Bad ::=
    Bad ~ [\d\D]
    Good ~ [\d\D]
END_OF_DSL
    test_grammar(
        'nulling terminal grammar',
        $nulling_terminal_grammar,
        <<'END_OF_MESSAGE'
A lexeme in L0 is not a lexeme in G1: Bad
END_OF_MESSAGE
    );
}

if (1) {
    my $start_not_lhs_grammar = <<'END_OF_DSL';
    inaccessible is fatal by default
    :start ::= Bad
    Top ::= Bad
    Bad ~ [\d\D]
END_OF_DSL
    test_grammar(
        'start symbol not on lhs',
        $start_not_lhs_grammar,
        qq{Inaccessible symbol: Top\n}
    );
}

if (1) {
    my $unproductive_start_grammar = <<'END_OF_DSL';
    :start ::= Bad
    Top ::= Bad
    Bad ::= Worse
    Worse ::= Bad
    Top ::= Good
    Good ~ [\d\D]
END_OF_DSL
    test_grammar(
        'unproductive start symbol',
        $unproductive_start_grammar,
        qq{Unproductive start symbol\n}
    );
}

# vim: expandtab shiftwidth=4:
