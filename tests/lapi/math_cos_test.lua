--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

18 – The Mathematical Library
https://www.lua.org/pil/18.html

6.7 – Mathematical Functions
https://www.lua.org/manual/5.3/manual.html#6.7

Synopsis: math.cos(x)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local x = fdp:consume_number(test_lib.MIN_INT, test_lib.MAX_INT)
    local cos_x = math.cos(x)
    assert(type(cos_x) == "number")
    assert(cos_x >= -1 and cos_x <= 1)
    local epsilon = 1^-10

    local n = fdp:consume_number(0, 100)
    -- Calculate the functions of the form `cos(i*pi - x), where
    -- i = 1, 3, 5, etc. These functions are equivalent, given the
    -- trigonometric identity.
    for i = 1, n do
        assert(test_lib.approx_equal(
            math.abs(math.cos(i * math.pi - x)), math.abs(cos_x), epsilon))
    end
end

local args = {
    artifact_prefix = "math_cos_",
}
luzer.Fuzz(TestOneInput, nil, args)
