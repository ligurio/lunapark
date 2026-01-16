--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

18 – The Mathematical Library
https://www.lua.org/pil/18.html

6.7 – Mathematical Functions
https://www.lua.org/manual/5.3/manual.html#6.7

Misleading assertion in asm_fload() for mips,
https://github.com/LuaJIT/LuaJIT/issues/1043

Synopsis: math.abs(x)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local n = fdp:consume_number(test_lib.MIN_INT, test_lib.MAX_INT)
    local abs = n
    if abs < 0 then
        abs = -abs
    end
    assert(math.abs(n) == abs)
end

local args = {
    artifact_prefix = "math_abs_",
}
luzer.Fuzz(TestOneInput, nil, args)
