--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

recff_next does not take into account the situation when all next results are consumed,
https://github.com/LuaJIT/LuaJIT/issues/753

Key removed from a table during traversal may not be accepted by 'next',
https://github.com/lua/lua/commit/52c86797608f1bf927be5bab1e9b97b7d35bdf2c

Synopsis: next(table [, index])
]]

local luzer = require("luzer")
local test_lib = require("lib")
local MAX_INT = test_lib.MAX_INT

local ignored_msgs = {
    "invalid key to 'next'",
}

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local MAX_N = 1000
    local count = fdp:consume_integer(0, MAX_N)
    local tbl = fdp:consume_integers(test_lib.MIN_INT, test_lib.MAX_INT, count)
    -- Use string keys to activate hash part of the table.
    tbl.a = fdp:consume_string(test_lib.MAX_STR_LEN)
    tbl.b = fdp:consume_string(test_lib.MAX_STR_LEN)
    local index = fdp:consume_integer(0, MAX_INT)

    local err_handler = test_lib.err_handler(ignored_msgs)
    local ok, res = xpcall(next, err_handler, tbl, index)
    if not ok then return end
    assert(type(res) == "number" or type(res) == "string")
end

local args = {
    artifact_prefix = "builtin_next_",
}
luzer.Fuzz(TestOneInput, nil, args)
