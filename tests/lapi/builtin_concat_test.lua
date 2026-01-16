--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

2.5.4 – Concatenation
https://www.lua.org/manual/5.1/manual.html

Recording of __concat in GC64 mode,
https://github.com/LuaJIT/LuaJIT/issues/839

Bug: Unbalanced Stack After Hot Instruction error on table concatenation,
https://github.com/LuaJIT/LuaJIT/issues/690

LJ_GC64: Fix lua_concat(),
https://github.com/LuaJIT/LuaJIT/issues/881

Buffer overflow in string concatenation,
https://github.com/lua/lua/commit/5853c37a83ec66ccb45094f9aeac23dfdbcde671

Wrong assert when reporting concatenation errors
(manifests only when Lua is compiled in debug mode).
https://www.lua.org/bugs.html#5.2.2-3

Wrong error message in some concatenations,
https://www.lua.org/bugs.html#5.1.2-5

Concat metamethod converts numbers to strings,
https://www.lua.org/bugs.html#5.1.1-8

String concatenation may cause arithmetic overflow, leading to
a buffer overflow,
https://www.lua.org/bugs.html#5.0.2-1
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local str = fdp:consume_string(test_lib.MAX_STR_LEN)
    if str == nil then return -1 end
    local str_chars = {}
    str:gsub(".", function(c) table.insert(str_chars, c) end)

    local str_concat = ""
    for _, c in ipairs(str_chars) do
        str_concat = str_concat .. c
    end
    assert(str_concat == str)
end

local args = {
    artifact_prefix = "builtin_concat_",
}
luzer.Fuzz(TestOneInput, nil, args)
