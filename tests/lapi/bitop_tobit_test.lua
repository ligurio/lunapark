--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Synopsis: bit.tobit(x)
]]

local luzer = require("luzer")
local test_lib = require("lib")

if test_lib.lua_version() ~= "LuaJIT" then
    print("Unsupported version.")
    os.exit(0)
end

local tobit = bit.tobit

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    local x
    if fdp:consume_boolean() then
        x = fdp:consume_integer(test_lib.MIN_INT, test_lib.MAX_INT)
    else
        x = fdp:consume_number(test_lib.MIN_INT64, test_lib.MAX_INT64)
    end
    local res = tobit(x)
    assert(type(res) == "number")

    -- Idempotence.
    assert(tobit(res) == res)

    -- Integer result in 32-bit range.
    assert(math.floor(res) == res)
    assert(res >= test_lib.MIN_INT and res <= test_lib.MAX_INT)

    -- Wrap-around at the 32-bit boundaries.
    assert(tobit(test_lib.MAX_INT + 1) == test_lib.MIN_INT)
    assert(tobit(test_lib.MIN_INT - 1) == test_lib.MAX_INT)

    -- Already in range: identity after floor.
    if not test_lib.is_nan(x)
       and math.floor(x) == x
       and x >= test_lib.MIN_INT and x <= test_lib.MAX_INT then
        assert(res == x)
    end
    -- Deterministic special values. `bit.tobit` is declared to take
    -- an integer, while NaN and Inf are doubles. Conversion of
    -- NaN/Inf is implementation-defined; LuaJIT's number-to-bit
    -- path yields 0 on the supported targets.
    ---@diagnostic disable: param-type-mismatch
    assert(tobit(0 / 0) == 0)
    assert(tobit(math.huge) == 0)
    assert(tobit(-math.huge) == 0)
    ---@diagnostic enable: param-type-mismatch

end

local args = {
    artifact_prefix = "bitop_tobit_",
}
luzer.Fuzz(TestOneInput, nil, args)
