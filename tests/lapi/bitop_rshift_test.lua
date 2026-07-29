--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Missing guard for obscure situations with open upvalues aliasing SSA slots,
https://github.com/LuaJIT/LuaJIT/issues/176

Negation in macro 'luaV_shiftr' may overflow,
https://github.com/lua/lua/commit/62fb93442753cbfb828335cd172e71471dffd536

Synopsis: bit.rshift(x, n)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local is_luajit = test_lib.lua_version() == "LuaJIT"

local rshift
if is_luajit then
    rshift = bit.rshift
else
    rshift = test_lib.bitwise_op(">>")
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
    local res = rshift(x, n)
    assert(type(res) == "number")

    -- Zero shift.
    assert(rshift(x, 0) == x)

    -- Composability.
    assert(rshift(x, 2) == rshift(rshift(x, 1), 1))

    -- LuaJIT masks the shift count to 5 bits.
    if is_luajit then
        assert(rshift(x, n) == rshift(x, n % 32))
    elseif n >= 64 then
        assert(rshift(x, n) == 0)
    end

    -- For non-negative x, rshift(x, n) == floor(x / 2^sh).
    if x >= 0 then
        local sh = is_luajit and n % 32 or n
        assert(rshift(x, n) == math.floor(x / (2 ^ sh)))
    end

    -- Consistency with tobit (LuaJIT only).
    if is_luajit then
        -- `rshift` is assigned in both branches above, so the
        -- analyzer cannot infer a single function type.
        ---@diagnostic disable-next-line: param-type-mismatch
        assert(rshift(bit.tobit(x), n) == bit.tobit(rshift(x, n)))
    end
end

local args = {
    artifact_prefix = "bitop_rshift_",
}
luzer.Fuzz(TestOneInput, nil, args)
