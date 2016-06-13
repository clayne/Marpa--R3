--[[

This is meta-programming -- Lua code that writes C code.  Meta-programming
introduces a lot of additonal complexity for each line.  It's often
far more trouble than it is worth.  But in this case, just one of its
advantages, the automated generation of Lua wrappers for the libmarpa
methods allows the elimination of thousands of lines of code.

--]]

-- luacheck: std lua51

-- assumes that, when called, out_file to set to output file
local error_file
local event_file

local function c_safe_string (s)
    s = string.gsub(s, '"', '\\034')
    s = string.gsub(s, '\\', '\\092')
    return '"' .. s .. '"'
end

for _,v in ipairs(arg) do
   if not v:find("=")
   then return nil, "Bad options: ", arg end
   local id, val = v:match("^([^=]+)%=(.*)") -- no space around =
   if id == "out" then io.output(val)
   elseif id == "errors" then error_file = val
   elseif id == "events" then event_file = val
   else return nil, "Bad id in options: ", id end
end

-- initial piece
io.write[=[
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

#define LUA_LIB
#include "marpa.h"
#include "lua.h"
#include "lauxlib.h"

#include "compat-5.2.c"

#undef UNUSED
#if     __GNUC__ >  2 || (__GNUC__ == 2 && __GNUC_MINOR__ >  4)
#define UNUSED __attribute__((__unused__))
#else
#define UNUSED
#endif

#define EXPECTED_LIBMARPA_MAJOR 8
#define EXPECTED_LIBMARPA_MINOR 3
#define EXPECTED_LIBMARPA_MICRO 0

/* For debugging */
static void dump_stack (lua_State *L) {
      int i;
      int top = lua_gettop(L);
      for (i = 1; i <= top; i++) {  /* repeat for each level */
        int t = lua_type(L, i);
        switch (t) {
    
          case LUA_TSTRING:  /* strings */
            printf("`%s'", lua_tostring(L, i));
            break;
    
          case LUA_TBOOLEAN:  /* booleans */
            printf(lua_toboolean(L, i) ? "true" : "false");
            break;
    
          case LUA_TNUMBER:  /* numbers */
            printf("%g", lua_tonumber(L, i));
            break;
    
          default:  /* other values */
            printf("%s", lua_typename(L, t));
            break;
    
        }
        printf("  ");  /* put a separator */
      }
      printf("\n");  /* end the listing */
}

static void dump_table(lua_State *L, int raw_table_index)
{
    /* Original stack: [ ... ] */
    const int table_index = lua_absindex(L, raw_table_index);
    lua_pushnil(L);
    /* [ ..., nil ] */
    while (lua_next(L, table_index))
    {
        /* [ ..., key, value ] */
        const int value_stack_ix = lua_gettop(L);
        const int key_stack_ix = lua_gettop(L)+1;
        /* Copy the key, because lua_tostring() can be destructive */
        lua_pushvalue(L, -2);
        /* [ ..., key, value, key_copy ] */
        switch (lua_type(L, key_stack_ix)) {
    
          case LUA_TSTRING:  /* strings */
            printf("`%s'", lua_tostring(L, key_stack_ix));
            break;
    
          case LUA_TBOOLEAN:  /* booleans */
            printf(lua_toboolean(L, key_stack_ix) ? "true" : "false");
            break;
    
          case LUA_TNUMBER:  /* numbers */
            printf("%g", lua_tonumber(L, key_stack_ix));
            break;
    
          case LUA_TTABLE:  /* numbers */
            printf("table %s", lua_tostring(L, key_stack_ix));
            break;
    
          default:  /* other values */
            printf("%s", lua_typename(L, lua_type(L, key_stack_ix)));
            break;
    
        }
        printf(" -> ");  /* end the listing */
        switch (lua_type(L, value_stack_ix)) {
    
          case LUA_TSTRING:  /* strings */
            printf("`%s'", lua_tostring(L, value_stack_ix));
            break;
    
          case LUA_TBOOLEAN:  /* booleans */
            printf(lua_toboolean(L, value_stack_ix) ? "true" : "false");
            break;
    
          case LUA_TNUMBER:  /* numbers */
            printf("%g", lua_tonumber(L, value_stack_ix));
            break;
    
          case LUA_TTABLE:  /* numbers */
            printf("table %s", lua_tostring(L, value_stack_ix));
            break;
    
          default:  /* other values */
            printf("%s", lua_typename(L, lua_type(L, value_stack_ix)));
            break;
    
        }
        printf("\n");  /* end the listing */
        /* [ ..., key, value, key_copy ] */
        lua_pop(L, 2);
        /* [ ..., key ] */
    }
    /* Back to original stack: [ ... ] */
}

]=]

-- error codes

io.write[=[
struct s_libmarpa_error_code {
   lua_Integer code;
   const char* mnemonic;
   const char* description;
};

]=]

do
    local f = assert(io.open(error_file, "r"))
    local code_lines = {}
    local code_mnemonics = {}
    local max_code = 0
    while true do
        local line = f:read()
        if line == nil then break end
        local i,_ = string.find(line, "#")
        local stripped
        if (i == nil) then stripped = line
        else stripped = string.sub(line, 0, i-1)
        end
        if string.find(stripped, "%S") then
            local raw_code
            local raw_mnemonic
            local description
            _, _, raw_code, raw_mnemonic, description = string.find(stripped, "^(%d+)%sMARPA_ERR_(%S+)%s(.*)$")
            local code = tonumber(raw_code)
            if description == nil then return nil, "Bad line in error code file ", line end
            if code > max_code then max_code = code end
            local mnemonic = 'LUIF_ERR_' .. raw_mnemonic
            code_mnemonics[code] = mnemonic
            code_lines[code] = string.format( '   { %d, %s, %s },',
                code,
                c_safe_string(mnemonic),
                c_safe_string(description)
                )
        end
    end

    io.write('#define LIBMARPA_MIN_ERROR_CODE 0\n')
    io.write('#define LIBMARPA_MAX_ERROR_CODE ' .. max_code .. '\n\n')

    for i = 0, max_code do
        local mnemonic = code_mnemonics[i]
        if mnemonic then
            io.write(
                   string.format('#define %s %d\n', mnemonic, i)
           )
       end
    end
    io.write('\n')
    io.write('struct s_libmarpa_error_code libmarpa_error_codes[LIBMARPA_MAX_ERROR_CODE-LIBMARPA_MIN_ERROR_CODE+1] = {\n')
    for i = 0, max_code do
        local code_line = code_lines[i]
        if code_line then
           io.write(code_line .. '\n')
        else
           io.write(
               string.format(
                   '    { %d, "LUIF_ERROR_RESERVED", "Unknown Libmarpa error %d" },\n',
                   i, i
               )
           )
        end
    end
    io.write('};\n\n');
    f:close()
end

-- for Kollos's own (that is, non-Libmarpa) error codes
do
    local code_lines = {}
    local code_mnemonics = {}
    local min_code = 200
    local max_code = 200

    -- Should add some checks on the errors, checking for
    -- 1.) duplicate mnenomics
    -- 2.) duplicate error codes

    local function luif_error_add (code, mnemonic, description)
        code_mnemonics[code] = mnemonic
        code_lines[code] = string.format( '   { %d, %s, %s },',
            code,
            c_safe_string(mnemonic),
            c_safe_string(description)
            )
        if code > max_code then max_code = code end
    end

    -- LUIF_ERR_RESERVED_200 is a place-holder , not expected to be actually used
    luif_error_add( 200, "LUIF_ERR_RESERVED_200", "Unexpected Kollos error: 200")
    luif_error_add( 201, "LUIF_ERR_LUA_VERSION", "Bad Lua version")
    luif_error_add( 202, "LUIF_ERR_LIBMARPA_HEADER_VERSION_MISMATCH", "Libmarpa header does not match expected version")
    luif_error_add( 203, "LUIF_ERR_LIBMARPA_LIBRARY_VERSION_MISMATCH", "Libmarpa library does not match expected version")

    io.write('#define KOLLOS_MIN_ERROR_CODE ' .. min_code .. '\n')
    io.write('#define KOLLOS_MAX_ERROR_CODE ' .. max_code .. '\n\n')
    for i = min_code, max_code
    do
        local mnemonic = code_mnemonics[i]
        if mnemonic then
            io.write(
                   string.format('#define %s %d\n', mnemonic, i)
           )
       end
    end

    io.write('\n')
    io.write('struct s_libmarpa_error_code kollos_error_codes[(KOLLOS_MAX_ERROR_CODE-KOLLOS_MIN_ERROR_CODE)+1] = {\n')
    for i = min_code, max_code do
        local code_line = code_lines[i]
        if code_line then
           io.write(code_line .. '\n')
        else
           io.write(
               string.format(
                   '    { %d, "LUIF_ERROR_RESERVED", "Unknown Kollos error %d" },\n',
                   i, i
               )
           )
        end
    end
    io.write('};\n\n');

