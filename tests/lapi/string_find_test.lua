--[=[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.4 – String Manipulation
https://www.lua.org/manual/5.3/manual.html#6.4

Bug in "Don't use STRREF for pointer diff in string.find().",
https://github.com/LuaJIT/LuaJIT/issues/540

Some patterns can overflow the C stack, due to recursion,
https://www.lua.org/bugs.html#5.2.1-1

Properly fix pointer diff in string.find(),
https://github.com/LuaJIT/LuaJIT/commit/0bee44c9

Synopsis: string.find(s, pattern [, init [, plain]])
]]=]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    os.setlocale(test_lib.random_locale(fdp), "all")
    local str = fdp:consume_string(test_lib.MAX_STR_LEN)
    local pattern = fdp:consume_string(test_lib.MAX_STR_LEN)
    local init = fdp:consume_integer(0, test_lib.MAX_INT)
    local plain = fdp:consume_boolean()
    -- Avoid errors like "malformed pattern (missing ']')".
    local ok, _ = pcall(string.find, str, pattern, init, plain)
    if not ok then
        return
    end
    local begin_pos, end_pos = string.find(str, pattern, init, plain)
    -- `string.format()` returns two numbers or "fail".
    assert((type(begin_pos) == "number" and type(end_pos) == "number") or
           (begin_pos == nil or end_pos == nil) or
           begin_pos == "fail")
    -- `string.format()` and `string:format()` is the same.
    assert(string.find(str, pattern, init, plain) ==
           str:find(pattern, init, plain))
end

local args = {
    artifact_prefix = "string_find_",
}
luzer.Fuzz(TestOneInput, nil, args)
