--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.6 – Table Manipulation,
https://www.lua.org/manual/5.1/manual.html#5.5

'table.sort' does not work for partial orders,
https://github.com/lua/lua/commit/825ac8eca8e384d6ad2538b5670088c31e08a9d7

Synopsis: table.sort(list [, comp])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local MIN_INT = test_lib.MIN_INT64
local MAX_INT = test_lib.MAX_INT64

local function random_table(fdp, n)
    local count = fdp:consume_integer(0, n)
    local item_type = fdp:oneof({ "number", "string" })
    local tbl
    if item_type == "number" then
        tbl = fdp:consume_integers(MIN_INT, MAX_INT, count)
    elseif item_type == "string" then
        tbl = fdp:consume_strings(test_lib.MAX_STR_LEN, count)
    else
        assert("Unsupported type")
    end
    return tbl
end

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    -- Beware, huge length leads to slow units.
    local MAX_N = 1000
    local t = random_table(fdp, MAX_N)
    local len = #t
    table.sort(t)
    assert(len == #t)

    for i = 1, len - 1 do
        assert(t[i] <= t[i + 1])
    end
end

local args = {
    artifact_prefix = "table_sort_",
}
luzer.Fuzz(TestOneInput, nil, args)
