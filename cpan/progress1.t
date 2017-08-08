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

# Note: ah2.t and bocage.t folded into this test

# the example grammar in Aycock/Horspool "Practical Earley Parsing",
# _The Computer Journal_, Vol. 45, No. 6, pp. 620-630,
# in its "NNF" form

# Non-working code, not kept up to date
# Kept for reference

use 5.010001;
use strict;
use warnings;

use Test::More tests => 11;
use POSIX qw(setlocale LC_ALL);

POSIX::setlocale(LC_ALL, "C");

use lib 'inc';
use Marpa::R3::Test;
use Marpa::R3;

## no critic (Subroutines::RequireArgUnpacking)

sub default_action {
    my (undef, $v) = @_;
    my $v_count = scalar @{$v};
    return q{}   if $v_count <= 0;
    return $v->[0] if $v_count == 1;
    return '(' . ( join q{;}, @{$v}) . ')';
}

## use critic

my $dsl = <<'END_OF_DSL';
:default ::= action => main::default_action
:start ::= S
S ::= A A A A A A A
A ::=
A ::= 'a'
END_OF_DSL

my $grammar = Marpa::R3::Scanless::G->new( {   source => \$dsl });

Marpa::R3::Test::is( $grammar->productions_show(), <<'EOS', 'Aycock/Horspool Rules' );
R1 [:start:] ::= S
R2 S ::= A A A A A A A
R3 A ::=
R4 A ::= 'a'
R5 [:lex_start:] ~ 'a'
R6 'a' ~ [a]
EOS

Marpa::R3::Test::is( $grammar->symbols_show(),
    <<'EOS', 'Aycock/Horspool Symbols' );
S1 A
S2 S
S3 [:lex_start:]
S4 [:start:]
S5 'a'
S6 [a]
EOS

Marpa::R3::Test::is( $grammar->nrls_show(),
    <<'EOS', 'Aycock/Horspool NRLs' );
