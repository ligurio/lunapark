--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

rawset and rawget do not ignore extra arguments,
https://www.lua.org/bugs.html#5.0.2-4

Synopsis: rawget(table, index)
]]

local luzer = require("luzer")
local test_lib = require("lib")
local MAX_INT = test_lib.MAX_INT
local MIN_INT = test_lib.MIN_INT

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local MAX_N = 1000
    local count = fdp:consume_integer(0, MAX_N)
    local tbl = fdp:consume_integers(MIN_INT, MAX_INT, count)
    local value = fdp:consume_string(test_lib.MAX_STR_LEN)
    tbl.field = value
    local res = rawget(tbl, "field")
    assert(res == value)
    local mt = {
        __index = function(_table, _key)
            assert(nil, "assertion is not reachable")
        end,
    }
    setmetatable(tbl, mt)
    res = rawget(tbl, "field")
    assert(res == value)
end

local args = {
    artifact_prefix = "builtin_rawget_",
}
luzer.Fuzz(TestOneInput, nil, args)
