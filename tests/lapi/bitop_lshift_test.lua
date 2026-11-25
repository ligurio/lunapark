--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Wrong code generation for constants in bitwise operations,
https://github.com/lua/lua/commit/c764ca71a639f5585b5f466bea25dc42b855a4b0

Synopsis: bit.lshift(x, n)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local is_luajit = test_lib.lua_version() == "LuaJIT"

local lshift
if is_luajit then
    lshift = bit.lshift
else
    lshift = test_lib.bitwise_op("<<")
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    local MAX_INT = test_lib.MAX_INT
    local MIN_INT = test_lib.MIN_INT
    local x = fdp:consume_integer(MIN_INT, MAX_INT)
    -- PUC Rio Lua shifts by 64 or more always produce zero, so keep
    -- the range meaningful for it.
    local MAX_SHIFT = is_luajit and MAX_INT or 64
    local n = fdp:consume_integer(0, MAX_SHIFT)
    local res = lshift(x, n)
    assert(type(res) == "number")

    -- Zero shift.
    assert(lshift(x, 0) == x)

    -- Composability.
    assert(lshift(x, 2) == lshift(lshift(x, 1), 1))

    -- LuaJIT masks the shift count to 5 bits.
    if is_luajit then
        assert(lshift(x, n) == lshift(x, n % 32))
    elseif n >= 64 then
        assert(lshift(x, n) == 0)
    end

    -- Consistency with tobit (LuaJIT only).
    if is_luajit then
        -- `lshift` is assigned in both branches above, so the
        -- analyzer cannot infer a single function type.
        ---@diagnostic disable-next-line: param-type-mismatch
        assert(lshift(bit.tobit(x), n) == bit.tobit(lshift(x, n)))
    end
end

local args = {
    artifact_prefix = "bitop_lshift_",
}
luzer.Fuzz(TestOneInput, nil, args)
