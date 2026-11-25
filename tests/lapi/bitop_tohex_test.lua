--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Synopsis: bit.tohex(x [,n])
]]

local luzer = require("luzer")
local test_lib = require("lib")

if test_lib.lua_version() ~= "LuaJIT" then
    print("Unsupported version.")
    os.exit(0)
end

local tohex = bit.tohex
local tobit = bit.tobit

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    local MAX_INT = test_lib.MAX_INT
    local MIN_INT = test_lib.MIN_INT
    local x = fdp:consume_integer(MIN_INT, MAX_INT)
    -- A huge `n` produces a huge string, keep the range small.
    local n = fdp:consume_integer(-16, 16)
    local res = tohex(x, n)
    assert(type(res) == "string")

    -- Length: `n` positive gives exactly `n` digits, `n` negative
    -- gives exactly `-n` digits, `n` zero gives an empty string.
    if n > 0 then
        assert(#res == n)
    elseif n < 0 then
        assert(#res == -n)
    else
        assert(#res == 0)
    end

    -- Only hex digits. A negative `n` produces uppercase digits.
    if #res > 0 then
        assert(res:match("^[0-9a-fA-F]+$"))
    end

    -- Round-trip recovers the value when all 32 bits are printed.
    if n >= 8 then
        local value = assert(tonumber(res, 16))
        assert(tobit(value) == tobit(x))
    end
end

local args = {
    artifact_prefix = "bitop_tohex_",
}
luzer.Fuzz(TestOneInput, nil, args)