end

-- error objects
--
-- There are written in C, but not because of efficiency --
-- efficiency is not needed, and in any case, when the overhead
-- from the use of the debug calls is considered, is not really
-- gained.
--
-- The reason for the use of C is that the error routines
-- must be available for use inside both C and Lua, and must
-- also be available as early as possible during set up.
-- It's possible to run Lua code both inside C and early in
-- the set up, but the added unclarity, complexity from issues
-- of error reporting for the Lua code, etc., etc. mean that
-- it actually is easier to write them in C than in Lua.

io.write[=[

static inline const char* error_description_by_code(lua_Integer error_code)
{
   if (error_code >= LIBMARPA_MIN_ERROR_CODE && error_code <= LIBMARPA_MAX_ERROR_CODE) {
       return libmarpa_error_codes[error_code-LIBMARPA_MIN_ERROR_CODE].description;
   }
   if (error_code >= KOLLOS_MIN_ERROR_CODE && error_code <= KOLLOS_MAX_ERROR_CODE) {
       return kollos_error_codes[error_code-KOLLOS_MIN_ERROR_CODE].description;
   }
   return (const char *)0;
}

static inline int l_error_description_by_code(lua_State* L)
{
   const lua_Integer error_code = luaL_checkinteger(L, 1);
   const char* description = error_description_by_code(error_code);
   if (description)
   {
       lua_pushstring(L, description);
   } else {
       lua_pushfstring(L, "Unknown error code (%d)", error_code);
   }
   return 1;
}
 
static inline const char* error_name_by_code(lua_Integer error_code)
{
   if (error_code >= LIBMARPA_MIN_ERROR_CODE && error_code <= LIBMARPA_MAX_ERROR_CODE) {
       return libmarpa_error_codes[error_code-LIBMARPA_MIN_ERROR_CODE].mnemonic;
   }
   if (error_code >= KOLLOS_MIN_ERROR_CODE && error_code <= KOLLOS_MAX_ERROR_CODE) {
       return kollos_error_codes[error_code-KOLLOS_MIN_ERROR_CODE].mnemonic;
   }
   return (const char *)0;
}

static inline int l_error_name_by_code(lua_State* L)
{
   const lua_Integer error_code = luaL_checkinteger(L, 1);
   const char* mnemonic = error_name_by_code(error_code);
   if (mnemonic)
   {
       lua_pushstring(L, mnemonic);
   } else {
       lua_pushfstring(L, "Unknown error code (%d)", error_code);
   }
   return 1;
}
 
]=]

-- event codes

io.write[=[

struct s_libmarpa_event_code {
   lua_Integer code;
   const char* mnemonic;
   const char* description;
};

]=]

do
    local f = assert(io.open(event_file, "r"))
    local code_lines = {}
    local code_mnemonics = {}
    local max_code = 0
    while true do
        local line = f:read()
        if line == nil then break end
        local i,_ = string.find(line, "#")
        local stripped
        if (i == nil) then stripped = line
        else stripped = string.sub(line, 0, i-1)
        end
        if string.find(stripped, "%S") then
            local raw_code
            local raw_mnemonic
            local description
            _, _, raw_code, raw_mnemonic, description = string.find(stripped, "^(%d+)%sMARPA_EVENT_(%S+)%s(.*)$")
            local code = tonumber(raw_code)
            if description == nil then return nil, "Bad line in event code file ", line end
            if code > max_code then max_code = code end
            local mnemonic = 'LIBMARPA_EVENT_' .. raw_mnemonic
            code_mnemonics[code] = mnemonic
            code_lines[code] = string.format( '   { %d, %s, %s },',
                code,
                c_safe_string(mnemonic),
                c_safe_string(description)
                )
        end
    end

    io.write('#define LIBMARPA_MIN_EVENT_CODE 0\n')
    io.write('#define LIBMARPA_MAX_EVENT_CODE ' .. max_code .. '\n\n')

    for i = 0, max_code do
        local mnemonic = code_mnemonics[i]
        if mnemonic then
            io.write(
                   string.format('#define %s %d\n', mnemonic, i)
           )
       end
    end
    io.write('\n')
    io.write('struct s_libmarpa_event_code libmarpa_event_codes[LIBMARPA_MAX_EVENT_CODE-LIBMARPA_MIN_EVENT_CODE+1] = {\n')
    for i = 0, max_code do
        local code_line = code_lines[i]
        if code_line then
           io.write(code_line .. '\n')
        else
           io.write(
               string.format(
                   '    { %d, "LUIF_EVENT_RESERVED", "Unknown Libmarpa event %d" },\n',
                   i, i
               )
           )
        end
    end
    io.write('};\n\n');
    f:close()
end

io.write[=[

static inline const char* event_description_by_code(lua_Integer event_code)
{
   if (event_code >= LIBMARPA_MIN_EVENT_CODE && event_code <= LIBMARPA_MAX_EVENT_CODE) {
       return libmarpa_event_codes[event_code-LIBMARPA_MIN_EVENT_CODE].description;
   }
   return (const char *)0;
}

static inline int l_event_description_by_code(lua_State* L)
{
   const lua_Integer event_code = luaL_checkinteger(L, 1);
   const char* description = event_description_by_code(event_code);
   if (description)
   {
       lua_pushstring(L, description);
   } else {
       lua_pushfstring(L, "Unknown event code (%d)", event_code);
   }
   return 1;
}
 
static inline const char* event_name_by_code(lua_Integer event_code)
{
   if (event_code >= LIBMARPA_MIN_EVENT_CODE && event_code <= LIBMARPA_MAX_EVENT_CODE) {
       return libmarpa_event_codes[event_code-LIBMARPA_MIN_EVENT_CODE].mnemonic;
   }
   return (const char *)0;
}

static inline int l_event_name_by_code(lua_State* L)
{
   const lua_Integer event_code = luaL_checkinteger(L, 1);
   const char* mnemonic = event_name_by_code(event_code);
   if (mnemonic)
   {
       lua_pushstring(L, mnemonic);
   } else {
       lua_pushfstring(L, "Unknown event code (%d)", event_code);
   }
   return 1;
}
 
]=]

io.write[=[

/* userdata metatable keys
   The contents of these locations are never examined.
   These location are used as a key in the Lua registry.
   This guarantees that the key will be unique
   within the Lua state.
*/
static char kollos_error_mt_key;
static char kollos_g_ud_mt_key;
static char kollos_r_ud_mt_key;
static char kollos_b_ud_mt_key;
static char kollos_o_ud_mt_key;
static char kollos_t_ud_mt_key;
static char kollos_v_ud_mt_key;

/* Leaves the stack as before,
   except with the error object on top */
static inline void kollos_error(lua_State* L,
    Marpa_Error_Code code, const char* details)
{
   const int error_object_stack_ix = lua_gettop(L)+1;
   lua_newtable(L);
   /* [ ..., error_object ] */
   lua_rawgetp(L, LUA_REGISTRYINDEX, &kollos_error_mt_key);
   /* [ ..., error_object, error_metatable ] */
   lua_setmetatable(L, error_object_stack_ix);
   /* [ ..., error_object ] */
   lua_pushinteger(L, (lua_Integer)code);
   lua_setfield(L, error_object_stack_ix, "code" );
  if (0) printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
  if (0) printf ("%s code = %d\n", __PRETTY_FUNCTION__, code);
   /* [ ..., error_object ] */
   lua_pushstring(L, details);
   lua_setfield(L, error_object_stack_ix, "details" );
   /* [ ..., error_object ] */
}

static int l_error_new(lua_State* L)
{
  if (lua_istable (L, 1))
    {
      const int table_ix = 1;
      lua_getfield (L, table_ix, "code");
      /* [ error_table,  code ] */
      if (!lua_isnumber (L, -1))
	{
	  /* Want a special code for this, eventually */
	  const Marpa_Error_Code code = MARPA_ERR_DEVELOPMENT;
	  lua_pushinteger (L, (lua_Integer) code);
	  lua_setfield (L, table_ix, "code");
	}
      lua_pop (L, 1);
      lua_rawgetp (L, LUA_REGISTRYINDEX, &kollos_error_mt_key);
      /* [ error_table, error_metatable ] */
      lua_setmetatable (L, table_ix);
      /* [ error_table ] */
      return 1;
    }
  if (lua_isnumber (L, 1))
    {
      const Marpa_Error_Code code = lua_tointeger (L, 1);
      const char *details = lua_tostring (L, 2);
      lua_pop (L, 2);
      kollos_error (L, code, details);
      return 1;
    }
  {
    /* Want a special code for this, eventually */
    const Marpa_Error_Code code = MARPA_ERR_DEVELOPMENT;
    const char *details = "Error code is not a number";
    kollos_error (L, code, details);
    return 1;
  }
}

/* Replace an error object, on top of the stack,
   with its string equivalent
 */
static inline void error_tostring(lua_State* L)
{
  Marpa_Error_Code error_code = -1;
  const int error_object_ix = lua_gettop (L);
  const char *temp_string;

  /* Room for details, code, mnemonic, description,
   * plus separators before and after: 4*3 = 12
   */
  luaL_checkstack (L, 12, "not enough stack for error_tostring()");

  lua_getfield (L, error_object_ix, "string");

  /* [ ..., error_object, string ] */

  if (0) printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
  /* If present, a "string" overrides everything else */
  if (lua_isstring (L, -1))
    {
      lua_replace (L, error_object_ix);
      return;
    }

  /* [ ..., error_object, bad-string ] */
  lua_pop (L, 1);
  /* [ ..., error_object ] */

  lua_getfield (L, error_object_ix, "details");
  /* [ ..., error_object, details ] */
  if (lua_isstring (L, -1))
    {
      lua_pushstring (L, ": ");
    }
  else
    {
      lua_pop (L, 1);
    }

  /* [ ..., error_object ] */
  lua_getfield (L, error_object_ix, "code");
  /* [ ..., error_object, code ] */
  if (0) printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
  if (!lua_isnumber (L, -1))
    {
      lua_pop (L, 1);
      lua_pushstring (L, "[No error code]");
    }
  else
    {
      error_code = lua_tointeger (L, -1);
      /* Concatenation will eventually convert a numeric
       * code on top of the stack to a string, so we do
       * nothing with it here.
       */
    }

  lua_pushstring (L, " ");	/* Add space separator */

  temp_string = error_name_by_code (error_code);
  if (temp_string)
    {
      lua_pushstring (L, temp_string);
    }
  else
    {
      lua_pushfstring (L, "Unknown error code (%d)", (int) error_code);
    }
  lua_pushstring (L, " ");	/* Add space separator */

  temp_string = error_description_by_code (error_code);
  lua_pushstring (L, temp_string ? temp_string : "[no description]");
  lua_pushstring (L, "\n");	/* Add space separator */

  if (0) printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
  lua_concat (L, lua_gettop (L) - error_object_ix);
  /* stack is [ ..., error_object, concatenated_result ] */
  lua_replace (L, error_object_ix);
  /* [ ..., concatenated_result ] */
}
  
static inline int kollos_throw(lua_State* L,
    Marpa_Error_Code code, const char* details)
{
   kollos_error(L, code, details);
   error_tostring(L);
   return lua_error(L);
}

/* not safe - intended for internal use */
static inline int wrap_kollos_throw(lua_State* L)
{
   const Marpa_Error_Code code = lua_tointeger(L, 1);
   const char* details = lua_tostring(L, 2);
  if (0) printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
  if (0) printf ("%s code = %d\n", __PRETTY_FUNCTION__, code);
   return kollos_throw(L, code, details);
   /* NOTREACHED */
}

]=]

