--[=[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html
6.5 – Table Manipulation,
https://www.lua.org/manual/5.2/manual.html#6.5

Compiler can optimize away overflow check in table.unpack,
https://www.lua.org/bugs.html#5.2.3-1

Returns the type of its only argument, coded as a string.
The possible results of this function are "nil"
(a string, not the value nil), "number", "string",
"boolean", "table", "function", "thread", and "userdata".

lua_checkstack may have arithmetic overflow for large 'size',
https://www.lua.org/bugs.html#5.1.3-3

unpack with maximum indices may crash due to arithmetic overflow,
https://www.lua.org/bugs.html#5.1.3-4

Fix overflow check in unpack(),
https://github.com/LuaJIT/LuaJIT/pull/574

Synopsis: unpack(list [, i [, j]])
]]=]

local luzer = require("luzer")
local test_lib = require("lib")

local unpack = unpack or table.unpack
local MAX_INT = test_lib.MAX_INT64
local MIN_INT = test_lib.MAX_INT64

local ignored_msgs = {
    -- `i` and `j` cannot be bigger than INT_MAX, otherwise an
    -- error "too many results to unpack" is raised.
    "too many results to unpack",
}

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)

    local str = fdp:consume_string(test_lib.MAX_STR_LEN)
    local str_chars = {}
    str:gsub(".", function(c)
        local with_key = fdp:consume_boolean()
        if with_key then
            local idx = fdp:consume_integer(MIN_INT, MAX_INT)
            str_chars[idx] = c
        else
            table.insert(str_chars, c)
        end
    end)

    -- By default, `i` is 1 and `j` is #list.
    local default_indices = fdp:consume_boolean()
    if default_indices then
        unpack(str_chars)
    end

    local i = fdp:consume_integer(MIN_INT, MAX_INT)
    local j = fdp:consume_integer(MIN_INT, MAX_INT)
    local err_handler = test_lib.err_handler(ignored_msgs)
    local ok, _ = xpcall(unpack, err_handler, str_chars, i, j)
    if not ok then return end
end

local args = {
    artifact_prefix = "builtin_unpack_",
}
luzer.Fuzz(TestOneInput, nil, args)
