--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

18 – The Mathematical Library
https://www.lua.org/pil/18.html

6.7 – Mathematical Functions
https://www.lua.org/manual/5.3/manual.html#6.7

Sqrt(x) and x^0.5 not interchangeable,
https://github.com/LuaJIT/LuaJIT/issues/684

Synopsis: math.sqrt(x)

See properties in
"ESA/390 Enhanced Floating Point Support: An Overview"
(The Facts of Floating Point Arithmetic) [1].

1. http://ftpmirror.your.org/pub/misc/ftp.software.ibm.com/software/websphere/awdtools/hlasm/sh93fpov.pdf
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local x = fdp:consume_number(0, test_lib.MAX_INT)
    assert(type(x) == "number")
    -- Note, `math.sqrt(x)` and `x^0.5` are not interchangeable,
    -- see [1].
    --
    -- 1. https://github.com/LuaJIT/LuaJIT/issues/684#issuecomment-822427297
    local epsilon = 1^-10
    assert(test_lib.approx_equal(math.sqrt(x), x^0.5, epsilon))
end

local args = {
    artifact_prefix = "math_sqrt_",
}
luzer.Fuzz(TestOneInput, nil, args)
