<!--
Copyright 2016 Jeffrey Kegler
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

# The Perl-to-Kollos glue code

# Table of contents
<!--
../lua/lua ../kollos/toc.lua < glue.lua.md
-->
* [About the glue code](#about-the-glue-code)
* [The by-tag code cache](#the-by-tag-code-cache)
* [The main Lua code file](#the-main-lua-code-file)
  * [Preliminaries to the main code](#preliminaries-to-the-main-code)

## About the glue code

This is the code for the glue
code between Perl and Kollos.
Kollos is the "middle layer" of Marpa.

This document is evolving.
In particular, the boundard between Kollos and its glue
code has not solidified yet.

Also undetermined is how to deal with Lua name space.
Can I assume this "glue" code is in charge of the global
namespace, or should it be organized as a package?
For now, I am just dumping everything into the global namespace.

## The by-tag code cache

Caches functions by "tag".
This is done to avoid the overhead of repeatedly compiling
the Lua code.
Eventually all such code should be named and
moved into Kollos,
or into these "glue" routines.
But that may take a while, and in the meantime
we may want meaningful performance numbers.

```
    -- miranda: section+ Lua declarations
    _M.code_by_tag = {}

```

## The main Lua code file

```
    -- miranda: section main
    -- miranda: insert legal preliminaries
    -- miranda: insert luacheck declarations
    -- miranda: insert enforce strict globals

    inspect = require "inspect"
    kollos = require "kollos"

    -- TODO delete following 2 lines
    -- print('_G: ', inspect(_G, { depth = 1 }))
    -- print('kollos: ', inspect(kollos, { depth = 1 }))

    local _M = {}

    -- miranda: insert Lua declarations
    -- miranda: insert most Lua function declarations

    return _M

    -- vim: set expandtab shiftwidth=4:
```

### Preliminaries to the main code

Licensing, etc.

```

    -- miranda: section legal preliminaries

    -- Copyright 2016 Jeffrey Kegler
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

Set "strict" globals, using code taken from strict.lua.

```

    -- miranda: section enforce strict globals
    local strict_mt = {}
    do
        local mt = getmetatable(_G)
        if mt == nil then
          mt = strict_mt
          setmetatable(_G, mt)
        end

        mt.__declared = {}

        local function what ()
          local d = debug.getinfo(3, "S")
          return d and d.what or "C"
        end

        mt.__newindex = function (t, n, v)
          if not mt.__declared[n] then
            local w = what()
            if w ~= "main" and w ~= "C" then
              error("assign to undeclared variable '"..n.."'", 2)
            end
            mt.__declared[n] = true
          end
          rawset(t, n, v)
        end

        mt.__index = function (t, n)
          if not mt.__declared[n] and what() ~= "C" then
            error("variable '"..n.."' is not declared", 2)
          end
          return rawget(t, n)
        end

        function strict_on()
            local G_mt = getmetatable(_G)
            if G_mt == nil then
              setmetatable(_G, strict_mt)
            end
        end

        function strict_off()
            local G_mt = getmetatable(_G)
            if G_mt == strict_mt then
              setmetatable(_G, nil)
            end
        end

        strict = {
            on = strict_on,
            off = strict_off
        }

        package.loaded["strict"] = strict

    end


```

## Dummy C code

```
    -- miranda: section C structure declarations
    struct glue_dummy {
        int dummy;
    };

    -- miranda: section C structure definitions

    /* For now something so that the file isn't empty */
    struct glue_dummy marpa_glue_dummy;

```

## The Perl-to-Kollos Glue C code file

```
    -- miranda: section glue_c
    -- miranda: language c
    -- miranda: insert preliminaries to the c library code

    -- miranda: insert C structure definitions

    /* vim: set expandtab shiftwidth=4: */
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
    #include "glue.h"

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
    #define EXPECTED_LIBMARPA_MINOR 4
    #define EXPECTED_LIBMARPA_MICRO 0

```

## The Perl-to-Kollos Glue C header file

```
    -- miranda: section glue_h
    -- miranda: language c
    -- miranda: insert preliminary comments of the c header file

    #ifndef GLUE_H
    #define GLUE_H

    #include "lua.h"
    #include "lauxlib.h"
    #include "lualib.h"

    -- miranda: insert C structure declarations

    #endif

    /* vim: set expandtab shiftwidth=4: */
```

### Preliminaries to the C header file

```
    -- miranda: section preliminary comments of the c header file

    /*
     * Copyright 2016 Jeffrey Kegler
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
Nothing here, for now.
```
    -- miranda: sequence-exec argument processing
    -- miranda: sequence-exec metacode utilities
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

    for _,v in ipairs(arg) do
       if not v:find("=")
       then return nil, "Bad options: ", arg end
       local id, val = v:match("^([^=]+)%=(.*)") -- no space around =
       if id == "out" then io.output(val)
       else return nil, "Bad id in options: ", id end
    end
    ]==]
```

## Kollos utilities

```
    -- miranda: section+ most Lua function declarations
    function _M.posix_lc(str)
       return str:gsub('[A-Z]', function(str) return string.char(string.byte(str)) end)
    end

```

<!--
vim: expandtab shiftwidth=4:
-->
