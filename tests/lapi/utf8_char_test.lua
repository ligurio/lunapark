--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.5 – UTF-8 Support
https://www.lua.org/manual/5.3/manual.html#6.5

Synopsis: utf8.char(...)
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

local unpack = unpack or table.unpack

local ignored_msgs = {
    "value out of range",
}

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    -- Limit count to prevent error "too many results to unpack".
    local MAX_N = 1000
    local count = fdp:consume_integer(1, MAX_N)
    local chars = fdp:consume_integers(MIN_INT, MAX_INT, count)
    os.setlocale(test_lib.random_locale(fdp), "all")
    local err_handler = test_lib.err_handler(ignored_msgs)
    local ok, _ = xpcall(utf8.char, err_handler, unpack(chars))
    if not ok then return end
end

local args = {
    artifact_prefix = "utf8_char_",
}
luzer.Fuzz(TestOneInput, nil, args)
