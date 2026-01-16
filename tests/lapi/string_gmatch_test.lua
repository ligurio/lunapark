--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.4 – String Manipulation
https://www.lua.org/manual/5.3/manual.html#6.4

GC64: string.gmatch crash,
https://github.com/LuaJIT/LuaJIT/issues/300

gmatch iterator fails when called from a coroutine different from
the one that created it,
https://www.lua.org/bugs.html#5.3.2-3

Synopsis: string.gmatch(s, pattern [, init])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    os.setlocale(test_lib.random_locale(fdp), "all")
    local s = fdp:consume_string(test_lib.MAX_STR_LEN)
    local pattern = fdp:consume_string(test_lib.MAX_STR_LEN)
    local init = fdp:consume_integer(0, test_lib.MAX_INT)
    string.gmatch(s, pattern, init)
end

local args = {
    artifact_prefix = "string_gmatch_",
}
luzer.Fuzz(TestOneInput, nil, args)
