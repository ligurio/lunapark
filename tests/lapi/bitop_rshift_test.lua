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

local rshift
if test_lib.lua_version() == "LuaJIT" then
    rshift = bit.rshift
else
    rshift = test_lib.bitwise_op(">>")
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local MAX_INT = test_lib.MAX_INT
    local x = fdp:consume_integer(0, MAX_INT)
    local n = fdp:consume_integer(1, 32)
    local res = rshift(x, n)
    assert(type(res) == "number")
end

local args = {
    artifact_prefix = "bitop_rshift_",
}
luzer.Fuzz(TestOneInput, nil, args)