-- functions

io.write[=[

static void luif_err_throw(lua_State *L, int error_code) {

#if 0
    const char *where;
    luaL_where(L, 1);
    where = lua_tostring(L, -1);
#endif

    if (error_code < LIBMARPA_MIN_ERROR_CODE || error_code > LIBMARPA_MAX_ERROR_CODE) {
        luaL_error(L, "Libmarpa returned invalid error code %d", error_code);
    }
    luaL_error(L, "%s", libmarpa_error_codes[error_code].description );
}

static void luif_err_throw2(lua_State *L, int error_code, const char *msg) {

#if 0
    const char *where;
    luaL_where(L, 1);
    where = lua_tostring(L, -1);
#endif

    if (error_code < 0 || error_code > LIBMARPA_MAX_ERROR_CODE) {
        luaL_error(L, "%s\n    Libmarpa returned invalid error code %d", msg, error_code);
    }
    luaL_error(L, "%s\n    %s", msg, libmarpa_error_codes[error_code].description);
}

static void check_libmarpa_table(
    lua_State* L, const char *function_name, int stack_ix, const char *expected_type)
{
  const char *actual_type;
  /* stack is [ ... ] */
  if (!lua_istable (L, stack_ix))
    {
      const char *typename = lua_typename (L, lua_type (L, stack_ix));
      luaL_error (L, "%s arg #1 type is %s, expected table",
		  function_name, typename);
    }
  lua_getfield (L, stack_ix, "_type");
  /* stack is [ ..., field ] */
  if (!lua_isstring (L, -1))
    {
      const char *typename = lua_typename (L, lua_type (L, -1));
      luaL_error (L, "%s arg #1 field '_type' is %s, expected string",
		  function_name, typename);
    }
  actual_type = lua_tostring (L, -1);
  if (strcmp (actual_type, expected_type))
    {
      luaL_error (L, "%s arg #1 table is %s, expected %s",
		  function_name, actual_type, expected_type);
    }
  /* stack is [ ..., field ] */
  lua_pop (L, 1);
  /* stack is [ ... ] */
}

]=]

-- Here are the meta-programmed wrappers --
-- this is Lua code which writes the C code based on
-- a "signature" for the wrapper
--
-- This meta-programming does not attempt to work for
-- all of the wrappers.  It works only when
--   1.) The number of arguments is fixed.
--   2.) Their type is from a fixed list.
--   3.) Converting the return value to int is a good thing to do.
--   4.) Non-negatvie return values indicate success
--   5.) Return values less than -1 indicate failure
--   6.) Return values less than -1 set the error code
--   7.) Return value of -1 is "soft" and returning nil is
--       the right thing to do

local function c_type_of_libmarpa_type(libmarpa_type)
    if (libmarpa_type == 'int') then return 'int' end
    if (libmarpa_type == 'Marpa_Assertion_ID') then return 'int' end
    if (libmarpa_type == 'Marpa_Earley_Item_ID') then return 'int' end
    if (libmarpa_type == 'Marpa_AHM_ID') then return 'int' end
    if (libmarpa_type == 'Marpa_IRL_ID') then return 'int' end
    if (libmarpa_type == 'Marpa_NSY_ID') then return 'int' end
    if (libmarpa_type == 'Marpa_Or_Node_ID') then return 'int' end
    if (libmarpa_type == 'Marpa_And_Node_ID') then return 'int' end
    if (libmarpa_type == 'Marpa_Rank') then return 'int' end
    if (libmarpa_type == 'Marpa_Rule_ID') then return 'int' end
    if (libmarpa_type == 'Marpa_Symbol_ID') then return 'int' end
    if (libmarpa_type == 'Marpa_Earley_Set_ID') then return 'int' end
    return "!UNIMPLEMENTED!";
end

local libmarpa_class_type = {
  g = "Marpa_Grammar",
  r = "Marpa_Recognizer",
  b = "Marpa_Bocage",
  o = "Marpa_Order",
  t = "Marpa_Tree",
  v = "Marpa_Value",
};

local libmarpa_class_name = {
  g = "grammar",
  r = "recce",
  b = "bocage",
  o = "order",
  t = "tree",
  v = "value",
};

