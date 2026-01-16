--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

18 – The Mathematical Library
https://www.lua.org/pil/18.html

6.7 – Mathematical Functions
https://www.lua.org/manual/5.3/manual.html#6.7

vm_mips.dasc assumes 32-bit FPU register model,
https://github.com/LuaJIT/LuaJIT/issues/1040

math.ceil fails to return -0 for -1 < x < -0.5,
https://github.com/LuaJIT/LuaJIT/issues/859

ARM64 - corrupted local variable on trace exit / snapshot replay,
https://github.com/LuaJIT/LuaJIT/issues/579

x86/x64: Fix math.ceil(-0.9) result sign,
https://github.com/LuaJIT/LuaJIT/issues/859

Synopsis: math.ceil(x)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local x = fdp:consume_number(test_lib.MIN_INT, test_lib.MAX_INT)
    local res = math.ceil(x)
    assert(type(res) == "number")
end

local args = {
    artifact_prefix = "math_ceil_",
}
luzer.Fuzz(TestOneInput, nil, args)
