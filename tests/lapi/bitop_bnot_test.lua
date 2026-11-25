--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Synopsis: bit.bnot(x)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local is_luajit = test_lib.lua_version() == "LuaJIT"

local bnot
if is_luajit then
    bnot = bit.bnot
else
    bnot = test_lib.bitwise_op("~")
end

-- Edge cases.
assert(bnot(0) == -1)
assert(bnot(-1) == 0)

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    local MAX_INT = test_lib.MAX_INT
    local MIN_INT = test_lib.MIN_INT
    local x = fdp:consume_integer(MIN_INT, MAX_INT)
    local res = bnot(x)
    assert(type(res) == "number")

    -- For any integer x, the following identity holds [1]:
    --
    -- 1. https://www.lua.org/manual/5.2/manual.html
    assert(bnot(x) == (-1 - x))

    -- Involution.
    local double_not = bnot(bnot(x))
    if is_luajit then
        assert(double_not == bit.tobit(x))
    else
        assert(double_not == x)
    end
end

local args = {
    artifact_prefix = "bitop_bnot_",
}
luzer.Fuzz(TestOneInput, nil, args)
