--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

Synopsis: select(index, ...)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local unpack = unpack or table.unpack
local MAX_INT = test_lib.MAX_INT64
local MIN_INT = test_lib.MIN_INT64
local MAX_STR_LEN = test_lib.MAX_STR_LEN

local function random_value(fdp)
    local item_type = fdp:oneof({
        "boolean",
        "integer",
        "number",
        "string",
        "table",
    })
    local item
    if item_type == "string" then
        item = fdp:consume_string(MAX_STR_LEN)
    elseif item_type == "boolean" then
        item = fdp:consume_boolean()
    elseif item_type == "integer" then
        item = fdp:consume_integer(MIN_INT, MAX_INT)
    elseif item_type == "number" then
        item = fdp:consume_number(MIN_INT, MAX_INT)
    elseif item_type == "table" then
        local MAX_N = 10
        item = fdp:consume_numbers(MIN_INT, MAX_INT, MAX_N)
    else
        assert("Unsupported type")
    end
    return item
end

local ignored_msgs = {
    "index out of range",
}

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)

    local MAX_N = 1000
    local count = fdp:consume_integer(1, MAX_N)
    local tbl = {}
    for _ = 1, count do
        table.insert(tbl, random_value(fdp))
    end

    local index = fdp:consume_boolean() and "#" or
                  fdp:consume_integer(0, MAX_INT)
    if index == "#" then
        assert(select(index, unpack(tbl)) == count)
    end
    local err_handler = test_lib.err_handler(ignored_msgs)
    local ok, res = xpcall(select, err_handler, index, unpack(tbl))
    if not ok then return end
    -- Don't want to test multiresults.
    if index == "#" then
        assert(res == count)
    else
        -- The value by the given index.
        assert(res == tbl[index])
    end
end

local args = {
    artifact_prefix = "builtin_select_",
}
luzer.Fuzz(TestOneInput, nil, args)
