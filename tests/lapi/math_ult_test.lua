--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

18 – The Mathematical Library
https://www.lua.org/pil/18.html

6.7 – Mathematical Functions
https://www.lua.org/manual/5.3/manual.html#6.7

Synopsis: math.ult(m, n)
]]

local luzer = require("luzer")
local test_lib = require("lib")

-- The function `math.ult()` is available since Lua 5.3.
if test_lib.lua_current_version_lt_than(5, 3) then
    print("Unsupported version.")
    os.exit(0)
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local m = fdp:consume_integer(test_lib.MIN_INT, test_lib.MAX_INT)
    local n = fdp:consume_integer(test_lib.MIN_INT, test_lib.MAX_INT)
    local res = math.ult(m, n)
    assert(type(res) == "boolean")
end

local args = {
    artifact_prefix = "math_ult_",
}
luzer.Fuzz(TestOneInput, nil, args)