local c_fn_signatures = {
  {"marpa_g_completion_symbol_activate", "Marpa_Symbol_ID", "sym_id", "int", "activate"},
  {"marpa_g_error_clear"},
  {"marpa_g_event_count"},
  {"marpa_g_force_valued"},
  {"marpa_g_has_cycle"},
  {"marpa_g_highest_rule_id"},
  {"marpa_g_highest_symbol_id"},
  {"marpa_g_is_precomputed"},
  {"marpa_g_nulled_symbol_activate", "Marpa_Symbol_ID", "sym_id", "int", "activate"},
  {"marpa_g_precompute"},
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
  {"marpa_g_zwa_new", "int", "default_value"},
  {"marpa_g_zwa_place", "Marpa_Assertion_ID", "zwaid", "Marpa_Rule_ID", "xrl_id", "int", "rhs_ix"},
  {"marpa_r_completion_symbol_activate", "Marpa_Symbol_ID", "sym_id", "int", "reactivate"},
  {"marpa_r_alternative", "Marpa_Symbol_ID", "token", "int", "value", "int", "length"}, -- See note
  {"marpa_r_current_earleme"},
  {"marpa_r_earleme_complete"}, -- See note below
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
  {"marpa_v_valued_force"},
  {"marpa_v_rule_is_valued_set", "Marpa_Rule_ID", "symbol_id", "int", "value"},
  {"marpa_v_symbol_is_valued_set", "Marpa_Symbol_ID", "symbol_id", "int", "value"},
  {"_marpa_g_ahm_count"},
  {"_marpa_g_ahm_irl", "Marpa_AHM_ID", "item_id"},
  {"_marpa_g_ahm_position", "Marpa_AHM_ID", "item_id"},
  {"_marpa_g_ahm_postdot", "Marpa_AHM_ID", "item_id"},
  {"_marpa_g_irl_count"},
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
  -- {"_marpa_r_source_token", "int", "*value_p"},
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

-- Here are notes
-- on those methods for which the wrapper requirements are "bent"
-- a little bit.
--
-- marpa_r_alternative() -- generates events
--  Returns an error code.  Since these are always non-negative, from
--  the wrapper's point of view, marpa_r_alternative() always succeeds.
--
-- marpa_r_earleme_complete() -- generates events

local check_for_table_template = [=[
!!INDENT!!check_libmarpa_table(L,
!!INDENT!!  "!!FUNCNAME!!",
!!INDENT!!  self_stack_ix,
!!INDENT!!  "!!CLASS_NAME!!"
!!INDENT!!);
]=]

for ix = 1, #c_fn_signatures do
   local signature = c_fn_signatures[ix]
   local arg_count = math.floor(#signature/2)
   local function_name = signature[1]
   local unprefixed_name = string.gsub(function_name, "^[_]?marpa_", "");
   local class_letter = string.gsub(unprefixed_name, "_.*$", "");
   local wrapper_name = "wrap_" .. unprefixed_name;
   io.write("static int ", wrapper_name, "(lua_State *L)\n");
   io.write("{\n");
   io.write("  ", libmarpa_class_type[class_letter], " self;\n");
   io.write("  const int self_stack_ix = 1;\n");
   io.write("  Marpa_Grammar grammar;\n");
   for arg_ix = 1, arg_count do
     local arg_type = signature[arg_ix*2]
     local arg_name = signature[1 + arg_ix*2]
     io.write("  ", arg_type, " ", arg_name, ";\n");
   end
   io.write("  int result;\n\n");

   -- These wrappers will not be external interfaces
   -- so eventually they will run unsafe.
   -- But for now we check arguments, and we'll leave
   -- the possibility for debugging
   local safe = true;
   if (safe) then
      io.write("  if (1) {\n")

      local check_for_table =
        string.gsub(check_for_table_template, "!!FUNCNAME!!", wrapper_name);
      check_for_table =
        string.gsub(check_for_table, "!!INDENT!!", "    ");
      check_for_table =
        string.gsub(check_for_table, "!!CLASS_NAME!!", libmarpa_class_name[class_letter])
      io.write(check_for_table);
      -- I do not get the values from the integer checks,
      -- because this code
      -- will be turned off most of the time
      for arg_ix = 1, arg_count do
          io.write("    luaL_checkint(L, ", (arg_ix+1), ");\n")
      end
      io.write("  }\n");
   end -- if (!unsafe)

   for arg_ix = arg_count, 1, -1 do
     local arg_type = signature[arg_ix*2]
     local arg_name = signature[1 + arg_ix*2]
     local c_type = c_type_of_libmarpa_type(arg_type)
     assert(c_type == "int", ("type " .. arg_type .. " not implemented"))
     io.write("  ", arg_name, " = lua_tointeger(L, -1);\n")
     io.write("  lua_pop(L, 1);\n")
   end

   io.write('  lua_getfield (L, -1, "_libmarpa");\n')
   -- stack is [ self, self_ud ]
   local cast_to_ptr_to_class_type = "(" ..  libmarpa_class_type[class_letter] .. "*)"
   io.write("  self = *", cast_to_ptr_to_class_type, "lua_touserdata (L, -1);\n")
   io.write("  lua_pop(L, 1);\n")
   -- stack is [ self ]

   io.write('  lua_getfield (L, -1, "_libmarpa_g");\n')
   -- stack is [ self, grammar_ud ]
   io.write("  grammar = *(Marpa_Grammar*)lua_touserdata (L, -1);\n")
   io.write("  lua_pop(L, 1);\n")
   -- stack is [ self ]

   -- assumes converting result to int is safe and right thing to do
   -- if that assumption is wrong, generate the wrapper by hand
   io.write("  result = (int)", function_name, "(self\n")
   for arg_ix = 1, arg_count do
     local arg_name = signature[1 + arg_ix*2]
     io.write("     ,", arg_name, "\n")
   end
   io.write("    );\n")
   io.write("  if (result == -1) { lua_pushnil(L); return 1; }\n")
   io.write("  if (result < -1) {\n")
   io.write("    Marpa_Error_Code marpa_error = marpa_g_error(grammar, NULL);\n")
   io.write("    int throw_flag;\n")
   local wrapper_name_as_c_string = '"' .. wrapper_name .. '()"'
   io.write('    lua_getfield (L, -1, "throw");\n')
   -- stack is [ self, throw_flag ]
   io.write("    throw_flag = lua_toboolean (L, -1);\n")
   io.write('    if (throw_flag) {\n')
   io.write('        kollos_throw( L, marpa_error, ', wrapper_name_as_c_string, ');\n')
   io.write('    }\n')
   io.write("  }\n")
   io.write("  lua_pushinteger(L, (lua_Integer)result);\n")
   io.write("  return 1;\n")
   io.write("}\n\n");

   -- Now write the code that adds the functions to the kollos object

end

-- grammar wrappers which need to be hand written

io.write[=[

/* Handle libmarpa grammar errors in the most usual way.
   Uses 1 position on the stack, and throws the
   error, if so desired.
   The error may not be thrown, and it expects the
   caller to handle any non-thrown error.
*/
static void
common_g_error_handler (lua_State * L,
		      Marpa_Grammar * p_g,
		      int grammar_stack_ix, const char *description)
{
  int throw_flag;
  const char *error_string = NULL;
  const Marpa_Error_Code marpa_error = marpa_g_error (*p_g, &error_string);
  /* Try to avoid any possiblity of stack overflow */
  lua_getfield (L, grammar_stack_ix, "throw");
  /* [ ..., throw_flag ] */
  throw_flag = lua_toboolean (L, -1);
  if (throw_flag)
    {
      kollos_throw (L, marpa_error, description);
    }
  /* Leave the stack as we found it */
  lua_pop(L, 1);
}

/* Handle libmarpa recce errors in the most usual way.
   Uses 1 position on the stack, and throws the
   error, if so desired.
   The error may not be thrown, and it expects the
   caller to handle any non-thrown error.
*/
static void
common_r_error_handler (lua_State * L,
			int recce_stack_ix, const char *description)
{
  int throw_flag;
  Marpa_Error_Code marpa_error;
  Marpa_Grammar *grammar_ud;
  lua_getfield (L, recce_stack_ix, "_libmarpa_g");
  /* [ ..., grammar_ud ] */
  grammar_ud = (Marpa_Grammar *) lua_touserdata (L, -1);
  lua_pop(L, 1);
  marpa_error = marpa_g_error (*grammar_ud, NULL);
  lua_getfield (L, recce_stack_ix, "throw");
  /* [ ..., throw_flag ] */
  throw_flag = lua_toboolean (L, -1);
  if (throw_flag)
    {
      kollos_throw (L, marpa_error, description);
    }
  /* Leave the stack as we found it */
  lua_pop(L, 1);
}

/* Handle libmarpa bocage errors in the most usual way.
   Uses 1 position on the stack, and throws the
   error, if so desired.
   The error may not be thrown, and it expects the
   caller to handle any non-thrown error.
*/
static void
common_b_error_handler (lua_State * L,
			int bocage_stack_ix, const char *description)
{
  int throw_flag;
  Marpa_Error_Code marpa_error;
  Marpa_Grammar *grammar_ud;
  lua_getfield (L, bocage_stack_ix, "_libmarpa_g");
  /* [ ..., grammar_ud ] */
  grammar_ud = (Marpa_Grammar *) lua_touserdata (L, -1);
  lua_pop(L, 1);
  marpa_error = marpa_g_error (*grammar_ud, NULL);
  lua_getfield (L, bocage_stack_ix, "throw");
  /* [ ..., throw_flag ] */
  throw_flag = lua_toboolean (L, -1);
  /* [ ..., throw_flag ] */
  if (throw_flag)
    {
      kollos_throw (L, marpa_error, description);
    }
  /* [ ..., throw_flag ] */
  /* Leave the stack as we found it */
  lua_pop(L, 1);
}

/* Handle libmarpa order errors in the most usual way.
   Uses 1 position on the stack, and throws the
   error, if so desired.
   The error may not be thrown, and it expects the
   caller to handle any non-thrown error.
*/
static void
common_o_error_handler (lua_State * L,
			int order_stack_ix, const char *description)
{
  int throw_flag;
  Marpa_Error_Code marpa_error;
  Marpa_Grammar *grammar_ud;
  lua_getfield (L, order_stack_ix, "_libmarpa_g");
  /* [ ..., grammar_ud ] */
  grammar_ud = (Marpa_Grammar *) lua_touserdata (L, -1);
  lua_pop(L, 1);
  marpa_error = marpa_g_error (*grammar_ud, NULL);
  lua_getfield (L, order_stack_ix, "throw");
  /* [ ..., throw_flag ] */
  throw_flag = lua_toboolean (L, -1);
  /* [ ..., throw_flag ] */
  if (throw_flag)
    {
      kollos_throw (L, marpa_error, description);
    }
  /* [ ..., throw_flag ] */
  /* Leave the stack as we found it */
  lua_pop(L, 1);
}

/* Handle libmarpa tree errors in the most usual way.
   Uses 1 position on the stack, and throws the
   error, if so desired.
   The error may not be thrown, and it expects the
   caller to handle any non-thrown error.
*/
static void
common_t_error_handler (lua_State * L,
			int tree_stack_ix, const char *description)
{
  int throw_flag;
  Marpa_Error_Code marpa_error;
  Marpa_Grammar *grammar_ud;
  lua_getfield (L, tree_stack_ix, "_libmarpa_g");
  /* [ ..., grammar_ud ] */
  grammar_ud = (Marpa_Grammar *) lua_touserdata (L, -1);
  lua_pop(L, 1);
  marpa_error = marpa_g_error (*grammar_ud, NULL);
  lua_getfield (L, tree_stack_ix, "throw");
  /* [ ..., throw_flag ] */
  throw_flag = lua_toboolean (L, -1);
  /* [ ..., throw_flag ] */
  if (throw_flag)
    {
      kollos_throw (L, marpa_error, description);
    }
  /* [ ..., throw_flag ] */
  /* Leave the stack as we found it */
  lua_pop(L, 1);
}

/* Handle libmarpa value errors in the most usual way.
   Uses 1 position on the stack, and throws the
   error, if so desired.
   The error may not be thrown, and it expects the
   caller to handle any non-thrown error.
*/
static void
common_v_error_handler (lua_State * L,
			int value_stack_ix, const char *description)
{
  int throw_flag;
  Marpa_Error_Code marpa_error;
  Marpa_Grammar *grammar_ud;
  lua_getfield (L, value_stack_ix, "_libmarpa_g");
  /* [ ..., grammar_ud ] */
  grammar_ud = (Marpa_Grammar *) lua_touserdata (L, -1);
  lua_pop(L, 1);
  marpa_error = marpa_g_error (*grammar_ud, NULL);
  lua_getfield (L, value_stack_ix, "throw");
  /* [ ..., throw_flag ] */
  throw_flag = lua_toboolean (L, -1);
  /* [ ..., throw_flag ] */
  if (throw_flag)
    {
      kollos_throw (L, marpa_error, description);
    }
  /* [ ..., throw_flag ] */
  /* Leave the stack as we found it */
  lua_pop(L, 1);
}

static int
wrap_grammar_new (lua_State * L)
{
  /* [ grammar_table ] */
  const int grammar_stack_ix = 1;
  if (0)
    printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);

  /* expecting a table */
  if (1)
    {
      check_libmarpa_table (L, "wrap_grammar_NEW()", grammar_stack_ix,
			    "grammar");
    }

  /* I have forked Libmarpa into Kollos, which makes version checking
   * pointless.  But we may someday use the LuaJIT,
   * and version checking will be needed there.
   */

  {
    const char *const header_mismatch =
      "Header version does not match expected version";
    /* Make sure the header is from the version we want */
    if (MARPA_MAJOR_VERSION != EXPECTED_LIBMARPA_MAJOR)
      luif_err_throw2 (L, LUIF_ERR_MAJOR_VERSION_MISMATCH, header_mismatch);
    if (MARPA_MINOR_VERSION != EXPECTED_LIBMARPA_MINOR)
      luif_err_throw2 (L, LUIF_ERR_MINOR_VERSION_MISMATCH, header_mismatch);
    if (MARPA_MICRO_VERSION != EXPECTED_LIBMARPA_MICRO)
      luif_err_throw2 (L, LUIF_ERR_MICRO_VERSION_MISMATCH, header_mismatch);
  }

  {
    /* Now make sure the library is from the version we want */
    const char *const library_mismatch =
      "Library version does not match expected version";
    int version[3];
    const Marpa_Error_Code error_code = marpa_version (version);
    if (error_code != MARPA_ERR_NONE)
      luif_err_throw2 (L, error_code, "marpa_version() failed");
    if (version[0] != EXPECTED_LIBMARPA_MAJOR)
      luif_err_throw2 (L, LUIF_ERR_MAJOR_VERSION_MISMATCH, library_mismatch);
    if (version[1] != EXPECTED_LIBMARPA_MINOR)
      luif_err_throw2 (L, LUIF_ERR_MINOR_VERSION_MISMATCH, library_mismatch);
    if (version[2] != EXPECTED_LIBMARPA_MICRO)
      luif_err_throw2 (L, LUIF_ERR_MICRO_VERSION_MISMATCH, library_mismatch);
  }

  /* stack is [ grammar_table ] */
  {
    Marpa_Config marpa_config;
    Marpa_Grammar *p_g;
    int result;
    /* [ grammar_table ] */
    p_g = (Marpa_Grammar *) lua_newuserdata (L, sizeof (Marpa_Grammar));
    /* [ grammar_table, userdata ] */
    lua_rawgetp (L, LUA_REGISTRYINDEX, &kollos_g_ud_mt_key);
    lua_setmetatable (L, -2);
    /* [ grammar_table, userdata ] */

    /* dup top of stack */
    lua_pushvalue (L, -1);
    /* [ grammar_table, userdata, userdata ] */
    lua_setfield (L, grammar_stack_ix, "_libmarpa");
    /* [ grammar_table, userdata ] */
    lua_setfield (L, grammar_stack_ix, "_libmarpa_g");
    /* [ grammar_table ] */

    marpa_c_init (&marpa_config);
    *p_g = marpa_g_new (&marpa_config);
    if (!*p_g)
      {
	int throw_flag;
	Marpa_Error_Code marpa_error = marpa_c_error (&marpa_config, NULL);
	lua_getfield (L, -1, "throw");
	throw_flag = lua_toboolean (L, -1);
	/* [ grammar_table, throw_flag ] */
	if (throw_flag)
	  {
	    kollos_throw (L, marpa_error, "marpa_g_new()");
	  }
	lua_pushnil (L);
	return 1;
      }
    result = marpa_g_force_valued (*p_g);
    if (result < 0)
      {
	common_g_error_handler (L, p_g, grammar_stack_ix,
				"marpa_g_force_valued()");
	lua_pushnil (L);
	return 1;
      }
    if (0)
      printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
    /* [ grammar_table ] */
    return 1;
  }
}

/* The grammar error code */
static int wrap_grammar_error(lua_State *L)
{
   /* [ grammar_object ] */
  const int grammar_stack_ix = 1;
  Marpa_Grammar *p_g;
  Marpa_Error_Code marpa_error;
  const char *error_string = NULL;

  lua_getfield (L, grammar_stack_ix, "_libmarpa");
  /* [ grammar_object, grammar_ud ] */
  p_g = (Marpa_Grammar *) lua_touserdata (L, -1);
  marpa_error = marpa_g_error(*p_g, &error_string);
  lua_pushinteger(L, (lua_Integer)marpa_error);
  lua_pushstring(L, error_string);
  /* [ grammar_object, grammar_ud, error_code, error_string ] */
  return 2;
}

/* The C wrapper for Libmarpa event reading.
   It assumes we just want all of them.
 */
static int wrap_grammar_events(lua_State *L)
{
  /* [ grammar_object ] */
  const int grammar_stack_ix = 1;
  Marpa_Grammar *p_g;
  int event_count;

  lua_getfield (L, grammar_stack_ix, "_libmarpa");
  /* [ grammar_object, grammar_ud ] */
  p_g = (Marpa_Grammar *) lua_touserdata (L, -1);
  event_count = marpa_g_event_count (*p_g);
  if (event_count < 0)
    {
      common_g_error_handler (L, p_g, grammar_stack_ix,
			      "marpa_g_event_count()");
      return 0;
    }
  lua_pop (L, 1);
  /* [ grammar_object ] */
  lua_createtable (L, event_count, 0);
  /* [ grammar_object, result_table ] */
  {
    const int result_table_ix = lua_gettop (L);
    int event_ix;
    for (event_ix = 0; event_ix < event_count; event_ix++)
      {
	Marpa_Event_Type event_type;
	Marpa_Event event;
	/* [ grammar_object, result_table ] */
	event_type = marpa_g_event (*p_g, &event, event_ix);
	if (event_type <= -2)
	  {
	    common_g_error_handler (L, p_g, grammar_stack_ix,
				    "marpa_g_event()");
	    return 0;
	  }
	lua_pushinteger (L, event_ix*2 + 1);
	lua_pushinteger (L, event_type);
	/* [ grammar_object, result_table, event_ix*2+1, event_type ] */
	lua_settable (L, result_table_ix);
	/* [ grammar_object, result_table ] */
	lua_pushinteger (L, event_ix*2 + 2);
	lua_pushinteger (L, marpa_g_event_value (&event));
	/* [ grammar_object, result_table, event_ix*2+2, event_value ] */
	lua_settable (L, result_table_ix);
	/* [ grammar_object, result_table ] */
      }
  }
  /* [ grammar_object, result_table ] */
  return 1;
}

/* Another C wrapper for Libmarpa event reading.
   It assumes we want them one by one.
 */
static int wrap_grammar_event(lua_State *L)
{
  /* [ grammar_object ] */
  const int grammar_stack_ix = 1;
  const int event_ix_stack_ix = 2;
  Marpa_Grammar *p_g;
  Marpa_Event_Type event_type;
  Marpa_Event event;
  const int event_ix = (Marpa_Symbol_ID)lua_tointeger(L, event_ix_stack_ix)-1;

  lua_getfield (L, grammar_stack_ix, "_libmarpa");
  /* [ grammar_object, grammar_ud ] */
  p_g = (Marpa_Grammar *) lua_touserdata (L, -1);
  /* [ grammar_object, grammar_ud ] */
  event_type = marpa_g_event (*p_g, &event, event_ix);
  if (event_type <= -2)
    {
      common_g_error_handler (L, p_g, grammar_stack_ix, "marpa_g_event()");
      return 0;
    }
  lua_pushinteger (L, event_type);
  lua_pushinteger (L, marpa_g_event_value (&event));
  /* [ grammar_object, grammar_ud, event_type, event_value ] */
  return 2;
}
/* Rule RHS limited to 7 symbols --
 * 7 because I can encode dot position in 3 bit
 */
static int wrap_grammar_rule_new(lua_State *L)
{
    Marpa_Grammar *p_g;
    Marpa_Rule_ID result;
    Marpa_Symbol_ID lhs;
    /* As an old kernel driver programmer, I
     * don't like to put arrays on the stack,
     * but one of this size should be safe on
     * anything like a modern architecture.
     */
    Marpa_Symbol_ID rhs[2];
    int rhs_length;
    /* [ grammar_object, lhs, rhs ... ] */
    const int grammar_stack_ix = 1;

    /* This will not be an external interface,
     * so eventually we will run unsafe.
     * This checking code is for debugging.
     */
    if (1)
      {
        check_libmarpa_table (L, "wrap_grammar_rule_new()", grammar_stack_ix,
                              "grammar");
      }

    lhs = (Marpa_Symbol_ID)lua_tointeger(L, 2);
    /* Unsafe, no arg count checking */
    rhs_length = lua_isnumber(L, 4) ? 2 : 1;
    {
      int rhs_ix;
      for (rhs_ix = 0; rhs_ix < rhs_length; rhs_ix++)
        {
          rhs[rhs_ix] = (Marpa_Symbol_ID) lua_tointeger (L, rhs_ix + 3);
        }
    }
    lua_pop(L, lua_gettop(L)-1);
    /* [ grammar_object ] */

    lua_getfield (L, -1, "_libmarpa");
    /* [ grammar_object, grammar_ud ] */
    p_g = (Marpa_Grammar *) lua_touserdata (L, -1);

    result = (Marpa_Rule_ID)marpa_g_rule_new(*p_g, lhs, rhs, rhs_length);
    if (result <= -1) common_g_error_handler (L, p_g, grammar_stack_ix,
			    "marpa_g_rule_new()");
    lua_pushinteger(L, (lua_Integer)result);
    return 1;
}

]=]

-- recognizer wrappers which need to be hand-written

io.write[=[

static int
wrap_recce_new (lua_State * L)
{
  const int recce_stack_ix = 1;
  const int grammar_stack_ix = 2;
  if (0)
    printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
  /* [ recce_table, grammar_table ] */
  if (1)
    {
      check_libmarpa_table (L, "wrap_recce_new()", recce_stack_ix, "recce");
      check_libmarpa_table (L, "wrap_recce_new()", grammar_stack_ix,
			    "grammar");
    }

  /* [ recce_table, grammar_table ] */
  {
    Marpa_Recognizer *recce_ud;
    Marpa_Grammar *grammar_ud;

    /* [ recce_table, grammar_table ] */
    recce_ud =
      (Marpa_Recognizer *) lua_newuserdata (L, sizeof (Marpa_Recognizer));
    /* [ recce_table, , grammar_table, recce_ud ] */
    lua_rawgetp (L, LUA_REGISTRYINDEX, &kollos_r_ud_mt_key);
    /* [ recce_table, grammar_table, recce_ud, recce_ud_mt ] */
    lua_setmetatable (L, -2);
    /* [ recce_table, grammar_table, recce_ud ] */

    lua_setfield (L, recce_stack_ix, "_libmarpa");
    /* [ recce_table, grammar_table ] */
    lua_getfield (L, grammar_stack_ix, "_libmarpa_g");
    /* [ recce_table, grammar_table, g_ud ] */
    grammar_ud = (Marpa_Grammar *) lua_touserdata (L, -1);
    lua_setfield (L, recce_stack_ix, "_libmarpa_g");
    /* [ recce_table, grammar_table ] */

    *recce_ud = marpa_r_new (*grammar_ud);
    if (!*recce_ud)
      {
	common_r_error_handler (L, recce_stack_ix, "marpa_r_new()");
        lua_pushnil (L);
        return 1;
      }
  }
  if (0)
    printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
  /* [ recce_table, grammar_table ] */
  lua_pop (L, 1);
  /* [ recce_table ] */
  return 1;
}

/* The grammar error code */
static int wrap_progress_item(lua_State *L)
{
  /* [ grammar_object ] */
  const int recce_stack_ix = 1;
  Marpa_Recce *p_r;
  Marpa_Earley_Set_ID origin;
  int position;
  Marpa_Rule_ID rule_id;

  lua_getfield (L, recce_stack_ix, "_libmarpa");
  /* [ recce_object, recce_ud ] */
  p_r = (Marpa_Recce *) lua_touserdata (L, -1);
  rule_id = marpa_r_progress_item (*p_r, &position, &origin);
  if (rule_id < -1)
    {
      common_r_error_handler (L, recce_stack_ix, "marpa_r_progress_item()");
      lua_pushinteger (L, (lua_Integer) rule_id);
      return 1;
    }
  if (rule_id == -1)
    {
      return 0;
    }
  lua_pushinteger (L, (lua_Integer) rule_id);
  lua_pushinteger (L, (lua_Integer) position);
  lua_pushinteger (L, (lua_Integer) origin);
  /* [ recce_object, recce_ud, 
   *     rule_id, position, origin ]
   */
  return 3;
}

]=]

-- bocage wrappers which need to be hand-written

io.write[=[

static int
wrap_bocage_new (lua_State * L)
{
  const int bocage_stack_ix = 1;
  const int recce_stack_ix = 2;
  const int symbol_stack_ix = 3;
  const int start_stack_ix = 4;
  const int end_stack_ix = 5;
  int end_earley_set = -1;
  int end_earley_set_is_nil = 0;

  if (0)
    printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
  /* [ bocage_table, recce_table ] */
  if (1)
    {
      check_libmarpa_table (L, "wrap_bocage_new()", bocage_stack_ix, "bocage");
      check_libmarpa_table (L, "wrap_bocage_new()", recce_stack_ix, "recce");
      luaL_checktype(L, symbol_stack_ix, LUA_TNIL);
      luaL_checktype(L, start_stack_ix, LUA_TNIL);
    }

  if (lua_type(L, end_stack_ix) == LUA_TNIL) {
      end_earley_set_is_nil = 1;
  } else {
      end_earley_set = luaL_checkint(L, end_stack_ix);
  }
  /* Make some stack space */
  lua_pop(L, 3);

  /* [ bocage_table, recce_table ] */
  {
    Marpa_Recognizer *recce_ud;
    /* Important: the bocage does *not* hold a reference to
         the recognizer, so it should not memoize the userdata
         pointing to it. */

    /* [ bocage_table, recce_table ] */
    Marpa_Bocage* bocage_ud =
      (Marpa_Bocage *) lua_newuserdata (L, sizeof (Marpa_Bocage));
    /* [ bocage_table, recce_table, bocage_ud ] */
    lua_rawgetp (L, LUA_REGISTRYINDEX, &kollos_b_ud_mt_key);
    /* [ bocage_table, recce_table, bocage_ud, bocage_ud_mt ] */
    lua_setmetatable (L, -2);
    /* [ bocage_table, recce_table, bocage_ud ] */

    lua_setfield (L, bocage_stack_ix, "_libmarpa");
    /* [ bocage_table, recce_table ] */
    lua_getfield (L, recce_stack_ix, "_libmarpa_g");
    /* [ recce_table, recce_table, g_ud ] */
    lua_setfield (L, bocage_stack_ix, "_libmarpa_g");
    /* [ bocage_table, recce_table ] */
    lua_getfield (L, recce_stack_ix, "_libmarpa");
    /* [ recce_table, recce_table, recce_ud ] */
    recce_ud = (Marpa_Recognizer *) lua_touserdata (L, -1);
    /* [ bocage_table, recce_table, recce_ud ] */

    if (end_earley_set_is_nil) {
        /* No error check -- always succeeds, say libmarpa docs */
        end_earley_set = marpa_r_latest_earley_set(*recce_ud);
    } else {
       if (end_earley_set < 0) {
         common_b_error_handler (L, bocage_stack_ix,
             "bocage_new(): end earley set arg is negative");
         lua_pushnil (L);
         return 1;
       }
    }

    *bocage_ud = marpa_b_new (*recce_ud, end_earley_set);
    if (!*bocage_ud)
      {
	common_b_error_handler (L, bocage_stack_ix, "marpa_b_new()");
        lua_pushnil (L);
        return 1;
      }
  }
  if (0)
    printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
  /* [ bocage_table, recce_table, recce_ud ] */
  lua_pop (L, 2);
  /* [ bocage_table ] */
  return 1;
}

]=]

-- order wrappers which need to be hand-written

io.write[=[

static int
wrap_order_new (lua_State * L)
{
  const int order_stack_ix = 1;
  const int bocage_stack_ix = 2;

  if (0)
    printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
  /* [ order_table, bocage_table ] */
  if (1)
    {
      check_libmarpa_table (L, "wrap_order_new()", order_stack_ix, "order");
      check_libmarpa_table (L, "wrap_order_new()", bocage_stack_ix, "bocage");
    }

  /* [ order_table, bocage_table ] */
  {
    Marpa_Bocage *bocage_ud;

    /* [ order_table, bocage_table ] */
    Marpa_Order* order_ud =
      (Marpa_Order *) lua_newuserdata (L, sizeof (Marpa_Order));
    /* [ order_table, bocage_table, order_ud ] */
    lua_rawgetp (L, LUA_REGISTRYINDEX, &kollos_o_ud_mt_key);
    /* [ order_table, bocage_table, order_ud, order_ud_mt ] */
    lua_setmetatable (L, -2);
    /* [ order_table, bocage_table, order_ud ] */

    lua_setfield (L, order_stack_ix, "_libmarpa");
    /* [ order_table, bocage_table ] */
    lua_getfield (L, bocage_stack_ix, "_libmarpa_g");
    /* [ order_table, bocage_table, g_ud ] */
    lua_setfield (L, order_stack_ix, "_libmarpa_g");
    /* [ order_table, bocage_table ] */
    lua_getfield (L, bocage_stack_ix, "_libmarpa");
    /* [ order_table, bocage_table, bocage_ud ] */
    bocage_ud = (Marpa_Bocage *) lua_touserdata (L, -1);
    /* [ order_table, bocage_table, bocage_ud ] */

    *order_ud = marpa_o_new (*bocage_ud);
    if (!*order_ud)
      {
	common_o_error_handler (L, order_stack_ix, "marpa_o_new()");
        lua_pushnil (L);
        return 1;
      }
  }
  if (0)
    printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
  /* [ order_table, bocage_table, bocage_ud ] */
  lua_pop (L, 2);
  /* [ order_table ] */
  return 1;
}

]=]

-- tree wrappers which need to be hand-written

io.write[=[

static int
wrap_tree_new (lua_State * L)
{
  const int tree_stack_ix = 1;
  const int order_stack_ix = 2;

  if (0)
    printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
  /* [ tree_table, order_table ] */
  if (1)
    {
      check_libmarpa_table (L, "wrap_tree_new()", tree_stack_ix, "tree");
      check_libmarpa_table (L, "wrap_tree_new()", order_stack_ix, "order");
    }

  /* [ tree_table, order_table ] */
  {
    Marpa_Order *order_ud;
    /* Important: the tree does *not* hold a reference to
         the recognizer, so it should not memoize the userdata
         pointing to it. */

    /* [ tree_table, order_table ] */
    Marpa_Tree* tree_ud =
      (Marpa_Tree *) lua_newuserdata (L, sizeof (Marpa_Tree));
    /* [ tree_table, order_table, tree_ud ] */
    lua_rawgetp (L, LUA_REGISTRYINDEX, &kollos_t_ud_mt_key);
    /* [ tree_table, order_table, tree_ud, tree_ud_mt ] */
    lua_setmetatable (L, -2);
    /* [ tree_table, order_table, tree_ud ] */

    lua_setfield (L, tree_stack_ix, "_libmarpa");
    /* [ tree_table, order_table ] */
    lua_getfield (L, order_stack_ix, "_libmarpa_g");
    /* [ tree_table, order_table, g_ud ] */
    lua_setfield (L, tree_stack_ix, "_libmarpa_g");
    /* [ tree_table, order_table ] */
    lua_getfield (L, order_stack_ix, "_libmarpa");
    /* [ tree_table, order_table, order_ud ] */
    order_ud = (Marpa_Order *) lua_touserdata (L, -1);
    /* [ tree_table, order_table, order_ud ] */

    *tree_ud = marpa_t_new (*order_ud);
    if (!*tree_ud)
      {
	common_t_error_handler (L, tree_stack_ix, "marpa_t_new()");
        lua_pushnil (L);
        return 1;
      }
  }
  if (0)
    printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
  /* [ tree_table, order_table, order_ud ] */
  lua_pop (L, 2);
  /* [ tree_table ] */
  return 1;
}

]=]

-- value wrappers which need to be hand-written

io.write[=[

static int
wrap_value_new (lua_State * L)
{
  const int value_stack_ix = 1;
  const int tree_stack_ix = 2;

  if (0)
    printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
  /* [ value_table, tree_table ] */
  if (1)
    {
      check_libmarpa_table (L, "wrap_value_new()", value_stack_ix, "value");
      check_libmarpa_table (L, "wrap_value_new()", tree_stack_ix, "tree");
    }

  /* [ value_table, tree_table ] */
  {
    Marpa_Tree *tree_ud;
    /* Important: the value does *not* hold a reference to
         the recognizer, so it should not memoize the userdata
         pointing to it. */

    /* [ value_table, tree_table ] */
    Marpa_Value* value_ud =
      (Marpa_Value *) lua_newuserdata (L, sizeof (Marpa_Value));
    /* [ value_table, tree_table, value_ud ] */
    lua_rawgetp (L, LUA_REGISTRYINDEX, &kollos_v_ud_mt_key);
    /* [ value_table, tree_table, value_ud, value_ud_mt ] */
    lua_setmetatable (L, -2);
    /* [ value_table, tree_table, value_ud ] */

    lua_setfield (L, value_stack_ix, "_libmarpa");
    /* [ value_table, tree_table ] */
    lua_getfield (L, tree_stack_ix, "_libmarpa_g");
    /* [ value_table, tree_table, g_ud ] */
    lua_setfield (L, value_stack_ix, "_libmarpa_g");
    /* [ value_table, tree_table ] */
    lua_getfield (L, tree_stack_ix, "_libmarpa");
    /* [ value_table, tree_table, tree_ud ] */
    tree_ud = (Marpa_Tree *) lua_touserdata (L, -1);
    /* [ value_table, tree_table, tree_ud ] */

    *value_ud = marpa_v_new (*tree_ud);
    if (!*value_ud)
      {
	common_v_error_handler (L, value_stack_ix, "marpa_v_new()");
        lua_pushnil (L);
        return 1;
      }
  }
  if (0)
    printf ("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
  /* [ value_table, tree_table, tree_ud ] */
  lua_pop (L, 2);
  /* [ value_table ] */
  return 1;
}

]=]


io.write[=[

/*
 * Userdata metatable methods
 */

static int l_grammar_ud_mt_gc(lua_State *L) {
    Marpa_Grammar *p_g;
    if (0) printf("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
    p_g = (Marpa_Grammar *) lua_touserdata (L, 1);
    if (*p_g) marpa_g_unref(*p_g);
   return 0;
}

static int l_recce_ud_mt_gc(lua_State *L) {
    Marpa_Recognizer *p_recce;
    if (0) printf("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
    p_recce = (Marpa_Recognizer *) lua_touserdata (L, 1);
    if (*p_recce) marpa_r_unref(*p_recce);
   return 0;
}

static int l_bocage_ud_mt_gc(lua_State *L) {
    Marpa_Bocage *p_bocage;
    if (0) printf("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
    p_bocage = (Marpa_Bocage *) lua_touserdata (L, 1);
    if (*p_bocage) marpa_b_unref(*p_bocage);
   return 0;
}

static int l_order_ud_mt_gc(lua_State *L) {
    Marpa_Order *p_order;
    if (0) printf("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
    p_order = (Marpa_Order *) lua_touserdata (L, 1);
    if (*p_order) marpa_o_unref(*p_order);
   return 0;
}

static int l_tree_ud_mt_gc(lua_State *L) {
    Marpa_Tree *p_tree;
    if (0) printf("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
    p_tree = (Marpa_Tree *) lua_touserdata (L, 1);
    if (*p_tree) marpa_t_unref(*p_tree);
   return 0;
}

static int l_value_ud_mt_gc(lua_State *L) {
    Marpa_Value *p_value;
    if (0) printf("%s %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
    p_value = (Marpa_Value *) lua_touserdata (L, 1);
    if (*p_value) marpa_v_unref(*p_value);
   return 0;
}

LUALIB_API int luaopen_kollos_c(lua_State *L);
LUALIB_API int luaopen_kollos_c(lua_State *L)
{
    /* Create the main kollos object */
    const int kollos_table_stack_ix = lua_gettop(L) + 1;
    lua_newtable(L);

    /* Set up Kollos error handling metatable.
       The metatable starts out empty.
    */
    lua_newtable(L);
    /* [ kollos, error_mt ] */
    lua_rawsetp(L, LUA_REGISTRYINDEX, &kollos_error_mt_key);
    /* [ kollos ] */

    /* Set up Kollos grammar userdata metatable */
    lua_newtable(L);
    /* [ kollos, mt_ud_g ] */
    lua_pushcfunction(L, l_grammar_ud_mt_gc);
    /* [ kollos, mt_g_ud, gc_function ] */
    lua_setfield(L, -2, "__gc");
    /* [ kollos, mt_g_ud ] */
    lua_rawsetp(L, LUA_REGISTRYINDEX, &kollos_g_ud_mt_key);
    /* [ kollos ] */

    /* Set up Kollos recce userdata metatable */
    lua_newtable(L);
    /* [ kollos, mt_ud_r ] */
    lua_pushcfunction(L, l_recce_ud_mt_gc);
    /* [ kollos, mt_r_ud, gc_function ] */
    lua_setfield(L, -2, "__gc");
    /* [ kollos, mt_r_ud ] */
    lua_rawsetp(L, LUA_REGISTRYINDEX, &kollos_r_ud_mt_key);
    /* [ kollos ] */

    /* Set up Kollos bocage userdata metatable */
    lua_newtable(L);
    /* [ kollos, mt_ud_bocage ] */
    lua_pushcfunction(L, l_bocage_ud_mt_gc);
    /* [ kollos, mt_b_ud, gc_function ] */
    lua_setfield(L, -2, "__gc");
    /* [ kollos, mt_b_ud ] */
    lua_rawsetp(L, LUA_REGISTRYINDEX, &kollos_b_ud_mt_key);
    /* [ kollos ] */

    /* Set up Kollos order userdata metatable */
    lua_newtable(L);
    /* [ kollos, mt_ud_order ] */
    lua_pushcfunction(L, l_order_ud_mt_gc);
    /* [ kollos, mt_o_ud, gc_function ] */
    lua_setfield(L, -2, "__gc");
    /* [ kollos, mt_o_ud ] */
    lua_rawsetp(L, LUA_REGISTRYINDEX, &kollos_o_ud_mt_key);
    /* [ kollos ] */

    /* Set up Kollos tree userdata metatable */
    lua_newtable(L);
    /* [ kollos, mt_ud_tree ] */
    lua_pushcfunction(L, l_tree_ud_mt_gc);
    /* [ kollos, mt_t_ud, gc_function ] */
    lua_setfield(L, -2, "__gc");
    /* [ kollos, mt_t_ud ] */
    lua_rawsetp(L, LUA_REGISTRYINDEX, &kollos_t_ud_mt_key);
    /* [ kollos ] */

    /* Set up Kollos value userdata metatable */
    lua_newtable(L);
    /* [ kollos, mt_ud_value ] */
    lua_pushcfunction(L, l_value_ud_mt_gc);
    /* [ kollos, mt_v_ud, gc_function ] */
    lua_setfield(L, -2, "__gc");
    /* [ kollos, mt_v_ud ] */
    lua_rawsetp(L, LUA_REGISTRYINDEX, &kollos_v_ud_mt_key);
    /* [ kollos ] */

    /* In alphabetical order by field name */

    lua_pushcfunction(L, l_error_description_by_code);
    /* [ kollos, function ] */
    lua_setfield(L, kollos_table_stack_ix, "error_description");
    /* [ kollos ] */

    lua_pushcfunction(L, l_error_name_by_code);
    lua_setfield(L, kollos_table_stack_ix, "error_name");

    lua_pushcfunction(L, l_error_new);
    lua_setfield(L, kollos_table_stack_ix, "error_new");

    lua_pushcfunction(L, wrap_kollos_throw);
    lua_setfield(L, kollos_table_stack_ix, "error_throw");

    lua_pushcfunction(L, l_event_name_by_code);
    lua_setfield(L, kollos_table_stack_ix, "event_name");

    lua_pushcfunction(L, l_event_description_by_code);
    lua_setfield(L, kollos_table_stack_ix, "event_description");

    lua_pushcfunction(L, wrap_grammar_error);
    lua_setfield(L, kollos_table_stack_ix, "grammar_error");

    lua_pushcfunction(L, wrap_grammar_event);
    lua_setfield(L, kollos_table_stack_ix, "grammar_event");

    lua_pushcfunction(L, wrap_grammar_events);
    lua_setfield(L, kollos_table_stack_ix, "grammar_events");

    lua_pushcfunction(L, wrap_grammar_new);
    lua_setfield(L, kollos_table_stack_ix, "grammar_new");

    lua_pushcfunction(L, wrap_grammar_rule_new);
    lua_setfield(L, kollos_table_stack_ix, "grammar_rule_new");

    lua_pushcfunction(L, wrap_recce_new);
    lua_setfield(L, kollos_table_stack_ix, "recce_new");

    lua_pushcfunction(L, wrap_progress_item);
    lua_setfield(L, kollos_table_stack_ix, "recce_progress_item");

    lua_pushcfunction(L, wrap_bocage_new);
    lua_setfield(L, kollos_table_stack_ix, "bocage_new");

    lua_pushcfunction(L, wrap_order_new);
    lua_setfield(L, kollos_table_stack_ix, "order_new");

    lua_pushcfunction(L, wrap_tree_new);
    lua_setfield(L, kollos_table_stack_ix, "tree_new");

    lua_pushcfunction(L, wrap_value_new);
    lua_setfield(L, kollos_table_stack_ix, "value_new");

    lua_newtable (L);
    /* [ kollos, error_code_table ] */
    {
      const int name_table_stack_ix = lua_gettop (L);
      int error_code;
      for (error_code = LIBMARPA_MIN_ERROR_CODE;
           error_code <= LIBMARPA_MAX_ERROR_CODE; error_code++)
        {
          lua_pushinteger (L, (lua_Integer) error_code);
          lua_setfield (L, name_table_stack_ix,
                        libmarpa_error_codes[error_code -
                                             LIBMARPA_MIN_ERROR_CODE].mnemonic);
        }
      for (error_code = KOLLOS_MIN_ERROR_CODE;
           error_code <= KOLLOS_MAX_ERROR_CODE; error_code++)
        {
          lua_pushinteger (L, (lua_Integer) error_code);
          lua_setfield (L, name_table_stack_ix,
                        kollos_error_codes[error_code -
                                           KOLLOS_MIN_ERROR_CODE].mnemonic);
        }
    }
      /* if (1) dump_table(L, -1); */

    /* [ kollos, error_code_table ] */
    lua_setfield (L, kollos_table_stack_ix, "error_code_by_name");

    lua_newtable (L);
    /* [ kollos, event_code_table ] */
    {
      const int name_table_stack_ix = lua_gettop (L);
      int event_code;
      for (event_code = LIBMARPA_MIN_EVENT_CODE;
           event_code <= LIBMARPA_MAX_EVENT_CODE; event_code++)
        {
          lua_pushinteger (L, (lua_Integer) event_code);
          lua_setfield (L, name_table_stack_ix,
                        libmarpa_event_codes[event_code -
                                             LIBMARPA_MIN_EVENT_CODE].mnemonic);
        }
    }
      /* if (1) dump_table(L, -1); */

    /* [ kollos, event_code_table ] */
    lua_setfield (L, kollos_table_stack_ix, "event_code_by_name");

]=]

-- This code goes through the signatures table again,
-- to put the wrappers into kollos object fields

for ix = 1, #c_fn_signatures do
   local signature = c_fn_signatures[ix]
   local function_name = signature[1]
   local unprefixed_name = function_name:gsub("^[_]?marpa_", "", 1);
   local class_letter = unprefixed_name:gsub("_.*$", "", 1);
   local wrapper_name = "wrap_" .. unprefixed_name;
   io.write("  lua_pushcfunction(L, " .. wrapper_name .. ");\n")
   local classless_name = function_name:gsub("^[_]?marpa_[^_]*_", "")
   local initial_underscore = function_name:match('^_') and '_' or ''
   local quoted_field_name = '"' .. initial_underscore .. libmarpa_class_name[class_letter] .. '_' .. classless_name .. '"'
   io.write("  lua_setfield(L, kollos_table_stack_ix, " .. quoted_field_name .. ");\n")
end

io.write[=[
  /* [ kollos ] */
  /* For debugging */
  if (0) dump_table(L, -1);

  /* Fail if not 5.1 ? */

  /* [ kollos ] */
  return 1;
}

/* vim: expandtab shiftwidth=4:
 */
]=]
