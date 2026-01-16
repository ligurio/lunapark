--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Synopsis: bit.bxor(x1 [,x2...])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local bxor
local band
local bor
local bnot
if test_lib.lua_version() == "LuaJIT" then
    bxor = bit.bxor
    band = bit.band
    bor = bit.bor
    bnot = bit.bnot
else
    bxor = test_lib.bitwise_op("~")
    band = test_lib.bitwise_op("&")
    bor = test_lib.bitwise_op("|")
    bnot = test_lib.bitwise_op("~")
end

local unpack = unpack or table.unpack

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local MAX_INT = test_lib.MAX_INT
    local MIN_INT = test_lib.MIN_INT
    local x = fdp:consume_integer(MIN_INT, MAX_INT)
    local y = fdp:consume_integer(MIN_INT, MAX_INT)
    local z = fdp:consume_integer(MIN_INT, MAX_INT)

    -- Commutative law.
    assert(bxor(x, y) == bxor(y, x))

    assert(bxor(x, bxor(y, z)) == bxor(bxor(x, y), z))
    assert(bxor(x, x) == 0)
    -- a ^ b = (a | b) & (~a | ~b)
    assert(bxor(x, y) == band(bor(x, y), bor(bnot(x), bnot(y))))
    -- a ^ b = (a & ~b) | (~a & b)
    assert(bxor(x, y) == bor(band(x, bnot(y)), band(bnot(x), y)))
    assert(bxor(x, y, y) == x)
    assert(bxor(bxor(x, y), y) == x)

    if test_lib.lua_version() == "LuaJIT" then
        local MAX_UINT = bor(test_lib.MAX_INT, test_lib.MIN_INT)
        assert(bxor(x, MAX_UINT) == bnot(x))
    else
        local MAX_UINT64 = bor(test_lib.MAX_INT64, test_lib.MIN_INT64)
        assert(bxor(x, MAX_UINT64) == bnot(x))
    end
    assert(bxor(x, 0) == x)

    -- Multiple arguments.
    -- `n` must be less than UINT_MAX and there are at least extra
    -- free stack slots in the stack, otherwise an error
    -- "too many results to unpack" is raised, see <ltablib.c>.
    local n = fdp:consume_integer(2, 1024)
    local bxor_args = fdp:consume_integers(0, MAX_INT, n)
    local res = bxor(unpack(bxor_args))
    assert(type(res) == "number")

    -- Commutative law.
    table.sort(bxor_args)
    assert(res == bxor(unpack(bxor_args)))
end

local args = {
    artifact_prefix = "bitop_bxor_",
}
luzer.Fuzz(TestOneInput, nil, args)
