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

package Marpa::R3::Trace::G;

use 5.010001;
use warnings;
use strict;

use vars qw($VERSION $STRING_VERSION);
$VERSION        = '4.001_035';
$STRING_VERSION = $VERSION;
$VERSION        = eval $VERSION;

sub new {
    my ( $class, $slg, $name ) = @_;
    my $tracer = bless [], $class;
    my $thin_slg = $slg->[Marpa::R3::Internal::Scanless::G::C];
    $tracer->[Marpa::R3::Internal::Trace::G::SLG_C] = $thin_slg;
    $tracer->[Marpa::R3::Internal::Trace::G::NAME] = $name;
    my $lmw_name = 'lmw_' . (lc $name) . 'g';
    $tracer->[Marpa::R3::Internal::Trace::G::LMW_NAME]
      = $lmw_name;
    $slg->[Marpa::R3::Internal::Scanless::G::PER_LMG]->{$lmw_name} = $tracer;

    my $field_name = 'lmw_' . (lc $name) . 'g';
    my $grammar_c = Marpa::R3::Thin::G->new($thin_slg, $field_name);
    $tracer->[Marpa::R3::Internal::Trace::G::C] = $grammar_c;

    $thin_slg->call_by_tag(
        ('@' . __FILE__ . ':' .  __LINE__),
      <<'END_OF_LUA', 's', (lc $name));
    local g, short_name = ...
    lmw_g_name = 'lmw_' .. short_name .. 'g'
    local lmw_g = g[lmw_g_name]
    lmw_g.short_name = short_name
    lmw_g:post_metal()
END_OF_LUA

    return $tracer;
} ## end sub new

sub grammar {
    my ($self) = @_;
    return $self->[Marpa::R3::Internal::Trace::G::C];
}

sub name {
    my ($self) = @_;
    return $self->[Marpa::R3::Internal::Trace::G::NAME];
}

# TODO: Convert to SLG method and delete
sub symbol_name {
    my ( $self, $symbol_id ) = @_;
    my $thin_slg = $self->[Marpa::R3::Internal::Trace::G::SLG_C];

    my $short_lmw_g_name = $self->[Marpa::R3::Internal::Trace::G::NAME];
    my $lmw_g_name = 'lmw_' . (lc $short_lmw_g_name) . 'g';
    my ($sym_name) = $thin_slg->call_by_tag(
        ('@' . __FILE__ . ':' .  __LINE__),
      <<'END_OF_LUA', 'si', $lmw_g_name, $symbol_id);
    local g, lmw_g_name, symbol_id = ...
    local lmw_g = g[lmw_g_name]
    return lmw_g:symbol_name(symbol_id)
END_OF_LUA
    return $sym_name;

} ## end sub symbol_name

sub show_dotted_irl {
    my ( $self, $irl_id, $dot_position ) = @_;
    my $thin_slg         = $self->[Marpa::R3::Internal::Trace::G::SLG_C];
    my $short_name = $self->[Marpa::R3::Internal::Trace::G::NAME];
    my ($result) =
      $thin_slg->call_by_tag(
        ('@' . __FILE__ . ':' .  __LINE__),
	<<'END_OF_LUA', 'sii', (lc $short_name), $irl_id, $dot_position );
    local g, short_name, irl_id, dot_position = ...
    local lmw_g_field_name = 'lmw_' .. short_name .. 'g'
    -- print('lmw_g_field_name', lmw_g_field_name)
    local lmw_g = g[lmw_g_field_name]
    return lmw_g:show_dotted_irl(irl_id, dot_position)
END_OF_LUA
    return $result;
}
 ## end sub show_dotted_irl

sub show_ahm {
    my ( $self, $item_id ) = @_;
    my $thin_slg         = $self->[Marpa::R3::Internal::Trace::G::SLG_C];
    my $short_lmw_g_name = $self->[Marpa::R3::Internal::Trace::G::NAME];
    my $lmw_g_name       = 'lmw_' . ( lc $short_lmw_g_name ) . 'g';

    my ($text) = $thin_slg->call_by_tag(
        ('@' . __FILE__ . ':' .  __LINE__),
	<<'END_OF_LUA', 'si', $lmw_g_name, $item_id );
    local g, lmw_g_name, item_id = ...
    local lmw_g = g[lmw_g_name]
    return lmw_g:show_ahm(item_id)
END_OF_LUA

    return $text;
} ## end sub show_ahm

sub show_briefer_ahm {
    my ( $self, $item_id ) = @_;
    my $thin_slg         = $self->[Marpa::R3::Internal::Trace::G::SLG_C];
    my $short_lmw_g_name = $self->[Marpa::R3::Internal::Trace::G::NAME];
    my $lmw_g_name       = 'lmw_' . ( lc $short_lmw_g_name ) . 'g';

    my ($text) = $thin_slg->call_by_tag(
        ('@' . __FILE__ . ':' .  __LINE__),
	<<'END_OF_LUA', 'si', $lmw_g_name, $item_id );
    local g, lmw_g_name, item_id = ...
    local lmw_g = g[lmw_g_name]
    local irl_id = lmw_g:_ahm_irl(item_id)
    local dot_position = lmw_g:_ahm_position(item_id)
    if (dot_position < 0 ) then
        return string.format("R%d$", irl_id)
    end
    return string.format("R%d:%d", irl_id, dot_position)
END_OF_LUA

    return $text;

}

sub show_ahms {
    my ( $self ) = @_;
    my $thin_slg         = $self->[Marpa::R3::Internal::Trace::G::SLG_C];
    my $short_lmw_g_name = $self->[Marpa::R3::Internal::Trace::G::NAME];
    my $lmw_g_name       = 'lmw_' . ( lc $short_lmw_g_name ) . 'g';

    my ($text) = $thin_slg->call_by_tag(
        ('@' . __FILE__ . ':' .  __LINE__),
	<<'END_OF_LUA', 's', $lmw_g_name );
    local g, lmw_g_name, item_id = ...
    local lmw_g = g[lmw_g_name]
    local pieces = {}
    local count = lmw_g:_ahm_count()
    for i = 0, count -1 do
        pieces[#pieces+1] = lmw_g:show_ahm(i)
    end
    return table.concat(pieces)
END_OF_LUA

    return $text;

} ## end sub show_ahms

sub isy_name {
    my ( $self, $symbol_id ) = @_;
    my $thin_slg         = $self->[Marpa::R3::Internal::Trace::G::SLG_C];
    my $short_lmw_g_name = $self->[Marpa::R3::Internal::Trace::G::NAME];
    my $lmw_g_name       = 'lmw_' . ( lc $short_lmw_g_name ) . 'g';
    my ($sym_name) =
      $thin_slg->call_by_tag(
        ('@' . __FILE__ . ':' .  __LINE__),
	<<'END_OF_LUA', 'si', $lmw_g_name, $symbol_id );
    local g, lmw_g_name, symbol_id = ...
    local lmw_g = g[lmw_g_name]
    return lmw_g:isy_name(symbol_id)
END_OF_LUA
    return $sym_name;

} ## end sub isy_name

# TODO: Convert to SLG method and delete
# Return DSL form of symbol
# Does no checking
sub Marpa::R3::Trace::G::symbol_dsl_form {
    my ( $tracer, $isyid ) = @_;
    my $xsy_by_isyid   = $tracer->[Marpa::R3::Internal::Trace::G::XSY_BY_ISYID];
    my $xsy = $xsy_by_isyid->[$isyid];
    return if not defined $xsy;
    return $xsy->[Marpa::R3::Internal::XSY::DSL_FORM];
}

# TODO: Convert to SLG method and delete
# Return display form of symbol
# Does lots of checking and makes use of alternatives.
sub Marpa::R3::Trace::G::symbol_in_display_form {
    my ( $tracer, $symbol_id ) = @_;
    my $text = $tracer->symbol_dsl_form( $symbol_id )
      // $tracer->symbol_name($symbol_id);
    return "<!No symbol with ID $symbol_id!>" if not defined $text;
    return ( $text =~ m/\s/xms ) ? "<$text>" : $text;
}

sub Marpa::R3::Trace::G::show_symbols {
    my ( $tracer, $verbose, ) = @_;
    my $text = q{};
    $verbose    //= 0;

    my $grammar_name = $tracer->[Marpa::R3::Internal::Trace::G::NAME];
    my $grammar_c     = $tracer->[Marpa::R3::Internal::Trace::G::C];

    for my $symbol_id ( 0 .. $grammar_c->highest_symbol_id() ) {

        $text .= join q{ }, $grammar_name, "S$symbol_id",
          $tracer->symbol_in_display_form( $symbol_id );
        $text .= "\n";

        if ( $verbose >= 2 ) {

            my @tag_list = ();
            $grammar_c->symbol_is_productive($symbol_id)
              or push @tag_list, 'unproductive';
            $grammar_c->symbol_is_accessible($symbol_id)
              or push @tag_list, 'inaccessible';
            $grammar_c->symbol_is_nulling($symbol_id)
              and push @tag_list, 'nulling';
            $grammar_c->symbol_is_terminal($symbol_id)
              and push @tag_list, 'terminal';

            if (@tag_list) {
                $text .= q{  } . ( join q{ }, q{/*}, @tag_list, q{*/} ) . "\n";
            }

            $text .=
              "  Internal name: <" . $tracer->symbol_name($symbol_id) . qq{>\n};

        } ## end if ( $verbose >= 2 )

        if ( $verbose >= 3 ) {

            my $dsl_form = $tracer->symbol_dsl_form( $symbol_id );
            if ($dsl_form) { $text .= qq{  SLIF name: $dsl_form\n}; }

        } ## end if ( $verbose >= 3 )

    } ## end for my $symbol ( @{$symbols} )

    return $text;
}

sub Marpa::R3::Trace::G::brief_irl {
    my ( $self, $irl_id ) = @_;
    my $thin_slg         = $self->[Marpa::R3::Internal::Trace::G::SLG_C];
    my $short_lmw_g_name = $self->[Marpa::R3::Internal::Trace::G::NAME];
    my $lmw_g_name       = 'lmw_' . ( lc $short_lmw_g_name ) . 'g';

    my ($text) = $thin_slg->call_by_tag( ( '@' . __FILE__ . ':' . __LINE__ ),
        <<'END_OF_LUA', 'si', $lmw_g_name, $irl_id );
    local g, lmw_g_name, irl_id = ...
    local lmw_g = g[lmw_g_name]
    return lmw_g:brief_irl(irl_id)
END_OF_LUA

    return $text;
}

sub Marpa::R3::Trace::G::show_isys {
    my ( $tracer ) = @_;
    my $thin_slg         = $tracer->[Marpa::R3::Internal::Trace::G::SLG_C];
    my $short_lmw_g_name = $tracer->[Marpa::R3::Internal::Trace::G::NAME];
    my $lmw_g_name       = 'lmw_' . ( lc $short_lmw_g_name ) . 'g';
    my ($result) =
      $thin_slg->call_by_tag(
        ('@' . __FILE__ . ':' .  __LINE__),
	<<'END_OF_LUA', 's', $lmw_g_name );
    local g, lmw_g_name = ...
    local lmw_g = g[lmw_g_name]
    local nsy_count = lmw_g:_nsy_count()
    local pieces = {}
    for isy_id = 0, nsy_count - 1 do
        pieces[#pieces+1] = lmw_g:show_isy(isy_id)
    end
    return table.concat(pieces)
END_OF_LUA
    return $result;
}

sub Marpa::R3::Trace::G::show_irls {
    my ($tracer) = @_;
    my $thin_slg         = $tracer->[Marpa::R3::Internal::Trace::G::SLG_C];
    my $short_lmw_g_name = $tracer->[Marpa::R3::Internal::Trace::G::NAME];
    my $lmw_g_name       = 'lmw_' . ( lc $short_lmw_g_name ) . 'g';
    my ($result) =
      $thin_slg->call_by_tag(
        ('@' . __FILE__ . ':' .  __LINE__),
	<<'END_OF_LUA', 's', $lmw_g_name );
    local g, lmw_g_name = ...
    local lmw_g = g[lmw_g_name]
    local irl_count = lmw_g:_irl_count()
    local pieces = {}
    for irl_id = 0, irl_count - 1 do
        pieces[#pieces+1] = lmw_g:brief_irl(irl_id)
    end
    pieces[#pieces+1] = ''
    return table.concat(pieces, '\n')
END_OF_LUA
    return $result;
}
