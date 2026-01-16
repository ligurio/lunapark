--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

Incorrect recording of getmetatable() for IO handlers,
https://github.com/LuaJIT/LuaJIT/issues/1279

Synopsis: getmetatable(object)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local tbl = {}
    local fdp = luzer.FuzzedDataProvider(buf)
    -- Build a random table and set a known key to it to check
    -- it's presence in metatable.
    local MAX_N = 100
    local count = fdp:consume_integer(0, MAX_N)
    local mt = fdp:consume_integers(test_lib.MIN_INT, test_lib.MAX_INT, count)
    setmetatable(tbl, mt)
    local metatable = getmetatable(tbl)
    assert(test_lib.arrays_equal(metatable, mt))
end

local args = {
    artifact_prefix = "builtin_getmetatable_",
}
luzer.Fuzz(TestOneInput, nil, args)
