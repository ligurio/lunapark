--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Synopsis: bit.swap(x)
]]

local luzer = require("luzer")
local test_lib = require("lib")

if test_lib.lua_version() ~= "LuaJIT" then
    print("Unsupported version.")
    os.exit(0)
end

local bswap = bit.bswap
local tobit = bit.tobit
local bnot = bit.bnot

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    local MAX_INT = test_lib.MAX_INT
    local MIN_INT = test_lib.MIN_INT
    local x = fdp:consume_integer(MIN_INT, MAX_INT)
    local res = bswap(x)
    assert(type(res) == "number")

    -- Involution.
    assert(bswap(res) == tobit(x))

    -- bswap commutes with bnot.
    assert(bswap(bnot(x)) == bnot(bswap(x)))

    -- Edge cases. `bit.bswap` operates on signed 32-bit values, so
    -- compare with the truncated literal.
    assert(bswap(0) == 0)
    assert(bswap(0xFFFFFFFF) == tobit(0xFFFFFFFF))
end

local args = {
    artifact_prefix = "bitop_bswap_",
}
luzer.Fuzz(TestOneInput, nil, args)
