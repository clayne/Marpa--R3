# Copyright 2016 Jeffrey Kegler
# This file is part of Marpa::R3.  Marpa::R3 is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Marpa::R3 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Marpa::R3.  If not, see
# http://www.gnu.org/licenses/.

# DO NOT EDIT THIS FILE DIRECTLY
# It was generated by make_internal_pm.pl

package Marpa::R3::Internal;

use 5.010001;
use strict;
use warnings;
use Carp;

use vars qw($VERSION $STRING_VERSION);
$VERSION        = '4.001_000';
$STRING_VERSION = $VERSION;
$VERSION = eval $VERSION;


package Marpa::R3::Internal::Symbol;
use constant ID => 0;
use constant BLESSING => 1;
use constant LEXEME_SEMANTICS => 2;
use constant DISPLAY_FORM => 3;
use constant DSL_FORM => 4;
use constant LEGACY_NAME => 5;
use constant DESCRIPTION => 6;
use constant IF_INACCESSIBLE => 7;

package Marpa::R3::Internal::Rule;
use constant ID => 0;
use constant NAME => 1;
use constant DISCARD_SEPARATION => 2;
use constant MASK => 3;
use constant SLIF_TAG => 4;
use constant ACTION_NAME => 5;
use constant BLESSING => 6;
use constant DESCRIPTION => 7;

package Marpa::R3::Internal::Grammar;
use constant C => 0;
use constant TRACER => 1;
use constant RULES => 2;
use constant RULE_ID_BY_TAG => 3;
use constant SYMBOLS => 4;
use constant ACTIONS => 5;
use constant BLESS_PACKAGE => 6;
use constant DEFAULT_ACTION => 7;
use constant TRACE_FILE_HANDLE => 8;
use constant WARNINGS => 9;
use constant INTERNAL => 10;
use constant CHARACTER_CLASSES => 11;
use constant CHARACTER_CLASS_TABLE => 12;
use constant LAST_BASIC_DATA_FIELD => 12;
use constant DEFAULT_EMPTY_ACTION => 13;
use constant ACTION_OBJECT => 14;
use constant INFINITE_ACTION => 15;
use constant LAST_EVALUATOR_FIELD => 15;
use constant PROBLEMS => 16;
use constant LAST_RECOGNIZER_FIELD => 16;
use constant START_NAME => 17;
use constant INACCESSIBLE_OK => 18;
use constant UNPRODUCTIVE_OK => 19;
use constant TRACE_RULES => 20;
use constant LAST_FIELD => 20;

package Marpa::R3::Internal::Recognizer;
use constant C => 0;
use constant B_C => 1;
use constant O_C => 2;
use constant T_C => 3;
use constant GRAMMAR => 4;
use constant TREE_MODE => 5;
use constant ASF_OR_NODES => 6;
use constant TRACE_FILE_HANDLE => 7;
use constant END_OF_PARSE => 8;
use constant MAX_PARSES => 9;
use constant RANKING_METHOD => 10;
use constant TRACE_ACTIONS => 11;
use constant TRACE_TERMINALS => 12;
use constant TRACE_VALUES => 13;
use constant WARNINGS => 14;
use constant NO_PARSE => 15;
use constant READ_STRING_ERROR => 16;
use constant NULL_VALUES => 17;
use constant PER_PARSE_CONSTRUCTOR => 18;
use constant RESOLVE_PACKAGE => 19;
use constant RESOLVE_PACKAGE_SOURCE => 20;
use constant REGISTRATIONS => 21;
use constant CLOSURE_BY_SYMBOL_ID => 22;
use constant CLOSURE_BY_RULE_ID => 23;

package Marpa::R3::Internal::Progress_Report;
use constant RULE_ID => 0;
use constant POSITION => 1;
use constant ORIGIN => 2;
use constant CURRENT => 3;

package Marpa::R3::Internal::Glade;
use constant ID => 0;
use constant SYMCHES => 1;
use constant VISITED => 2;
use constant REGISTERED => 3;

package Marpa::R3::Internal::Choicepoint;
use constant ASF => 0;
use constant FACTORING_STACK => 1;
use constant OR_NODE_IN_USE => 2;

package Marpa::R3::Internal::Nook;
use constant PARENT => 0;
use constant OR_NODE => 1;
use constant FIRST_CHOICE => 2;
use constant LAST_CHOICE => 3;
use constant IS_CAUSE => 4;
use constant IS_PREDECESSOR => 5;
use constant CAUSE_IS_EXPANDED => 6;
use constant PREDECESSOR_IS_EXPANDED => 7;

package Marpa::R3::Internal::ASF;
use constant SLR => 0;
use constant LEXEME_RESOLUTIONS => 1;
use constant RULE_RESOLUTIONS => 2;
use constant FACTORING_MAX => 3;
use constant RULE_BLESSINGS => 4;
use constant SYMBOL_BLESSINGS => 5;
use constant SYMCH_BLESSING_PACKAGE => 6;
use constant FACTORING_BLESSING_PACKAGE => 7;
use constant PROBLEM_BLESSING_PACKAGE => 8;
use constant DEFAULT_RULE_BLESSING_PACKAGE => 9;
use constant DEFAULT_TOKEN_BLESSING_PACKAGE => 10;
use constant OR_NODES => 11;
use constant GLADES => 12;
use constant INTSET_BY_KEY => 13;
use constant NEXT_INTSET_ID => 14;
use constant NIDSET_BY_ID => 15;
use constant POWERSET_BY_ID => 16;

package Marpa::R3::Internal::ASF::Traverse;
use constant ASF => 0;
use constant VALUES => 1;
use constant CODE => 2;
use constant PER_TRAVERSE_OBJECT => 3;
use constant GLADE => 4;
use constant SYMCH_IX => 5;
use constant FACTORING_IX => 6;

package Marpa::R3::Internal::Nidset;
use constant ID => 0;
use constant NIDS => 1;

package Marpa::R3::Internal::Powerset;
use constant ID => 0;
use constant NIDSET_IDS => 1;

package Marpa::R3::Internal::Scanless::G;
use constant C => 0;
use constant THICK_LEX_GRAMMARS => 1;
use constant THICK_G1_GRAMMAR => 2;
use constant CHARACTER_CLASS_TABLES => 3;
use constant DISCARD_EVENT_BY_LEXER_RULE => 4;
use constant MASK_BY_RULE_ID => 5;
use constant DEFAULT_G1_START_ACTION => 6;
use constant COMPLETION_EVENT_BY_ID => 7;
use constant NULLED_EVENT_BY_ID => 8;
use constant PREDICTION_EVENT_BY_ID => 9;
use constant LEXEME_EVENT_BY_ID => 10;
use constant SYMBOL_IDS_BY_EVENT_NAME_AND_TYPE => 11;
use constant CACHE_RULEIDS_BY_LHS_NAME => 12;
use constant TRACE_FILE_HANDLE => 13;
use constant TRACE_TERMINALS => 14;

package Marpa::R3::Internal::Scanless::R;
use constant C => 0;
use constant GRAMMAR => 1;
use constant THICK_G1_RECCE => 2;
use constant P_INPUT_STRING => 3;
use constant EXHAUSTION_ACTION => 4;
use constant REJECTION_ACTION => 5;
use constant TRACE_FILE_HANDLE => 6;
use constant TRACE_LEXERS => 7;
use constant TRACE_TERMINALS => 8;
use constant READ_STRING_ERROR => 9;
use constant EVENTS => 10;
use constant ERROR_MESSAGE => 11;

1;
