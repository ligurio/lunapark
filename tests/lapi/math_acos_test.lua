--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

18 – The Mathematical Library
https://www.lua.org/pil/18.html

6.7 – Mathematical Functions
https://www.lua.org/manual/5.3/manual.html#6.7

Synopsis: math.acos(x)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local x = fdp:consume_number(-1, 1)
    local y = math.acos(x)
    assert(y >= 0)
    assert(y <= math.pi)
    local epsilon = 1^-10
    if x ~= 0 then
        assert(test_lib.approx_equal(y, math.pi - math.acos(-x), epsilon))
        assert(test_lib.approx_equal(math.cos(y), x, epsilon))
    end
end

local args = {
    artifact_prefix = "math_acos_",
}
luzer.Fuzz(TestOneInput, nil, args)
