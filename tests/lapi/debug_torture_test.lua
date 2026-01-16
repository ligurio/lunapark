--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Parameter 'what' of 'debug.getinfo' cannot start with '>',
https://www.lua.org/bugs.html#5.4.2-2

Access to debug information in line hook of stripped function,
https://github.com/lua/lua/commit/ae5b5ba529753c7a653901ffc29b5ea24c3fdf3a

Return hook may not see correct values for active local variables when function returns,
https://www.lua.org/bugs.html#5.3.0-4

The PC out-of-range in lj_debug_frameline(),
https://github.com/LuaJIT/LuaJIT/issues/1369

LuaJIT segfault in debug.getinfo(),
https://github.com/LuaJIT/LuaJIT/issues/509

Negation overflow in getlocal/setlocal,
https://github.com/lua/lua/commit/a585eae6e7ada1ca9271607a4f48dfb17868ab7b

debug.getlocal on a coroutine suspended in a hook can crash the interpreter,
https://www.lua.org/bugs.html#5.3.0-2

lua_getupvalue and lua_setupvalue do not check for index too small,
https://www.lua.org/bugs.html#5.0.2-2

Synopsis: debug.getupvalue (f, up)
Synopsis: debug.getlocal([thread,] level, local)
Synopsis: debug.getinfo([thread,] function [, what])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local what = {
    "n", -- Fills in the field `name` and `namewhat`.
    "S", -- Fills in the fields `source`, `short_src`,
         -- `linedefined`, `lastlinedefined`, and `what`.
    "l", -- Fills in the field `currentline`.
    "u", -- Fills in the field `nups`.
    "f", -- Pushes onto the stack the function that is running at
         -- the given level.
    "L", -- Pushes onto the stack a table whose indices are the
         -- numbers of the lines that are valid on the function.
}
-- Fills in the field `istailcall`.
if test_lib.lua_current_version_ge_than(5, 2) then
    table.insert(what, "t")
end
-- Fills in the fields `ftransfer` and `ntransfer`.
if test_lib.lua_current_version_ge_than(5, 4) then
    table.insert(what, "r")
end

local hook_mask = {
    "c", -- The hook is called every time Lua calls a function.
    "r", -- The hook is called every time Lua returns from a
         -- function.
    "l", -- The hook is called every time Lua enters a new line of
         -- code.
}

local loadstring = type(loadstring) == "function" and loadstring or load

local what_modes_str
local what_modes_map

local function check_getinfo(ar)
    if what_modes_map.S then
        assert(ar.source ~= nil and type(ar.source) == "string")
        assert(ar.short_src ~= nil and type(ar.short_src) == "string")
        assert(ar.linedefined ~= nil and type(ar.linedefined) == "number")
        assert(ar.lastlinedefined ~= nil and
               type(ar.lastlinedefined) == "number")
        assert(ar.what ~= nil and (ar.what == "Lua" or
                                   ar.what == "C" or
                                   ar.what == "main"))
        -- Beware, in PUC Rio Lua `srclen` can be omitted with
        -- `S` mode, see <ldebug.c>.
        assert(ar.srclen == nil or type(ar.srclen) == "number")
    end

    if what_modes_map.l then
        assert(ar.currentline ~= nil and type(ar.currentline) == "number")
    end

    if what_modes_map.t then
        assert(ar.name == nil or type(ar.name) == "string")
        assert(ar.namewhat == "global" or
               ar.namewhat == "local" or
               ar.namewhat == "method" or
               ar.namewhat == "field" or
               ar.namewhat == "upvalue" or
               ar.namewhat == "" or
               -- Undocumented in PUC Rio Lua (5.4+?).
               ar.namewhat == "hook" or
               ar.namewhat == "metamethod" or
               ar.namewhat == nil)
    end

    if what_modes_map.t then
        assert(type(ar.istailcall) == "boolean")
    end

    if what_modes_map.u then
        assert(ar.nups ~= nil and type(ar.nups) == "number")
        assert(ar.nparams ~= nil and type(ar.nparams) == "number")
        if ar.what == "C" then
            assert(ar.nparams == 0)
            assert(ar.isvararg == true)
        end
        assert(type(ar.isvararg) == "boolean")
    end

    if what_modes_map.r then
        assert(ar.ftransfer ~= nil and type(ar.ftransfer) == "number")
        assert(ar.ntransfer ~= nil and type(ar.ntransfer) == "number")
    end
end

local function touch_upvalues(func, nups)
    if not func then return end
    for j = 1, nups do
        local n, _ = debug.getupvalue(func, j)
        if not n then break end
    end
end

local function debug_hook()
    local level = 0
    local ar = debug.getinfo(level, what_modes_str)
    while ar do
        -- "Touch" fields.
        check_getinfo(ar)

        -- "Touch" locals.
        local i = 1
        while true do
            local name, _ = debug.getlocal(level, i)
            if name == nil then break end
            i = i + 1
        end

        -- "Touch" upvalues.
        local func = debug.getinfo(level, what_modes_str).func
        local nups = debug.getinfo(level, "u").nups
        touch_upvalues(func, nups)

        level = level + 1
        ar = debug.getinfo(level, what_modes_str)
    end
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)

    -- Generate a random 'what'.
    what_modes_map = {}
    local what_modes_array = {}
    local count_modes = fdp:consume_integer(0, #what)
    for _ = 0, count_modes do
        local mode = fdp:oneof(what)
        table.insert(what_modes_array, mode)
        what_modes_map[mode] = true
    end
    what_modes_str = table.concat(what_modes_array)

    -- Generate a random hook mask.
    local n_hook_mask = fdp:consume_integer(0, #hook_mask)
    local mask = {}
    for _ = 0, n_hook_mask do
        local m = fdp:oneof(hook_mask)
        table.insert(mask, m)
    end

    -- Turn on the hook.
    debug.sethook(debug_hook, table.concat(mask), 1)

    local code = fdp:consume_string(test_lib.MAX_STR_LEN)
    local chunk = loadstring(code)
    if chunk == nil then
        return -1
    end
    pcall(chunk)

    -- Turn off the hook.
    debug.sethook()
end

local args = {
    artifact_prefix = "debug_torture_",
}
-- lj_bcread.c:123: bcread_byte: buffer read overflow
if test_lib.lua_version() == "LuaJIT" then
    args.only_ascii = 1
end
luzer.Fuzz(TestOneInput, nil, args)
