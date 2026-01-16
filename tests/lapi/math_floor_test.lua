--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

18 – The Mathematical Library
https://www.lua.org/pil/18.html

6.7 – Mathematical Functions
https://www.lua.org/manual/5.3/manual.html#6.7

Synopsis: math.floor(x)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local a = fdp:consume_number(test_lib.MIN_INT, test_lib.MAX_INT)
    local res = math.floor(a)
    assert(type(res) == "number")
end

local args = {
    artifact_prefix = "math_floor_",
}
luzer.Fuzz(TestOneInput, nil, args)
