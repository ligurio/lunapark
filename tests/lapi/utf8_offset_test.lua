--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.5 – UTF-8 Support
https://www.lua.org/manual/5.3/manual.html#6.5

Synopsis: utf8.offset(s, n [, i])
]]

local luzer = require("luzer")
local test_lib = require("lib")
local MAX_INT = test_lib.MAX_INT
local MIN_INT = test_lib.MIN_INT

-- The function is introduced in Lua 5.3.
if test_lib.lua_current_version_lt_than(5, 3) then
    print("Unsupported version.")
    os.exit()
end

local ignored_msgs = {
    "initial position is a continuation byte",
}

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local max_len = fdp:consume_integer(0, MAX_INT)
    local s = fdp:consume_string(max_len)
    local n = fdp:consume_integer(MIN_INT, MAX_INT)
    local i = fdp:consume_integer(1, MAX_INT)
    os.setlocale(test_lib.random_locale(fdp), "all")
    local err_handler = test_lib.err_handler(ignored_msgs)
    local ok, _ = xpcall(utf8.offset, err_handler, s, n, i)
    if not ok then return end
end

local args = {
    artifact_prefix = "utf8_offset_",
}
luzer.Fuzz(TestOneInput, nil, args)
