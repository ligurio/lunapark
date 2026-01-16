--[=[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.9 – Operating System Facilities
https://www.lua.org/manual/5.3/manual.html#6.9

LuaJIT 2.1 VM out of memory for `os.date`,
https://github.com/LuaJIT/LuaJIT/issues/463

Checking a format for os.date may read pass the format string,
https://www.lua.org/bugs.html#5.3.3-2

os.date throws an error when result is the empty string,
https://www.lua.org/bugs.html#5.1.1-4

Synopsis: os.date([format [, time]])
]]=]

local luzer = require("luzer")
local test_lib = require("lib")

local ignored_msgs = {
    "invalid conversion specifier",
}

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    os.setlocale(test_lib.random_locale(fdp), "all")
    local format = fdp:consume_string(test_lib.MAX_STR_LEN)
    local time = fdp:consume_integer(test_lib.MIN_INT, test_lib.MAX_INT)
    local err_handler = test_lib.err_handler(ignored_msgs)
    local ok, res = xpcall(os.date, err_handler, format, time)
    if not ok then return end
    local type_check = type(res) == "string" or type(res) == "table"
    local undocumented_type_check = type(res) == "number" or res == nil
    assert(type_check or undocumented_type_check)
end

local args = {
    artifact_prefix = "os_date_",
}
luzer.Fuzz(TestOneInput, nil, args)
