--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

Synopsis: rawequal(v1, v2)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local MAX_INT = test_lib.MAX_INT
local MIN_INT = test_lib.MIN_INT
local MAX_STR_LEN = test_lib.MAX_STR_LEN

-- "A metamethod only is selected when both objects being compared
-- have the same type and the same metamethod for the selected
-- operation.", https://www.lua.org/manual/5.1/manual.html#2.8.
local function random_pair_values(fdp)
    local item_type = fdp:oneof({
        "boolean",
        "integer",
        "number",
        "string",
        "table",
    })
    local item1, item2
    if item_type == "string" then
        item1 = fdp:consume_string(MAX_STR_LEN)
        item2 = fdp:consume_string(MAX_STR_LEN)
    elseif item_type == "boolean" then
        item1 = fdp:consume_boolean()
        item2 = fdp:consume_boolean()
    elseif item_type == "integer" then
        item1 = fdp:consume_integer(MIN_INT, MAX_INT)
        item2 = fdp:consume_integer(MIN_INT, MAX_INT)
    elseif item_type == "number" then
        item1 = fdp:consume_number(MIN_INT, MAX_INT)
        item2 = fdp:consume_number(MIN_INT, MAX_INT)
    elseif item_type == "table" then
        item1 = fdp:consume_numbers(MIN_INT, MAX_INT, 10)
        item2 = fdp:consume_numbers(MIN_INT, MAX_INT, 10)
    else
        assert("Unsupported type")
    end
    return item1, item2
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local v1, v2 = random_pair_values(fdp)
    local comp1 = rawequal(v1, v2)
    assert(type(comp1 == "boolean"))
    local mt = {
        __eq = function(_op1, _op2)
            assert(nil, "assertion is not reachable")
        end,
    }
    debug.setmetatable(v1, mt)
    debug.setmetatable(v2, mt)
    local comp2 = rawequal(v1, v2)
    assert(type(comp2 == "boolean"))
    assert(comp1 == comp2)
end

local args = {
    artifact_prefix = "builtin_rawequal_",
}
luzer.Fuzz(TestOneInput, nil, args)
