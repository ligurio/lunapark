--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Synopsis: bit.arshift(x, n)
]]

local luzer = require("luzer")
local test_lib = require("lib")

if test_lib.lua_version() ~= "LuaJIT" then
    print("Unsupported version.")
    os.exit(0)
end

local arshift = bit.arshift
local bxor = bit.bxor

local function is_opposite_sign(a, b)
    return bxor(a, b) < 0
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local MAX_INT = test_lib.MAX_INT
    local MIN_INT = test_lib.MIN_INT
    local x = fdp:consume_integer(MIN_INT, MAX_INT)
    local n = fdp:consume_integer(MIN_INT, MAX_INT)
    local res = arshift(x, n)
    assert(type(res) == "number")
    assert(is_opposite_sign(x, res) == false)
end

local args = {
    artifact_prefix = "bitop_arshift_",
}
luzer.Fuzz(TestOneInput, nil, args)
