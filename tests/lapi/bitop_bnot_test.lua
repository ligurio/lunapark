--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Synopsis: bit.bnot(x)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local bnot
if test_lib.lua_version() == "LuaJIT" then
    bnot = bit.bnot
else
    bnot = test_lib.bitwise_op("~")
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local MAX_INT = test_lib.MAX_INT
    local MIN_INT = test_lib.MIN_INT
    local x = fdp:consume_integer(MIN_INT, MAX_INT)
    local res = bnot(x)
    assert(type(res) == "number")

    -- For any integer x, the following identity holds [1]:
    --
    -- 1. https://www.lua.org/manual/5.2/manual.html
    assert(bnot(x) == (-1 - x))
end

local args = {
    artifact_prefix = "bitop_bnot_",
}
luzer.Fuzz(TestOneInput, nil, args)
