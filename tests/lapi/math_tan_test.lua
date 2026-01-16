--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

18 – The Mathematical Library
https://www.lua.org/pil/18.html

6.7 – Mathematical Functions
https://www.lua.org/manual/5.3/manual.html#6.7

Synopsis: math.tan(x)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local x = fdp:consume_number(test_lib.MIN_INT, test_lib.MAX_INT)
    local sin_x = math.sin(x)
    local cos_x = math.cos(x)
    local tan_x = math.tan(x)

    local epsilon = 1^-10
    if cos_x ~= 0 then
        assert(test_lib.approx_equal(tan_x, sin_x / cos_x, epsilon))
    end
end

local args = {
    artifact_prefix = "math_tan_",
}
luzer.Fuzz(TestOneInput, nil, args)
