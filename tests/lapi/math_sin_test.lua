--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

18 – The Mathematical Library
https://www.lua.org/pil/18.html

6.7 – Mathematical Functions
https://www.lua.org/manual/5.3/manual.html#6.7

Synopsis: math.sin(x)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local x = fdp:consume_number(test_lib.MIN_INT, test_lib.MAX_INT)
    local sin_x = math.sin(x)
    assert(type(sin_x) == "number")
    assert(sin_x >= -1 and sin_x <= 1)
    local cos_x = math.cos(x)
    local epsilon = 1^-10
    assert(test_lib.approx_equal(cos_x^2 + sin_x^2, 1, epsilon))

    local n = fdp:consume_number(0, 100)
    -- Calculate the functions of the form `sin(i*pi - x), where
    -- i = 1, 3, 5, etc. These functions are equivalent, given the
    -- trigonometric identity.
    for i = 1, n do
        assert(test_lib.approx_equal(
            math.abs(math.sin(i * math.pi - x)), math.abs(sin_x), epsilon))
    end
end

local args = {
    artifact_prefix = "math_sin_",
}
luzer.Fuzz(TestOneInput, nil, args)
