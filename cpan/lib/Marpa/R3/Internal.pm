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

# DO NOT EDIT THIS FILE DIRECTLY
# It was generated by make_internal_pm.pl

package Marpa::R3::Internal;

use 5.010001;
use strict;
use warnings;
use Carp;

use vars qw($VERSION $STRING_VERSION);
$VERSION        = '4.001_003';
$STRING_VERSION = $VERSION;
$VERSION = eval $VERSION;


package Marpa::R3::Internal::XSY;
use constant ID => 0;
use constant NAME => 1;
use constant NAME_SOURCE => 2;
use constant BLESSING => 3;
use constant LEXEME_SEMANTICS => 4;
use constant DSL_FORM => 5;
use constant IF_INACCESSIBLE => 6;

package Marpa::R3::Internal::Rule;
use constant ID => 0;
use constant NAME => 1;
use constant DISCARD_SEPARATION => 2;
use constant MASK => 3;
use constant SLIF_TAG => 4;
use constant ACTION_NAME => 5;
use constant BLESSING => 6;

package Marpa::R3::Internal::Trace::G;
use constant NAME => 0;
use constant C => 1;
use constant NAME_BY_ISYID => 2;
use constant ISYID_BY_NAME => 3;
use constant XSY_BY_ISYID => 4;
use constant START_NAME => 5;
use constant RULES => 6;

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
use constant L0_TRACER => 1;
use constant G1_TRACER => 2;
use constant CHARACTER_CLASS_TABLE => 3;
use constant DISCARD_EVENT_BY_LEXER_RULE => 4;
use constant MASK_BY_RULE_ID => 5;
use constant XSY_BY_ID => 6;
use constant XSY_BY_NAME => 7;
use constant COMPLETION_EVENT_BY_ID => 8;
use constant NULLED_EVENT_BY_ID => 9;
use constant PREDICTION_EVENT_BY_ID => 10;
use constant LEXEME_EVENT_BY_ID => 11;
use constant SYMBOL_IDS_BY_EVENT_NAME_AND_TYPE => 12;
use constant CACHE_G1_IRLIDS_BY_LHS_NAME => 13;
use constant BLESS_PACKAGE => 14;
use constant IF_INACCESSIBLE => 15;
use constant WARNINGS => 16;
use constant TRACE_FILE_HANDLE => 17;
use constant TRACE_TERMINALS => 18;
use constant CHARACTER_CLASSES => 19;

package Marpa::R3::Internal::Scanless::R;
use constant SLG => 0;
use constant SLR_C => 1;
use constant R_C => 2;
use constant B_C => 3;
use constant O_C => 4;
use constant T_C => 5;
use constant P_INPUT_STRING => 6;
use constant EXHAUSTION_ACTION => 7;
use constant REJECTION_ACTION => 8;
use constant TRACE_FILE_HANDLE => 9;
use constant TRACE_LEXERS => 10;
use constant TRACE_TERMINALS => 11;
use constant TRACE_VALUES => 12;
use constant TRACE_ACTIONS => 13;
use constant READ_STRING_ERROR => 14;
use constant EVENTS => 15;
use constant ERROR_MESSAGE => 16;
use constant MAX_PARSES => 17;
use constant RANKING_METHOD => 18;
use constant NO_PARSE => 19;
use constant NULL_VALUES => 20;
use constant TREE_MODE => 21;
use constant END_OF_PARSE => 22;
use constant SEMANTICS_PACKAGE => 23;
use constant REGISTRATIONS => 24;
use constant CLOSURE_BY_SYMBOL_ID => 25;
use constant CLOSURE_BY_RULE_ID => 26;

1;
