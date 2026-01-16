--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Wrong code generation for constants in bitwise operations,
https://github.com/lua/lua/commit/c764ca71a639f5585b5f466bea25dc42b855a4b0

Synopsis: bit.lshift(x, n)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local lshift
if test_lib.lua_version() == "LuaJIT" then
    lshift = bit.lshift
else
    lshift = test_lib.bitwise_op("<<")
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local MAX_INT = test_lib.MAX_INT
    local x = fdp:consume_integer(0, MAX_INT)
    local n = fdp:consume_integer(1, 32)
    local res = lshift(x, n)
    assert(type(res) == "number")
end

local args = {
    artifact_prefix = "bitop_lshift_",
}
luzer.Fuzz(TestOneInput, nil, args)
