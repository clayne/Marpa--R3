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

# Tests of ambiguity detection in the target grammar
# (as opposed to the meta-grammar itself).
#
# This script is devoted to testing displays

use 5.010001;

use strict;
use warnings;

use Test::More tests => 4;
use English qw( -no_match_vars );
use POSIX qw(setlocale LC_ALL);

POSIX::setlocale(LC_ALL, "C");

use lib 'inc';
use Marpa::R3::Test;
use Marpa::R3;
use Data::Dumper;

our $DEBUG = 0;

my $source = \(<<'END_OF_SOURCE');
:default ::= action => ::array
pair ::= duple | item item
duple ::= item item
item ::= Hesperus | Phosphorus
Hesperus ::= 'a'
Phosphorus ::= 'a'
END_OF_SOURCE

my $input           = 'aa';
my $expected_value   = 'Application grammar is ambiguous';
my $expected_result = <<'END_OF_MESSAGE';
Ambiguous symch at Glade=2, Symbol=<pair>:
  The ambiguity is at B1L1c1-2
  Text is: aa
  There are 2 symches
  Symch 0 is a rule: pair ::= duple
  Symch 1 is a rule: pair ::= item item
END_OF_MESSAGE
my $test_name = 'Symch ambiguity';

my $grammar = Marpa::R3::Grammar->new( { source  => $source } );
my $recce   = Marpa::R3::Recognizer->new( { grammar => $grammar } );
my $is_ambiguous_parse = 1;

my ( $actual_value, $actual_result );
PROCESSING: {

    if ( not defined eval { $recce->read( \$input ); 1 } ) {
        say $EVAL_ERROR if $DEBUG;
        my $abbreviated_error = $EVAL_ERROR;
        chomp $abbreviated_error;
        $abbreviated_error =~ s/\n.*//xms;
        $actual_value  = 'No parse';
        $actual_result = $abbreviated_error;
        $is_ambiguous_parse = 0;
        last PROCESSING;
    } ## end if ( not defined eval { $recce->read( \$input ); 1 })

# Marpa::R3::Display
# name: ASF ambiguity reporting

    my $valuer = Marpa::R3::Valuer->new( { recognizer => $recce } );
    if ( $valuer->ambiguity_level() > 1 ) {
        my $asf = Marpa::R3::ASF2->new( { recognizer => $recce } );
        die 'No ASF' if not defined $asf;
        my $ambiguities = Marpa::R3::Internal_ASF2::ambiguities($asf);

        # Only report the first two
        my @ambiguities = grep {defined} @{$ambiguities}[ 0 .. 1 ];

        $actual_value = 'Application grammar is ambiguous';
        $actual_result =
            Marpa::R3::Internal_ASF2::ambiguities_show( $asf, \@ambiguities );
        last PROCESSING;
    }

# Marpa::R3::Display::End

    $is_ambiguous_parse = 0;

    my $value_ref = $valuer->value();
    if ( not defined $value_ref ) {
        $actual_value  = 'No parse';
        $actual_result = 'Input read to end but no parse';
        last PROCESSING;
    }
    $actual_value  = ${$value_ref};
    $actual_result = 'Parse OK';
    last PROCESSING;

} ## end PROCESSING:

Test::More::is(
    Data::Dumper::Dumper( \$actual_value ),
    Data::Dumper::Dumper( \$expected_value ),
    qq{Value of $test_name}
);
Test::More::is( $actual_result, $expected_result, qq{Result of $test_name} );

if ( !$is_ambiguous_parse ) {
    Test::More::fail(qq{glade_g1_span() start});
    Test::More::fail(qq{glade_g1_span() length});
}
else {
    my $asf = Marpa::R3::ASF->new( { recognizer => $recce } );
    my $glade = $asf->peak;

# Marpa::R3::Display
# name: glade_g1_span() example

    my ( $glade_start, $glade_length ) = $glade->g1_span();

# Marpa::R3::Display::End

    Test::More::is( $glade_start,  0, qq{glade_g1_span() start} );
    Test::More::is( $glade_length, 2, qq{glade_g1_span() length} );

} ## end else [ if ( !$is_ambiguous_parse ) ]

# vim: expandtab shiftwidth=4:
