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

local band
if test_lib.lua_version() == "LuaJIT" then
    band = bit.band
else
    band = test_lib.bitwise_op("&")
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
    assert(band(x, y) == band(y, x))

    assert(band(x, band(y, z)) == band(band(x, y), z))
    assert(band(x, 0) == 0)
    assert(band(x, x) == x)
    assert(band(x, -1) == x)

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
