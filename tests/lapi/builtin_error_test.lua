--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

Synopsis: error(message [, level])
]]

local luzer = require("luzer")
local test_lib = require("lib")
local MAX_INT = test_lib.MAX_INT

local function escape_pattern(text)
    return (text:gsub("[-.+%[%]()$^%%?*]", "%%%1"))
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    local level = fdp:consume_integer(0, MAX_INT)
    local message_len = fdp:consume_integer(0, MAX_INT)
    local message = fdp:consume_string(message_len)
    local ok, err = pcall(error, message, level)
    assert(ok == false)
    -- Escape message to avoid error "invalid pattern capture".
    --
    -- The \0 can mess up the matching, so we only use matching
    -- for parts of the message:
    -- | print(("lua\0lua"):match("lua\0lua"))
    -- | lua
    local matched = err:match(escape_pattern(message))
    assert(matched ~= nil)
end

local args = {
    artifact_prefix = "builtin_error_",
}
luzer.Fuzz(TestOneInput, nil, args)
