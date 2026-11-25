--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Wrong code generation for constants in bitwise operations,
https://github.com/lua/lua/commit/c764ca71a639f5585b5f466bea25dc42b855a4b0

Inconsistent behaviour of bit ops in DUALNUM mode,
https://github.com/LuaJIT/LuaJIT/issues/1273

Synopsis: bit.band(x1 [,x2...])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local is_luajit = test_lib.lua_version() == "LuaJIT"

local band
local bor
local bnot
if is_luajit then
    band = bit.band
    bor = bit.bor
    bnot = bit.bnot
else
    band = test_lib.bitwise_op("&")
    bor = test_lib.bitwise_op("|")
    bnot = test_lib.bitwise_op("~")
end

local unpack = unpack or table.unpack

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    local MAX_INT = test_lib.MAX_INT
    local MIN_INT = test_lib.MIN_INT
    local x = fdp:consume_integer(MIN_INT, MAX_INT)
    local y = fdp:consume_integer(MIN_INT, MAX_INT)
    local z = fdp:consume_integer(MIN_INT, MAX_INT)

    -- Commutative law.
    assert(band(x, y) == band(y, x))

    assert(band(x, band(y, z)) == band(band(x, y), z))
    assert(band(x, 0) == 0)
    assert(band(x, x) == x)
    assert(band(x, -1) == x)

    -- Distributive law: a & (b | c) = (a & b) | (a & c).
    assert(band(x, bor(y, z)) == bor(band(x, y), band(x, z)))

    -- Absorption.
    assert(band(x, bor(x, y)) == x)
    assert(bor(x, band(x, y)) == x)

    -- De Morgan's laws.
    assert(bnot(band(x, y)) == bor(bnot(x), bnot(y)))
    assert(bnot(bor(x, y)) == band(bnot(x), bnot(y)))

    -- Consistency with tobit (LuaJIT only).
    if is_luajit then
        -- `band` is assigned in both branches above, so the
        -- analyzer cannot infer a single function type.
        ---@diagnostic disable-next-line: param-type-mismatch
        assert(band(bit.tobit(x), bit.tobit(y)) == bit.tobit(band(x, y)))
    end

    -- Multiple arguments.
    -- `n` must be less than UINT_MAX and there are at least extra
    -- free stack slots in the stack, otherwise an error
    -- "too many results to unpack" is raised, see <ltablib.c>.
    local n = fdp:consume_integer(2, 1024)
    local band_args = fdp:consume_integers(0, MAX_INT, n)
    local res = band(unpack(band_args))
    assert(type(res) == "number")

    -- Commutative law.
    table.sort(band_args)
    assert(res == band(unpack(band_args)))
end

local args = {
    artifact_prefix = "bitop_band_",
}
luzer.Fuzz(TestOneInput, nil, args)
