--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

Fix binary number literal parsing,
https://www.freelists.org/post/luajit/Fractional-binary-number-literals
https://github.com/tarantool/luajit/commit/0ab421bc4077fa83039e653d4959fcdb2fa96ca6

tonumber produces wrong results for large exponents,
https://github.com/LuaJIT/LuaJIT/issues/788

tonumber("-0") returns 0, but it should be -0,
https://github.com/LuaJIT/LuaJIT/issues/528

Fix conversion for strings with null char,
https://github.com/LuaJIT/LuaJIT/pull/558

Synopsis: tonumber(e [, base])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local MIN_BASE = 2
local MAX_BASE = 36

-- 1. If one call `tonumber` with a specified base, then the first
-- argument must always be a string, otherwise one will get
-- surprises:
--
-- $ luajit -e 'print(tonumber(0xa, 16))'
-- 16
-- $ luajit -e 'print(tonumber("0xa", 16))'
-- 10
--
-- The Lua 5.1 documentation clearly states that:
-- If the argument is already a number or a string convertible to
-- a number, then tonumber returns this number;
--
-- 2. The surprises do not end if the first argument is a string,
-- namely, take 2 in 16-digit exponential notation:
--
-- $ luajit -e 'print(tonumber("0x1p1"), tonumber("0x1p1", 16))'
-- 2 nil
--
-- If one explicitly specify the base, you get `nil`. This
-- behavior persists until the Lua 5.4.

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local base = fdp:consume_integer(MIN_BASE, MAX_BASE)
    local e = fdp:consume_string(test_lib.MAX_STR_LEN)
    local res = tonumber(e, base)
    assert(type(res) == "number" or res == nil)
end

local args = {
    artifact_prefix = "builtin_tonumber_",
}
luzer.Fuzz(TestOneInput, nil, args)
