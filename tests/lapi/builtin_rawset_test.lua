--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

Memory-allocation error when resizing a table can leave it in an
inconsistent state, https://www.lua.org/bugs.html#5.3.4-7

rawset and rawget do not ignore extra arguments,
https://www.lua.org/bugs.html#5.0.2-4

Synopsis: rawset(table, index, value)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local MAX_INT = test_lib.MAX_INT
local MIN_INT = test_lib.MIN_INT
local MAX_STR_LEN = test_lib.MAX_STR_LEN

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local MAX_N = 1000
    local count = fdp:consume_integer(0, MAX_N)
    local tbl = fdp:consume_integers(MIN_INT, MAX_INT, count)
    local value = fdp:consume_string(MAX_STR_LEN)

    -- Set new value to a table without metatable.
    local res = rawset(tbl, "field", value)
    assert(res.field == value)

    local mt = {
        __newindex = function(_table, _key, _value)
            assert(nil, "assertion is not reachable")
        end,
    }
    setmetatable(tbl, mt)
    value = fdp:consume_string(MAX_STR_LEN)

    -- Set new value to a table *with* metatable.
    res = rawset(tbl, "field", value)
    assert(res.field == value)
end

local args = {
    artifact_prefix = "builtin_rawset_",
}
luzer.Fuzz(TestOneInput, nil, args)
