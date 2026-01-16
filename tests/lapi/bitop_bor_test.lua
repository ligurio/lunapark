--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

ARM64: Should not fuse sign-extension into logical operands,
can fuse rotations though,
https://github.com/LuaJIT/LuaJIT/issues/1076

Wrong code generation for constants in bitwise operations,
https://github.com/lua/lua/commit/c764ca71a639f5585b5f466bea25dc42b855a4b0

Synopsis: bit.bor(x1 [,x2...])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local unpack = unpack or table.unpack

local bor
if test_lib.lua_version() == "LuaJIT" then
    bor = bit.bor
else
    bor = test_lib.bitwise_op("|")
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local MAX_INT = test_lib.MAX_INT
    local MIN_INT = test_lib.MIN_INT
    local x = fdp:consume_integer(MIN_INT, MAX_INT)
    local y = fdp:consume_integer(MIN_INT, MAX_INT)
    local z = fdp:consume_integer(MIN_INT, MAX_INT)
    local res = bor(x, y)
    assert(type(res) == "number")

    -- Commutative law.
    assert(bor(x, y) == bor(y, x))

    assert(bor(x, bor(y, z)) == bor(bor(x, y), z))
    assert(bor(x, 0) == x)
    assert(bor(x, x) == x)
    if test_lib.lua_version() == "LuaJIT" then
        local MAX_UINT = bor(test_lib.MAX_INT, test_lib.MIN_INT)
        assert(bor(x, MAX_UINT) == MAX_UINT)
    else
        local MAX_UINT64 = bor(test_lib.MAX_INT64, test_lib.MIN_INT64)
        assert(bor(x, MAX_UINT64) == MAX_UINT64)
    end

    -- Multiple arguments.
    -- `n` must be less than UINT_MAX and there are at least extra
    -- free stack slots in the stack, otherwise an error
    -- "too many results to unpack" is raised, see <ltablib.c>.
    local n = fdp:consume_integer(2, 1024)
    local args = fdp:consume_integers(0, MAX_INT, n)
    res = bor(unpack(args))
    assert(type(res) == "number")

    -- Commutative law.
    table.sort(args)
    assert(res == bor(unpack(args)))
end

local args = {
    artifact_prefix = "bitop_bor_",
}
luzer.Fuzz(TestOneInput, nil, args)
