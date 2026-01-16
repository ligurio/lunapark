--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

Synopsis: tostring(e)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)

    -- Since Lua 5.5 conversion float to string ensures that, for
    -- any float f, `tonumber(tostring(f)) == f`, but still
    -- avoiding noise like 1.1 converting to "1.1000000000000001",
    -- see [1].
    --
    -- 1. https://github.com/lua/lua/commit/1bf4b80f1ace8384eb9dd6f7f8b67256b3944a7a
    local n1 = fdp:consume_number(test_lib.MIN_INT64, test_lib.MAX_INT64)
    if test_lib.lua_version() == "LuaJIT" then
        n1 = fdp:consume_integer(test_lib.MIN_INT, test_lib.MAX_INT)
    end
    local n2 = tonumber(tostring(n1))
    assert(n1 == n2)
end

local args = {
    artifact_prefix = "builtin_tostring_",
}
luzer.Fuzz(TestOneInput, nil, args)
