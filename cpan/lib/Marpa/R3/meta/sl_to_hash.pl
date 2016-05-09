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

use 5.010001;
use strict;
use warnings;
use English qw( -no_match_vars );
use Data::Dumper;

# This is a 'meta' tool, so I relax some of the
# restrictions I use to guarantee portability.
use autodie;

# I expect to be run from a subdirectory in the
# development heirarchy
use lib '../../../';
use lib '../../../../blib/arch';
use Marpa::R3;

use Getopt::Long;
my $verbose         = 1;
my $help_flag       = 0;
my $result          = Getopt::Long::GetOptions(
    'help'       => \$help_flag,
);
die "usage $PROGRAM_NAME [--help] file ...\n" if $help_flag;

my $p_bnf = do { local $RS = undef; \(<>) };
my $ast = Marpa::R3::Internal::MetaAST->new($p_bnf);
my $parse_result = $ast->ast_to_hash($p_bnf);

sub sort_bnf {
    my $cmp = $a->{lhs} cmp $b->{lhs};
    return $cmp if $cmp;
    my $a_rhs_length = scalar @{ $a->{rhs} };
    my $b_rhs_length = scalar @{ $b->{rhs} };
    $cmp = $a_rhs_length <=> $b_rhs_length;
    return $cmp if $cmp;
    for my $ix ( 0 .. ( $a_rhs_length - 1 ) ) {
        $cmp = $a->{rhs}->[$ix] cmp $b->{rhs}->[$ix];
        return $cmp if $cmp;
    }
    return 0;
} ## end sub sort_bnf

my %cooked_parse_result = (
    xsy                     => $parse_result->{xsy},
    xbnf                     => $parse_result->{xbnf},
    character_classes       => $parse_result->{character_classes},
    symbols                 => $parse_result->{symbols},
    discard_default_adverbs => $parse_result->{discard_default_adverbs},
    lexeme_default_adverbs  => $parse_result->{lexeme_default_adverbs},
    first_lhs               => $parse_result->{first_lhs},
    start_lhs               => $parse_result->{start_lhs},
);

my @rule_sets = keys %{ $parse_result->{rules} };
for my $rule_set (@rule_sets) {
    my $aoh        = $parse_result->{rules}->{$rule_set};
    my $sorted_aoh = [ sort sort_bnf @{$aoh} ];
    $cooked_parse_result{rules}->{$rule_set} = $sorted_aoh;
}

say "## The code after this line was automatically generated by ",
    $PROGRAM_NAME;
say "## Date: ", scalar localtime();
$Data::Dumper::Sortkeys = 1;
print Data::Dumper->Dump( [ \%cooked_parse_result ], [qw(hashed_metag)] );
say "## The code before this line was automatically generated by ",
    $PROGRAM_NAME;
