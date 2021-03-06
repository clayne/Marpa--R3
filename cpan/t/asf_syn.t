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

# The low-level ASF synopses and related tests

# TODO -- Revisit this once I decide whether ASF operates at XRL or IRL
# level.
# MITOSIS: ASF

use 5.010001;

use strict;
use warnings;

use Test::More tests => 1;
use English qw( -no_match_vars );
use POSIX qw(setlocale LC_ALL);

POSIX::setlocale(LC_ALL, "C");

use lib 'inc';
use Marpa::R3::Test;
use Marpa::R3;
use Data::Dumper;
use Scalar::Util;

# Marpa::R3::Display
# name: ASF low-level calls synopsis, code part 1

my $grammar = Marpa::R3::Grammar->new(
    {   source => \(<<'END_OF_SOURCE'),
:start ::= pair
pair ::= duple | item item
duple ::= item item
item ::= Hesperus | Phosphorus
Hesperus ::= 'a'
Phosphorus ::= 'a'
END_OF_SOURCE
    }
);

my $recce = Marpa::R3::Recognizer->new( { grammar => $grammar } );
$recce->read( \'aa' );
my $asf = Marpa::R3::ASF2->new( { recognizer => $recce } );
die 'No ASF' if not defined $asf;
my $output_as_array = asf_to_basic_tree($asf);
my $actual_output   = array_display($output_as_array);

# Marpa::R3::Display::End

# Marpa::R3::Display
# name: ASF low-level calls synopsis, output
# start-after-line: EXPECTED_OUTPUT
# end-before-line: '^EXPECTED_OUTPUT$'

my $expected_output = <<'EXPECTED_OUTPUT';
Glade 2 has 2 symches
  Glade 2, Symch 0, pair ::= duple
      Glade 6, duple ::= item item
          Glade 8 has 2 symches
            Glade 8, Symch 0, item ::= Hesperus
                Glade 1, Hesperus ::= 'a'
                    Glade 14, Symbol 'a': "a"
            Glade 8, Symch 1, item ::= Phosphorus
                Glade 13, Phosphorus ::= 'a'
                    Glade 17, Symbol 'a': "a"
          Glade 7 has 2 symches
            Glade 7, Symch 0, item ::= Phosphorus
                Glade 9, Phosphorus ::= 'a'
                    Glade 22, Symbol 'a': "a"
            Glade 7, Symch 1, item ::= Hesperus
                Glade 21, Hesperus ::= 'a'
                    Glade 25, Symbol 'a': "a"
  Glade 2, Symch 1, pair ::= item item
      Glade 8 revisited
      Glade 7 revisited
EXPECTED_OUTPUT

# Marpa::R3::Display::End

Marpa::R3::Test::is( $actual_output, $expected_output,
    'Output for basic ASF synopsis' );

# Marpa::R3::Display
# name: ASF low-level calls synopsis, code part 2

sub asf_to_basic_tree {
    my ( $asf, $glade ) = @_;
    my $peak = $asf->peak();
    return glade_to_basic_tree( $asf, $peak, [] );
} ## end sub asf_to_basic_tree

sub glade_to_basic_tree {
    my ( $asf, $glade, $seen ) = @_;
    return bless ["Glade $glade revisited"], 'My_Revisit'
        if $seen->[$glade];
    $seen->[$glade] = 1;
    my $grammar     = $asf->grammar();
    my @symches     = ();
    my $symch_count = $asf->glade_symch_count($glade);
    SYMCH: for ( my $symch_ix = 0; $symch_ix < $symch_count; $symch_ix++ ) {
        my $g1_rule_id = $asf->g1_symch_rule_id( $glade, $symch_ix );
        if ( $g1_rule_id < 0 ) {
            my $literal      = $asf->glade_literal($glade);
            my $symbol_id    = $asf->g1_glade_symbol_id($glade);
            my $display_form = $grammar->g1_symbol_display_form($symbol_id);
            push @symches,
                bless [qq{Glade $glade, Symbol $display_form: "$literal"}],
                'My_Token';
            next SYMCH;
        } ## end if ( $g1_rule_id < 0 )

        # ignore any truncation of the partitions
        my $factoring_count =
            $asf->symch_factoring_count( $glade, $symch_ix );
        my @symch_description = ("Glade $glade");
        push @symch_description, "Symch $symch_ix" if $symch_count > 1;
        push @symch_description, $grammar->g1_rule_show($g1_rule_id);
        my $symch_description = join q{, }, @symch_description;

        my @factorings = ($symch_description);
        for (
            my $factor_ix = 0;
            $factor_ix < $factoring_count;
            $factor_ix++
            )
        {
            my $downglades =
                $asf->factoring_downglades( $glade, $symch_ix,
                $factor_ix );
            push @factorings,
                bless [ map { glade_to_basic_tree( $asf, $_, $seen ) }
                    @{$downglades} ], 'My_Rule';
        } ## end for ( my $factor_ix = 0; $factor_ix < $factoring_count...)
        if ( $factoring_count > 1 ) {
            push @symches,
                bless [
                "Glade $glade, symch $symch_ix has $factoring_count partitions",
                @factorings
                ],
                'My_Factorings';
            next SYMCH;
        } ## end if ( $factoring_count > 1 )
        push @symches, bless [ @factorings[ 0, 1 ] ], 'My_Factorings';
    } ## end SYMCH: for ( my $symch_ix = 0; $symch_ix < $symch_count; ...)
    return bless [ "Glade $glade has $symch_count symches", @symches ],
        'My_Symches'
        if $symch_count > 1;
    return $symches[0];
} ## end sub glade_to_basic_tree

# Marpa::R3::Display::End

# Marpa::R3::Display
# name: ASF low-level calls synopsis, code part 3

sub array_display {
    my ($array) = @_;
    my ( undef, @lines ) = @{ array_lines_display($array) };
    my $text = q{};
    for my $line (@lines) {
        my ( $indent, $body ) = @{$line};
        $indent -= 6;
        $text .= ( q{ } x $indent ) . $body . "\n";
    }
    return $text;
} ## end sub array_display

sub array_lines_display {
    my ($array) = @_;
    my $reftype = Scalar::Util::reftype($array) // '!undef!';
    return [ [ 0, $array ] ] if $reftype ne 'ARRAY';
    my @lines = ();
    ELEMENT: for my $element ( @{$array} ) {
        for my $line ( @{ array_lines_display($element) } ) {
            my ( $indent, $body ) = @{$line};
            push @lines, [ $indent + 2, $body ];
        }
    } ## end ELEMENT: for my $element ( @{$array} )
    return \@lines;
} ## end sub array_lines_display

# Marpa::R3::Display::End

# vim: expandtab shiftwidth=4:
