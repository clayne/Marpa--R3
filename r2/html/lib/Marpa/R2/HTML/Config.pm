# Copyright 2012 Jeffrey Kegler
# This file is part of Marpa::R2.  Marpa::R2 is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Marpa::R2 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Marpa::R2.  If not, see
# http://www.gnu.org/licenses/.

package Marpa::R2::HTML::Config;

use 5.010;
use strict;
use warnings;

use English qw( -no_match_vars );

# Generate the default configuration
sub new {
    my ($class) = @_;
    require Marpa::R2::HTML::Config::Default;
    my $self = {
        rules => $Marpa::R2::HTML::Internal::Config::Default::CORE_RULES,
        descriptor_by_tag =>
            $Marpa::R2::HTML::Internal::Config::Default::TAG_DESCRIPTOR,
        ruby_slippers_rank_by_name =>
            $Marpa::R2::HTML::Internal::Config::Default::RUBY_SLIPPERS_RANK_BY_NAME,
        is_empty_element =>
            $Marpa::R2::HTML::Internal::Config::Default::IS_EMPTY_ELEMENT,
    };
    return bless $self, $class;
} ## end sub new

sub new_from_compile {
    my ( $class, $source_ref ) = @_;
    require Marpa::R2::HTML::Config::Compile;
    return bless Marpa::R2::HTML::Config::Compile::compile($source_ref), $class;
} ## end sub new_from_compile

sub contents {
    my ($self) = @_;
    return @{$self}{
        qw( rules descriptor_by_tag
            ruby_slippers_rank_by_name is_empty_element )
        };
} ## end sub contents

my $legal_preamble = <<'END_OF_TEXT';
# Copyright 2012 Jeffrey Kegler
# This file is part of Marpa::R2.  Marpa::R2 is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Marpa::R2 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Marpa::R2.  If not, see
# http://www.gnu.org/licenses/.

END_OF_TEXT

sub as_string {
    my ($self) = @_;

    require Data::Dumper;
    require Marpa::R2::HTML::Config::Default;

    local $Data::Dumper::Purity   = 1;
    local $Data::Dumper::Sortkeys = 1;
    my @contents = $self->contents();

    # Start with the legal language
    return \(
              $legal_preamble
            . '# This file was generated automatically by '
            . __PACKAGE__ . "\n"
            . '# The date of generation was '
            . ( scalar localtime() ) . "\n" . "\n"
            . "package Marpa::R2::HTML::Internal::Config::Default;\n" . "\n"
            . Data::Dumper->Dump(
            \@contents,
            [   qw( CORE_RULES TAG_DESCRIPTOR
                    RUBY_SLIPPERS_RANK_BY_NAME IS_EMPTY_ELEMENT )
            ]
            )
    );

} ## end sub as_string

1;
