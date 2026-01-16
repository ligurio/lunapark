--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

Synopsis: ipairs(t)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local MAX_N = 1000
    local count = fdp:consume_integer(0, MAX_N)
    local tbl = fdp:consume_integers(test_lib.MIN_INT, test_lib.MAX_INT, count)
    for i, v in ipairs(tbl) do
        assert(type(i) == "number")
        assert(type(v) == "number")
    end
end

local args = {
    artifact_prefix = "builtin_ipairs_",
}
luzer.Fuzz(TestOneInput, nil, args)
