--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Test helpers.
]]

-- The function determines a Lua version.
local function lua_version()
    local major, minor = _VERSION:match("([%d]+)%.(%d+)")
    local version = {
        major = tonumber(major),
        minor = tonumber(minor),
    }
    local is_luajit, _ = pcall(require, "jit")
    local lua_name = is_luajit and "LuaJIT" or "PUC Rio Lua"
    return lua_name, version
end

local function version_ge(version1, version2)
    if version1.major ~= version2.major then
        return version1.major > version2.major
    else
        return version1.minor >= version2.minor
    end
end

local function lua_current_version_ge_than(major, minor)
    local _, current_version = lua_version()
    return version_ge(current_version, { major = major, minor = minor })
end

local function lua_current_version_lt_than(major, minor)
    return not lua_current_version_ge_than(major, minor)
end

-- By default `lua_Integer` is ptrdiff_t in Lua 5.1 and Lua 5.2
-- and `long long` in Lua 5.3+, (usually a 64-bit two-complement
-- integer), but that can be changed to `long` or `int` (usually a
-- 32-bit two-complement integer), see LUA_INT_TYPE in
-- <luaconf.h>. Lua 5.3+ has two functions: `math.maxinteger` and
-- `math.mininteger` that returns an integer with the maximum
-- value for an integer and an integer with the minimum value for
-- an integer, see [1] and [2].

-- `0x7ffffffffffff` is a maximum integer in `long long`, however
-- this number is not representable in `double` and the nearest
-- number representable in `double` is `0x7ffffffffffffc00`.
--
-- 1. https://www.lua.org/manual/5.1/manual.html#lua_Integer
-- 2. https://www.lua.org/manual/5.3/manual.html#lua_Integer
local MAX_INT64 = math.maxinteger or  0x7ffffffffffffc00
local MIN_INT64 = math.mininteger or -0x8000000000000000
-- 32-bit integers
local MAX_INT =  0x7fffffff
local MIN_INT = -0x80000000

local MAX_STR_LEN = 4096

local function bitwise_op(op_name)
    return function(...)
        local n = select("#", ...)
        local chunk
        -- Bitwise exclusive OR and bitwise NOT have the same
        -- operator.
        if (op_name == "&" or op_name == "|") then
            assert(n > 1)
        end
        if n == 1 then
            local x = ...
            chunk = ("return %s %d"):format(op_name, x)
        else
            local op_name_ws = (" %s "):format(op_name)
            chunk = "return " .. table.concat({...}, op_name_ws)
        end
        return assert(load(chunk))()
    end
end

local function math_pow(x, y)
    return x ^ y
end

local function approx_equal(a, b, epsilon)
    local abs = math.abs
    return abs(a - b) <= ((abs(a) < abs(b) and abs(b) or abs(a)) * epsilon)
end

local locales

local function random_locale(fdp)
    if locales then
        return fdp:oneof(locales)
    end
    local locale_it = io.popen("locale -a"):read("*a"):gmatch("([^\n]*)\n?")
    locales = {}
    for locale in locale_it do
        table.insert(locales, locale)
    end

    return fdp:oneof(locales)
end

local function err_handler(ignored_msgs)
    return function(error_msg)
        for _, ignored_msg in ipairs(ignored_msgs) do
            local x, _ = string.find(error_msg, ignored_msg)
            if x then break end
        end
    end
end

local function is_nan(v)
    return v ~= v
end

local function arrays_equal(t1, t2)
    for i = 1, #t1 do
        if t1[i] ~= t2[i] and
           not (is_nan(t1[i]) and is_nan(t2[i])) then
            return false
        end
    end
    return #t1 == #t2
end

return {
    approx_equal = approx_equal,
    arrays_equal = arrays_equal,
    bitwise_op = bitwise_op,
    err_handler = err_handler,
    lua_current_version_ge_than = lua_current_version_ge_than,
    lua_current_version_lt_than = lua_current_version_lt_than,
    lua_version = lua_version,
    math_pow = math_pow,
    MAX_INT64 = MAX_INT64,
    MIN_INT64 = MIN_INT64,
    MAX_INT = MAX_INT,
    MIN_INT = MIN_INT,
    MAX_STR_LEN = MAX_STR_LEN,

    -- FDP.
    random_locale = random_locale,
}
