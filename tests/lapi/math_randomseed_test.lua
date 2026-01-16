--[=====[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

18 – The Mathematical Library
https://www.lua.org/pil/18.html

6.7 – Mathematical Functions
https://www.lua.org/manual/5.3/manual.html#6.7

Synopsis: math.randomseed([x [, y]])
--]=====]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local x = fdp:consume_integer(test_lib.MIN_INT, test_lib.MAX_INT)
    local y = fdp:consume_integer(test_lib.MIN_INT, test_lib.MAX_INT)
    -- Since Lua 5.4 the function returns the two seed components
    -- that were effectively used, so that setting them again
    -- repeats the sequence.
    local a, b = math.randomseed(x, y)
    if test_lib.lua_current_version_ge_than(5, 4) then
        assert(type(a) == "number" and type(b) == "number")
    end
end

local args = {
    artifact_prefix = "math_randomseed_",
}
luzer.Fuzz(TestOneInput, nil, args)
