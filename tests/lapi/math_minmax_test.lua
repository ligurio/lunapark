--[[
SPDX-License-Identifier: ISC
Copyright (c) 2026, Sergey Bronnikov.

6.7 – Mathematical Functions
https://www.lua.org/manual/5.3/manual.html#6.7

Synopsis: math.min(x, ...)
Synopsis: math.max(x, ...)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local unpack = unpack or table.unpack

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local n = fdp:consume_integer(1, 10)
    local nums = fdp:consume_integers(test_lib.MIN_INT, test_lib.MAX_INT, n)
    local min = math.min(unpack(nums))
    local max = math.max(unpack(nums))
    assert(type(min) == "number")
    assert(type(max) == "number")
    assert(min <= max)
    for _, v in ipairs(nums) do
        assert(v >= min)
        assert(v <= max)
    end
end

local args = {
    artifact_prefix = "math_min_",
}
luzer.Fuzz(TestOneInput, nil, args)
