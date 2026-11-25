--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Synopsis: bit.arshift(x, n)
]]

local luzer = require("luzer")
local test_lib = require("lib")

if test_lib.lua_version() ~= "LuaJIT" then
    print("Unsupported version.")
    os.exit(0)
end

local arshift = bit.arshift
local bxor = bit.bxor
local rshift = bit.rshift
local tobit = bit.tobit

local function is_opposite_sign(a, b)
    return bxor(a, b) < 0
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    local MAX_INT = test_lib.MAX_INT
    local MIN_INT = test_lib.MIN_INT
    local x = fdp:consume_integer(MIN_INT, MAX_INT)
    ---@type integer
    local n = fdp:consume_integer(MIN_INT, MAX_INT)
    local res = arshift(x, n)
    assert(type(res) == "number")
    assert(is_opposite_sign(x, res) == false)

    -- Zero shift.
    assert(arshift(x, 0) == tobit(x))

    -- LuaJIT masks the shift count to 5 bits.
    assert(arshift(x, n) == arshift(x, n % 32))

    -- For non-negative x, arshift coincides with logical rshift.
    if x >= 0 and n >= 0 then
        assert(arshift(x, n) == rshift(x, n))
    end

    -- Composability: arshift(x, 2) == arshift(arshift(x, 1), 1).
    assert(arshift(x, 2) == arshift(arshift(x, 1), 1))

    -- Sign-extension: arshift(x, 1) == floor(tobit(x) / 2).
    assert(arshift(x, 1) == math.floor(tobit(x) / 2))
end

local args = {
    artifact_prefix = "bitop_arshift_",
}
luzer.Fuzz(TestOneInput, nil, args)
