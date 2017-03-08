<!--
Copyright 2017 Jeffrey Kegler
Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
-->

# The Kollos code

# Table of contents
<!--
cd kollos && ../lua/lua toc.lua < kollos.lua.md
-->
* [About Kollos](#about-kollos)
* [Development Notes](#development-notes)
  * [To Do](#to-do)
    * [TODO notes](#todo-notes)
  * [Use generations in Libmarpa trees](#use-generations-in-libmarpa-trees)
  * [Kollos assumes core libraries are loaded](#kollos-assumes-core-libraries-are-loaded)
  * [Kollos assumes global name "kollos"](#kollos-assumes-global-name-kollos)
  * [New lexer features](#new-lexer-features)
  * [Discard events](#discard-events)
* [Kollos object](#kollos-object)
* [Kollos registry objects](#kollos-registry-objects)
* [Kollos SLIF grammar object](#kollos-slif-grammar-object)
* [Kollos SLIF recognizer object](#kollos-slif-recognizer-object)
  * [Constructor](#constructor)
  * [Reading](#reading)
  * [Locations](#locations)
  * [Events](#events)
  * [Progress reporting](#progress-reporting)
  * [Exceptions](#exceptions)
  * [Diagnostics](#diagnostics)
* [Kollos semantics](#kollos-semantics)
  * [VM operations](#vm-operations)
    * [VM debug operation](#vm-debug-operation)
    * [VM debug operation](#vm-debug-operation)
    * [VM no-op operation](#vm-no-op-operation)
    * [VM bail operation](#vm-bail-operation)
    * [VM result operations](#vm-result-operations)
    * [VM "result is undef" operation](#vm-result-is-undef-operation)
    * [VM "result is token value" operation](#vm-result-is-token-value-operation)
    * [VM "result is N of RHS" operation](#vm-result-is-n-of-rhs-operation)
    * [VM "result is N of sequence" operation](#vm-result-is-n-of-sequence-operation)
    * [VM operation: result is constant](#vm-operation-result-is-constant)
    * [Operation of the values array](#operation-of-the-values-array)
    * [VM "push undef" operation](#vm-push-undef-operation)
    * [VM "push one" operation](#vm-push-one-operation)
    * [Find current token literal](#find-current-token-literal)
    * [VM "push values" operation](#vm-push-values-operation)
    * [VM operation: push start location](#vm-operation-push-start-location)
    * [VM operation: push length](#vm-operation-push-length)
    * [VM operation: push G1 start location](#vm-operation-push-g1-start-location)
    * [VM operation: push G1 length](#vm-operation-push-g1-length)
    * [VM operation: push constant onto values array](#vm-operation-push-constant-onto-values-array)
    * [VM operation: set the array blessing](#vm-operation-set-the-array-blessing)
    * [VM operation: result is array](#vm-operation-result-is-array)
    * [VM operation: callback](#vm-operation-callback)
  * [Run the virtual machine](#run-the-virtual-machine)
  * [Find and perform the VM operations](#find-and-perform-the-vm-operations)
  * [Tree export operations](#tree-export-operations)
  * [VM-related utilities for use in the Perl code](#vm-related-utilities-for-use-in-the-perl-code)
    * [Return operation key given its name](#return-operation-key-given-its-name)
    * [Return operation name given its key](#return-operation-name-given-its-key)
    * [Return the top index of the stack](#return-the-top-index-of-the-stack)
    * [Return the value of a stack entry](#return-the-value-of-a-stack-entry)
    * [Set the value of a stack entry](#set-the-value-of-a-stack-entry)
    * [Convert current, origin Earley set to L0 span](#convert-current-origin-earley-set-to-l0-span)
* [The grammar Libmarpa wrapper](#the-grammar-libmarpa-wrapper)
* [The recognizer Libmarpa wrapper](#the-recognizer-libmarpa-wrapper)
* [The valuator Libmarpa wrapper](#the-valuator-libmarpa-wrapper)
  * [Initialize a valuator](#initialize-a-valuator)
  * [Reset a valuator](#reset-a-valuator)
* [Diagnostics](#diagnostics)
* [Libmarpa interface](#libmarpa-interface)
  * [Standard template methods](#standard-template-methods)
  * [Constructors](#constructors)
* [The main Lua code file](#the-main-lua-code-file)
  * [Preliminaries to the main code](#preliminaries-to-the-main-code)
* [The Kollos C code file](#the-kollos-c-code-file)
  * [Stuff from okollos](#stuff-from-okollos)
  * [Kollos metal loader](#kollos-metal-loader)
  * [Create a sandbox](#create-a-sandbox)
  * [Preliminaries to the C library code](#preliminaries-to-the-c-library-code)
* [The Kollos C header file](#the-kollos-c-header-file)
  * [Preliminaries to the C header file](#preliminaries-to-the-c-header-file)
* [Meta-coding utilities](#meta-coding-utilities)
  * [Metacode execution sequence](#metacode-execution-sequence)
  * [Dedent method](#dedent-method)
  * [`c_safe_string` method](#c-safe-string-method)
  * [Meta code argument processing](#meta-code-argument-processing)
* [Kollos utilities](#kollos-utilities)

## About Kollos

This is the code for Kollos, the "middle layer" of Marpa.
Below it is Libmarpa, a library written in
the C language which contains the actual parse engine.
Above it is code in a higher level language -- at this point Perl.

This document is evolving.  Most of the "middle layer" is still
in the Perl code or in the Perl XS, and not represented here.
This document only contains those portions converted to Lua or
to Lua-centeric C code.

The intent is that eventually
all the code in this file will be "pure"
Kollos -- no Perl knowledge.
That is not the case at the moment.

## Development Notes

This section is first for the convenience of the
active developers.
Readers trying to familiarize themselves with Kollos
may want to skip it or skim it
in their first readings.

### To Do

#### TODO notes

Throughout the code, the string "TODO" marks notes
for action during or after development.
Not all of these are included or mentioned
in these "Development Notes".

### Use generations in Libmarpa trees

Currently a valuator "pauses" its base tree, so
that it does not change during the life of the tree.
This gets tricky for the Lua garbage collection --
the valuator may not be garbage collected quickly,
and no new tree can be created meantime.
Instead, add a generation number to the tree, and
use that.

### Kollos assumes core libraries are loaded

Currently Kollos assumes that the
core libraries are loaded.
Going forward, it needs to "require" then,
like an ordinary Lua library.

### Kollos assumes global name "kollos"

The Kollos methods now often assume that the kollos
class can be found as a global named "kollos".
Namespace hygiene and preserving the ability to
load multiple kollos packages (for debugging, say),
requires that this be changed.
Going forward, we will store kollos as a field
in all libmarpa wrapper and Kollos registry object metatables,
and use that in all methods.
like an ordinary Lua library.

### New lexer features

* "Eager" tokens (currently all tokens are "greedy")

*  Changing priorities to be "non-local".  Current priorities only break
ties for tokens at the same location.  "Non-local" means if there is a
priority 2 lexeme of any length and/or eagerness, you will get that
lexeme, and not any lexeme of priority 1 or lower.

* Lookahead.

### Discard events

[ These are design notes from some time ago, for a never-implemented
feature.  I have not idea what will become of these ideas. ]

Defining a discard event for a token causes an event to be generated
when an instance of that token is discarded.  (Note that I avoid calling
discarded tokens "lexemes".  This is for pedantic reasons.)

I will allow the `event` adverb for discard statements.
The following are some possible
variants of the discard statement:

```
   :discard ~ ws event => 'wsdiscard'=off

   :discard ~ <ws> event => wsdiscard=on

   :discard ~ ws event => 'wsdiscard'
```

These cause the event `wsdiscard` to be generated when a `<ws>`
token is discarded.
The `=on` or `=off` after the event name determines whether the event is
initialized as active or inactive.
If set to `on` (the default), the event is initialized
active.  If set to `off`, the event is initialized inactive.

I add the ability to initialize discard events as active
or inactive,
because I expect that applications will often
want to define grammars which allow the possibility of events on discard
tokens, but that applications
will also often want the ability to initialize them to inactive.

A new named parameter of the `$recce->new()` method will allow the
application to change this initial setting, on a per-token basis.
The main expected use of this is to turn on, at runtime, discard events
that were initialized to inactive.

There will also be a new `discard default` statement, modeled on the
`lexeme default` statement.  An example:

```
   discard default => event => ::name=off
```

This says that,
for all `:discard` statements with no explicit event name,
the event name is based on the name of the discarded symbol,
and that the event is initialized
to inactive.

Discard events will be non-lexeme, named events,
and will be accessible via the `$recce->events()` method.
Conceptually, they always occur after the token has been discarded.
The event described will have 4 elements:

    * the event name, as with all events;

    * the physical input location where the discarded token starts;

    * the length of the discarded token in physical
      input locations; and

    * the last G1 location of a lexeme.

(Recall that lexemes, by definition, are not discarded.)
If no lexeme has yet been recognized, the G1 location will be zero.
The main use of the G1 location will be for syncing discarded
tokens with a parse tree.

Marpa::R3 parse event descriptors have been documented as
containing 1 or more elements, but those currently implemented
always contain only one element, the event name.
Discard events will therefore be the first event
whose descriptor
actually contains more than a single element.

## Kollos object

`ref_count` maintains a reference count that controls
the destruction of Kollos interpreters.
`warn` is for a warning callback -- it's not
currently used.
`buffer` is used by kollos internally, usually
for buffering symbol ID's in the libmarpa wrappers.
`buffer_capacity` is its current capacity.

The buffer strategy currently is to set its capacity to the
maximum symbol count of any of the grammars in the Kollos
interpreter.

```
    -- miranda: section utility function definitions

    /* I assume this will be inlined by the compiler */
    static Marpa_Symbol_ID *shared_buffer_get(lua_State* L)
    {
        Marpa_Symbol_ID* buffer;
        const int base_of_stack = marpa_lua_gettop(L);
        marpa_lua_pushvalue(L, marpa_lua_upvalueindex(1));
        if (!marpa_lua_istable(L, -1)) {
            internal_error_handle(L, "missing upvalue table",
            __PRETTY_FUNCTION__, __FILE__, __LINE__);
        }
        marpa_lua_getfield(L, -1, "buffer");
        buffer = marpa_lua_touserdata(L, -1);
        marpa_lua_settop(L, base_of_stack);
        return buffer;
    }

    -- miranda: section C function declarations
    /* I probably will, in the final version, want this to be a
     * static utility, internal to Kollos
     */
    void kollos_shared_buffer_resize(
        lua_State* L,
        size_t desired_capacity);
```

Not Lua C API.
Manipulates Lua stack,
leaving it as is.

```
    -- miranda: section external C function definitions
    void kollos_shared_buffer_resize(
        lua_State* L,
        size_t desired_capacity)
    {
        size_t buffer_capacity;
        const int base_of_stack = marpa_lua_gettop(L);
        const int upvalue_ix = base_of_stack + 1;

        marpa_lua_pushvalue(L, marpa_lua_upvalueindex(1));
        if (!marpa_lua_istable(L, -1)) {
            internal_error_handle(L, "missing upvalue table",
            __PRETTY_FUNCTION__, __FILE__, __LINE__);
        }
        marpa_lua_getfield(L, upvalue_ix, "buffer_capacity");
        buffer_capacity = (size_t)marpa_lua_tointeger(L, -1);
        /* Is this test needed after development? */
        if (buffer_capacity < 1) {
            internal_error_handle(L, "bad buffer capacity",
            __PRETTY_FUNCTION__, __FILE__, __LINE__);
        }
        if (desired_capacity > buffer_capacity) {
            /* TODO: this optimizes for space, not speed.
             * Insist capacity double on each realloc()?
             */
            (void)marpa_lua_newuserdata (L,
                desired_capacity * sizeof (Marpa_Symbol_ID));
            marpa_lua_setfield(L, upvalue_ix, "buffer");
            marpa_lua_pushinteger(L, (lua_Integer)desired_capacity);
            marpa_lua_setfield(L, upvalue_ix, "buffer_capacity");
        }
        marpa_lua_settop(L, base_of_stack);
    }

```

## Kollos registry objects

A Kollos registry object is an object kept in its
registry.
These generated ID's which allow them to be identified
safely to non-Lua code.
They have increment and decrement methods.

These increment and decrement methods are intended only
for non-Lua code.
They make it possible
for the non-Lua code to be sure that the Lua
registry object exists for as long as they
require it.

Lua code should not use the reference counter.
Lua code
should simply copy the table object -- in Lua this
is a reference and Lua's GC will do the right thing.

`kollos_robrefinc()`
creates a new reference
to a Kollos registry object,
and takes ownership of it.

```

    -- miranda: section+ C function declarations
    void kollos_robrefinc(lua_State* L, lua_Integer lua_ref);
    -- miranda: section+ lua interpreter management
    void kollos_robrefinc(lua_State* L, lua_Integer lua_ref)
    {
        int rob_ix;
        const int base_of_stack = marpa_lua_gettop(L);
        lua_Integer refcount;
        if (marpa_lua_geti(L, LUA_REGISTRYINDEX, lua_ref) != LUA_TTABLE) {
            internal_error_handle (L, "registry object is not a table",
                __PRETTY_FUNCTION__, __FILE__, __LINE__);
        }
        rob_ix = marpa_lua_gettop(L);
        if (marpa_lua_getfield(L, rob_ix, "ref_count") != LUA_TNUMBER) {
            internal_error_handle (L, "rob ref_count is not a number",
                __PRETTY_FUNCTION__, __FILE__, __LINE__);
        }
        refcount = marpa_lua_tointeger(L, -1);
        refcount += 1;
        marpa_lua_pushinteger(L, refcount);
        marpa_lua_setfield(L, rob_ix, "ref_count");
        marpa_lua_settop(L, base_of_stack);
    }

```

Give up ownership of a reference to a Kollos registry object.
Deletes the interpreter if the reference count drops to zero.

```

    -- miranda: section+ C function declarations
    void kollos_robrefdec(lua_State* L, lua_Integer lua_ref);
    -- miranda: section+ lua interpreter management
    void kollos_robrefdec(lua_State* L, lua_Integer lua_ref)
    {
        int rob_ix;
        const int base_of_stack = marpa_lua_gettop(L);
        lua_Integer refcount;
        if (marpa_lua_geti(L, LUA_REGISTRYINDEX, lua_ref) != LUA_TTABLE) {
            internal_error_handle (L, "registry object is not a table",
                __PRETTY_FUNCTION__, __FILE__, __LINE__);
        }
        rob_ix = marpa_lua_gettop(L);
        if (marpa_lua_getfield(L, rob_ix, "ref_count") != LUA_TNUMBER) {
            internal_error_handle (L, "rob ref_count is not a number",
                __PRETTY_FUNCTION__, __FILE__, __LINE__);
        }
        refcount = marpa_lua_tointeger(L, -1);
        if (refcount <= 1) {
           marpa_luaL_unref(L, LUA_REGISTRYINDEX, (int)lua_ref);
           marpa_lua_settop(L, base_of_stack);
           return;
        }
        refcount -= 1;
        marpa_lua_pushinteger(L, refcount);
        marpa_lua_setfield(L, rob_ix, "ref_count");
        marpa_lua_settop(L, base_of_stack);
    }

```

## Kollos SLIF grammar object

This is a registry object.

```
    -- miranda: section+ luaL_Reg definitions
    static const struct luaL_Reg slg_methods[] = {
      { NULL, NULL },
    };

```

This "post-new" method will become the latter part of the
`slg_new()` method.

```
    -- miranda: section+ most Lua function definitions
    function _M.class_slg.post_new(grammar)
        grammar.nulling_semantics = {}
        grammar.rule_semantics = {}
        grammar.token_semantics = {}
        grammar.per_codepoint = {}
        return
    end

```

## Kollos SLIF recognizer object

This is a registry object.

```
    -- miranda: section+ luaL_Reg definitions
    static const struct luaL_Reg slr_methods[] = {
      { NULL, NULL },
    };

```

### Constructor

```
    -- miranda: section+ most Lua function definitions
    function _M.class_slr.l0r_new(recce, perl_pos)
        local l0r = _M.recce_new(recce.slg.lmw_l0g)
        if not l0r then
            error('Internal error: l0r_new() failed %s',
                recce.slg.lmw_l0g:error_description())
        end
        recce.lmw_l0r = l0r
        local too_many_earley_items = recce.too_many_earley_items
        if too_many_earley_items >= 0 then
            recce.lmw_l0r:earley_item_warning_threshold_set(too_many_earley_items)
        end
         -- for now use a per-recce field
         -- later replace with a local
        recce.terminals_expected = recce.lmw_g1r:terminals_expected()
        local count = #recce.terminals_expected
        if not count or count < 0 then
            local error_description = recce.lmw_g1r:error_description()
            error('Internal error: terminals_expected() failed in u_l0r_new(); %s',
                    error_description)
        end
        for i = 0, count -1 do
            local ix = i + 1
            local terminal = recce.terminals_expected[ix]
            local assertion = recce.slg.g1_symbols[terminal].assertion
            assertion = assertion or -1
            if assertion >= 0 then
                local result = recce.lmw_l0r:zwa_default_set(assertion, 1)
                if result < 0 then
                    local error_description = recce.lmw_l0r:error_description()
                    error('Problem in u_l0r_new() with assertion ID %ld and lexeme ID %ld: %s',
                        assertion, terminal, error_description
                    )
                end
            end
            if recce.trace_terminals >= 3 then
                local q = recce.event_queue
                q[#q+1] = { '!trace', 'expected lexeme', perl_pos, terminal, assertion }
            end
        end
        local result = recce.lmw_l0r:start_input()
        if result and result <= -2 then
            local error_description = recce.lmw_l0r:error_description()
            error('Internal error: problem with recce:start_input(l0r): %s',
                error_description)
        end
    end

```

### Reading

"Complete" an earleme in L0.
Return nil on success,
otherwise a failure code.

```
    -- miranda: section+ most Lua function definitions
    function _M.class_slr.l0_earleme_complete(recce)
        local l0r = recce.lmw_l0r
        local complete_result = recce.lmw_l0r:earleme_complete()
        if complete_result == -2 then
            if l0r:error_code() == _M.err.PARSE_EXHAUSTED then
                return 'exhausted on failure'
            end
        end
        if complete_result < 0 then
            error('Problem in r->l0_read(), earleme_complete() failed: ',
            l0r:error_description())
        end
        if complete_result > 0 then
            recce:l0_convert_events(recce.perl_pos)
            local is_exhausted = recce.lmw_l0r:is_exhausted()
            if is_exhausted ~= 0 then
                return 'exhausted on success'
            end
        end
        return
    end

```

Read an alternative.
Returns the number of alternatives accepted,
which will be 1 or 0.

```
    -- miranda: section+ most Lua function definitions
    function _M.class_slr.l0_alternative(recce, symbol_id)
        local l0r = recce.lmw_l0r
        local codepoint = recce.codepoint
        local result = l0r:alternative(symbol_id, 1, 1)
        if result == _M.err.UNEXPECTED_TOKEN_ID then
            if recce.trace_terminals >= 1 then
                local q = recce.event_queue
                q[#q+1] = { '!trace', 'lexer rejected codepoint', codepoint,
                     recce.perl_pos, symbol_id}
            end
            return 0
        end
        if result == _M.err.NONE then
            if recce.trace_terminals >= 1 then
            local q = recce.event_queue
            q[#q+1] = { '!trace', 'lexer accepted codepoint', codepoint,
                recce.perl_pos, symbol_id}
            end
            return 1
        end
        error(string.format([[
             Problem alternative() failed at char ix %d; symbol id %d; codepoint 0x%x
             Problem in l0_read(), alternative() failed: %s
        ]],
            recce.perl_pos, symbol_id, codepoint, l0r:error_description()
        ))
    end


```

Read the current codepoint in L0.
Returns nil on success,
otherwise an error code string.

```
    -- miranda: section+ most Lua function definitions
    function _M.class_slr.l0_read_codepoint(recce)
        local codepoint = recce.codepoint
        local ops = recce.per_codepoint[codepoint]
        if ops == nil then
            -- print( '1 unregistered char', codepoint, -1)
            return 'unregistered char'
        end
        if ops == false then
            -- print( 'invalid char', codepoint, -1)
            return 'invalid char'
        end
        local op_count = #ops
        if op_count <= 0 then
            -- print( '2 unregistered char', codepoint, op_count)
            return 'unregistered char'
        end
        if recce.trace_terminals >= 1 then
           local q = recce.event_queue
           q[#q+1] = { '!trace', 'lexer reading codepoint', codepoint, recce.perl_pos}
        end
        local tokens_accepted = 0
        for ix = 1, op_count do
            local symbol_id = recce.per_codepoint[codepoint][ix]
            tokens_accepted = tokens_accepted +
                 recce:l0_alternative(symbol_id)
        end
        if tokens_accepted < 1 then return 'rejected char' end
        local complete_result = recce:l0_earleme_complete()
        if complete_result then return complete_result end
        return
    end

```

Read a lexeme from the L0 recognizer.
Returns a status string.

```
    -- miranda: section+ most Lua function definitions
    function _M.class_slr.l0_read_lexeme(recce)
        if not recce.lmw_l0r then
            recce:l0r_new(recce.perl_pos)
        end
        while true do
            local codepoint = -1
            if recce.perl_pos >= recce.end_pos then
                return 'ok'
            end
            -- +1 because codepoints array is 1-based
            local codepoint = recce.codepoints[recce.perl_pos+1]
            recce.codepoint = codepoint
            local errmsg = recce:l0_read_codepoint()
            if errmsg then return errmsg end
            recce.perl_pos = recce.perl_pos + 1
            if recce.trace_terminals > 0 then
               return 'tracing'
            end
        end
        error('Unexpected fall through in l0_read()')
    end

```

Read alternatives into the G1 grammar.

```
    -- miranda: section+ most Lua function definitions
    function _M.class_slr.g1_alternatives(slr, lexeme_start, lexeme_end, g1_lexeme)
        if slr.trace_terminals > 2 then
            local q = slr.event_queue
            q[#q+1] = { '!trace', 'g1 attempting lexeme', lexeme_start, lexeme_end, g1_lexeme}
        end
        local g1r = slr.lmw_g1r
        local kollos = getmetatable(g1r).kollos
        local value_is_literal = kollos.defines.TOKEN_VALUE_IS_LITERAL
        local return_value = g1r:alternative(g1_lexeme, value_is_literal, 1)
        -- print('return value = ', inspect(return_value))
        if return_value == kollos.err.UNEXPECTED_TOKEN_ID then
            error('Internal error: Marpa rejected expected token')
        end
        if return_value == kollos.err.DUPLICATE_TOKEN then
            local q = slr.event_queue
            q[#q+1] = { '!trace', 'g1 duplicate lexeme', lexeme_start, lexeme_end, g1_lexeme}
            goto NEXT_EVENT
        end
        if return_value ~= kollos.err.NONE then
            local l0r = slr.lmw_l0r
            error(string.format([[
                 'Problem SLR->read() failed on symbol id %d at position %d: %s'
            ]],
                g1_lexeme, slr.perl_pos, l0r:error_description()
            ))
            goto NEXT_EVENT
        end
        do
            if slr.trace_terminals > 0 then
                local q = slr.event_queue
                q[#q+1] = { '!trace', 'g1 accepted lexeme', lexeme_start, lexeme_end, g1_lexeme}
            end
            slr.start_of_pause_lexeme = lexeme_start
            slr.end_of_pause_lexeme = lexeme_end
            local pause_after_active = slr.g1_symbols[g1_lexeme].pause_after_active
            if pause_after_active then
                local q = slr.event_queue
                if slr.trace_terminals > 2 then
                    q[#q+1] = { '!trace', 'g1 pausing after lexeme', lexeme_start, lexeme_end, g1_lexeme}
                end
                q[#q+1] = { 'after lexeme', g1_lexeme}
            end
        end
        ::NEXT_EVENT::
        return return_value
    end
```

### Locations

Given a G1 span return an L0 span.
Note that the data for G1 location `n` is kept in
`es_data[n+1]`, the data for Earley set `n+1`.
Never fails -- any G1 span is converted into some
kind of L0 span.  Further,
the L0 span is zero-count iff the count of the G1
span is zero or less.

```
    -- miranda: section+ most Lua function definitions
    function _M.class_slr.g1_to_l0_span(slr, g1_start, g1_count)
         local es_data = slr.es_data
         if g1_count <= 0 then
             if g1_start < 0 then
                 return 0, 0
             end
             if g1_start >= #es_data then
                 local last_data = es_data[#es_data]
                 return last_data[1] + last_data[2], 0
             end
             local first_es_data = es_data[g1_start+1]
             return first_es_data[1], 0
         end
         -- count cannot be less than 1,
         -- g1_end >= g1_start, always
         local g1_end = g1_start + g1_count - 1
         if g1_start < 0 then g1_start = 0 end
         if g1_end < 0 then g1_end = 0 end
         if g1_start >= #es_data then g1_start = #es_data - 1 end
         if g1_end >= #es_data then g1_end = #es_data - 1 end
         local start_es_data = es_data[g1_start+1]
         local end_es_data = es_data[g1_end+1]
         local l0_start = start_es_data[1]
         local end_es_start = end_es_data[1]
         local end_es_length = end_es_data[2]
         local l0_length = end_es_start + end_es_length - l0_start
         -- Because Marpa allowed backward jumps in the input, negative
         -- lengths were possible.  Change these to point to a single
         -- character.
         if l0_length < 1 then l0_length = 1 end
         return l0_start, l0_length
    end

```

### Events

```
    -- miranda: section+ most Lua function definitions

    -- TODO: perl_pos arg is development hack --
    -- eventually use recce.perl_pos
    function _M.class_slr.g1_convert_events(recce, perl_pos)
        local g1g = recce.slg.lmw_g1g
        local q = recce.event_queue
        local events = g1g:events()
        for i = 1, #events, 2 do
            local event_type = events[i]
            local event_value = events[i+1]
            if event_type == _M.event["EXHAUSTED"] then
                goto NEXT_EVENT
            end
            if event_type == _M.event["SYMBOL_COMPLETED"] then
                q[#q+1] = { 'symbol completed', event_value}
                goto NEXT_EVENT
            end
            if event_type == _M.event["SYMBOL_NULLED"] then
                q[#q+1] = { 'symbol nulled', event_value}
                goto NEXT_EVENT
            end
            if event_type == _M.event["SYMBOL_PREDICTED"] then
                q[#q+1] = { 'symbol predicted', event_value}
                goto NEXT_EVENT
            end
            if event_type == _M.event["EARLEY_ITEM_THRESHOLD"] then
                q[#q+1] = { 'g1 earley item threshold exceeded',
                    perl_pos, event_value}
                goto NEXT_EVENT
            end
            local event_data = _M.event[event_type]
            if not event_data then
                result_string = string.format(
                    'unknown event code, %d', event_type
                )
            else
                result_string = event_data.name
            end
            q[#q+1] = { 'unknown_event', result_string}
            ::NEXT_EVENT::
        end
    end

    -- TODO: perl_pos arg is development hack --
    -- eventually use recce.perl_pos
    function _M.class_slr.l0_convert_events(recce, perl_pos)
        local l0g = recce.slg.lmw_l0g
        local q = recce.event_queue
        local events = l0g:events()
        for i = 1, #events, 2 do
            local event_type = events[i]
            local event_value = events[i+1]
            if event_type == _M.event["EXHAUSTED"] then
                goto NEXT_EVENT
            end
            if event_type == _M.event["EARLEY_ITEM_THRESHOLD"] then
                q[#q+1] = { 'l0 earley item threshold exceeded',
                    perl_pos, event_value}
                goto NEXT_EVENT
            end
            local event_data = _M.event[event_type]
            if not event_data then
                result_string = string.format(
                    'unknown event code, %d', event_type
                )
            else
                result_string = event_data.name
            end
            q[#q+1] = { 'unknown_event', result_string}
            ::NEXT_EVENT::
        end
    end

```

### Progress reporting

Given a scanless
recognizer and a symbol,
`last_completed()`
returns the start earley set
and length
of the last such symbol completed,
or nil if there was none.

```
    -- miranda: section+ most Lua function definitions
    function _M.class_slr.last_completed(recce, symbol_id)
         local g1r = recce.lmw_g1r
         local g1g = recce.slg.lmw_g1g
         local latest_earley_set = g1r:latest_earley_set()
         local first_origin = latest_earley_set + 1
         local earley_set = latest_earley_set
         while earley_set >= 0 do
             g1r:progress_report_start(earley_set)
             while true do
                 local rule_id, dot_position, origin = g1r:progress_item()
                 if not rule_id then goto LAST_ITEM end
                 if dot_position ~= -1 then goto NEXT_ITEM end
                 local lhs_id = g1g:rule_lhs(rule_id)
                 if symbol_id ~= lhs_id then goto NEXT_ITEM end
                 if origin < first_origin then
                     first_origin = origin
                 end
                 ::NEXT_ITEM::
             end
             ::LAST_ITEM::
             g1r:progress_report_finish()
             if first_origin <= latest_earley_set then
                 goto LAST_EARLEY_SET
             end
             earley_set = earley_set - 1
         end
         ::LAST_EARLEY_SET::
         if earley_set < 0 then return end
         return first_origin, earley_set - first_origin
    end

```

```
    -- miranda: section+ most Lua function definitions
    function _M.class_slr.progress(recce, ordinal_arg)
        local g1r = recce.lmw_g1r
        local ordinal = ordinal_arg
        local latest_earley_set = g1r:latest_earley_set()
        if ordinal > latest_earley_set then
            error(string.format(
                "Argument out of bounds in recce->progress(%d)\n"
                .. "   Argument specifies Earley set after the latest Earley set 0\n"
                .. "   The latest Earley set is Earley set $latest_earley_set\n",
                ordinal_arg
                ))
        elseif ordinal < 0 then
            ordinal = latest_earley_set + 1 + ordinal
            if ordinal < 0 then
                error(string.format(
                    "Argument out of bounds in recce->progress(%d)\n"
                    .. "   Argument specifies Earley set before Earley set 0\n",
                    ordinal_arg
                ))
            end
            end
        local result = {}
        g1r:progress_report_start(ordinal)
        while true do
            local rule_id, dot_position, origin = g1r:progress_item()
            if not rule_id then goto LAST_ITEM end
            result[#result+1] = { rule_id, dot_position, origin }
        end
        ::LAST_ITEM::
        g1r:progress_report_finish()
        return result
    end

```

### Exceptions

```
    -- miranda: section+ C extern variables
    extern char kollos_X_fallback_mt_key;
    extern char kollos_X_proto_asis_mt_key;
    extern char kollos_X_proto_mt_key;
    extern char kollos_X_mt_key;
    -- miranda: section+ metatable keys
    char kollos_X_fallback_mt_key;
    char kollos_X_proto_asis_mt_key;
    char kollos_X_proto_mt_key;
    char kollos_X_mt_key;
    -- miranda: section+ set up empty metatables

    /* mt_X_fallback = {} */
    marpa_lua_newtable (L);
    marpa_lua_pushvalue (L, -1);
    marpa_lua_rawsetp (L, LUA_REGISTRYINDEX, &kollos_X_fallback_mt_key);
    /* kollos.mt_X_fallback = mt_X_fallback */
    marpa_lua_setfield (L, kollos_table_stack_ix, "mt_X_fallback");

    /* mt_X_proto = {} */
    marpa_lua_newtable (L);
    marpa_lua_pushvalue (L, -1);
    marpa_lua_rawsetp (L, LUA_REGISTRYINDEX, &kollos_X_proto_mt_key);
    /* kollos.mt_X_proto = mt_X_proto */
    marpa_lua_setfield (L, kollos_table_stack_ix, "mt_X_proto");

    /* mt_X_proto_asis = {} */
    marpa_lua_newtable (L);
    marpa_lua_pushvalue (L, -1);
    marpa_lua_rawsetp (L, LUA_REGISTRYINDEX, &kollos_X_proto_asis_mt_key);
    /* kollos.mt_X_proto_asis = mt_X_proto_asis */
    marpa_lua_setfield (L, kollos_table_stack_ix, "mt_X_proto_asis");

    /* Set up exception metatables, initially empty */
    /* mt_X = {} */
    marpa_lua_newtable (L);
    marpa_lua_pushvalue (L, -1);
    marpa_lua_rawsetp (L, LUA_REGISTRYINDEX, &kollos_X_mt_key);
    /* kollos.mt_X = mt_X */
    marpa_lua_setfield (L, kollos_table_stack_ix, "mt_X");

```

The "fallback" for converting an exception is make it part
of a table with a fallback __tostring method, which uses the
inspect package to dump it.

```
    -- miranda: section+ populate metatables

    -- `inspect` is used in our __tostring methods, but
    -- it also calls __tostring.  This global is used to
    -- prevent any recursive calls.
    _M.recursive_tostring = false

    local function X_fallback_tostring(self)
         -- print("in X_fallback_tostring")
         local desc
         if _M.recursive_tostring then
             desc = '[Recursive call of inspect]'
         else
             _M.recursive_tostring = 'X_fallback_tostring'
             desc = inspect(self, { depth = 3 })
             _M.recursive_tostring = false
         end
         local nl = ''
         local where = ''
         if type(self) == 'table' then
             local where = self.where
             if where and desc:sub(-1) ~= '\n' then
                 nl = '\n'
             end
         end
         local traceback = debug.traceback("Kollos internal error: bad exception object")
         return desc .. nl .. where .. '\n' .. traceback
    end

    local function X_tostring(self)
         -- print("in X_tostring")
         if type(self) ~= 'table' then
              return X_fallback_tostring(self)
         end
         local desc = self.msg
         local desc_type = type(desc)
         if desc_type == "string" then
             local nl = ''
             local where = self.where
             if where then
                 if desc:sub(-1) ~= '\n' then nl = '\n' end
             else
                 where = ''
             end
             return desc .. nl .. where
         end

         -- no `msg` so look for a code
         local error_code = self.code
         if error_code then
              local description = _M.error_description(error_code)
              local details = self.details
              local pieces = {}
              if details then
                  pieces[#pieces+1] = details
                  pieces[#pieces+1] = ': '
              end
              pieces[#pieces+1] = description
              local where = self.where
              if where then
                  pieces[#pieces+1] = '\n'
                  pieces[#pieces+1] = where
              end
              return table.concat(pieces)
         end

         -- no `msg` or `code` so we fall back
         return X_fallback_tostring(self)
    end

    local function error_tostring(self)
         print("Calling error_tostring")
         return '[error_tostring]'
    end

    _M.mt_X.__tostring = X_tostring
    _M.mt_X_proto.__tostring = X_tostring
    _M.mt_X_proto_asis.__tostring = X_tostring
    _M.mt_X_fallback.__tostring = X_fallback_tostring

```

A function to throw exceptions which do not carry a
traceback.  This is for "user" errors, where "user"
means the error can be explained in user-friendly terms
and things like stack traces are unnecessary.
(These errors are also usually "user" errors in the sense
that the user caused them,
but that is not necessarily the case.)

```
    -- miranda: section+ most Lua function definitions
    function _M.userX(msg)
        local X = { msg = msg, traceback = false }
        setmetatable(X, _M.mt_X)
        error(X)
    end
```

### Diagnostics

This is not currently used.
It was created for development,
and is being kept for use as
part of a "Pure Lua" implementation.

```
    -- miranda: section+ most Lua function definitions
    function _M.class_slr.show_leo_item(recce)
        local g1r = recce.lmw_g1r
        local g1g = recce.slg.lmw_g1g
        local leo_base_state = g1r:_leo_base_state()
        if not leo_base_state then return '' end
        local trace_earley_set = g1r:_trace_earley_set()
        local trace_earleme = g1r:earleme(trace_earley_set)
        local postdot_symbol_id = g1r:_postdot_item_symbol()
        local postdot_symbol_name = g1g:isy_name(postdot_symbol_id)
        local predecessor_symbol_id = g1r:_leo_predecessor_symbol()
        local base_origin_set_id = g1r:_leo_base_origin()
        local base_origin_earleme = g1r:earleme(base_origin_set_id)
        local link_texts = {
            string.format("%q", postdot_symbol_name)
        }
        if predecessor_symbol_id then
            link_texts[#link_texts+1] = string.format(
                'L%d@%d', predecessor_symbol_id, base_origin_earleme
            );
        end
        link_texts[#link_texts+1] = string.format(
            'S%d@%d-%d',
            leo_base_state,
            base_origin_earleme,
            trace_earleme
        );
        return string.format('L%d@%d [%s]',
             postdot_symbol_id, trace_earleme,
             table.concat(link_texts, '; '));
    end

```

## Kollos semantics

Initially, Marpa's semantics were performed using a VM (virtual machine)
of about two dozen
operations.  I am converting them to Lua, one by one.  Once they are in
Lua, the flexibility in defining operations becomes much greater than when
they were in C/XS.  The set of operations which can be defined becomes
literally open-ended.

With Lua replacing C, the constraints which dictated the original design
of this VM are completely altered.
It remains an open question what becomes of this VM and its operation
set as Marpa evolves.
For example,
at the extreme end, every program in the old VM could be replaced with
one that is a single instruction long, with that single instruction
written entirely in Lua.
If this were done, there no longer would be a VM, in any real sense of the
word.

### VM operations

A return value of -1 indicates this should be the last VM operation.
A return value of 0 or greater indicates this is the last VM operation,
and that there is a Perl callback with the contents of the values array
as its arguments.
A return value of -2 or less indicates that the reading of VM operations
should continue.

Note the use of tails calls in the Lua code.
Maintainers should be aware that these are finicky.
In particular, while `return f(x)` is turned into a tail call,
`return (f(x))` is not.

The next function is a utility to set
up the VM table.

#### VM debug operation

```
    -- miranda: section VM utilities

        _M.vm_ops = {}
        _M.vm_op_names = {}
        _M.vm_op_keys = {}
        local function op_fn_add(name, fn)
            local ops = _M.vm_ops
            local new_ix = #ops + 1
            ops[new_ix] = fn
            ops[name] = fn
            _M.vm_op_names[new_ix] = name
            _M.vm_op_keys[name] = new_ix
            return new_ix
        end

```


#### VM debug operation

Was used for development.
Perhaps I should delete this.

```
    -- miranda: section VM operations

    local function op_fn_debug (recce)
        for k,v in pairs(recce) do
            print(k, v)
        end
        mt = debug.getmetatable(recce)
        print([[=== metatable ===]])
        for k,v in pairs(mt) do
            print(k, v)
        end
        return -2
    end
    op_fn_add("debug", op_fn_debug)

```

#### VM no-op operation

This is to be kept after development,
even if not used.
It may be useful in debugging.

```
    -- miranda: section+ VM operations

    local function op_fn_noop (recce)
        return -2
    end
    op_fn_add("noop", op_fn_noop)

```

#### VM bail operation

This is to used for development.
Its intended use is as a dummy argument,
which, if it is used by accident
as a VM operation,
fast fails with a clear message.

```
    -- miranda: section+ VM operations

    local function op_fn_bail (recce)
        error('executing VM op "bail"')
    end
    op_fn_add("bail", op_fn_bail)

```

#### VM result operations

If an operation in the VM returns -1, it is a
"result operation".
The actual result is expected to be in the stack
at index `recce.this_step.result`.

The result operation is not required to be the
last operation in a sequence,
and
a sequence of operations does not have to contain
a result operation.
If there are
other operations after the result operation,
they will not be performed.
If a sequence ends without encountering a result
operation, an implicit "no-op" result operation
is assumed and, as usual,
the result is the value in the stack
at index `recce.this_step.result`.

#### VM "result is undef" operation

Perhaps the simplest operation.
The result of the semantics is a Perl undef.

```
    -- miranda: section+ VM operations

    local function op_fn_result_is_undef(recce)
        local stack = recce.lmw_v.stack
        local undef_tree_op = { 'perl', 'undef' }
        setmetatable(undef_tree_op, _M.mt_tree_op)
        stack[recce.this_step.result] = undef_tree_op
        return -1
    end
    op_fn_add("result_is_undef", op_fn_result_is_undef)

```

#### VM "result is token value" operation

The result of the semantics is the value of the
token at the current location.
It's assumed to be a MARPA_STEP_TOKEN step --
if not the value is an undef.

```
    -- miranda: section+ VM operations

    local function op_fn_result_is_token_value(recce)
        if recce.this_step.type ~= 'MARPA_STEP_TOKEN' then
          return op_fn_result_is_undef(recce)
        end
        local stack = recce.lmw_v.stack
        local result_ix = recce.this_step.result
        stack[result_ix] = recce:current_token_literal()
        if recce.trace_values > 0 then
          local top_of_queue = #recce.trace_values_queue;
          local tag, token_sv
          recce.trace_values_queue[top_of_queue+1] =
             {tag, recce.this_step.type, recce.this_step.symbol, recce.this_step.value, token_sv};
             -- io.stderr:write('[step_type]: ', inspect(recce))
        end
        return -1
    end
    op_fn_add("result_is_token_value", op_fn_result_is_token_value)

```

#### VM "result is N of RHS" operation

```
    -- miranda: section+ VM operations
    local function op_fn_result_is_n_of_rhs(recce, rhs_ix)
        if recce.this_step.type ~= 'MARPA_STEP_RULE' then
          return op_fn_result_is_undef(recce)
        end
        local stack = recce.lmw_v.stack
        local result_ix = recce.this_step.result
        repeat
            if rhs_ix == 0 then break end
            local fetch_ix = result_ix + rhs_ix
            if fetch_ix > recce.this_step.arg_n then
                local undef_tree_op = { 'perl', 'undef' }
                setmetatable(undef_tree_op, _M.mt_tree_op)
                stack[result_ix] = undef_tree_op
                break
            end
            stack[result_ix] = stack[fetch_ix]
        until 1
        return -1
    end
    op_fn_add("result_is_n_of_rhs", op_fn_result_is_n_of_rhs)

```

#### VM "result is N of sequence" operation

In `stack`,
set the result to the `item_ix`'th item of a sequence.
`stack` is a 0-based Perl AV.
Here "sequence" means a sequence in which the separators
have been kept.
For those with separators discarded,
the "N of RHS" operation should be used.

```
    -- miranda: section+ VM operations
    local function op_fn_result_is_n_of_sequence(recce, item_ix)
        if recce.this_step.type ~= 'MARPA_STEP_RULE' then
          return op_fn_result_is_undef(recce)
        end
        local result_ix = recce.this_step.result
        local fetch_ix = result_ix + item_ix * 2
        if fetch_ix > recce.this_step.arg_n then
          return op_fn_result_is_undef(recce)
        end
        local stack = recce.lmw_v.stack
        if item_ix > 0 then
            stack[result_ix] = stack[fetch_ix]
        end
        return -1
    end
    op_fn_add("result_is_n_of_sequence", op_fn_result_is_n_of_sequence)

```

#### VM operation: result is constant

Returns a constant result.

```
    -- miranda: section+ VM operations
    local function op_fn_result_is_constant(recce, constant_ix)
        local constant_tree_op = { 'perl', 'constant', constant_ix }
        setmetatable(constant_tree_op, _M.mt_tree_op)
        local stack = recce.lmw_v.stack
        local result_ix = recce.this_step.result
        stack[result_ix] = constant_tree_op
        if recce.trace_values > 0 and recce.this_step.type == 'MARPA_STEP_TOKEN' then
            local top_of_queue = #recce.trace_values_queue
            recce.trace_values_queue[top_of_queue+1] =
                { "valuator unknown step", recce.this_step.type, recce.token, constant}
                      -- io.stderr:write('valuator unknown step: ', inspect(recce))
        end
        return -1
    end
    op_fn_add("result_is_constant", op_fn_result_is_constant)

```

#### Operation of the values array

The following operations add elements to the `values` array.
This is a special array which may eventually be the result of the
sequence of operations.

#### VM "push undef" operation

Push an undef on the values array.

```
    -- miranda: section+ VM operations

    local function op_fn_push_undef(recce, dummy, new_values)
        local next_ix = #new_values + 1;
        local undef_tree_op = { 'perl', 'undef' }
        setmetatable(undef_tree_op, _M.mt_tree_op)
        new_values[next_ix] = undef_tree_op
        return -2
    end
    op_fn_add("push_undef", op_fn_push_undef)

```

#### VM "push one" operation

Push one of the RHS child values onto the values array.

```
    -- miranda: section+ VM operations

    local function op_fn_push_one(recce, rhs_ix, new_values)
        if recce.this_step.type ~= 'MARPA_STEP_RULE' then
          return op_fn_push_undef(recce, nil, new_values)
        end
        local stack = recce.lmw_v.stack
        local result_ix = recce.this_step.result
        local next_ix = #new_values + 1;
        new_values[next_ix] = stack[result_ix + rhs_ix]
        return -2
    end
    op_fn_add("push_one", op_fn_push_one)

```

#### Find current token literal

`current_token_literal` return the literal
equivalent of the current token.
It assumes that there *is* a current token,
that is,
it assumes that the caller has ensured that
`recce.this_step.type ~= 'MARPA_STEP_TOKEN'`.

```
    -- miranda: section+ VM operations
    function _M.class_slr.current_token_literal(recce)
      if recce.token_is_literal == recce.this_step.value then
          local start_es = recce.this_step.start_es_id
          local end_es = recce.this_step.es_id
          local g1_count = end_es - start_es + 1
          local l0_start, l0_length =
              recce:earley_sets_to_L0_span(start_es, end_es)
          if l0_length <= 0 then return '' end
          local tree_op = { 'perl', 'literal', l0_start, l0_length }
          setmetatable(tree_op, _M.mt_tree_op)
          return tree_op
      end
      return recce.token_values[recce.this_step.value]
    end

```

#### VM "push values" operation

Push the child values onto the `values` list.
If it is a token step, then
the token at the current location is pushed onto the `values` list.
If it is a nulling step, the nothing is pushed.
Otherwise the values of the RHS children are pushed.

`increment` is 2 for sequences where separators must be discarded,
1 otherwise.

```
    -- miranda: section+ VM operations

    local function op_fn_push_values(recce, increment, new_values)
        if recce.this_step.type == 'MARPA_STEP_TOKEN' then
            local next_ix = #new_values + 1;
            new_values[next_ix] = recce:current_token_literal()
            return -2
        end
        if recce.this_step.type == 'MARPA_STEP_RULE' then
            local stack = recce.lmw_v.stack
            local arg_n = recce.this_step.arg_n
            local result_ix = recce.this_step.result
            local to_ix = #new_values + 1;
            for from_ix = result_ix,arg_n,increment do
                new_values[to_ix] = stack[from_ix]
                to_ix = to_ix + 1
            end
            return -2
        end
        -- if 'MARPA_STEP_NULLING_SYMBOL', or unrecogized type
        return -2
    end
    op_fn_add("push_values", op_fn_push_values)

```

#### VM operation: push start location

The current start location in input location terms -- that is,
in terms of the input string.

```
    -- miranda: section+ VM operations
    local function op_fn_push_start(recce, dummy, new_values)
        local start_es = recce.this_step.start_es_id
        local es_data = recce.es_data
        local l0_start
        start_es = start_es + 1
        if start_es > #es_data then
             local es_entry = es_data[#es_data]
             l0_start = es_entry[1] + es_entry[2]
        elseif start_es < 1 then
             l0_start = 0
        else
             local es_entry = es_data[start_es]
             l0_start = es_entry[1]
        end
        local next_ix = #new_values + 1;
        new_values[next_ix] = l0_start
        return -2
    end
    op_fn_add("push_start", op_fn_push_start)


```

#### VM operation: push length

The length of the current step in input location terms --
that is, in terms of the input string

```
    -- miranda: section+ VM operations
    local function op_fn_push_length(recce, dummy, new_values)
        local start_es = recce.this_step.start_es_id
        local end_es = recce.this_step.es_id
        local es_data = recce.es_data
        local l0_length = 0
        start_es = start_es + 1
        local start_es_entry = es_data[start_es]
        if start_es_entry then
            local l0_start = start_es_entry[1]
            local end_es_entry = es_data[end_es]
            l0_length =
                end_es_entry[1] + end_es_entry[2] - l0_start
        end
        local next_ix = #new_values + 1;
        new_values[next_ix] = l0_length
        return -2
    end
    op_fn_add("push_length", op_fn_push_length)

```

#### VM operation: push G1 start location

The current start location in G1 location terms -- that is,
in terms of G1 Earley sets.

```
    -- miranda: section+ VM operations
    local function op_fn_push_g1_start(recce, dummy, new_values)
        local next_ix = #new_values + 1;
        new_values[next_ix] = recce.this_step.start_es_id
        return -2
    end
    op_fn_add("push_g1_start", op_fn_push_g1_start)

```

#### VM operation: push G1 length

The length of the current step in G1 terms --
that is, in terms of G1 Earley sets.

```
    -- miranda: section+ VM operations
    local function op_fn_push_g1_length(recce, dummy, new_values)
        local next_ix = #new_values + 1;
        new_values[next_ix] = (recce.this_step.es_id
            - recce.this_step.start_es_id) + 1
        return -2
    end
    op_fn_add("push_g1_length", op_fn_push_g1_length)

```

#### VM operation: push constant onto values array

```
    -- miranda: section+ VM operations
    local function op_fn_push_constant(recce, constant_ix, new_values)
        local constant_tree_op = { 'perl', 'constant', constant_ix }
        setmetatable(constant_tree_op, _M.mt_tree_op)
        -- io.stderr:write('constant_ix: ', constant_ix, "\n")
        local next_ix = #new_values + 1;
        new_values[next_ix] = constant_tree_op
        return -2
    end
    op_fn_add("push_constant", op_fn_push_constant)

```

#### VM operation: set the array blessing

The blessing is registered in a constant, and this operation
lets the VM know its index.  The index is cleared at the beginning
of every sequence of operations

```
    -- miranda: section+ VM operations
    local function op_fn_bless(recce, blessing_ix)
        recce.this_step.blessing_ix = blessing_ix
        return -2
    end
    op_fn_add("bless", op_fn_bless)

```

#### VM operation: result is array

This operation tells the VM that the current `values` array
is the result of this sequence of operations.

```
    -- miranda: section+ VM operations
    local function op_fn_result_is_array(recce, dummy, new_values)
        local blessing_ix = recce.this_step.blessing_ix
        if blessing_ix then
          new_values = { 'perl', 'bless', new_values, blessing_ix }
          setmetatable(new_values, _M.mt_tree_op)
        end
        local stack = recce.lmw_v.stack
        local result_ix = recce.this_step.result
        stack[result_ix] = new_values
        return -1
    end
    op_fn_add("result_is_array", op_fn_result_is_array)

```

#### VM operation: callback

Tells the VM to create a callback to Perl, with
the `values` array as an argument.
The return value of 3 is a vestige of an earlier
implementation, which returned the size of the
`values` array.

```
    -- miranda: section+ VM operations
    local function op_fn_callback(recce, dummy, new_values)
        local blessing_ix = recce.this_step.blessing_ix
        local step_type = recce.this_step.type
        if step_type ~= 'MARPA_STEP_RULE'
            and step_type ~= 'MARPA_STEP_NULLING_SYMBOL'
        then
            io.stderr:write(
                'Internal error: callback for wrong step type ',
                step_type
            )
            os.exit(false)
        end
        local blessing_ix = recce.this_step.blessing_ix
        if blessing_ix then
          new_values = { 'perl', 'bless', new_values, blessing_ix }
          setmetatable(new_values, _M.mt_tree_op)
        end
        return 3
    end
    op_fn_add("callback", op_fn_callback)

```

### Run the virtual machine

```
    -- miranda: section+ VM operations
    function _M.class_slr.do_ops(recce, ops, new_values)
        local op_ix = 1
        while op_ix <= #ops do
            local op_code = ops[op_ix]
            if op_code == 0 then return -1 end
            if op_code ~= _M.defines.op_lua then
            end
            local fn_key = ops[op_ix+1]
            local arg = ops[op_ix+2]
            if recce.trace_values >= 3 then
              local queue = recce.trace_values_queue
              local tag = 'starting lua op'
              queue[#queue+1] = {'starting op', recce.this_step.type, 'lua'}
              queue[#queue+1] = {tag, recce.this_step.type, _M.vm_op_names[fn_key]}
              -- io.stderr:write('starting op: ', inspect(recce))
            end
            -- io.stderr:write('ops: ', inspect(_M.vm_ops), '\n')
            -- io.stderr:write('fn_key: ', inspect(fn_key), '\n')
            local op_fn = _M.vm_ops[fn_key]
            local result = op_fn(recce, arg, new_values)
            if result >= -1 then return result end
            op_ix = op_ix + 3
            end
        return -1
    end

```

### Find and perform the VM operations

Determine the appropriate VM operations for this
step, and perform them.
Return codes are

* 3 for callback;
* 1 for return the step type;
* 0 for return an empty list;
* -1 for return 'trace';
* -2 for no return.

The mnemonic for these codes is
that they represent the size of the list returned to Perl,
with "trace" and "do not return" being special cases.

```
    -- miranda: section+ VM operations
    function _M.class_slr.find_and_do_ops(recce)
        recce.trace_values_queue = {}
        local grammar = recce.slg
        while true do
            local new_values = {}
            local ops = {}
            recce:step()
            if recce.this_step.type == 'MARPA_STEP_INACTIVE' then
                return 0, new_values
            end
            if recce.this_step.type == 'MARPA_STEP_RULE' then
                ops = grammar.rule_semantics[recce.this_step.rule]
                if not ops then
                    ops = _M.rule_semantics_default
                end
                goto DO_OPS
            end
            if recce.this_step.type == 'MARPA_STEP_TOKEN' then
                ops = grammar.token_semantics[recce.this_step.symbol]
                if not ops then
                    ops = _M.token_semantics_default
                end
                goto DO_OPS
            end
            if recce.this_step.type == 'MARPA_STEP_NULLING_SYMBOL' then
                ops = grammar.nulling_semantics[recce.this_step.symbol]
                if not ops then
                    ops = _M.nulling_semantics_default
                end
                goto DO_OPS
            end
            if true then return 1, new_values end
            ::DO_OPS::
            if not ops then
                error(string.format('No semantics defined for %s', recce.this_step.type))
            end
            local do_ops_result = recce:do_ops(ops, new_values)
            local stack = recce.lmw_v.stack
            -- truncate stack
            local above_top = recce.this_step.result + 1
            for i = above_top,#stack do stack[i] = nil end
            if do_ops_result > 0 then
                return 3, new_values
            end
            if #recce.trace_values_queue > 0 then return -1, new_values end
        end
    end

```

Set up the default VM operations

```
    -- miranda: section+ VM default operations
    do
        -- we record these values to set the defaults, below
        local op_lua =  _M.defines.MARPA_OP_LUA
        local op_bail_key = _M.vm_op_keys["bail"]
        local result_is_constant_key = _M.vm_op_keys["result_is_constant"]
        local result_is_undef_key = _M.vm_op_keys["result_is_undef"]
        local result_is_token_value_key = _M.vm_op_keys["result_is_token_value"]

        _M.nulling_semantics_default = { op_lua, result_is_undef_key, op_bail_key, 0 }
        _M.token_semantics_default = { op_lua, result_is_token_value_key, op_bail_key, 0 }
        _M.rule_semantics_default = { op_lua, result_is_undef_key, op_bail_key, 0 }

    end


```

### Tree export operations

The "tree export operations" are performed when a tree is transformed
from Kollos form to a form
suitable for its parent layer.
Currently the only parent layer is Marpa::R3.

The tree export operations
are defined as light userdata referring to a dedicated global
constant, which guarantees they will never collide with user data.
The global constants are defined only for the purpose of creating
a unique address --
their contents are never used.

These operations are always the first element of a sequence.
They tell
Kollos how to transform the rest of the sequence.

The "asis" operation simply passes on the 2nd element of the sequence
as an SV.
It probably will not be needed much

```
    -- miranda: section+ C global constant variables
    static int tree_op_asis;
    -- miranda: section+ create tree export operations
    marpa_lua_pushlightuserdata(L, (void *)&tree_op_asis);
    marpa_lua_setfield(L, kollos_table_stack_ix, "tree_op_asis");

```

The "bless" operation passes on the 2nd element of the sequence,
blessed using the 3rd element.
The 3rd element must be a string.

```
    -- miranda: section+ C global constant variables
    static int tree_op_bless;
    -- miranda: section+ create tree export operations
    marpa_lua_pushlightuserdata(L, (void *)&tree_op_bless);
    marpa_lua_setfield(L, kollos_table_stack_ix, "tree_op_bless");

```

### VM-related utilities for use in the Perl code

The following operations are used by the higher-level Perl code
to set and discover various Lua values.

#### Return operation key given its name

```
    -- miranda: section Utilities for semantics
    function _M.get_op_fn_key_by_name(op_name)
        return _M.vm_op_keys[op_name]
    end

```

#### Return operation name given its key

```
    -- miranda: section+ Utilities for semantics
    function _M.get_op_fn_name_by_key(op_key)
        return _M.vm_op_names[op_key]
    end

```

#### Return the top index of the stack

```
    -- miranda: section+ Utilities for semantics
    function _M.class_slr.stack_top_index(recce)
        return recce.this_step.result
    end

```

#### Return the value of a stack entry

```
    -- miranda: section+ Utilities for semantics
    function _M.class_slr.stack_get(recce, ix)
        local stack = recce.lmw_v.stack
        return stack[ix+0]
    end

```

#### Set the value of a stack entry

```
    -- miranda: section+ Utilities for semantics
    function _M.class_slr.stack_set(recce, ix, v)
        local stack = recce.lmw_v.stack
        stack[ix+0] = v
    end

```

#### Convert current, origin Earley set to L0 span

Given a current Earley set and an origin Earley set,
return a span in L0 terms.
The purpose is assumed to be a find a literal
equivalent.
All zero length literals are alike,
so the logic is careless about the l0_start when l0_length
is zero.

```
    -- miranda: section+ Utilities for semantics
    function _M.class_slr.earley_sets_to_L0_span(recce, start_earley_set, end_earley_set)
      start_earley_set = start_earley_set + 1
      -- normalize start_earley_set
      if start_earley_set < 1 then start_earley_set = 1 end
      if end_earley_set < start_earley_set then
          return 0, 0
      end
      local es_data = recce.es_data
      local start_entry = es_data[start_earley_set]
      if not start_entry then
          return 0, 0
      end
      local end_entry = es_data[end_earley_set]
      if not end_entry then
          end_entry = es_data[#es_data]
      end
      local l0_start = start_entry[1]
      local l0_length = end_entry[1] + end_entry[2] - l0_start
      return l0_start, l0_length
    end

```

## The grammar Libmarpa wrapper

Constructor

```
    -- miranda: section+ copy metal tables
    _M.metal.grammar_new = _M.grammar_new
    -- miranda: section+ most Lua function definitions
    function _M.grammar_new()
        local lmw_g = _M.metal.grammar_new()
        lmw_g.isyid_by_name = {}
        lmw_g.name_by_isyid = {}
        return lmw_g
    end

```

```
    -- miranda: section+ copy metal tables
    _M.metal_grammar.symbol_new = _M.class_grammar.symbol_new
    -- miranda: section+ most Lua function definitions
    function _M.class_grammar.symbol_new(lmw_g, symbol_name)
        local symbol_id = _M.metal_grammar.symbol_new(lmw_g)
        lmw_g.isyid_by_name[symbol_name] = symbol_id
        lmw_g.name_by_isyid[symbol_id] = symbol_name
        return symbol_id
    end

```

```
    -- miranda: section+ grammar Libmarpa wrapper Lua functions

    function _M.class_grammar.symbol_name(lmw_g, symbol_id)
        local symbol_name = lmw_g.name_by_isyid[symbol_id]
        if symbol_name then return symbol_name end
        return string.format('R%d', symbol_id)
    end

    function _M.class_grammar.irl_isyids(lmw_g, rule_id)
        local lhs = lmw_g:rule_lhs(rule_id)
        if not lhs then return {} end
        local symbols = { lhs }
        for rhsix = 0, lmw_g:rule_length(rule_id) - 1 do
             symbols[#symbols+1] = lmw_g:rule_rhs(rule_id, rhsix)
        end
        return symbols
    end

    function _M.class_grammar.ahm_describe(lmw_g, ahm_id)
        local irl_id = lmw_g:_ahm_irl(ahm_id)
        local dot_position = lmw_g:_ahm_position(ahm_id)
        if dot_position < 0 then
            return string.format('R%d$', irl_id)
        end
        return string.format('R%d:%d', irl_id, dot_position)
    end

    function _M.class_grammar.show_dotted_irl(lmw_g, irl_id, dot_position)
        local lhs_id = lmw_g:_irl_lhs(irl_id)
        local irl_length = lmw_g:_irl_length(irl_id)
        local lhs_name = lmw_g:isy_name(lhs_id)
        local pieces = { lhs_name, '::=' }
        if dot_position < 0 then
            dot_position = irl_length
        end
        for ix = 0, irl_length - 1 do
            local rhs_nsy_id = lmw_g:_irl_rhs(irl_id, ix)
            local rhs_nsy_name = lmw_g:isy_name(rhs_nsy_id)
            if ix == dot_position then
                pieces[#pieces+1] = '.'
            end
            pieces[#pieces+1] = rhs_nsy_name
        end
        if dot_position >= irl_length then
            pieces[#pieces+1] = '.'
        end
        return table.concat(pieces, ' ')
    end

```

```
    -- miranda: section+ grammar Libmarpa wrapper Lua functions

    function _M.class_grammar.isy_name(lmw_g, nsy_id_arg)
         -- start symbol
         local nsy_id = math.tointeger(nsy_id_arg)
         if not nsy_id then error('Bad isy_name() symbol ID arg: ' .. inspect(nsy_id_arg)) end
         local nsy_is_start = 0 ~= lmw_g:_nsy_is_start(nsy_id)
         if nsy_is_start then
             local xsy_id = lmw_g:_source_xsy(nsy_id)
             local xsy_name = lmw_g:symbol_name(xsy_id)
             return xsy_name .. "[']"
         end

         -- sequence LHS
         local lhs_xrl = lmw_g:_nsy_lhs_xrl(nsy_id)
         if lhs_xrl and lmw_g:sequence_min(lhs_xrl) then
             local original_lhs_id = lmw_g:rule_lhs(lhs_xrl)
             local lhs_name = lmw_g:symbol_name(original_lhs_id)
             return lhs_name .. "[Seq]"
         end

         -- virtual symbol
         local xrl_offset = lmw_g:_nsy_xrl_offset(nsy_id)
         if xrl_offset and xrl_offset > 0 then
             local original_lhs_id = lmw_g:rule_lhs(lhs_xrl)
             local lhs_name = lmw_g:symbol_name(original_lhs_id)
             return string.format("%s[R%d:%d]",
                 lhs_name, lhs_xrl, xrl_offset)
         end

         -- real, named symbol or its nulling equivalent
         local xsy_id = lmw_g:_source_xsy(nsy_id)
         local xsy_name = lmw_g:symbol_name(xsy_id)
         local is_nulling = 0 ~= lmw_g:_nsy_is_nulling(nsy_id)
         if is_nulling then
             xsy_name = xsy_name .. "[]"
         end
         return xsy_name
    end

    function _M.class_grammar.show_ahm(lmw_g, item_id)
        local postdot_id = lmw_g:_ahm_postdot(item_id)
        local pieces = { "AHM " .. item_id .. ': ' }
        local properties = {}
        if not postdot_id then
            properties[#properties+1] = 'completion'
        else
            properties[#properties+1] =
               'postdot = "' ..  lmw_g:isy_name(postdot_id) .. '"'
        end
        pieces[#pieces+1] = table.concat(properties, '; ')
        pieces[#pieces+1] = "\n    "
        local irl_id = lmw_g:_ahm_irl(item_id)
        local dot_position = lmw_g:_ahm_position(item_id)
        pieces[#pieces+1] = lmw_g:show_dotted_irl(irl_id, dot_position)
        pieces[#pieces+1] = '\n'
        return table.concat(pieces)
    end

    function _M.class_grammar.show_ahms(lmw_g)
        local pieces = {}
        local count = lmw_g:_ahm_count()
        for i = 0, count -1 do
            pieces[#pieces+1] = lmw_g:show_ahm(i)
        end
        return table.concat(pieces)
    end

    function _M.class_grammar.show_isy(lmw_g, isy_id)
        local name = lmw_g:isy_name(isy_id)
        local pieces = { string.format("%d: %s", isy_id, name) }
        local tags = {}
        local is_nulling = 0 ~= lmw_g:_nsy_is_nulling(isy_id)
        if is_nulling then
        tags[#tags+1] = 'nulling'
        end
        if #tags > 0 then
            pieces[#pieces+1] = ', ' .. table.concat(tags, ' ')
        end
        pieces[#pieces+1] = '\n'
        return table.concat(pieces)
    end

    function _M.class_grammar.brief_irl(lmw_g, irl_id)
        local pieces = { string.format("%d: ", irl_id) }
        local lhs_id = lmw_g:_irl_lhs(irl_id)
        pieces[#pieces+1] = lmw_g:isy_name(lhs_id)
        pieces[#pieces+1] = " ->"
        local rh_length = lmw_g:_irl_length(irl_id)
        if rh_length > 0 then
           local rhs_names = {}
           for rhs_ix = 0, rh_length - 1 do
              local this_rhs_id = lmw_g:_irl_rhs(irl_id, rhs_ix)
              rhs_names[#rhs_names+1] = lmw_g:isy_name(this_rhs_id)
           end
           pieces[#pieces+1] = " " .. table.concat(rhs_names, " ")
        end
        return table.concat(pieces)
    end

```

## The recognizer Libmarpa wrapper

Functions for tracing Earley sets

```
    -- miranda: section+ recognizer Libmarpa wrapper Lua functions
    function _M.class_recce.leo_item_data(lmw_r)
        local lmw_g = lmw_r.lmw_g
        local leo_base_state = lmw_r:_leo_base_state()
        if not leo_base_state then return end
        local trace_earley_set = lmw_r:_trace_earley_set()
        local trace_earleme = lmw_r:earleme(trace_earley_set)
        local postdot_symbol_id = lmw_r:_postdot_item_symbol()
        local postdot_symbol_name = lmw_g:isy_name(postdot_symbol_id)
        local predecessor_symbol_id = lmw_r:_leo_predecessor_symbol()
        local base_origin_set_id = lmw_r:_leo_base_origin()
        local base_origin_earleme = lmw_r:earleme(base_origin_set_id)
        return {
            postdot_symbol_name = postdot_symbol_name,
            postdot_symbol_id = postdot_symbol_id,
            predecessor_symbol_id = predecessor_symbol_id,
            base_origin_earleme = base_origin_earleme,
            leo_base_state = leo_base_state,
            trace_earleme = trace_earleme
        }
    end

    function _M.class_recce.token_link_data(lmw_r)
        local lmw_g = lmw_r.lmw_g
        local result = {}
        local token_id, value_ix = lmw_r:_source_token()
        local predecessor_ahm = lmw_r:_source_predecessor_state()
        local origin_set_id = lmw_r:_earley_item_origin()
        local origin_earleme = lmw_r:earleme(origin_set_id)
        local middle_earleme = origin_earleme
        local middle_set_id = lmw_r:_source_middle()
        if predecessor_ahm then
            middle_earleme = lmw_r:earleme(middle_set_id)
        end
        local token_name = lmw_g:isy_name(token_id)
        result.predecessor_ahm = predecessor_ahm
        result.origin_earleme = origin_earleme
        result.middle_set_id = middle_set_id
        result.middle_earleme = middle_earleme
        result.token_name = token_name
        result.token_id = token_id
        result.value_ix = value_ix
        if value_ix ~= 2 then
            result.value = recce.token_values[value_ix]
        end
        return result
    end

    function _M.class_recce.completion_link_data(lmw_r, ahm_id)
        local lmw_g = lmw_r.lmw_g
        local g1r = recce.lmw_g1r
        local result = {}
        local predecessor_state = g1r:_source_predecessor_state()
        local origin_set_id = g1r:_earley_item_origin()
        local origin_earleme = g1r:earleme(origin_set_id)
        local middle_set_id = g1r:_source_middle()
        local middle_earleme = g1r:earleme(middle_set_id)
        result.predecessor_state = predecessor_state
        result.origin_earleme = origin_earleme
        result.middle_earleme = middle_earleme
        result.middle_set_id = middle_set_id
        result.ahm_id = ahm_id
        return result
    end

    function _M.class_recce.leo_link_data(lmw_r, ahm_id)
        local lmw_g = lmw_r.lmw_g
        local g1r = recce.lmw_g1r
        local result = {}
        local middle_set_id = g1r:_source_middle()
        local middle_earleme = g1r:earleme(middle_set_id)
        local leo_transition_symbol = g1r:_source_leo_transition_symbol()
        result.middle_earleme = middle_earleme
        result.leo_transition_symbol = leo_transition_symbol
        result.ahm_id = ahm_id
        return result
    end

    function _M.class_recce.earley_item_data(lmw_r, set_id, item_id)
        local item_data = {}
        local lmw_g = lmw_r.lmw_g

        local result = lmw_r:_earley_set_trace(set_id)
        if not result then return end

        local ahm_id_of_yim = lmw_r:_earley_item_trace(item_id)
        if not ahm_id_of_yim then return end

        local origin_set_id  = lmw_r:_earley_item_origin()
        local origin_earleme = lmw_r:earleme(origin_set_id)
        local current_earleme = lmw_r:earleme(set_id)

        local irl_id = lmw_g:_ahm_irl(ahm_id_of_yim)
        local dot_position = lmw_g:_ahm_position(ahm_id_of_yim)

        item_data.current_set_id = set_id
        item_data.current_earleme = current_earleme
        item_data.ahm_id_of_yim = ahm_id_of_yim
        item_data.origin_set_id = origin_set_id
        item_data.origin_earleme = origin_earleme
        item_data.irl_id = irl_id
        item_data.dot_position = dot_position

        do -- token links
            local symbol_id = lmw_r:_first_token_link_trace()
            local links = {}
            while symbol_id do
                links[#links+1] = lmw_r:token_link_data()
                symbol_id = lmw_r:_next_token_link_trace()
            end
            item_data.token_links = links
        end

        do -- completion links
            local ahm_id = lmw_r:_first_completion_link_trace()
            local links = {}
            while ahm_id do
                links[#links+1] = lmw_r:completion_link_data(ahm_id)
                ahm_id = lmw_r:_next_completion_link_trace()
            end
            item_data.completion_links = links
        end

        do -- leo links
            local ahm_id = lmw_r:_first_leo_link_trace()
            local links = {}
            while ahm_id do
                links[#links+1] = lmw_r:leo_link_data(ahm_id)
                ahm_id = lmw_r:_next_leo_link_trace()
            end
            item_data.leo_links = links
        end

        return item_data
    end

    function _M.class_recce.earley_set_data(lmw_r, set_id)
        -- print('earley_set_data(', set_id, ')')
        local lmw_g = lmw_r.lmw_g
        local data = {}

        local result = lmw_r:_earley_set_trace(set_id)
        if not result then return end

        local earleme = lmw_r:earleme(set_id)
        data.earleme = earleme

        local item_id = 0
        while true do
            local item_data = lmw_r:earley_item_data(set_id, item_id)
            if not item_data then break end
            data[#data+1] = item_data
            item_id = item_id + 1
        end
        data.leo = {}
        local postdot_symbol_id = lmw_r:_first_postdot_item_trace();
        while postdot_symbol_id do
            -- If there is no base Earley item,
            -- then this is not a Leo item, so we skip it
            local leo_item_data = lmw_r:leo_item_data()
            if leo_item_data then
                data.leo[#data.leo+1] = leo_item_data
            end
            postdot_symbol_id = lmw_r:_next_postdot_item_trace()
        end
        -- print('earley_set_data() ->', inspect(data))
        return data
    end

    function _M.class_slr.g1_earley_set_data(recce, set_id)
        local lmw_r = recce.lmw_g1r
        local result = lmw_r:earley_set_data(set_id)
        return result
    end

```

```
    -- miranda: section+ various Kollos lua defines
    _M.defines.TOKEN_VALUE_IS_UNDEF = 1
    _M.defines.TOKEN_VALUE_IS_LITERAL = 2

    _M.defines.MARPA_OP_LUA = 3
    _M.defines.MARPA_OP_NOOP = 4
    _M.op_names = {
        [_M.defines.MARPA_OP_LUA] = "lua",
        [_M.defines.MARPA_OP_NOOP] = "noop",
    }

    -- miranda: section+ temporary defines
    /* TODO: Delete after development */
    #define MARPA_OP_LUA 3
    #define MARPA_OP_NOOP 4

```

## The valuator Libmarpa wrapper

The "valuator" portion of Kollos produces the
value of a
Kollos parse.

### Initialize a valuator

Called when a valuator is set up.

```
    -- miranda: section+ valuator Libmarpa wrapper Lua functions

    function _M.class_slr.value_init(recce, trace_values)

        if not recce.lmw_v then
            error('no recce.lmw_v in value_init()')
        end

        recce.trace_values = trace_values;
        recce.trace_values_queue = {};
        if recce.trace_values > 0 then
          local top_of_queue = #recce.trace_values_queue;
          recce.trace_values_queue[top_of_queue+1] = {
            "valuator trace level", 0,
            recce.trace_values,
          }
        end

        recce.lmw_v.stack = {}
    end

```

### Reset a valuator

A function to be called whenever a valuator is reset.
It should free all memory associated with the valuation.

```

    -- miranda: section+ valuator Libmarpa wrapper Lua functions

    function _M.class_slr.valuation_reset(recce)
        -- io.stderr:write('Initializing rule semantics to nil\n')

        recce.trace_values = 0;
        recce.trace_values_queue = {};

        recce.lmw_b = nil
        recce.lmw_o = nil
        recce.lmw_t = nil
        recce.lmw_v = nil
        -- Libmarpa's tree pausing requires value objects to
        -- be destroyed quickly
        -- print("About to collect garbage")
        collectgarbage()
    end

```

## Diagnostics

```
    -- miranda: section+ diagnostics
    function _M.class_slr.and_node_tag(recce, and_node_id)
        local bocage = recce.lmw_b
        local parent_or_node_id = bocage:_and_node_parent(and_node_id)
        local origin = bocage:_or_node_origin(parent_or_node_id)
        local origin_earleme = recce.lmw_g1r:earleme(origin)

        local current_earley_set = bocage:_or_node_set(parent_or_node_id)
        local current_earleme = recce.lmw_g1r:earleme(current_earley_set)

        local cause_id = bocage:_and_node_cause(and_node_id)
        local predecessor_id = bocage:_and_node_predecessor(and_node_id)

        local middle_earley_set = bocage:_and_node_middle(and_node_id)
        local middle_earleme = recce.lmw_g1r:earleme(middle_earley_set)

        local position = bocage:_or_node_position(parent_or_node_id)
        local irl_id = bocage:_or_node_irl(parent_or_node_id)

        local tag = { string.format("R%d:%d@%d-%d",
            irl_id,
            position,
            origin_earleme,
            current_earleme)
        }

        if cause_id then
            tag[#tag+1] = string.format("C%d", bocage:_or_node_irl(cause_id))
        else
            tag[#tag+1] = string.format("S%d", bocage:_and_node_symbol(and_node_id))
        end
        tag[#tag+1] = string.format("@%d", middle_earleme)
        return table.concat(tag)
    end

    function _M.class_slr.show_and_nodes(recce)
        local bocage = recce.lmw_b
        local g1r = recce.lmw_g1r
        local data = {}
        local id = -1
        while true do
            id = id + 1
            local parent = bocage:_and_node_parent(id)
            -- print('parent:', parent)
            if not parent then break end
            local predecessor = bocage:_and_node_predecessor(id)
            local cause = bocage:_and_node_cause(id)
            local symbol = bocage:_and_node_symbol(id)
            local origin = bocage:_or_node_origin(parent)
            local set = bocage:_or_node_set(parent)
            local irl_id = bocage:_or_node_irl(parent)
            local position = bocage:_or_node_position(parent)
            local origin_earleme = g1r:earleme(origin)
            local current_earleme = g1r:earleme(set)
            local middle_earley_set = bocage:_and_node_middle(id)
            local middle_earleme = g1r:earleme(middle_earley_set)
            local desc = {string.format(
                "And-node #%d: R%d:%d@%d-%d",
                id,
                irl_id,
                position,
                origin_earleme,
                current_earleme)}
            -- Marpa::R2's show_and_nodes() had a minor bug:
            -- cause_irl_id was not set properly and therefore
            -- not used in the sort.  That problem is fixed
            -- here.
            local cause_irl_id = -1
            if cause then
                cause_irl_id = bocage:_or_node_irl(cause)
                desc[#desc+1] = 'C' .. cause_irl_id
            else
                desc[#desc+1] = 'S' .. symbol
            end
            desc[#desc+1] = '@' .. middle_earleme
            if not symbol then symbol = -1 end
            data[#data+1] = {
                origin_earleme,
                current_earleme,
                irl_id,
                position,
                middle_earleme,
                symbol,
                cause_irl_id,
                table.concat(desc)
            }
        end
        -- print('data:', inspect(data))

        local function cmp_data(i, j)
            for ix = 1, #i do
                if i[ix] < j[ix] then return true end
                if i[ix] > j[ix] then return false end
            end
            return false
        end

        table.sort(data, cmp_data)
        local result = {}
        for _,datum in pairs(data) do
            result[#result+1] = datum[#datum]
        end
        result[#result+1] = '' -- so concat adds a final '\n'
        return table.concat(result, '\n')
    end

    function _M.class_slr.or_node_tag(recce, or_node_id)
        local bocage = recce.lmw_b
        local set = bocage:_or_node_set(or_node_id)
        local irl_id = bocage:_or_node_irl(or_node_id)
        local origin = bocage:_or_node_origin(or_node_id)
        local position = bocage:_or_node_position(or_node_id)
        return string.format("R%d:%d@%d-%d",
            irl_id,
            position,
            origin,
            set)
    end

    function _M.class_slr.show_or_nodes(recce)
        local bocage = recce.lmw_b
        local g1r = recce.lmw_g1r
        local data = {}
        local id = -1
        while true do
            id = id + 1
            local origin = bocage:_or_node_origin(id)
            if not origin then break end
            local set = bocage:_or_node_set(id)
            local irl_id = bocage:_or_node_irl(id)
            local position = bocage:_or_node_position(id)
            local origin_earleme = g1r:earleme(origin)
            local current_earleme = g1r:earleme(set)

            local desc = {string.format(
                "R%d:%d@%d-%d",
                irl_id,
                position,
                origin_earleme,
                current_earleme)}
            data[#data+1] = {
                origin_earleme,
                current_earleme,
                irl_id,
                table.concat(desc)
            }
        end

        local function cmp_data(i, j)
            for ix = 1, #i do
                if i[ix] < j[ix] then return true end
                if i[ix] > j[ix] then return false end
            end
            return false
        end

        table.sort(data, cmp_data)
        local result = {}
        for _,datum in pairs(data) do
            result[#result+1] = datum[#datum]
        end
        result[#result+1] = '' -- so concat adds a final '\n'
        return table.concat(result, '\n')
    end

`show_bocage` returns a string which describes the bocage.

    -- miranda: section+ diagnostics
    function _M.class_slr.show_bocage(recce)
        local bocage = recce.lmw_b
        local data = {}
        local or_node_id = -1
        while true do
            or_node_id = or_node_id + 1
            local irl_id = bocage:_or_node_irl(or_node_id)
            if not irl_id then goto LAST_OR_NODE end
            local position = bocage:_or_node_position(or_node_id)
            local or_origin = bocage:_or_node_origin(or_node_id)
            local origin_earleme = recce.lmw_g1r:earleme(or_origin)
            local or_set = bocage:_or_node_set(or_node_id)
            local current_earleme = recce.lmw_g1r:earleme(or_set)
            local and_node_ids = {}
            local first_and_id = bocage:_or_node_first_and(or_node_id)
            local last_and_id = bocage:_or_node_last_and(or_node_id)
            for and_node_id = first_and_id, last_and_id do
                local symbol = bocage:_and_node_symbol(and_node_id)
                local cause_tag
                if symbol then cause_tag = 'S' .. symbol end
                local cause_id = bocage:_and_node_cause(and_node_id)
                local cause_irl_id
                if cause_id then
                    cause_irl_id = bocage:_or_node_irl(cause_id)
                    cause_tag = recce:or_node_tag(cause_id)
                end
                local parent_tag = recce:or_node_tag(or_node_id)
                local predecessor_id = bocage:_and_node_predecessor(and_node_id)
                local predecessor_tag = "-"
                if predecessor_id then
                    predecessor_tag = recce:or_node_tag(predecessor_id)
                end
                local tag = string.format(
                    "%d: %d=%s %s %s",
                    and_node_id,
                    or_node_id,
                    parent_tag,
                    predecessor_tag,
                    cause_tag
                )
                data[#data+1] = { and_node_id, tag }
            end
            ::LAST_AND_NODE::
        end
        ::LAST_OR_NODE::

        local function cmp_data(i, j)
            if i[1] < j[1] then return true end
            return false
        end

        table.sort(data, cmp_data)
        local result = {}
        for _,datum in pairs(data) do
            result[#result+1] = datum[#datum]
        end
        result[#result+1] = '' -- so concat adds a final '\n'
        return table.concat(result, '\n')

    end

```

## Libmarpa interface

```
    --[==[ miranda: exec libmarpa interface globals

    function c_type_of_libmarpa_type(libmarpa_type)
        if (libmarpa_type == 'int') then return 'int' end
        if (libmarpa_type == 'Marpa_And_Node_ID') then return 'int' end
        if (libmarpa_type == 'Marpa_Assertion_ID') then return 'int' end
        if (libmarpa_type == 'Marpa_AHM_ID') then return 'int' end
        if (libmarpa_type == 'Marpa_Earley_Item_ID') then return 'int' end
        if (libmarpa_type == 'Marpa_Earley_Set_ID') then return 'int' end
        if (libmarpa_type == 'Marpa_IRL_ID') then return 'int' end
        if (libmarpa_type == 'Marpa_Nook_ID') then return 'int' end
        if (libmarpa_type == 'Marpa_NSY_ID') then return 'int' end
        if (libmarpa_type == 'Marpa_Or_Node_ID') then return 'int' end
        if (libmarpa_type == 'Marpa_Rank') then return 'int' end
        if (libmarpa_type == 'Marpa_Rule_ID') then return 'int' end
        if (libmarpa_type == 'Marpa_Symbol_ID') then return 'int' end
        return "!UNIMPLEMENTED!";
    end

    libmarpa_class_type = {
      g = "Marpa_Grammar",
      r = "Marpa_Recognizer",
      b = "Marpa_Bocage",
      o = "Marpa_Order",
      t = "Marpa_Tree",
      v = "Marpa_Value",
    };

    libmarpa_class_name = {
      g = "grammar",
      r = "recce",
      b = "bocage",
      o = "order",
      t = "tree",
      v = "value",
    };

    libmarpa_class_sequence = { 'g', 'r', 'b', 'o', 't', 'v'}

    function wrap_libmarpa_method(signature)
       local arg_count = math.floor(#signature/2)
       local function_name = signature[1]
       local unprefixed_name = string.gsub(function_name, "^[_]?marpa_", "");
       local class_letter = string.gsub(unprefixed_name, "_.*$", "");
       local wrapper_name = "wrap_" .. unprefixed_name;
       local result = {}
       result[#result+1] = "static int " .. wrapper_name .. "(lua_State *L)\n"
       result[#result+1] = "{\n"
       result[#result+1] = "  " .. libmarpa_class_type[class_letter] .. " self;\n"
       result[#result+1] = "  const int self_stack_ix = 1;\n"
       for arg_ix = 1, arg_count do
         local arg_type = signature[arg_ix*2]
         local arg_name = signature[1 + arg_ix*2]
         result[#result+1] = "  " .. arg_type .. " " .. arg_name .. ";\n"
       end
       result[#result+1] = "  int result;\n\n"

       -- These wrappers will not be external interfaces
       -- so eventually they will run unsafe.
       -- But for now we check arguments, and we'll leave
       -- the possibility for debugging
       local safe = true;
       if (safe) then
          result[#result+1] = "  if (1) {\n"

          result[#result+1] = "    marpa_luaL_checktype(L, self_stack_ix, LUA_TTABLE);"
          -- I do not get the values from the integer checks,
          -- because this code
          -- will be turned off most of the time
          for arg_ix = 1, arg_count do
              result[#result+1] = "    marpa_luaL_checkinteger(L, " .. (arg_ix+1) .. ");\n"
          end
          result[#result+1] = "  }\n"
       end -- if (!unsafe)

       for arg_ix = arg_count, 1, -1 do
         local arg_type = signature[arg_ix*2]
         local arg_name = signature[1 + arg_ix*2]
         local c_type = c_type_of_libmarpa_type(arg_type)
         assert(c_type == "int", ("type " .. arg_type .. " not implemented"))
         result[#result+1] = "{\n"
         result[#result+1] = "  const lua_Integer this_arg = marpa_lua_tointeger(L, -1);\n"

         -- Each call checks that its arguments are in range
         -- the point of this check is to make sure that C's integer conversions
         -- do not change the value before the call gets it.
         -- We assume that all types involved are at least 32 bits and signed, so that
         -- values from -2^30 to 2^30 will be unchanged by any conversions.
         result[#result+1] = [[  marpa_luaL_argcheck(L, (-(1<<30) <= this_arg && this_arg <= (1<<30)), -1, "argument out of range");]], "\n"

         result[#result+1] = string.format("  %s = (%s)this_arg;\n", arg_name, arg_type)
         result[#result+1] = "  marpa_lua_pop(L, 1);\n"
         result[#result+1] = "}\n"
       end

       result[#result+1] = '  marpa_lua_getfield (L, -1, "_libmarpa");\n'
       -- stack is [ self, self_ud ]
       local cast_to_ptr_to_class_type = "(" ..  libmarpa_class_type[class_letter] .. "*)"
       result[#result+1] = "  self = *" .. cast_to_ptr_to_class_type .. "marpa_lua_touserdata (L, -1);\n"
       result[#result+1] = "  marpa_lua_pop(L, 1);\n"
       -- stack is [ self ]

       -- assumes converting result to int is safe and right thing to do
       -- if that assumption is wrong, generate the wrapper by hand
       result[#result+1] = "  result = (int)" .. function_name .. "(self\n"
       for arg_ix = 1, arg_count do
         local arg_name = signature[1 + arg_ix*2]
         result[#result+1] = "     ," .. arg_name .. "\n"
       end
       result[#result+1] = "    );\n"
       result[#result+1] = "  if (result == -1) { marpa_lua_pushnil(L); return 1; }\n"
       result[#result+1] = "  if (result < -1) {\n"
       result[#result+1] = string.format(
                            "   return libmarpa_error_handle(L, self_stack_ix, %q);\n",
                            wrapper_name .. '()')
       result[#result+1] = "  }\n"
       result[#result+1] = "  marpa_lua_pushinteger(L, (lua_Integer)result);\n"
       result[#result+1] = "  return 1;\n"
       result[#result+1] = "}\n\n"

       return table.concat(result, '')

    end

    -- end of exec
    ]==]
```

### Standard template methods

Here are the meta-programmed wrappers --
This is Lua code which writes the C code based on
a "signature" for the wrapper

This meta-programming does not attempt to work for
all of the wrappers.  It works only when
1. The number of arguments is fixed.
2. Their type is from a fixed list.
3. Converting the return value to int is a good thing to do.
4. Non-negative return values indicate success
5. Return values less than -1 indicate failure
6. Return values less than -1 set the error code
7. Return value of -1 is "soft" and returning nil is
      the right thing to do

On those methods for which the wrapper requirements are "bent"
a little bit:

* marpa_r_alternative() -- generates events
Returns an error code.  Since these are always non-negative, from
the wrapper's point of view, marpa_r_alternative() always succeeds.

* marpa_r_earleme_complete() -- generates events

```

  -- miranda: section standard libmarpa wrappers
  --[==[ miranda: exec declare standard libmarpa wrappers
  signatures = {
    {"marpa_g_completion_symbol_activate", "Marpa_Symbol_ID", "sym_id", "int", "activate"},
    {"marpa_g_default_rank"},
    {"marpa_g_default_rank_set", "Marpa_Rank", "rank" },
    {"marpa_g_error_clear"},
    {"marpa_g_event_count"},
    {"marpa_g_force_valued"},
    {"marpa_g_has_cycle"},
    {"marpa_g_highest_rule_id"},
    {"marpa_g_highest_symbol_id"},
    {"marpa_g_is_precomputed"},
    {"marpa_g_nulled_symbol_activate", "Marpa_Symbol_ID", "sym_id", "int", "activate"},
    {"marpa_g_prediction_symbol_activate", "Marpa_Symbol_ID", "sym_id", "int", "activate"},
    {"marpa_g_rule_is_accessible", "Marpa_Rule_ID", "rule_id"},
    {"marpa_g_rule_is_loop", "Marpa_Rule_ID", "rule_id"},
    {"marpa_g_rule_is_nullable", "Marpa_Rule_ID", "rule_id"},
    {"marpa_g_rule_is_nulling", "Marpa_Rule_ID", "rule_id"},
    {"marpa_g_rule_is_productive", "Marpa_Rule_ID", "rule_id"},
    {"marpa_g_rule_is_proper_separation", "Marpa_Rule_ID", "rule_id"},
    {"marpa_g_rule_length", "Marpa_Rule_ID", "rule_id"},
    {"marpa_g_rule_lhs", "Marpa_Rule_ID", "rule_id"},
    {"marpa_g_rule_null_high", "Marpa_Rule_ID", "rule_id"},
    {"marpa_g_rule_null_high_set", "Marpa_Rule_ID", "rule_id", "int", "flag"},
    {"marpa_g_rule_rank", "Marpa_Rule_ID", "rule_id" },
    {"marpa_g_rule_rank_set", "Marpa_Rule_ID", "rule_id", "Marpa_Rank", "rank" },
    {"marpa_g_rule_rhs", "Marpa_Rule_ID", "rule_id", "int", "ix"},
    {"marpa_g_sequence_min", "Marpa_Rule_ID", "rule_id"},
    {"marpa_g_sequence_separator", "Marpa_Rule_ID", "rule_id"},
    {"marpa_g_start_symbol"},
    {"marpa_g_start_symbol_set", "Marpa_Symbol_ID", "id"},
    {"marpa_g_symbol_is_accessible", "Marpa_Symbol_ID", "symbol_id"},
    {"marpa_g_symbol_is_completion_event", "Marpa_Symbol_ID", "sym_id"},
    {"marpa_g_symbol_is_completion_event_set", "Marpa_Symbol_ID", "sym_id", "int", "value"},
    {"marpa_g_symbol_is_counted", "Marpa_Symbol_ID", "symbol_id"},
    {"marpa_g_symbol_is_nullable", "Marpa_Symbol_ID", "symbol_id"},
    {"marpa_g_symbol_is_nulled_event", "Marpa_Symbol_ID", "sym_id"},
    {"marpa_g_symbol_is_nulled_event_set", "Marpa_Symbol_ID", "sym_id", "int", "value"},
    {"marpa_g_symbol_is_nulling", "Marpa_Symbol_ID", "symbol_id"},
    {"marpa_g_symbol_is_prediction_event", "Marpa_Symbol_ID", "sym_id"},
    {"marpa_g_symbol_is_prediction_event_set", "Marpa_Symbol_ID", "sym_id", "int", "value"},
    {"marpa_g_symbol_is_productive", "Marpa_Symbol_ID", "symbol_id"},
    {"marpa_g_symbol_is_start", "Marpa_Symbol_ID", "symbol_id"},
    {"marpa_g_symbol_is_terminal", "Marpa_Symbol_ID", "symbol_id"},
    {"marpa_g_symbol_is_terminal_set", "Marpa_Symbol_ID", "symbol_id", "int", "boolean"},
    {"marpa_g_symbol_is_valued", "Marpa_Symbol_ID", "symbol_id"},
    {"marpa_g_symbol_is_valued_set", "Marpa_Symbol_ID", "symbol_id", "int", "boolean"},
    {"marpa_g_symbol_new"},
    {"marpa_g_symbol_rank", "Marpa_Symbol_ID", "symbol_id" },
    {"marpa_g_symbol_rank_set", "Marpa_Symbol_ID", "symbol_id", "Marpa_Rank", "rank" },
    {"marpa_g_zwa_new", "int", "default_value"},
    {"marpa_g_zwa_place", "Marpa_Assertion_ID", "zwaid", "Marpa_Rule_ID", "xrl_id", "int", "rhs_ix"},
    {"marpa_r_completion_symbol_activate", "Marpa_Symbol_ID", "sym_id", "int", "reactivate"},
    {"marpa_r_alternative", "Marpa_Symbol_ID", "token", "int", "value", "int", "length"}, -- See above,
    {"marpa_r_current_earleme"},
    {"marpa_r_earleme_complete"}, -- See note above,
    {"marpa_r_earleme", "Marpa_Earley_Set_ID", "ordinal"},
    {"marpa_r_earley_item_warning_threshold"},
    {"marpa_r_earley_item_warning_threshold_set", "int", "too_many_earley_items"},
    {"marpa_r_earley_set_value", "Marpa_Earley_Set_ID", "ordinal"},
    {"marpa_r_expected_symbol_event_set", "Marpa_Symbol_ID", "xsyid", "int", "value"},
    {"marpa_r_furthest_earleme"},
    {"marpa_r_is_exhausted"},
    {"marpa_r_latest_earley_set"},
    {"marpa_r_latest_earley_set_value_set", "int", "value"},
    {"marpa_r_nulled_symbol_activate", "Marpa_Symbol_ID", "sym_id", "int", "reactivate"},
    {"marpa_r_prediction_symbol_activate", "Marpa_Symbol_ID", "sym_id", "int", "reactivate"},
    {"marpa_r_progress_report_finish"},
    {"marpa_r_progress_report_start", "Marpa_Earley_Set_ID", "ordinal"},
    {"marpa_r_start_input"},
    {"marpa_r_terminal_is_expected", "Marpa_Symbol_ID", "xsyid"},
    {"marpa_r_zwa_default", "Marpa_Assertion_ID", "zwaid"},
    {"marpa_r_zwa_default_set", "Marpa_Assertion_ID", "zwaid", "int", "default_value"},
    {"marpa_b_ambiguity_metric"},
    {"marpa_b_is_null"},
    {"marpa_o_ambiguity_metric"},
    {"marpa_o_high_rank_only_set", "int", "flag"},
    {"marpa_o_high_rank_only"},
    {"marpa_o_is_null"},
    {"marpa_o_rank"},
    {"marpa_t_next"},
    {"marpa_t_parse_count"},
    {"_marpa_t_size" },
    {"_marpa_t_nook_or_node", "Marpa_Nook_ID", "nook_id" },
    {"_marpa_t_nook_choice", "Marpa_Nook_ID", "nook_id" },
    {"_marpa_t_nook_parent", "Marpa_Nook_ID", "nook_id" },
    {"_marpa_t_nook_is_cause", "Marpa_Nook_ID", "nook_id" },
    {"_marpa_t_nook_cause_is_ready", "Marpa_Nook_ID", "nook_id" },
    {"_marpa_t_nook_is_predecessor", "Marpa_Nook_ID", "nook_id" },
    {"_marpa_t_nook_predecessor_is_ready", "Marpa_Nook_ID", "nook_id" },
    {"marpa_v_valued_force"},
    {"marpa_v_rule_is_valued_set", "Marpa_Rule_ID", "symbol_id", "int", "value"},
    {"marpa_v_symbol_is_valued_set", "Marpa_Symbol_ID", "symbol_id", "int", "value"},
    {"_marpa_v_nook"},
    {"_marpa_v_trace", "int", "flag"},
    {"_marpa_g_ahm_count"},
    {"_marpa_g_ahm_irl", "Marpa_AHM_ID", "item_id"},
    {"_marpa_g_ahm_postdot", "Marpa_AHM_ID", "item_id"},
    {"_marpa_g_irl_count"},
    {"_marpa_g_irl_is_virtual_lhs", "Marpa_IRL_ID", "irl_id"},
    {"_marpa_g_irl_is_virtual_rhs", "Marpa_IRL_ID", "irl_id"},
    {"_marpa_g_irl_length", "Marpa_IRL_ID", "irl_id"},
    {"_marpa_g_irl_lhs", "Marpa_IRL_ID", "irl_id"},
    {"_marpa_g_irl_rank", "Marpa_IRL_ID", "irl_id"},
    {"_marpa_g_irl_rhs", "Marpa_IRL_ID", "irl_id", "int", "ix"},
    {"_marpa_g_irl_semantic_equivalent", "Marpa_IRL_ID", "irl_id"},
    {"_marpa_g_nsy_count"},
    {"_marpa_g_nsy_is_lhs", "Marpa_NSY_ID", "nsy_id"},
    {"_marpa_g_nsy_is_nulling", "Marpa_NSY_ID", "nsy_id"},
    {"_marpa_g_nsy_is_semantic", "Marpa_NSY_ID", "nsy_id"},
    {"_marpa_g_nsy_is_start", "Marpa_NSY_ID", "nsy_id"},
    {"_marpa_g_nsy_lhs_xrl", "Marpa_NSY_ID", "nsy_id"},
    {"_marpa_g_nsy_rank", "Marpa_NSY_ID", "nsy_id"},
    {"_marpa_g_nsy_xrl_offset", "Marpa_NSY_ID", "nsy_id"},
    {"_marpa_g_real_symbol_count", "Marpa_IRL_ID", "irl_id"},
    {"_marpa_g_rule_is_keep_separation", "Marpa_Rule_ID", "rule_id"},
    {"_marpa_g_rule_is_used", "Marpa_Rule_ID", "rule_id"},
    {"_marpa_g_source_xrl", "Marpa_IRL_ID", "irl_id"},
    {"_marpa_g_source_xsy", "Marpa_NSY_ID", "nsy_id"},
    {"_marpa_g_virtual_end", "Marpa_IRL_ID", "irl_id"},
    {"_marpa_g_virtual_start", "Marpa_IRL_ID", "irl_id"},
    {"_marpa_g_xsy_nsy", "Marpa_Symbol_ID", "symid"},
    {"_marpa_g_xsy_nulling_nsy", "Marpa_Symbol_ID", "symid"},
    {"_marpa_r_earley_item_origin"},
    {"_marpa_r_earley_item_trace", "Marpa_Earley_Item_ID", "item_id"},
    {"_marpa_r_earley_set_size", "Marpa_Earley_Set_ID", "set_id"},
    {"_marpa_r_earley_set_trace", "Marpa_Earley_Set_ID", "set_id"},
    {"_marpa_r_first_completion_link_trace"},
    {"_marpa_r_first_leo_link_trace"},
    {"_marpa_r_first_postdot_item_trace"},
    {"_marpa_r_first_token_link_trace"},
    {"_marpa_r_is_use_leo"},
    {"_marpa_r_is_use_leo_set", "int", "value"},
    {"_marpa_r_leo_base_origin"},
    {"_marpa_r_leo_base_state"},
    {"_marpa_r_leo_predecessor_symbol"},
    {"_marpa_r_next_completion_link_trace"},
    {"_marpa_r_next_leo_link_trace"},
    {"_marpa_r_next_postdot_item_trace"},
    {"_marpa_r_next_token_link_trace"},
    {"_marpa_r_postdot_item_symbol"},
    {"_marpa_r_postdot_symbol_trace", "Marpa_Symbol_ID", "symid"},
    {"_marpa_r_source_leo_transition_symbol"},
    {"_marpa_r_source_middle"},
    {"_marpa_r_source_predecessor_state"},
    {"_marpa_r_trace_earley_set"},
    {"_marpa_b_and_node_cause", "Marpa_And_Node_ID", "ordinal"},
    {"_marpa_b_and_node_count"},
    {"_marpa_b_and_node_middle", "Marpa_And_Node_ID", "and_node_id"},
    {"_marpa_b_and_node_parent", "Marpa_And_Node_ID", "and_node_id"},
    {"_marpa_b_and_node_predecessor", "Marpa_And_Node_ID", "ordinal"},
    {"_marpa_b_and_node_symbol", "Marpa_And_Node_ID", "and_node_id"},
    {"_marpa_b_or_node_and_count", "Marpa_Or_Node_ID", "or_node_id"},
    {"_marpa_b_or_node_first_and", "Marpa_Or_Node_ID", "ordinal"},
    {"_marpa_b_or_node_irl", "Marpa_Or_Node_ID", "ordinal"},
    {"_marpa_b_or_node_is_semantic", "Marpa_Or_Node_ID", "or_node_id"},
    {"_marpa_b_or_node_is_whole", "Marpa_Or_Node_ID", "or_node_id"},
    {"_marpa_b_or_node_last_and", "Marpa_Or_Node_ID", "ordinal"},
    {"_marpa_b_or_node_origin", "Marpa_Or_Node_ID", "ordinal"},
    {"_marpa_b_or_node_position", "Marpa_Or_Node_ID", "ordinal"},
    {"_marpa_b_or_node_set", "Marpa_Or_Node_ID", "ordinal"},
    {"_marpa_b_top_or_node"},
    {"_marpa_o_and_order_get", "Marpa_Or_Node_ID", "or_node_id", "int", "ix"},
    {"_marpa_o_or_node_and_node_count", "Marpa_Or_Node_ID", "or_node_id"},
    {"_marpa_o_or_node_and_node_id_by_ix", "Marpa_Or_Node_ID", "or_node_id", "int", "ix"},
  }
  local result = {}
  for ix = 1,#signatures do
      result[#result+1] = wrap_libmarpa_method(signatures[ix])
  end
  return table.concat(result)
  -- end of exec
  ]==]

  -- miranda: section register standard libmarpa wrappers
  --[==[ miranda: exec register standard libmarpa wrappers
        local result = {}
        for ix = 1, #signatures do
           local signature = signatures[ix]
           local function_name = signature[1]
           local unprefixed_name = function_name:gsub("^[_]?marpa_", "", 1)
           local class_letter = unprefixed_name:gsub("_.*$", "", 1)
           local class_name = libmarpa_class_name[class_letter]
           local class_table_name = 'class_' .. class_name

           result[#result+1] = string.format("  marpa_lua_getfield(L, kollos_table_stack_ix, %q);\n", class_table_name)
           -- for example: marpa_lua_getfield(L, kollos_table_stack_ix, "class_grammar")

           result[#result+1] = "marpa_lua_pushvalue(L, upvalue_stack_ix);\n";

           local wrapper_name = "wrap_" .. unprefixed_name;
           result[#result+1] = string.format("  marpa_lua_pushcclosure(L, %s, 1);\n", wrapper_name)
           -- for example: marpa_lua_pushcclosure(L, wrap_g_highest_rule_id, 1)

           local classless_name = function_name:gsub("^[_]?marpa_[^_]*_", "")
           local initial_underscore = function_name:match('^_') and '_' or ''
           local field_name = initial_underscore .. classless_name
           result[#result+1] = string.format("  marpa_lua_setfield(L, -2, %q);\n", field_name)
           -- for example: marpa_lua_setfield(L, -2, "highest_rule_id")

           result[#result+1] = string.format("  marpa_lua_pop(L, 1);\n", field_name)

        end
        return table.concat(result)
  ]==]

```

```

  -- miranda: section create kollos libmarpa wrapper class tables
  --[==[ miranda: exec create kollos libmarpa wrapper class tables
        local result = {}
        for class_letter, class in pairs(libmarpa_class_name) do
           local class_table_name = 'class_' .. class
           local functions_to_register = class .. '_methods'
           -- class_xyz = {}
           result[#result+1] = string.format("  marpa_luaL_newlibtable(L, %s);\n", functions_to_register)
           -- add functions and upvalue to class_xyz
           result[#result+1] = "  marpa_lua_pushvalue(L, upvalue_stack_ix);\n"
           result[#result+1] = string.format("  marpa_luaL_setfuncs(L, %s, 1);\n", functions_to_register)
           -- class_xyz.__index = class_xyz
           result[#result+1] = "  marpa_lua_pushvalue(L, -1);\n"
           result[#result+1] = '  marpa_lua_setfield(L, -2, "__index");\n'
           -- kollos[class_xyz] = class_xyz
           result[#result+1] = "  marpa_lua_pushvalue(L, -1);\n"
           result[#result+1] = string.format("  marpa_lua_setfield(L, kollos_table_stack_ix, %q);\n", class_table_name);
           -- class_xyz[kollos] = kollos
           result[#result+1] = "  marpa_lua_pushvalue(L, kollos_table_stack_ix);\n"
           result[#result+1] = '  marpa_lua_setfield(L, -2, "kollos");\n'
        end
        return table.concat(result)
  ]==]

```

### Constructors

The standard constructors are generated indirectly, from a template.
This saves a lot of repetition, which makes for easier reading in the
long run.
In the short run, however, you may want first to look at the bocage
constructor.
It is specified directly, which can be easier for a first reading.


  -- miranda: section object constructors
  --[==[ miranda: exec object constructors
        local result = {}
        local template = [[
        |static int
        |wrap_!NAME!_new (lua_State * L)
        |{
        |  const int !BASE_NAME!_stack_ix = 1;
        |  int !NAME!_stack_ix;
        |
        |  if (0)
        |    printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
        |  if (1)
        |    {
        |      marpa_luaL_checktype(L, !BASE_NAME!_stack_ix, LUA_TTABLE);
        |    }
        |
        |  marpa_lua_newtable(L);
        |  /* [ base_table, class_table ] */
        |  !NAME!_stack_ix = marpa_lua_gettop(L);
        |  marpa_lua_pushvalue(L, marpa_lua_upvalueindex(2));
        |  marpa_lua_setmetatable (L, !NAME!_stack_ix);
        |  /* [ base_table, class_table ] */
        |
        |  {
        |    !BASE_TYPE! *!BASE_NAME!_ud;
        |
        |    !TYPE! *!NAME!_ud =
        |      (!TYPE! *) marpa_lua_newuserdata (L, sizeof (!TYPE!));
        |    /* [ base_table, class_table, class_ud ] */
        |    marpa_lua_rawgetp (L, LUA_REGISTRYINDEX, &kollos_!LETTER!_ud_mt_key);
        |    /* [ class_table, class_ud, class_ud_mt ] */
        |    marpa_lua_setmetatable (L, -2);
        |    /* [ class_table, class_ud ] */
        |
        |    marpa_lua_setfield (L, !NAME!_stack_ix, "_libmarpa");
        |    marpa_lua_getfield (L, !BASE_NAME!_stack_ix, "lmw_g");
        |    marpa_lua_setfield (L, !NAME!_stack_ix, "lmw_g");
        |    marpa_lua_getfield (L, !BASE_NAME!_stack_ix, "_libmarpa");
        |    !BASE_NAME!_ud = (!BASE_TYPE! *) marpa_lua_touserdata (L, -1);
        |
        |    *!NAME!_ud = marpa_!LETTER!_new (*!BASE_NAME!_ud);
        |    if (!*!NAME!_ud)
        |      {
        |        return libmarpa_error_handle (L, !NAME!_stack_ix, "marpa_!LETTER!_new()");
        |      }
        |  }
        |
        |  if (0)
        |    printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
        |  marpa_lua_settop(L, !NAME!_stack_ix );
        |  /* [ base_table, class_table ] */
        |  return 1;
        |}
        ]]
        -- for every class with a base,
        -- so that grammar constructor is special case
        for class_ix = 2, #libmarpa_class_sequence do
            local class_letter = libmarpa_class_sequence[class_ix]
            -- bocage constructor is special case
            if class_letter == 'b' then goto NEXT_CLASS end
            local class_name = libmarpa_class_name[class_letter]
            local class_type = libmarpa_class_type[class_letter]
            local base_class_letter = libmarpa_class_sequence[class_ix-1]
            local base_class_name = libmarpa_class_name[base_class_letter]
            local base_class_type = libmarpa_class_type[base_class_letter]
            local this_piece =
                pipe_dedent(template)
                   :gsub("!BASE_NAME!", base_class_name)
                   :gsub("!BASE_TYPE!", base_class_type)
                   :gsub("!BASE_LETTER!", base_class_letter)
                   :gsub("!NAME!", class_name)
                   :gsub("!TYPE!", class_type)
                   :gsub("!LETTER!", class_letter)
            result[#result+1] = this_piece
            ::NEXT_CLASS::
        end
        return table.concat(result, "\n")
  ]==]

The bocage constructor takes an extra argument, so it's a special
case.
It's close to the standard constructor.
The standard constructors are generated indirectly, from a template.
The template saves repetition, but is harder on a first reading.
This bocage constructor is specified directly,
so you may find it easer to read it first.

    -- miranda: section+ object constructors
    static int
    wrap_bocage_new (lua_State * L)
    {
      const int recce_stack_ix = 1;
      const int ordinal_stack_ix = 2;
      int bocage_stack_ix;

      if (0)
        printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
      if (1)
        {
          marpa_luaL_checktype(L, recce_stack_ix, LUA_TTABLE);
        }

      marpa_lua_newtable(L);
      bocage_stack_ix = marpa_lua_gettop(L);
      /* push "class_bocage" metatable */
      marpa_lua_pushvalue(L, marpa_lua_upvalueindex(2));
      marpa_lua_setmetatable (L, bocage_stack_ix);

      {
        Marpa_Recognizer *recce_ud;

        Marpa_Bocage *bocage_ud =
          (Marpa_Bocage *) marpa_lua_newuserdata (L, sizeof (Marpa_Bocage));
        /* [ base_table, class_table, class_ud ] */
        marpa_lua_rawgetp (L, LUA_REGISTRYINDEX, &kollos_b_ud_mt_key);
        /* [ class_table, class_ud, class_ud_mt ] */
        marpa_lua_setmetatable (L, -2);
        /* [ class_table, class_ud ] */

        marpa_lua_setfield (L, bocage_stack_ix, "_libmarpa");
        marpa_lua_getfield (L, recce_stack_ix, "lmw_g");
        marpa_lua_setfield (L, bocage_stack_ix, "lmw_g");
        marpa_lua_getfield (L, recce_stack_ix, "_libmarpa");
        recce_ud = (Marpa_Recognizer *) marpa_lua_touserdata (L, -1);

        {
          int is_ok = 0;
          lua_Integer ordinal = -1;
          if (marpa_lua_isnil(L, ordinal_stack_ix)) {
             is_ok = 1;
          } else {
             ordinal = marpa_lua_tointegerx(L, ordinal_stack_ix, &is_ok);
          }
          if (!is_ok) {
              marpa_luaL_error(L,
                  "problem with bocage_new() arg #2, type was %s",
                  marpa_luaL_typename(L, ordinal_stack_ix)
              );
          }
          *bocage_ud = marpa_b_new (*recce_ud, (int)ordinal);
        }

        if (!*bocage_ud)
          {
            return libmarpa_error_handle (L, bocage_stack_ix, "marpa_b_new()");
          }
      }

      if (0)
        printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
      marpa_lua_settop(L, bocage_stack_ix );
      /* [ base_table, class_table ] */
      return 1;
    }

```

The grammar constructor is a special case, because its argument is
a special "configuration" argument.

    -- miranda: section+ object constructors
    static int
    lca_grammar_new (lua_State * L)
    {
        int grammar_stack_ix;

        if (0)
            printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);

        marpa_lua_newtable (L);
        /* [ grammar_table ] */
        grammar_stack_ix = marpa_lua_gettop (L);
        /* push "class_grammar" metatable */
        marpa_lua_pushvalue(L, marpa_lua_upvalueindex(2));
        marpa_lua_setmetatable (L, grammar_stack_ix);
        /* [ grammar_table ] */

        {
            Marpa_Config marpa_configuration;
            Marpa_Grammar *grammar_ud =
                (Marpa_Grammar *) marpa_lua_newuserdata (L,
                sizeof (Marpa_Grammar));
            /* [ grammar_table, class_ud ] */
            marpa_lua_rawgetp (L, LUA_REGISTRYINDEX, &kollos_g_ud_mt_key);
            /* [ grammar_table, class_ud ] */
            marpa_lua_setmetatable (L, -2);
            /* [ grammar_table, class_ud ] */

            marpa_lua_setfield (L, grammar_stack_ix, "_libmarpa");

            marpa_c_init (&marpa_configuration);
            *grammar_ud = marpa_g_new (&marpa_configuration);
            if (!*grammar_ud) {
                return libmarpa_error_handle (L, grammar_stack_ix, "marpa_g_new()");
            }
        }

        /* Set my "lmw_g" field to myself */
        marpa_lua_pushvalue (L, grammar_stack_ix);
        marpa_lua_setfield (L, grammar_stack_ix, "lmw_g");

        marpa_lua_settop (L, grammar_stack_ix);
        /* [ grammar_table ] */
        return 1;
    }

```

## The main Lua code file

```
  -- miranda: section create metal tables
  --[==[ miranda: exec create metal tables
        local result = { "  _M.metal = {}" }
        for _, class in pairs(libmarpa_class_name) do
           local metal_table_name = 'metal_' .. class
           result[#result+1] = string.format("  _M[%q] = {}", metal_table_name);
        end
       result[#result+1] = ""
       return table.concat(result, "\n")
  ]==]

```

```
    -- miranda: section main
    -- miranda: insert legal preliminaries
    -- miranda: insert luacheck declarations

    require "strict"

    local _M = require "kollos.metal"

    -- miranda: insert create metal tables
    -- miranda: insert copy metal tables
    -- miranda: insert populate metatables

    -- set up various tables
    _M.upvalues.kollos = _M
    _M.defines = {}

    -- miranda: insert create sandbox table

    -- miranda: insert VM utilities
    -- miranda: insert VM operations
    -- miranda: insert VM default operations
    -- miranda: insert grammar Libmarpa wrapper Lua functions
    -- miranda: insert recognizer Libmarpa wrapper Lua functions
    -- miranda: insert valuator Libmarpa wrapper Lua functions
    -- miranda: insert diagnostics
    -- miranda: insert Utilities for semantics
    -- miranda: insert most Lua function definitions
    -- miranda: insert define Lua error codes
    -- miranda: insert define Lua event codes
    -- miranda: insert define Lua step codes
    -- miranda: insert various Kollos Lua defines

    return _M

    -- vim: set expandtab shiftwidth=4:
```

### Preliminaries to the main code

Licensing, etc.

```

    -- miranda: section legal preliminaries

    -- Copyright 2017 Jeffrey Kegler
    -- Permission is hereby granted, free of charge, to any person obtaining a
    -- copy of this software and associated documentation files (the "Software"),
    -- to deal in the Software without restriction, including without limitation
    -- the rights to use, copy, modify, merge, publish, distribute, sublicense,
    -- and/or sell copies of the Software, and to permit persons to whom the
    -- Software is furnished to do so, subject to the following conditions:
    --
    -- The above copyright notice and this permission notice shall be included
    -- in all copies or substantial portions of the Software.
    --
    -- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    -- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    -- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
    -- THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
    -- OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
    -- ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
    -- OTHER DEALINGS IN THE SOFTWARE.
    --
    -- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
```

Luacheck declarations

```

    -- miranda: section luacheck declarations

    -- luacheck: std lua53
    -- luacheck: globals bit
    -- luacheck: globals __FILE__ __LINE__

```

## The Kollos C code file

```
    -- miranda: section kollos_c
    -- miranda: language c
    -- miranda: insert preliminaries to the c library code

    -- miranda: insert C global constant variables

    -- miranda: insert private error code declarations
    -- miranda: insert define error codes
    -- miranda: insert private event code declarations
    -- miranda: insert define event codes
    -- miranda: insert private step code declarations
    -- miranda: insert define step codes

    -- miranda: insert error object code from okollos.c.lua
    -- miranda: insert base error handlers

    -- miranda: insert utilities from okollos.c.lua
    -- miranda: insert utility function definitions

    -- miranda: insert event related code from okollos.c.lua
    -- miranda: insert step structure code
    -- miranda: insert metatable keys
    -- miranda: insert non-standard wrappers
    -- miranda: insert object userdata gc methods
    -- miranda: insert luaL_reg definitions
    -- miranda: insert object constructors

    -- miranda: insert standard libmarpa wrappers
    -- miranda: insert define kollos_metal_loader method
    -- miranda: insert lua interpreter management

    -- miranda: insert  external C function definitions
    /* vim: set expandtab shiftwidth=4: */
```

### Stuff from okollos

```

    -- miranda: section utilities from okollos.c.lua

    /* For debugging */
    static void dump_stack (lua_State *L) UNUSED;
    static void dump_stack (lua_State *L) {
          int i;
          int top = marpa_lua_gettop(L);
          for (i = 1; i <= top; i++) {  /* repeat for each level */
            int t = marpa_lua_type(L, i);
            switch (t) {

              case LUA_TSTRING:  /* strings */
                printf("`%s'", marpa_lua_tostring(L, i));
                break;

              case LUA_TBOOLEAN:  /* booleans */
                printf(marpa_lua_toboolean(L, i) ? "true" : "false");
                break;

              case LUA_TNUMBER:  /* numbers */
                printf("%g", marpa_lua_tonumber(L, i));
                break;

              default:  /* other values */
                printf("%s", marpa_lua_typename(L, t));
                break;

            }
            printf("  ");  /* put a separator */
          }
          printf("\n");  /* end the listing */
    }

    -- miranda: section private error code declarations
    /* error codes */

    struct s_libmarpa_error_code {
       lua_Integer code;
       const char* mnemonic;
       const char* description;
    };

    -- miranda: section+ error object code from okollos.c.lua

    /* error objects
     *
     * There are written in C, but not because of efficiency --
     * efficiency is not needed, and in any case, when the overhead
     * from the use of the debug calls is considered, is not really
     * gained.
     *
     * The reason for the use of C is that the error routines
     * must be available for use inside both C and Lua, and must
     * also be available as early as possible during set up.
     * It's possible to run Lua code both inside C and early in
     * the set up, but the added unclarity, complexity from issues
     * of error reporting for the Lua code, etc., etc. mean that
     * it actually is easier to write them in C than in Lua.
     */

    -- miranda: section+ error object code from okollos.c.lua

    static inline const char *
    error_description_by_code (lua_Integer error_code)
    {
        if (error_code >= LIBMARPA_MIN_ERROR_CODE
            && error_code <= LIBMARPA_MAX_ERROR_CODE) {
            return marpa_error_codes[error_code -
                LIBMARPA_MIN_ERROR_CODE].description;
        }
        if (error_code >= KOLLOS_MIN_ERROR_CODE
            && error_code <= KOLLOS_MAX_ERROR_CODE) {
            return marpa_kollos_error_codes[error_code -
                KOLLOS_MIN_ERROR_CODE].description;
        }
        return (const char *) 0;
    }

    static inline void
    push_error_description_by_code (lua_State * L,
        lua_Integer error_code)
    {
        const char *description =
            error_description_by_code (error_code);
        if (description) {
            marpa_lua_pushstring (L, description);
        } else {
            marpa_lua_pushfstring (L, "Unknown error code (%d)",
                error_code);
        }
    }

    static inline int lca_error_description_by_code(lua_State* L)
    {
       const lua_Integer error_code = marpa_luaL_checkinteger(L, 1);
       if (marpa_lua_isinteger(L, 1)) {
           push_error_description_by_code(L, error_code);
           return 1;
       }
       marpa_luaL_tolstring(L, 1, NULL);
       return 1;
    }

    static inline const char* error_name_by_code(lua_Integer error_code)
    {
       if (error_code >= LIBMARPA_MIN_ERROR_CODE && error_code <= LIBMARPA_MAX_ERROR_CODE) {
           return marpa_error_codes[error_code-LIBMARPA_MIN_ERROR_CODE].mnemonic;
       }
       if (error_code >= KOLLOS_MIN_ERROR_CODE && error_code <= KOLLOS_MAX_ERROR_CODE) {
           return marpa_kollos_error_codes[error_code-KOLLOS_MIN_ERROR_CODE].mnemonic;
       }
       return (const char *)0;
    }

    static inline int lca_error_name_by_code(lua_State* L)
    {
       const lua_Integer error_code = marpa_luaL_checkinteger(L, 1);
       const char* mnemonic = error_name_by_code(error_code);
       if (mnemonic)
       {
           marpa_lua_pushstring(L, mnemonic);
       } else {
           marpa_lua_pushfstring(L, "Unknown error code (%d)", error_code);
       }
       return 1;
    }

    -- miranda: section private event code declarations

    struct s_libmarpa_event_code {
       lua_Integer code;
       const char* mnemonic;
       const char* description;
    };

    -- miranda: section+ event related code from okollos.c.lua

    static inline const char* event_description_by_code(lua_Integer event_code)
    {
       if (event_code >= LIBMARPA_MIN_EVENT_CODE && event_code <= LIBMARPA_MAX_EVENT_CODE) {
           return marpa_event_codes[event_code-LIBMARPA_MIN_EVENT_CODE].description;
       }
       return (const char *)0;
    }

    static inline int lca_event_description_by_code(lua_State* L)
    {
       const lua_Integer event_code = marpa_luaL_checkinteger(L, 1);
       const char* description = event_description_by_code(event_code);
       if (description)
       {
           marpa_lua_pushstring(L, description);
       } else {
           marpa_lua_pushfstring(L, "Unknown event code (%d)", event_code);
       }
       return 1;
    }

    static inline const char* event_name_by_code(lua_Integer event_code)
    {
       if (event_code >= LIBMARPA_MIN_EVENT_CODE && event_code <= LIBMARPA_MAX_EVENT_CODE) {
           return marpa_event_codes[event_code-LIBMARPA_MIN_EVENT_CODE].mnemonic;
       }
       return (const char *)0;
    }

    static inline int lca_event_name_by_code(lua_State* L)
    {
       const lua_Integer event_code = marpa_luaL_checkinteger(L, 1);
       const char* mnemonic = event_name_by_code(event_code);
       if (mnemonic)
       {
           marpa_lua_pushstring(L, mnemonic);
       } else {
           marpa_lua_pushfstring(L, "Unknown event code (%d)", event_code);
       }
       return 1;
    }

    -- miranda: section private step code declarations

    /* step codes */

    struct s_libmarpa_step_code {
       lua_Integer code;
       const char* mnemonic;
    };

    -- miranda: section+ step structure code

    static inline const char* step_name_by_code(lua_Integer step_code)
    {
       if (step_code >= MARPA_MIN_STEP_CODE && step_code <= MARPA_MAX_STEP_CODE) {
           return marpa_step_codes[step_code-MARPA_MIN_STEP_CODE].mnemonic;
       }
       return (const char *)0;
    }

    static inline int l_step_name_by_code(lua_State* L)
    {
       const lua_Integer step_code = marpa_luaL_checkinteger(L, 1);
       const char* mnemonic = step_name_by_code(step_code);
       if (mnemonic)
       {
           marpa_lua_pushstring(L, mnemonic);
       } else {
           marpa_lua_pushfstring(L, "Unknown step code (%d)", step_code);
       }
       return 1;
    }

    -- miranda: section+ metatable keys

    /* userdata metatable keys
       The contents of these locations are never examined.
       These location are used as a key in the Lua registry.
       This guarantees that the key will be unique
       within the Lua state.
    */
    static char kollos_g_ud_mt_key;
    static char kollos_r_ud_mt_key;
    static char kollos_b_ud_mt_key;
    static char kollos_o_ud_mt_key;
    static char kollos_t_ud_mt_key;
    static char kollos_v_ud_mt_key;

```

The metatable for tree ops is actually empty.
The presence or absence of the metatable itself
is used to determine if a table contains a
tree op.

```
    -- miranda: section+ C extern variables
    extern char kollos_tree_op_mt_key;
    -- miranda: section+ metatable keys
    char kollos_tree_op_mt_key;
    -- miranda: section+ set up empty metatables
    /* Set up tree op metatable, initially empty */
    /* tree_op_metatable = {} */
    marpa_lua_newtable (L);
    marpa_lua_pushvalue (L, -1);
    marpa_lua_rawsetp (L, LUA_REGISTRYINDEX, &kollos_tree_op_mt_key);
    /* kollos.mt_tree_op = tree_op_metatable */
    marpa_lua_setfield (L, kollos_table_stack_ix, "mt_tree_op");

```

```

    -- miranda: section+ base error handlers

    /* Leaves the stack as before,
       except with the error object on top */
    static inline void push_error_object(lua_State* L,
        lua_Integer code, const char* details)
    {
       const int error_object_stack_ix = marpa_lua_gettop(L)+1;
       marpa_lua_newtable(L);
       /* [ ..., error_object ] */
       marpa_lua_rawgetp(L, LUA_REGISTRYINDEX, &kollos_X_mt_key);
       /* [ ..., error_object, error_metatable ] */
       marpa_lua_setmetatable(L, error_object_stack_ix);
       /* [ ..., error_object ] */
       marpa_lua_pushinteger(L, code);
       marpa_lua_setfield(L, error_object_stack_ix, "code" );
      if (0) printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
      if (0) printf ("%s code = %ld\n", __PRETTY_FUNCTION__, (long)code);
       /* [ ..., error_object ] */

       marpa_luaL_traceback(L, L, NULL, 1);
       marpa_lua_setfield(L, error_object_stack_ix, "where");

       marpa_lua_pushstring(L, details);
       marpa_lua_setfield(L, error_object_stack_ix, "details" );
       /* [ ..., error_object ] */
    }

    -- miranda: section+ base error handlers

    /* grammar wrappers which need to be hand written */

    /* Get the throw flag from a libmarpa_wrapper.
     */
    static int get_throw_flag(lua_State* L, int lmw_stack_ix)
    {
        int result;
        const int base_of_stack = marpa_lua_gettop (L);
        marpa_luaL_checkstack (L, 10, "cannot grow stack");
        marpa_lua_pushvalue (L, lmw_stack_ix);
        if (!marpa_lua_getmetatable (L, lmw_stack_ix))
            goto FAILURE;
        if (marpa_lua_getfield (L, -1, "kollos") != LUA_TTABLE)
            goto FAILURE;
        if (marpa_lua_getfield (L, -1, "throw") != LUA_TBOOLEAN)
            goto FAILURE;
        result = marpa_lua_toboolean (L, -1);
        marpa_lua_settop (L, base_of_stack);
        return result;
      FAILURE:
        push_error_object (L, MARPA_ERR_DEVELOPMENT, "Bad throw flag");
        return marpa_lua_error (L);
    }

    /* Development errors are always thrown.
     */
    static void
    development_error_handle (lua_State * L,
                            const char *details)
    {
      push_error_object(L, MARPA_ERR_DEVELOPMENT, details);
      marpa_lua_pushvalue(L, -1);
      marpa_lua_setfield(L, marpa_lua_upvalueindex(1), "error_object");
      marpa_lua_error(L);
    }

```

Internal errors are those which "should not happen".
Often they were be caused by bugs.
Under the description, an exact and specific description
of the cause is not possible.
Instead,  information pinpointing the location in the
source code is provided.
The "throw" flag is ignored.

```
    -- miranda: section+ base error handlers
    static void
    internal_error_handle (lua_State * L,
                            const char *details,
                            const char *function,
                            const char *file,
                            int line
                            )
    {
      int error_object_ix;
      push_error_object(L, MARPA_ERR_INTERNAL, details);
      error_object_ix = marpa_lua_gettop(L);
      marpa_lua_pushstring(L, function);
      marpa_lua_setfield(L, error_object_ix, "function");
      marpa_lua_pushstring(L, file);
      marpa_lua_setfield(L, error_object_ix, "file");
      marpa_lua_pushinteger(L, line);
      marpa_lua_setfield(L, error_object_ix, "line");
      marpa_lua_pushvalue(L, error_object_ix);
      marpa_lua_setfield(L, marpa_lua_upvalueindex(1), "error_object");
      marpa_lua_error(L);
    }

    static int out_of_memory(lua_State* L) UNUSED;
    static int out_of_memory(lua_State* L) {
        return marpa_luaL_error(L, "Kollos out of memory");
    }

    /* If error is not thrown, it leaves a nil, then
     * the error object, on the stack.
     */
    static int
    libmarpa_error_code_handle (lua_State * L,
                            int lmw_stack_ix,
                            int error_code, const char *details)
    {
      int throw_flag = get_throw_flag(L, lmw_stack_ix);
      if (!throw_flag) {
          marpa_lua_pushnil(L);
      }
      if (0) fprintf (stderr, "%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
      push_error_object(L, error_code, details);
      if (0) fprintf (stderr, "%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
      /* [ ..., nil, error_object ] */
      marpa_lua_pushvalue(L, -1);
      marpa_lua_setfield(L, marpa_lua_upvalueindex(1), "error_object");
      if (0) fprintf (stderr, "%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
      if (throw_flag) return marpa_lua_error(L);
      if (0) fprintf (stderr, "%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
      return 2;
    }

    /* Handle libmarpa errors in the most usual way.
       Uses 2 positions on the stack, and throws the
       error, if so desired.
       The error may be thrown or not thrown.
       The caller is expected to handle any non-thrown error.
    */
    static int
    libmarpa_error_handle (lua_State * L,
                            int stack_ix, const char *details)
    {
      Marpa_Error_Code error_code;
      Marpa_Grammar *grammar_ud;
      const int base_of_stack = marpa_lua_gettop(L);

      marpa_lua_getfield (L, stack_ix, "lmw_g");
      marpa_lua_getfield (L, -1, "_libmarpa");
      /* [ ..., grammar_ud ] */
      grammar_ud = (Marpa_Grammar *) marpa_lua_touserdata (L, -1);
      marpa_lua_settop(L, base_of_stack);
      error_code = marpa_g_error (*grammar_ud, NULL);
      return libmarpa_error_code_handle(L, stack_ix, error_code, details);
    }

    /* A wrapper for libmarpa_error_handle to conform with the
     * Lua C API.  The only argument must be a Libmarpa wrapper
     * object.  These all define the `lmw_g` field.
     */
    static int
    lca_libmarpa_error(lua_State* L)
    {
       const int lmw_stack_ix = 1;
       const int details_stack_ix = 2;
       const char* details = marpa_lua_tostring (L, details_stack_ix);
       libmarpa_error_handle(L, lmw_stack_ix, details);
       /* Return only the error object,
        * not the nil on the stack
        * below it.
        */
       return 1;
    }

```

Return the current error_description
Lua C API.  The only argument must be a Libmarpa wrapper
object.
All such objects define the `lmw_g` field.
```
    -- miranda: section+ base error handlers

    static int
    lca_libmarpa_error_description(lua_State* L)
    {
        Marpa_Error_Code error_code;
        Marpa_Grammar *grammar_ud;
        const int lmw_stack_ix = 1;

        marpa_lua_getfield (L, lmw_stack_ix, "lmw_g");
        marpa_lua_getfield (L, -1, "_libmarpa");
        grammar_ud = (Marpa_Grammar *) marpa_lua_touserdata (L, -1);
        error_code = marpa_g_error (*grammar_ud, NULL);
        push_error_description_by_code(L, error_code);
        return 1;
    }

```

Return the current error data:
code, mnemonic and description.
Lua C API.  The only argument must be a Libmarpa wrapper
object.
All such objects define the `lmw_g` field.

```
    -- miranda: section+ base error handlers

    static int
    lca_libmarpa_error_code(lua_State* L)
    {
        Marpa_Error_Code error_code;
        Marpa_Grammar *grammar_ud;
        const int lmw_stack_ix = 1;

        marpa_lua_getfield (L, lmw_stack_ix, "lmw_g");
        marpa_lua_getfield (L, -1, "_libmarpa");
        grammar_ud = (Marpa_Grammar *) marpa_lua_touserdata (L, -1);
        error_code = marpa_g_error (*grammar_ud, NULL);
        marpa_lua_pushinteger (L, error_code);
        return 1;
    }

    -- miranda: section+ non-standard wrappers

    /* The C wrapper for Libmarpa event reading.
       It assumes we just want all of them.
     */
    static int lca_grammar_events(lua_State *L)
    {
      /* [ grammar_object ] */
      const int grammar_stack_ix = 1;
      Marpa_Grammar *p_g;
      int event_count;

      marpa_lua_getfield (L, grammar_stack_ix, "_libmarpa");
      /* [ grammar_object, grammar_ud ] */
      p_g = (Marpa_Grammar *) marpa_lua_touserdata (L, -1);
      event_count = marpa_g_event_count (*p_g);
      if (event_count < 0)
        {
          return libmarpa_error_handle (L, grammar_stack_ix,
                                  "marpa_g_event_count()");
        }
      marpa_lua_pop (L, 1);
      /* [ grammar_object ] */
      marpa_lua_createtable (L, event_count, 0);
      /* [ grammar_object, result_table ] */
      {
        const int result_table_ix = marpa_lua_gettop (L);
        int event_ix;
        for (event_ix = 0; event_ix < event_count; event_ix++)
          {
            Marpa_Event_Type event_type;
            Marpa_Event event;
            /* [ grammar_object, result_table ] */
            event_type = marpa_g_event (*p_g, &event, event_ix);
            if (event_type <= -2)
              {
                return libmarpa_error_handle (L, grammar_stack_ix,
                                        "marpa_g_event()");
              }
            marpa_lua_pushinteger (L, event_ix*2 + 1);
            marpa_lua_pushinteger (L, event_type);
            /* [ grammar_object, result_table, event_ix*2+1, event_type ] */
            marpa_lua_settable (L, result_table_ix);
            /* [ grammar_object, result_table ] */
            marpa_lua_pushinteger (L, event_ix*2 + 2);
            marpa_lua_pushinteger (L, marpa_g_event_value (&event));
            /* [ grammar_object, result_table, event_ix*2+2, event_value ] */
            marpa_lua_settable (L, result_table_ix);
            /* [ grammar_object, result_table ] */
          }
      }
      /* [ grammar_object, result_table ] */
      return 1;
    }

    /* Another C wrapper for Libmarpa event reading.
       It assumes we want them one by one.
     */
    static int lca_grammar_event(lua_State *L)
    {
      /* [ grammar_object ] */
      const int grammar_stack_ix = 1;
      const int event_ix_stack_ix = 2;
      Marpa_Grammar *p_g;
      Marpa_Event_Type event_type;
      Marpa_Event event;
      const int event_ix = (Marpa_Symbol_ID)marpa_lua_tointeger(L, event_ix_stack_ix)-1;

      marpa_lua_getfield (L, grammar_stack_ix, "_libmarpa");
      /* [ grammar_object, grammar_ud ] */
      p_g = (Marpa_Grammar *) marpa_lua_touserdata (L, -1);
      /* [ grammar_object, grammar_ud ] */
      event_type = marpa_g_event (*p_g, &event, event_ix);
      if (event_type <= -2)
        {
          return libmarpa_error_handle (L, grammar_stack_ix, "marpa_g_event()");
        }
      marpa_lua_pushinteger (L, event_type);
      marpa_lua_pushinteger (L, marpa_g_event_value (&event));
      /* [ grammar_object, grammar_ud, event_type, event_value ] */
      return 2;
    }

`lca_grammar_rule_new` wraps the Libmarpa method `marpa_g_rule_new()`.
If the rule is 7 symbols or fewer, I put it on the stack.  As an old
kernel driver programmer, I was trained to avoid putting even small
arrays on the stack, but one of this size should be safe on anything
close to a modern architecture.

Perhaps I will eventually limit Libmarpa's
rule RHS to 7 symbols, 7 because I can encode dot position in 3 bit.

    -- miranda: section+ non-standard wrappers

    static int lca_grammar_rule_new(lua_State *L)
    {
        Marpa_Grammar g;
        Marpa_Rule_ID result;
        Marpa_Symbol_ID lhs;

        /* [ grammar_object, lhs, rhs ... ] */
        const int grammar_stack_ix = 1;
        const int args_stack_ix = 2;
        /* 7 should be enough, almost always */
        const int rhs_buffer_size = 7;
        Marpa_Symbol_ID rhs_buffer[rhs_buffer_size];
        Marpa_Symbol_ID *rhs;
        int overflow = 0;
        lua_Integer arg_count;
        lua_Integer table_ix;

        /* This will not be an external interface,
         * so eventually we will run unsafe.
         * This checking code is for debugging.
         */
        marpa_luaL_checktype(L, grammar_stack_ix, LUA_TTABLE);
        marpa_luaL_checktype(L, args_stack_ix, LUA_TTABLE);

        marpa_lua_len(L, args_stack_ix);
        arg_count = marpa_lua_tointeger(L, -1);
        if (arg_count > 1<<30) {
            marpa_luaL_error(L,
                "grammar:rule_new() arg table length too long");
        }
        if (arg_count < 1) {
            marpa_luaL_error(L,
                "grammar:rule_new() arg table length must be at least 1");
        }

        /* arg_count - 2 == rhs_ix
         * For example, arg_count of 3, has one arg for LHS,
         * and 2 for RHS, so max rhs_ix == 1
         */
        if (((size_t)arg_count - 2) >= (sizeof(rhs_buffer)/sizeof(*rhs_buffer))) {
           /* Treat "overflow" arg counts as freaks.
            * We do not optimize for them, but do a custom
            * malloc/free pair for each.
            */
           rhs = malloc(sizeof(Marpa_Symbol_ID) * (size_t)arg_count);
           overflow = 1;
        } else {
           rhs = rhs_buffer;
        }

        marpa_lua_geti(L, args_stack_ix, 1);
        lhs = (Marpa_Symbol_ID)marpa_lua_tointeger(L, -1);
        for (table_ix = 2; table_ix <= arg_count; table_ix++)
        {
            /* Calculated as above */
            const int rhs_ix = (int)table_ix - 2;
            marpa_lua_geti(L, args_stack_ix, table_ix);
            rhs[rhs_ix] = (Marpa_Symbol_ID)marpa_lua_tointeger(L, -1);
            marpa_lua_settop(L, args_stack_ix);
        }

        marpa_lua_getfield (L, grammar_stack_ix, "_libmarpa");
        /* [ grammar_object, grammar_ud ] */
        g = *(Marpa_Grammar *) marpa_lua_touserdata (L, -1);

        result = (Marpa_Rule_ID)marpa_g_rule_new(g, lhs, rhs, ((int)arg_count - 1));
        if (overflow) free(rhs);
        if (result <= -1) return libmarpa_error_handle (L, grammar_stack_ix,
                                "marpa_g_rule_new()");
        marpa_lua_pushinteger(L, (lua_Integer)result);
        return 1;
    }

`lca_grammar_sequence_new` wraps the Libmarpa method `marpa_g_sequence_new()`.
If the rule is 7 symbols or fewer, I put it on the stack.  As an old
kernel driver programmer, I was trained to avoid putting even small
arrays on the stack, but one of this size should be safe on anything
like close to a modern architecture.

Perhaps I will eventually limit Libmarpa's
rule RHS to 7 symbols, 7 because I can encode dot position in 3 bit.

    -- miranda: section+ non-standard wrappers

    static int lca_grammar_sequence_new(lua_State *L)
    {
        Marpa_Grammar *p_g;
        Marpa_Rule_ID result;
        lua_Integer lhs = -1;
        lua_Integer rhs = -1;
        lua_Integer separator = -1;
        lua_Integer min = 1;
        int proper = 0;
        const int grammar_stack_ix = 1;
        const int args_stack_ix = 2;

        marpa_luaL_checktype (L, grammar_stack_ix, LUA_TTABLE);
        marpa_luaL_checktype (L, args_stack_ix, LUA_TTABLE);

        marpa_lua_pushnil (L);
        /* [ ..., nil ] */
        while (marpa_lua_next (L, args_stack_ix)) {
            /* [ ..., key, value ] */
            const char *string_key;
            const int value_stack_ix = marpa_lua_gettop (L);
            const int key_stack_ix = value_stack_ix - 1;
            int is_int = 0;
            switch (marpa_lua_type (L, key_stack_ix)) {

            case LUA_TSTRING:      /* strings */
                /* lua_tostring() is safe because arg is always a string */
                string_key = marpa_lua_tostring (L, key_stack_ix);
                if (!strcmp (string_key, "min")) {
                    min = marpa_lua_tointegerx (L, value_stack_ix, &is_int);
                    if (!is_int) {
                        return marpa_luaL_error (L,
                            "grammar:sequence_new() value of 'min' must be numeric");
                    }
                    goto NEXT_ELEMENT;
                }
                if (!strcmp (string_key, "proper")) {
                    proper = marpa_lua_toboolean (L, value_stack_ix);
                    goto NEXT_ELEMENT;
                }
                if (!strcmp (string_key, "separator")) {
                    separator =
                        marpa_lua_tointegerx (L, value_stack_ix, &is_int);
                    if (!is_int) {
                        return marpa_luaL_error (L,
                            "grammar:sequence_new() value of 'separator' must be a symbol ID");
                    }
                    goto NEXT_ELEMENT;
                }
                if (!strcmp (string_key, "lhs")) {
                    lhs = marpa_lua_tointegerx (L, value_stack_ix, &is_int);
                    if (!is_int || lhs < 0) {
                        return marpa_luaL_error (L,
                            "grammar:sequence_new() LHS must be a valid symbol ID");
                    }
                    goto NEXT_ELEMENT;
                }
                if (!strcmp (string_key, "rhs")) {
                    rhs = marpa_lua_tointegerx (L, value_stack_ix, &is_int);
                    if (!is_int || rhs < 0) {
                        return marpa_luaL_error (L,
                            "grammar:sequence_new() RHS must be a valid symbol ID");
                    }
                    goto NEXT_ELEMENT;
                }
                return marpa_luaL_error (L,
                    "grammar:sequence_new() bad string key (%s) in arg table",
                    string_key);

            default:               /* other values */
                return marpa_luaL_error (L,
                    "grammar:sequence_new() bad key type (%s) in arg table",
                    marpa_lua_typename (L, marpa_lua_type (L, key_stack_ix))
                    );

            }

          NEXT_ELEMENT:

            /* [ ..., key, value, key_copy ] */
            marpa_lua_settop (L, key_stack_ix);
            /* [ ..., key ] */
        }


        if (lhs < 0) {
            return marpa_luaL_error (L,
                "grammar:sequence_new(): LHS argument is missing");
        }
        if (rhs < 0) {
            return marpa_luaL_error (L,
                "grammar:sequence_new(): RHS argument is missing");
        }

        marpa_lua_getfield (L, grammar_stack_ix, "_libmarpa");
        p_g = (Marpa_Grammar *) marpa_lua_touserdata (L, -1);

        result =
            (Marpa_Rule_ID) marpa_g_sequence_new (*p_g,
            (Marpa_Symbol_ID) lhs,
            (Marpa_Symbol_ID) rhs,
            (Marpa_Symbol_ID) separator,
            (int) min, (proper ? MARPA_PROPER_SEPARATION : 0)
            );
        if (result <= -1)
            return libmarpa_error_handle (L, grammar_stack_ix,
                "marpa_g_rule_new()");
        marpa_lua_pushinteger (L, (lua_Integer) result);
        return 1;
    }

    static int lca_grammar_precompute(lua_State *L)
    {
        Marpa_Grammar self;
        const int self_stack_ix = 1;
        int highest_symbol_id;
        int result;

        if (1) {
            marpa_luaL_checktype (L, self_stack_ix, LUA_TTABLE);
        }
        marpa_lua_getfield (L, -1, "_libmarpa");
        self = *(Marpa_Grammar *) marpa_lua_touserdata (L, -1);
        marpa_lua_pop (L, 1);
        result = (int) marpa_g_precompute (self);
        if (result == -1) {
            marpa_lua_pushnil (L);
            return 1;
        }
        if (result < -1) {
            return libmarpa_error_handle (L, self_stack_ix,
                "grammar:precompute; marpa_g_precompute");
        }

        highest_symbol_id = marpa_g_highest_symbol_id (self);
        if (highest_symbol_id < 0) {
            return libmarpa_error_handle (L, self_stack_ix,
                "grammar:precompute; marpa_g_highest_symbol_id");
            return 1;
        }

        if (0) {
            printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
            printf ("About to resize buffer to %ld", (long) ( highest_symbol_id+1));
        }

        (void)kollos_shared_buffer_resize(L, (size_t) highest_symbol_id+1);
        marpa_lua_pushinteger (L, (lua_Integer) result);
        return 1;
    }

    /* -1 is a valid result, so ahm_position() is a special case */
    static int lca_grammar_ahm_position(lua_State *L)
    {
        Marpa_Grammar self;
        const int self_stack_ix = 1;
        Marpa_AHM_ID item_id;
        int result;

        if (1) {
            marpa_luaL_checktype (L, self_stack_ix, LUA_TTABLE);
            marpa_luaL_checkinteger (L, 2);
        }
        {
            const lua_Integer this_arg = marpa_lua_tointeger (L, -1);
            marpa_luaL_argcheck (L, (-(1 << 30) <= this_arg
                    && this_arg <= (1 << 30)), -1, "argument out of range");
            item_id = (Marpa_AHM_ID) this_arg;
            marpa_lua_pop (L, 1);
        }
        marpa_lua_getfield (L, -1, "_libmarpa");
        self = *(Marpa_Grammar *) marpa_lua_touserdata (L, -1);
        marpa_lua_pop (L, 1);
        result = (int) _marpa_g_ahm_position (self, item_id);
        if (result < -1) {
            return libmarpa_error_handle (L, self_stack_ix,
                "lca_grammar_ahm_position()");
        }
        marpa_lua_pushinteger (L, (lua_Integer) result);
        return 1;
    }

    -- miranda: section+ luaL_Reg definitions

    static const struct luaL_Reg grammar_methods[] = {
      { "error", lca_libmarpa_error },
      { "error_code", lca_libmarpa_error_code },
      { "error_description", lca_libmarpa_error_description },
      { "events", lca_grammar_events },
      { "precompute", lca_grammar_precompute },
      { "rule_new", lca_grammar_rule_new },
      { "sequence_new", lca_grammar_sequence_new },
      { "_ahm_position", lca_grammar_ahm_position },
      { NULL, NULL },
    };

    -- miranda: section+ C function declarations

    /* recce wrappers which need to be hand-written */

    void marpa_gen_recce_ud(lua_State* L, Marpa_Recce recce);

    -- miranda: section+ non-standard wrappers

    /* Caller must ensure enough stack space.
     * Leaves a new userdata on top of the stack.
     */
    void marpa_gen_recce_ud(lua_State* L, Marpa_Recce recce)
    {
        Marpa_Recce* p_recce;
        p_recce = (Marpa_Recce *) marpa_lua_newuserdata (L, sizeof (Marpa_Recce));
        *p_recce = recce;
        /* [ userdata ] */
        marpa_lua_rawgetp (L, LUA_REGISTRYINDEX, &kollos_r_ud_mt_key);
        /* [ userdata, metatable ] */
        marpa_lua_setmetatable (L, -2);
        /* [ userdata ] */
    }

    static int lca_recce_look_yim(lua_State *L)
    {
        const int recce_stack_ix = 1;
        Marpa_Recce r;
        Marpa_Grammar g;
        Marpa_Earley_Item_Look look;
        Marpa_Earley_Set_ID es_id;
        Marpa_Earley_Item_ID eim_id;
        int check_result;

        marpa_lua_getfield (L, recce_stack_ix, "_libmarpa");
        r = *(Marpa_Recce *) marpa_lua_touserdata (L, -1);
        marpa_lua_getfield (L, recce_stack_ix, "lmw_g");
        if (0) fprintf (stderr, "%s %s %d tos=%s\n", __PRETTY_FUNCTION__, __FILE__, __LINE__, marpa_luaL_typename(L, -1));
        marpa_lua_getfield (L, -1, "_libmarpa");
        g = *(Marpa_Grammar *) marpa_lua_touserdata (L, -1);
        es_id = (Marpa_Earley_Set_ID)marpa_luaL_checkinteger (L, 2);
        eim_id = (Marpa_Earley_Item_ID)marpa_luaL_checkinteger (L, 3);
        check_result = _marpa_r_yim_check(r, es_id, eim_id);
        if (check_result <= -2) {
           return libmarpa_error_handle (L, recce_stack_ix, "recce:progress_item()");
        }
        if (check_result == 0) {
            marpa_lua_pushnil(L);
            return 1;
        }
        if (check_result == -1) {
            return marpa_luaL_error(L, "yim_look(%d, %d): No such earley set",
                es_id, eim_id);
        }
        (void) _marpa_r_look_yim(r, &look, es_id, eim_id);
        /* The "raw xrl dot" is a development hack to test a fix
         * to the xrl dot value.
         * TODO -- Delete after development.
         */
        {
            const lua_Integer raw_xrl_dot = (lua_Integer)marpa_eim_look_dot(&look);
            lua_Integer xrl_dot = raw_xrl_dot;
            const lua_Integer irl_dot = (lua_Integer)marpa_eim_look_irl_dot(&look);
            const lua_Integer irl_id = marpa_eim_look_irl_id(&look);
            if (0) fprintf (stderr, "%s %s %d; xrl dot = %ld; irl dot = %ld; irl length = %ld\n", __PRETTY_FUNCTION__, __FILE__, __LINE__,
                (long)xrl_dot,
                (long)irl_dot,
                (long)_marpa_g_irl_length(g, (Marpa_IRL_ID)irl_id));
            if (irl_dot < 0) {
                xrl_dot = -1;
            }
            if (irl_dot >= (lua_Integer)_marpa_g_irl_length(g, (Marpa_IRL_ID)irl_id)) {
                xrl_dot = -1;
            }
            marpa_lua_pushinteger(L, (lua_Integer)marpa_eim_look_rule_id(&look));
            marpa_lua_pushinteger(L, xrl_dot);
            marpa_lua_pushinteger(L, (lua_Integer)marpa_eim_look_origin(&look));
            marpa_lua_pushinteger(L, irl_id);
            marpa_lua_pushinteger(L, irl_dot);
        }
        return 5;
    }

```

For an Earley set, call it `es`,
and an internal symbol, call it `sym`,
`lca_recce_postdot_eims` returns
a sequence containing
the Earley items in `es` whose
postdot symbol is `sym`.
If there are none, an empty table
is returned.

```
    -- miranda: section+ non-standard wrappers
    static int lca_recce_postdot_eims(lua_State *L)
    {
        const int recce_stack_ix = 1;
        Marpa_Recce r;
        Marpa_Postdot_Item_Look look;
        Marpa_Earley_Set_ID es_id;
        Marpa_Symbol_ID isy_id;
        int check_result;
        int table_ix;
        int eim_index;

        marpa_lua_getfield (L, recce_stack_ix, "_libmarpa");
        r = *(Marpa_Recce *) marpa_lua_touserdata (L, -1);
        es_id = (Marpa_Earley_Set_ID) marpa_luaL_checkinteger (L, 2);
        isy_id = (Marpa_Symbol_ID) marpa_luaL_checkinteger (L, 3);
        /* Every Earley set should contain an EIM #0 */
        check_result = _marpa_r_yim_check (r, es_id, 0);
        if (check_result <= -2) {
            return libmarpa_error_handle (L, recce_stack_ix,
                "recce:postdot_eims()");
        }
        if (check_result == 0) {
            marpa_lua_pushnil (L);
            return 1;
        }
        if (check_result == -1) {
            return marpa_luaL_error (L, "yim_look(%d, %d): No such earley set",
                es_id, 0);
        }
        marpa_lua_newtable (L);
        table_ix = 1;
        eim_index = _marpa_r_look_pim_eim_first (r, &look, es_id, isy_id);
        if (0) fprintf (stderr, "%s %s %d eim_index=%ld\n", __PRETTY_FUNCTION__, __FILE__, __LINE__, (long)eim_index);
        while (eim_index >= 0) {
            marpa_lua_pushinteger (L, (lua_Integer) eim_index);
            marpa_lua_rawseti (L, -2, table_ix);
            table_ix++;
            eim_index = _marpa_r_look_pim_eim_next (&look);
            if (0) fprintf (stderr, "%s %s %d eim_index=%ld\n", __PRETTY_FUNCTION__, __FILE__, __LINE__, (long)eim_index);
            if (0) fprintf (stderr, "%s %s %d tos=%ld\n", __PRETTY_FUNCTION__, __FILE__, __LINE__, (long)marpa_lua_gettop(L));
        }
        return 1;
    }

```

```
    -- miranda: section+ non-standard wrappers
    static int lca_recce_progress_item(lua_State *L)
    {
      /* [ recce_object ] */
      const int recce_stack_ix = 1;
      Marpa_Recce r;
      Marpa_Earley_Set_ID origin;
      int position;
      Marpa_Rule_ID rule_id;

      marpa_lua_getfield (L, recce_stack_ix, "_libmarpa");
      /* [ recce_object, recce_ud ] */
      r = *(Marpa_Recce *) marpa_lua_touserdata (L, -1);
      rule_id = marpa_r_progress_item (r, &position, &origin);
      if (rule_id < -1)
        {
          return libmarpa_error_handle (L, recce_stack_ix, "recce:progress_item()");
        }
      if (rule_id == -1)
        {
          return 0;
        }
      marpa_lua_pushinteger (L, (lua_Integer) rule_id);
      marpa_lua_pushinteger (L, (lua_Integer) position);
      marpa_lua_pushinteger (L, (lua_Integer) origin);
      return 3;
    }

    static int lca_recce_terminals_expected( lua_State *L )
    {
      /* [ recce_object ] */
      const int recce_stack_ix = 1;
      int count;
      int ix;
      Marpa_Recce r;

      /* The shared buffer is guaranteed to have space for all the symbol IDS
       * of the grammar.
       */
      Marpa_Symbol_ID* const buffer = shared_buffer_get(L);

      marpa_lua_getfield (L, recce_stack_ix, "_libmarpa");
      /* [ recce_object, recce_ud ] */
      r = *(Marpa_Recce *) marpa_lua_touserdata (L, -1);

      count = marpa_r_terminals_expected (r, buffer);
      if (count < 0) {
          return libmarpa_error_handle(L, recce_stack_ix, "grammar:terminals_expected; marpa_r_terminals_expected");
      }
      marpa_lua_newtable(L);
      for (ix = 0; ix < count; ix++) {
          marpa_lua_pushinteger(L, buffer[ix]);
          marpa_lua_rawseti(L, -2, ix+1);
      }
      return 1;
    }

    /* special-cased because two return values */
    static int lca_recce_source_token( lua_State *L )
    {
      Marpa_Recognizer self;
      const int self_stack_ix = 1;
      int result;
      int value;

      if (1) {
        marpa_luaL_checktype(L, self_stack_ix, LUA_TTABLE);  }
      marpa_lua_getfield (L, -1, "_libmarpa");
      self = *(Marpa_Recognizer*)marpa_lua_touserdata (L, -1);
      marpa_lua_pop(L, 1);
      result = (int)_marpa_r_source_token(self, &value);
      if (result == -1) { marpa_lua_pushnil(L); return 1; }
      if (result < -1) {
       return libmarpa_error_handle(L, self_stack_ix, "lca_recce_source_token()");
      }
      marpa_lua_pushinteger(L, (lua_Integer)result);
      marpa_lua_pushinteger(L, (lua_Integer)value);
      return 2;
    }

    -- miranda: section+ luaL_Reg definitions

    static const struct luaL_Reg recce_methods[] = {
      { "error", lca_libmarpa_error },
      { "error_code", lca_libmarpa_error_code },
      { "error_description", lca_libmarpa_error_description },
      { "terminals_expected", lca_recce_terminals_expected },
      { "earley_item_look", lca_recce_look_yim },
      { "postdot_eims", lca_recce_postdot_eims },
      { "progress_item", lca_recce_progress_item },
      { "_source_token", lca_recce_source_token },
      { NULL, NULL },
    };

    -- miranda: section+ C function declarations

    /* bocage wrappers which need to be hand-written */

    -- miranda: section+ luaL_Reg definitions

    static const struct luaL_Reg bocage_methods[] = {
      { "error", lca_libmarpa_error },
      { "error_code", lca_libmarpa_error_code },
      { "error_description", lca_libmarpa_error_description },
      { NULL, NULL },
    };

    /* order wrappers which need to be hand-written */

    -- miranda: section+ luaL_Reg definitions

    static const struct luaL_Reg order_methods[] = {
      { "error", lca_libmarpa_error },
      { "error_code", lca_libmarpa_error_code },
      { "error_description", lca_libmarpa_error_description },
      { NULL, NULL },
    };

    -- miranda: section+ C function declarations

    /* tree wrappers which need to be hand-written */

    -- miranda: section+ luaL_Reg definitions

    static const struct luaL_Reg tree_methods[] = {
      { "error", lca_libmarpa_error },
      { "error_code", lca_libmarpa_error_code },
      { "error_description", lca_libmarpa_error_description },
      { NULL, NULL },
    };

    /* value wrappers which need to be hand-written */

    -- miranda: section+ non-standard wrappers

    /* Returns ok, result,
     * where ok is a boolean and
     * on failure, result is an error object, while
     * on success, result is an table
     */
    static int
    wrap_v_step (lua_State * L)
    {
      const char *result_string;
      Marpa_Value v;
      Marpa_Step_Type step_type;
      const int value_stack_ix = 1;

      marpa_luaL_checktype (L, value_stack_ix, LUA_TTABLE);

      marpa_lua_getfield (L, value_stack_ix, "_libmarpa");
      /* [ value_table, value_ud ] */
      v = *(Marpa_Value *) marpa_lua_touserdata (L, -1);
      step_type = marpa_v_step (v);

      if (0) printf("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);

      if (step_type == MARPA_STEP_INACTIVE)
        {
          marpa_lua_pushboolean (L, 1);
          marpa_lua_pushnil (L);
          return 2;
        }

      if (step_type < 0)
        {
          return libmarpa_error_handle (L, value_stack_ix, "marpa_v_step()");
        }

      if (0) printf("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);

      result_string = step_name_by_code (step_type);
      if (result_string)
        {

          int return_value_ix;

          /* The table containing the return value */
          marpa_lua_newtable (L);
          return_value_ix = marpa_lua_gettop(L);
          marpa_lua_pushstring (L, result_string);
          marpa_lua_seti (L, return_value_ix, 1);

          if (step_type == MARPA_STEP_TOKEN)
            {
              marpa_lua_pushinteger (L, marpa_v_token (v));
              marpa_lua_seti (L, return_value_ix, 2);
              marpa_lua_pushinteger (L, marpa_v_token_start_es_id (v));
              marpa_lua_seti (L, return_value_ix, 3);
              marpa_lua_pushinteger (L, marpa_v_es_id (v));
              marpa_lua_seti (L, return_value_ix, 4);
              marpa_lua_pushinteger (L, marpa_v_result (v));
              marpa_lua_seti (L, return_value_ix, 5);
              marpa_lua_pushinteger (L, marpa_v_token_value (v));
              marpa_lua_seti (L, return_value_ix, 6);
              marpa_lua_pushboolean (L, 1);
              marpa_lua_insert (L, -2);
              return 2;
            }

          if (step_type == MARPA_STEP_NULLING_SYMBOL)
            {
              marpa_lua_pushinteger (L, marpa_v_token (v));
              marpa_lua_seti (L, return_value_ix, 2);
              marpa_lua_pushinteger (L, marpa_v_rule_start_es_id (v));
              marpa_lua_seti (L, return_value_ix, 3);
              marpa_lua_pushinteger (L, marpa_v_es_id (v));
              marpa_lua_seti (L, return_value_ix, 4);
              marpa_lua_pushinteger (L, marpa_v_result (v));
              marpa_lua_seti (L, return_value_ix, 5);
              marpa_lua_pushboolean (L, 1);
              marpa_lua_insert (L, -2);
              return 2;
            }

          if (step_type == MARPA_STEP_RULE)
            {
              marpa_lua_pushinteger (L, marpa_v_rule (v));
              marpa_lua_seti (L, return_value_ix, 2);
              marpa_lua_pushinteger (L, marpa_v_rule_start_es_id (v));
              marpa_lua_seti (L, return_value_ix, 3);
              marpa_lua_pushinteger (L, marpa_v_es_id (v));
              marpa_lua_seti (L, return_value_ix, 4);
              marpa_lua_pushinteger (L, marpa_v_result (v));
              marpa_lua_seti (L, return_value_ix, 5);
              marpa_lua_pushinteger (L, marpa_v_arg_0 (v));
              marpa_lua_seti (L, return_value_ix, 6);
              marpa_lua_pushinteger (L, marpa_v_arg_n (v));
              marpa_lua_seti (L, return_value_ix, 7);
              marpa_lua_pushboolean (L, 1);
              marpa_lua_insert (L, -2);
              return 2;
            }
        }

      if (0) printf("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);

      marpa_lua_pushfstring (L, "Problem in v->step(): unknown step type %d",
                             step_type);
      development_error_handle (L, marpa_lua_tostring (L, -1));
      marpa_lua_pushboolean (L, 0);
      marpa_lua_insert (L, -2);
      return 2;

    }

    /* Returns ok, result,
     * where ok is a boolean and
     * on failure, result is an error object, while
     * on success, result is an table
     */
    static int
    wrap_v_location (lua_State * L)
    {
      Marpa_Value v;
      Marpa_Step_Type step_type;
      const int value_stack_ix = 1;

      marpa_luaL_checktype (L, value_stack_ix, LUA_TTABLE);

      marpa_lua_getfield (L, value_stack_ix, "_libmarpa");
      /* [ value_table, value_ud ] */
      v = *(Marpa_Value *) marpa_lua_touserdata (L, -1);
      step_type = marpa_v_step_type (v);

      if (0) printf("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);

      switch(step_type) {
      case MARPA_STEP_RULE:
          marpa_lua_pushinteger(L, marpa_v_rule_start_es_id (v));
          marpa_lua_pushinteger(L, marpa_v_es_id (v));
          return 2;
      case MARPA_STEP_NULLING_SYMBOL:
          marpa_lua_pushinteger(L, marpa_v_token_start_es_id (v));
          marpa_lua_pushinteger(L, marpa_v_es_id (v));
          return 2;
      case MARPA_STEP_TOKEN:
          marpa_lua_pushinteger(L, marpa_v_token_start_es_id (v));
          marpa_lua_pushinteger(L, marpa_v_es_id (v));
          return 2;
      }
      return 0;
    }

    -- miranda: section+ luaL_Reg definitions

    static const struct luaL_Reg value_methods[] = {
      { "location", wrap_v_location },
      { "step", wrap_v_step },
      { NULL, NULL },
    };

    -- miranda: section+ object userdata gc methods

    /*
     * Userdata metatable methods
     */

    --[==[ miranda: exec object userdata gc methods
        local result = {}
        local template = [[
        |static int l_!NAME!_ud_mt_gc(lua_State *L) {
        |  !TYPE! *p_ud;
        |  if (0) printf("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
        |  p_ud = (!TYPE! *) marpa_lua_touserdata (L, 1);
        |  if (*p_ud) marpa_!LETTER!_unref(*p_ud);
        |  *p_ud = NULL;
        |  return 0;
        |}
        ]]
        for letter, class_name in pairs(libmarpa_class_name) do
           local class_type = libmarpa_class_type[letter]
           result[#result+1] =
               pipe_dedent(template)
                   :gsub("!NAME!", class_name)
                   :gsub("!TYPE!", class_type)
                   :gsub("!LETTER!", letter)
        end
        return table.concat(result)
    ]==]

```

### Kollos metal loader

To make this a real module, this fuction must be named "luaopen_kollos_metal".
The LUAOPEN_KOLLOS_METAL define allows us to override this for a declaration
compatible with static loading and namespace requirements like those of
Marpa::R3.

```
    -- miranda: section+ C function declarations
    #if !defined(LUAOPEN_KOLLOS_METAL)
    #define LUAOPEN_KOLLOS_METAL luaopen_kollos_metal
    #endif
    int LUAOPEN_KOLLOS_METAL(lua_State *L);
    -- miranda: section define kollos_metal_loader method
    int LUAOPEN_KOLLOS_METAL(lua_State *L)
    {
        /* The main kollos object */
        int kollos_table_stack_ix;
        int upvalue_stack_ix;

        /* Make sure the header is from the version we want */
        if (MARPA_MAJOR_VERSION != EXPECTED_LIBMARPA_MAJOR ||
            MARPA_MINOR_VERSION != EXPECTED_LIBMARPA_MINOR ||
            MARPA_MICRO_VERSION != EXPECTED_LIBMARPA_MICRO) {
            const char *message;
            marpa_lua_pushfstring
                (L,
                "Libmarpa header version mismatch: want %ld.%ld.%ld, have %ld.%ld.%ld",
                EXPECTED_LIBMARPA_MAJOR, EXPECTED_LIBMARPA_MINOR,
                EXPECTED_LIBMARPA_MICRO, MARPA_MAJOR_VERSION,
                MARPA_MINOR_VERSION, MARPA_MICRO_VERSION);
            message = marpa_lua_tostring (L, -1);
            internal_error_handle (L, message,
                __PRETTY_FUNCTION__, __FILE__, __LINE__);
        }

        /* Now make sure the library is from the version we want */
        {
            int version[3];
            const Marpa_Error_Code error_code = marpa_version (version);
            if (error_code != MARPA_ERR_NONE) {
                const char *description =
                    error_description_by_code (error_code);
                const char *message;
                marpa_lua_pushfstring (L, "marpa_version() failed: %s",
                    description);
                message = marpa_lua_tostring (L, -1);
                internal_error_handle (L, message, __PRETTY_FUNCTION__,
                    __FILE__, __LINE__);
            }
            if (version[0] != EXPECTED_LIBMARPA_MAJOR ||
                version[1] != EXPECTED_LIBMARPA_MINOR ||
                version[2] != EXPECTED_LIBMARPA_MICRO) {
                const char *message;
                marpa_lua_pushfstring
                    (L,
                    "Libmarpa library version mismatch: want %ld.%ld.%ld, have %ld.%ld.%ld",
                    EXPECTED_LIBMARPA_MAJOR, EXPECTED_LIBMARPA_MINOR,
                    EXPECTED_LIBMARPA_MICRO, version[0], version[1],
                    version[2]);
                message = marpa_lua_tostring (L, -1);
                internal_error_handle (L, message, __PRETTY_FUNCTION__,
                    __FILE__, __LINE__);
            }
        }

        /* Create the kollos class */
        marpa_lua_newtable (L);
        kollos_table_stack_ix = marpa_lua_gettop (L);
        /* Create the main kollos_c object, to give the
         * C language Libmarpa wrappers their own namespace.
         *
         */
        /* [ kollos ] */

        /* kollos.throw = true */
        marpa_lua_pushboolean (L, 1);
        marpa_lua_setfield (L, kollos_table_stack_ix, "throw");

        /* Create the shared upvalue table */
        {
            /* TODO increase initial buffer capacity
             * after testing.
             */
            const size_t initial_buffer_capacity = 1;
            marpa_lua_newtable (L);
            upvalue_stack_ix = marpa_lua_gettop (L);
            marpa_lua_newuserdata (L,
                sizeof (Marpa_Symbol_ID) * initial_buffer_capacity);
            marpa_lua_setfield (L, upvalue_stack_ix, "buffer");
            marpa_lua_pushinteger (L, (lua_Integer) initial_buffer_capacity);
            marpa_lua_setfield (L, upvalue_stack_ix, "buffer_capacity");
        }

        /* Also keep the upvalues in an element of the class */
        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_setfield (L, kollos_table_stack_ix, "upvalues");

        --miranda: insert create kollos libmarpa wrapper class tables

          /* Create the SLIF grammar metatable */
          marpa_luaL_newlibtable(L, slg_methods);
          marpa_lua_pushvalue(L, upvalue_stack_ix);
          marpa_luaL_setfuncs(L, slg_methods, 1);
          marpa_lua_pushvalue(L, -1);
          marpa_lua_setfield(L, -2, "__index");
          marpa_lua_pushvalue(L, -1);
          marpa_lua_setfield(L, kollos_table_stack_ix, "class_slg");
          marpa_lua_pushvalue(L, kollos_table_stack_ix);
          marpa_lua_setfield(L, -2, "kollos");

          /* Create the SLIF grammar metatable */
          marpa_luaL_newlibtable(L, slr_methods);
          marpa_lua_pushvalue(L, upvalue_stack_ix);
          marpa_luaL_setfuncs(L, slr_methods, 1);
          marpa_lua_pushvalue(L, -1);
          marpa_lua_setfield(L, -2, "__index");
          marpa_lua_pushvalue(L, -1);
          marpa_lua_setfield(L, kollos_table_stack_ix, "class_slr");
          marpa_lua_pushvalue(L, kollos_table_stack_ix);
          marpa_lua_setfield(L, -2, "kollos");

        /* Set up Kollos grammar userdata metatable */
        marpa_lua_newtable (L);
        /* [ kollos, mt_ud_g ] */
        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_pushcclosure (L, l_grammar_ud_mt_gc, 1);
        /* [ kollos, mt_g_ud, gc_function ] */
        marpa_lua_setfield (L, -2, "__gc");
        /* [ kollos, mt_g_ud ] */
        marpa_lua_rawsetp (L, LUA_REGISTRYINDEX, &kollos_g_ud_mt_key);
        /* [ kollos ] */

        /* Set up Kollos recce userdata metatable */
        marpa_lua_newtable (L);
        /* [ kollos, mt_ud_r ] */
        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_pushcclosure (L, l_recce_ud_mt_gc, 1);
        /* [ kollos, mt_r_ud, gc_function ] */
        marpa_lua_setfield (L, -2, "__gc");
        /* [ kollos, mt_r_ud ] */
        marpa_lua_rawsetp (L, LUA_REGISTRYINDEX, &kollos_r_ud_mt_key);
        /* [ kollos ] */

        /* Set up Kollos bocage userdata metatable */
        marpa_lua_newtable (L);
        /* [ kollos, mt_ud_bocage ] */
        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_pushcclosure (L, l_bocage_ud_mt_gc, 1);
        /* [ kollos, mt_b_ud, gc_function ] */
        marpa_lua_setfield (L, -2, "__gc");
        /* [ kollos, mt_b_ud ] */
        marpa_lua_rawsetp (L, LUA_REGISTRYINDEX, &kollos_b_ud_mt_key);
        /* [ kollos ] */

        /* Set up Kollos order userdata metatable */
        marpa_lua_newtable (L);
        /* [ kollos, mt_ud_order ] */
        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_pushcclosure (L, l_order_ud_mt_gc, 1);
        /* [ kollos, mt_o_ud, gc_function ] */
        marpa_lua_setfield (L, -2, "__gc");
        /* [ kollos, mt_o_ud ] */
        marpa_lua_rawsetp (L, LUA_REGISTRYINDEX, &kollos_o_ud_mt_key);
        /* [ kollos ] */

        /* Set up Kollos tree userdata metatable */
        marpa_lua_newtable (L);
        /* [ kollos, mt_ud_tree ] */
        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_pushcclosure (L, l_tree_ud_mt_gc, 1);
        /* [ kollos, mt_t_ud, gc_function ] */
        marpa_lua_setfield (L, -2, "__gc");
        /* [ kollos, mt_t_ud ] */
        marpa_lua_rawsetp (L, LUA_REGISTRYINDEX, &kollos_t_ud_mt_key);
        /* [ kollos ] */

        /* Set up Kollos value userdata metatable */
        marpa_lua_newtable (L);
        /* [ kollos, mt_ud_value ] */
        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_pushcclosure (L, l_value_ud_mt_gc, 1);
        /* [ kollos, mt_v_ud, gc_function ] */
        marpa_lua_setfield (L, -2, "__gc");
        /* [ kollos, mt_v_ud ] */
        marpa_lua_rawsetp (L, LUA_REGISTRYINDEX, &kollos_v_ud_mt_key);
        /* [ kollos ] */

        -- miranda: insert set up empty metatables

        /* In alphabetical order by field name */

        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_pushcclosure (L, lca_error_description_by_code, 1);
        /* [ kollos, function ] */
        marpa_lua_setfield (L, kollos_table_stack_ix, "error_description");
        /* [ kollos ] */

        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_pushcclosure (L, lca_error_name_by_code, 1);
        marpa_lua_setfield (L, kollos_table_stack_ix, "error_name");

        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_pushcclosure (L, lca_event_name_by_code, 1);
        marpa_lua_setfield (L, kollos_table_stack_ix, "event_name");

        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_pushcclosure (L, lca_event_description_by_code, 1);
        marpa_lua_setfield (L, kollos_table_stack_ix, "event_description");

        /* In Libmarpa object sequence order */

        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_getfield (L, kollos_table_stack_ix, "class_grammar");
        marpa_lua_pushcclosure (L, lca_grammar_new, 2);
        marpa_lua_setfield (L, kollos_table_stack_ix, "grammar_new");

        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_getfield (L, kollos_table_stack_ix, "class_recce");
        marpa_lua_pushcclosure (L, lca_grammar_event, 1);
        marpa_lua_setfield (L, kollos_table_stack_ix, "grammar_event");

        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_getfield (L, kollos_table_stack_ix, "class_recce");
        marpa_lua_pushcclosure (L, wrap_recce_new, 2);
        marpa_lua_setfield (L, kollos_table_stack_ix, "recce_new");

        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_getfield (L, kollos_table_stack_ix, "class_bocage");
        marpa_lua_pushcclosure (L, wrap_bocage_new, 2);
        marpa_lua_setfield (L, kollos_table_stack_ix, "bocage_new");

        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_getfield (L, kollos_table_stack_ix, "class_order");
        marpa_lua_pushcclosure (L, wrap_order_new, 2);
        marpa_lua_setfield (L, kollos_table_stack_ix, "order_new");

        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_getfield (L, kollos_table_stack_ix, "class_tree");
        marpa_lua_pushcclosure (L, wrap_tree_new, 2);
        marpa_lua_setfield (L, kollos_table_stack_ix, "tree_new");

        marpa_lua_pushvalue (L, upvalue_stack_ix);
        marpa_lua_getfield (L, kollos_table_stack_ix, "class_value");
        marpa_lua_pushcclosure (L, wrap_value_new, 2);
        marpa_lua_setfield (L, kollos_table_stack_ix, "value_new");

        marpa_lua_newtable (L);
        /* [ kollos, error_code_table ] */
        {
            const int name_table_stack_ix = marpa_lua_gettop (L);
            int error_code;
            for (error_code = LIBMARPA_MIN_ERROR_CODE;
                error_code <= LIBMARPA_MAX_ERROR_CODE; error_code++) {
                marpa_lua_pushinteger (L, (lua_Integer) error_code);
                marpa_lua_setfield (L, name_table_stack_ix,
                    marpa_error_codes[error_code -
                        LIBMARPA_MIN_ERROR_CODE].mnemonic);
            }
            for (error_code = KOLLOS_MIN_ERROR_CODE;
                error_code <= KOLLOS_MAX_ERROR_CODE; error_code++) {
                marpa_lua_pushinteger (L, (lua_Integer) error_code);
                marpa_lua_setfield (L, name_table_stack_ix,
                    marpa_kollos_error_codes[error_code -
                        KOLLOS_MIN_ERROR_CODE].mnemonic);
            }
        }

        /* [ kollos, error_code_table ] */
        marpa_lua_setfield (L, kollos_table_stack_ix, "error_code_by_name");

        marpa_lua_newtable (L);
        /* [ kollos, event_code_table ] */
        {
            const int name_table_stack_ix = marpa_lua_gettop (L);
            int event_code;
            for (event_code = LIBMARPA_MIN_EVENT_CODE;
                event_code <= LIBMARPA_MAX_EVENT_CODE; event_code++) {
                marpa_lua_pushinteger (L, (lua_Integer) event_code);
                marpa_lua_setfield (L, name_table_stack_ix,
                    marpa_event_codes[event_code -
                        LIBMARPA_MIN_EVENT_CODE].mnemonic);
            }
        }

        /* [ kollos, event_code_table ] */
        marpa_lua_setfield (L, kollos_table_stack_ix, "event_code_by_name");

        -- miranda: insert register standard libmarpa wrappers

            /* [ kollos ] */

        -- miranda: insert create tree export operations

        marpa_lua_settop (L, kollos_table_stack_ix);
        /* [ kollos ] */
        return 1;
    }

```

### Create a sandbox

Create a table, which can be used
as a "sandbox" for protect the global environment
from user code.
This code only creates the sandbox, it does not
set it as an environment -- it is assumed that
that will be done later,
after to-be-sandboxed Lua code is loaded,
but before it is executed.

```
    -- miranda: section create sandbox table

    local sandbox = {}
    _M.sandbox = sandbox
    sandbox.__index = _G
    setmetatable(sandbox, sandbox)

```

### Preliminaries to the C library code
```
    -- miranda: section preliminaries to the c library code
    /*
    ** Permission is hereby granted, free of charge, to any person obtaining
    ** a copy of this software and associated documentation files (the
    ** "Software"), to deal in the Software without restriction, including
    ** without limitation the rights to use, copy, modify, merge, publish,
    ** distribute, sublicense, and/or sell copies of the Software, and to
    ** permit persons to whom the Software is furnished to do so, subject to
    ** the following conditions:
    **
    ** The above copyright notice and this permission notice shall be
    ** included in all copies or substantial portions of the Software.
    **
    ** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    ** EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    ** MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    ** IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    ** CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    ** TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    ** SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    **
    ** [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
    */

    /* EDITS IN THIS FILE WILL BE LOST
     * This file is auto-generated.
     */

    #include "marpa.h"
    #include "kollos.h"

    #undef UNUSED
    #if     __GNUC__ >  2 || (__GNUC__ == 2 && __GNUC_MINOR__ >  4)
    #define UNUSED __attribute__((__unused__))
    #else
    #define UNUSED
    #endif

    #if defined(_MSC_VER)
    #define inline __inline
    #define __PRETTY_FUNCTION__ __FUNCTION__
    #endif

    #define EXPECTED_LIBMARPA_MAJOR 8
    #define EXPECTED_LIBMARPA_MINOR 6
    #define EXPECTED_LIBMARPA_MICRO 0

```

## The Kollos C header file

```
    -- miranda: section kollos_h
    -- miranda: language c
    -- miranda: insert preliminary comments of the c header file

    #ifndef KOLLOS_H
    #define KOLLOS_H

    #include "lua.h"
    #include "lauxlib.h"
    #include "lualib.h"

    -- miranda: insert temporary defines
    -- miranda: insert C extern variables
    -- miranda: insert C function declarations

    #endif

    /* vim: set expandtab shiftwidth=4: */
```

### Preliminaries to the C header file
```
    -- miranda: section preliminary comments of the c header file

    /*
     * Copyright 2017 Jeffrey Kegler
     * Permission is hereby granted, free of charge, to any person obtaining a
     * copy of this software and associated documentation files (the "Software"),
     * to deal in the Software without restriction, including without limitation
     * the rights to use, copy, modify, merge, publish, distribute, sublicense,
     * and/or sell copies of the Software, and to permit persons to whom the
     * Software is furnished to do so, subject to the following conditions:
     *
     * The above copyright notice and this permission notice shall be included
     * in all copies or substantial portions of the Software.
     *
     * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
     * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
     * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
     * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
     * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
     * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
     * OTHER DEALINGS IN THE SOFTWARE.
     */

    /* EDITS IN THIS FILE WILL BE LOST
     * This file is auto-generated.
     */

```

## Meta-coding utilities

### Metacode execution sequence

```
    -- miranda: sequence-exec argument processing
    -- miranda: sequence-exec metacode utilities
    -- miranda: sequence-exec libmarpa interface globals
    -- miranda: sequence-exec declare standard libmarpa wrappers
    -- miranda: sequence-exec register standard libmarpa wrappers
    -- miranda: sequence-exec create kollos libmarpa wrapper class tables
    -- miranda: sequence-exec object userdata gc methods
    -- miranda: sequence-exec create metal tables
```

### Dedent method

A pipe symbol is used when inlining code to separate the code's indentation
from the indentation used to display the code in this document.
The `pipe_dedent` method removes the display indentation.

```
    --[==[ miranda: exec metacode utilities
    function pipe_dedent(code)
        return code:gsub('\n *|', '\n'):gsub('^ *|', '', 1)
    end
    ]==]
```

### `c_safe_string` method

```
    --[==[ miranda: exec metacode utilities
    local function c_safe_string (s)
        s = string.gsub(s, '"', '\\034')
        s = string.gsub(s, '\\', '\\092')
        s = string.gsub(s, '\n', '\\n')
        return '"' .. s .. '"'
    end
    ]==]

```

### Meta code argument processing

The arguments show where to find the files containing event
and error codes.

```
    -- assumes that, when called, out_file to set to output file
    --[==[ miranda: exec argument processing
    local error_file
    local event_file

    for _,v in ipairs(arg) do
       if not v:find("=")
       then return nil, "Bad options: ", arg end
       local id, val = v:match("^([^=]+)%=(.*)") -- no space around =
       if id == "out" then io.output(val)
       elseif id == "errors" then error_file = val
       elseif id == "events" then event_file = val
       else return nil, "Bad id in options: ", id end
    end
    ]==]
```

## Kollos utilities

```
    -- miranda: section+ most Lua function definitions
    function _M.posix_lc(str)
       return str:gsub('[A-Z]', function(str) return string.char(string.byte(str)) end)
    end

```

<!--
vim: expandtab shiftwidth=4:
-->
