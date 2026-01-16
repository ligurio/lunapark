--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.9 – Operating System Facilities
https://www.lua.org/manual/5.3/manual.html#6.9

Synopsis: os.time([table])
]]

local luzer = require("luzer")
local test_lib = require("lib")
local MAX_INT64 = test_lib.MAX_INT64
local MIN_INT64 = test_lib.MIN_INT64

local ignored_msgs = {
    "field 'year' is out-of-bound",
}

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    os.setlocale(test_lib.random_locale(fdp), "all")
    local time = {
        day = fdp:consume_number(MIN_INT64, MAX_INT64),
        hour = fdp:consume_number(MIN_INT64, MAX_INT64),
        isdst = fdp:consume_boolean(),
        min = fdp:consume_number(MIN_INT64, MAX_INT64),
        month = fdp:consume_number(MIN_INT64, MAX_INT64),
        sec = fdp:consume_number(MIN_INT64, MAX_INT64),
        year = fdp:consume_number(MIN_INT64, MAX_INT64),
    }
    local err_handler = test_lib.err_handler(ignored_msgs)
    local ok, res = xpcall(os.time, err_handler, time)
    if not ok then return end
    local type_check = type(res) == "number" or type(res) == "table"
    local undocumented_type_check = res == nil
    assert(type_check or undocumented_type_check)
end

local args = {
    artifact_prefix = "os_time_",
}
luzer.Fuzz(TestOneInput, nil, args)
