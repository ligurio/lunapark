--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

18 – The Mathematical Library
https://www.lua.org/pil/18.html

6.7 – Mathematical Functions
https://www.lua.org/manual/5.3/manual.html#6.7

Two-parameter logarithm gives incorrect answers for matching inputs,
https://github.com/LuaJIT/LuaJIT/issues/1240

Synopsis: math.log(x [, b])
]]

local luzer = require("luzer")
local test_lib = require("lib")

-- The function `math.pow()` has been deprecated in PUC Rio Lua
-- 5.3, see Lua 5.3 Reference Manual, 8.2 – Changes in the
-- Libraries.
--
-- 1. https://www.lua.org/manual/5.3/manual.html
local pow
if test_lib.lua_current_version_ge_than(5, 3) then
    pow = test_lib.math_pow
else
    pow = math.pow
end

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    -- The natural logarithm (base e) of x. If x is ±0,
    -- returns -Infinity. If x < 0, returns NaN.
    local x = fdp:consume_number(0, test_lib.MAX_INT)
    local y = fdp:consume_number(0, test_lib.MAX_INT)
    local b = fdp:consume_number(test_lib.MIN_INT, test_lib.MAX_INT)
    if b <= 0 or b == 1 or x <= 0 or y <= 0 then return -1 end

    local eps = 1^-10

    -- Product rule.
    assert(test_lib.approx_equal(
        math.log(x * y, b), math.log(x, b) + math.log(y, b), eps))
    -- Quotient rule.
    assert(test_lib.approx_equal(
        math.log(x / y, b), math.log(x, b) - math.log(y, b), eps))
    -- Power rule.
    local pow_xy = pow(x, y)
    if (not test_lib.is_nan(pow_xy) and
        not test_lib.is_inf(pow_xy)) then
        assert(test_lib.approx_equal(
            math.log(pow_xy, b), y * math.log(x, b), eps))
    end
    -- Inverse property of logarithm.
    local pow_bx = pow(b, x)
    if (not test_lib.is_nan(pow_bx) and
        not test_lib.is_inf(pow_bx)) then
        assert(test_lib.approx_equal(math.log(pow_bx, b), x, eps))
    end
    -- Inverse property of exponent.
    local pow_b_log = pow(b, math.log(x, b))
    if (not test_lib.is_nan(pow_b_log) and
        not test_lib.is_inf(pow_b_log)) then
        assert(test_lib.approx_equal(pow_b_log, x, eps))
    end
    -- Zero rule.
    assert(math.log(1, b) == 0)
    -- Identity rule.
    assert(test_lib.approx_equal(math.log(b, b), 1, eps))
    -- Change of base formula.
    local log_b_y = math.log(b, y)
    if log_b_y ~= 0 then
        assert(test_lib.approx_equal(math.log(x, b), math.log(x, y) / log_b_y, eps))
    end
end

local args = {
    artifact_prefix = "math_log_",
}
luzer.Fuzz(TestOneInput, nil, args)