0: S ::= A S[R0:1]
1: S ::= A A[] A[] A[] A[] A[] A[]
2: S ::= A[] S[R0:1]
3: S[R0:1] ::= A S[R0:2]
4: S[R0:1] ::= A A[] A[] A[] A[] A[]
5: S[R0:1] ::= A[] S[R0:2]
6: S[R0:2] ::= A S[R0:3]
7: S[R0:2] ::= A A[] A[] A[] A[]
8: S[R0:2] ::= A[] S[R0:3]
9: S[R0:3] ::= A S[R0:4]
10: S[R0:3] ::= A A[] A[] A[]
11: S[R0:3] ::= A[] S[R0:4]
12: S[R0:4] ::= A S[R0:5]
13: S[R0:4] ::= A A[] A[]
14: S[R0:4] ::= A[] S[R0:5]
15: S[R0:5] ::= A A
16: S[R0:5] ::= A A[]
17: S[R0:5] ::= A[] A
18: A ::= [Lex-0]
19: [:start:] ::= S
20: [:start:]['] ::= [:start:]
EOS

my $recce = Marpa::R3::Scanless::R->new( {   grammar => $grammar });
my $input_length = 7;
my $input = ('a' x $input_length);
$recce->read( \$input );

sub earley_set_display {
    my ($earley_set) = @_;
    my ($result) = $recce->call_by_tag( ( '@' . __FILE__ . ':' . __LINE__ ),
        <<'END_OF_LUA', 'i', $earley_set );
      local slr, earley_set_id = ...
      local slg = slr.slg

    local function progress_line_do(
        slr, current_ordinal, origins, production_id, position
    )

        -- For origins[0], we apply
        --     -1 to convert earley set to G1, then
        --     +1 because it is an origin and the character
        --        doesn't begin until the next Earley set
        -- In other words, they balance and we do nothing
        local g1_first = origins[1]

        local slg = slr.slg
        local pcs = {}


        local dotted_type
        if position >= slg:xpr_length(production_id) then
            dotted_type = 'F'
            pcs[#pcs+1] = 'F' .. production_id
            goto TAG_FOUND
        end
        if position > 0 then
            dotted_type = 'R'
            pcs[#pcs+1] = 'R' .. production_id .. ':' .. position
            goto TAG_FOUND
        end
        dotted_type = 'P'
        pcs[#pcs+1] = 'P' .. production_id
        ::TAG_FOUND::

        if #origins > 1 then
            pcs[#pcs+1] = 'x' .. #origins
        end

        -- find the range
        if current_ordinal <= 0 then
            pcs[#pcs+1] = 'B0L0c0'
            goto HAVE_RANGE
        end
        if dotted_type == 'P' then
            local block, pos = slr:g1_pos_to_l0_first(current_ordinal)
            pcs[#pcs+1] = slr:lc_brief(pos, block)
            goto HAVE_RANGE
        end
        do
            if g1_first < 0 then g1_first = 0 end
            local g1_last = origins[#origins]
            local l0_first_b, l0_first_p = slr:g1_pos_to_l0_first(g1_first)
            local l0_last_b, l0_last_p = slr:g1_pos_to_l0_last(g1_last)
            pcs[#pcs+1] = slr:lc_range_brief(l0_first_b, l0_first_p, l0_last_b, l0_last_p)
            goto HAVE_RANGE
        end
        ::HAVE_RANGE::
        pcs[#pcs+1] = slg:xpr_dotted_show(production_id, position)
        return table.concat(pcs, ' ')
    end

      io.stderr:write(string.format("earley_set_display(%d)\n", earley_set_id))
      local g1r = slr.g1
      local result = { "=== Earley Set " .. earley_set_id .. "===" }
      local items = {}
      for item_id = 0, math.maxinteger do
          -- IRL data for debugging only -- delete
          local trv = _M.traverser_new(g1r, earley_set_id, item_id)
          local irl_id = trv:rule_id()
          if not irl_id then break end
          local xpr_id = slg:g1_rule_to_xprid(irl_id)
          if xpr_id then
              local xpr_dots = slg:g1_rule_to_xpr_dots(irl_id)
              local irl_dot = trv:dot()
              -- print('irl_dot', inspect(irl_dot))
              local xpr_dot
              local item_type = 1
              -- item_type is 0 for prediction, 1 for medial, 2 for completed
              if irl_dot == -1 then
                  xpr_dot = xpr_dots[#xpr_dots]
                  item_type = 2
              else
                  xpr_dot = xpr_dots[irl_dot+1]
              end
              if xpr_dot == 0 then item_type = 0 end
              -- print('xpr_dot', inspect(xpr_dot))
              local origin = trv:origin()
              items[#items+1] = { earley_set_id, item_type,
                  xpr_id, xpr_dot, origin }
          end
      end
      local last_ordinal
      local lines = {}
      for this_ordinal, rule_id, position, origins in _M.collected_progress_items(items) do
          if this_ordinal ~= last_ordinal then
              local location = 'B0L0c0'
              if this_ordinal > 0 then
                    local block, pos = slr:g1_pos_to_l0_first(this_ordinal)
                    location = slr:lc_brief(pos, block)
              end
              lines = { string.format('=== Earley set %d at %s ===', this_ordinal, location) }
              last_ordinal = this_ordinal
          end
          lines[#lines+1] = progress_line_do( 
            slr, this_ordinal, origins, rule_id, position )
      end
      lines[#lines+1] = '' -- to get a final "\n"
      return table.concat(lines, "\n")
END_OF_LUA
    return $result;
}

TODO: {
    local $TODO = "Problem with Earley Set 0";
    Marpa::R3::Test::is( earley_set_display(0), <<'EOS', 'Earley Set 0' );
=== Earley Set 0 ===
Huh?
EOS
}

Marpa::R3::Test::is( earley_set_display(1),
    <<'EOS', 'Earley Set 1' );
=== Earley Set 1 ===
S:1 @0-1 S ::= A . A A A A A A
S:2 @0-1 S ::= A A . A A A A A
S:3 @0-1 S ::= A A A . A A A A
S:4 @0-1 S ::= A A A A . A A A
S:5 @0-1 S ::= A A A A A . A A
S:6 @0-1 S ::= A A A A A A . A
S:-1 @0-1 S ::= A A A A A A A .
S:-1 @0-1 A ::= 'a' .
S:-1 @0-1 [:start:] ::= S .
EOS

Marpa::R3::Test::is( earley_set_display(2),
    <<'EOS', 'Earley Set 2' );
=== Earley Set 2 ===
S:2 @0-2 S ::= A A . A A A A A
S:3 @0-2 S ::= A A A . A A A A
S:4 @0-2 S ::= A A A A . A A A
S:5 @0-2 S ::= A A A A A . A A
S:6 @0-2 S ::= A A A A A A . A
S:-1 @0-2 S ::= A A A A A A A .
S:-1 @1-2 A ::= 'a' .
S:-1 @0-2 [:start:] ::= S .
EOS

Marpa::R3::Test::is( earley_set_display(3),
    <<'EOS', 'Earley Set 3' );
=== Earley Set 3 ===
S:3 @0-3 S ::= A A A . A A A A
S:4 @0-3 S ::= A A A A . A A A
S:5 @0-3 S ::= A A A A A . A A
S:6 @0-3 S ::= A A A A A A . A
S:-1 @0-3 S ::= A A A A A A A .
S:-1 @2-3 A ::= 'a' .
S:-1 @0-3 [:start:] ::= S .
EOS

Marpa::R3::Test::is( earley_set_display(4),
    <<'EOS', 'Earley Set 4' );
=== Earley Set 4 ===
S:4 @0-4 S ::= A A A A . A A A
S:5 @0-4 S ::= A A A A A . A A
S:6 @0-4 S ::= A A A A A A . A
S:-1 @0-4 S ::= A A A A A A A .
S:-1 @3-4 A ::= 'a' .
S:-1 @0-4 [:start:] ::= S .
EOS

Marpa::R3::Test::is( earley_set_display(5),
    <<'EOS', 'Earley Set 5' );
=== Earley Set 5 ===
S:5 @0-5 S ::= A A A A A . A A
S:6 @0-5 S ::= A A A A A A . A
S:-1 @0-5 S ::= A A A A A A A .
S:-1 @4-5 A ::= 'a' .
S:-1 @0-5 [:start:] ::= S .
EOS

Marpa::R3::Test::is( earley_set_display(6),
    <<'EOS', 'Earley Set 6' );
=== Earley Set 6 ===
S:6 @0-6 S ::= A A A A A A . A
S:-1 @0-6 S ::= A A A A A A A .
S:-1 @5-6 A ::= 'a' .
S:-1 @0-6 [:start:] ::= S .
EOS

Marpa::R3::Test::is( earley_set_display(7),
    <<'EOS', 'Earley Set 7' );
=== Earley Set 7 ===
S:-1 @0-7 S ::= A A A A A A A .
S:-1 @6-7 A ::= 'a' .
S:-1 @0-7 [:start:] ::= S .
EOS

# vim: expandtab shiftwidth=4: