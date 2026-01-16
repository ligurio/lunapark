--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

Synopsis: assert(v [, message])
]]

local luzer = require("luzer")
local test_lib = require("lib")
local MAX_INT = test_lib.MAX_INT

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local max_len = fdp:consume_integer(0, MAX_INT)
    local message = fdp:consume_string(max_len)
    local v = fdp:consume_boolean()
    local ok, _ = pcall(assert, v, message)
    assert(ok == v)
end

local args = {
    artifact_prefix = "builtin_assert_",
}
luzer.Fuzz(TestOneInput, nil, args)
