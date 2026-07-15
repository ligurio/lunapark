--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Test helpers.
]]

local unpack = unpack or table.unpack

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
        assert(n > 0)
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
    if locales == nil then
        locales = {}
        local ph = io.popen("locale -a")
        if ph ~= nil then
            for locale in ph:read("*a"):gmatch("([^\n]*)\n?") do
                table.insert(locales, locale)
            end
            ph:close()
        end
        if #locales == 0 then
            table.insert(locales, "C")
        end
    end
    return fdp:oneof(locales)
end

local function err_handler(ignored_msgs)
    return function(error_msg)
        for _, ignored_msg in ipairs(ignored_msgs) do
            if string.find(error_msg, ignored_msg, 1, true) then
                return
            end
        end
        error(error_msg, 2)
    end
end

local function gc_setpause(fdp)
    local pause = fdp:consume_integer(0, 1000)
    local res = collectgarbage("setpause", pause)
    assert(type(res) == "number")
end

local function gc_setstepmul(fdp)
    local step_multiplier = fdp:consume_integer(0, 1000)
    local res = collectgarbage("setstepmul", step_multiplier)
    assert(type(res) == "number")
end

local GC_PARAM = {
    "minormul",
    "majorminor",
    "minormajor",
    "pause",
    "stepmul",
    "stepsize",
}

local function gc_param(fdp)
    local param_name = fdp:oneof(GC_PARAM)
    local MIN_PARAM = 0
    local MAX_PARAM = 100000
    local param_value = fdp:consume_integer(MIN_PARAM, MAX_PARAM)
    local res = collectgarbage("param", param_name, param_value)
    assert(type(res) == "number")
end

-- This option can be followed by two numbers: the
-- garbage-collector minor multiplier and the major multiplier.
local function gc_generational(fdp)
    local args = fdp:consume_integers(0, MAX_INT, 2)
    local res = collectgarbage("generational", unpack(args))
    assert(type(res) == "string")
end

-- This option can be followed by three numbers: the
-- garbage-collector pause, the step multiplier, and the step
-- size.
local function gc_incremental(fdp)
    local args = fdp:consume_integers(0, MAX_INT, 3)
    local res = collectgarbage("incremental", unpack(args))
    assert(type(res) == "string")
end

local gc_ignored_msgs = {
    "invalid format option",
    "invalid option",
    "bad argument",
    "cannot resume",
}

local function gc_random_action(fdp, gc_actions)
    local gc_action = fdp:oneof(gc_actions)
    local handler = err_handler(gc_ignored_msgs)
    local ok, err = pcall(gc_action, fdp)
    if not ok then handler(err) end
end

local GC_ACTIONS = {}
if lua_version() == "LuaJIT" then
    table.insert(GC_ACTIONS, gc_setpause)
    table.insert(GC_ACTIONS, gc_setstepmul)
else
    table.insert(GC_ACTIONS, gc_param)
    table.insert(GC_ACTIONS, gc_generational)
    table.insert(GC_ACTIONS, gc_incremental)
end

local LJ_OPT = {
    "abc",
    "cse",
    "dce",
    "dse",
    "fma",
    "fold",
    "fuse",
    "fwd",
    "loop",
    "narrow",
    "sink",
}

-- The table contains LuaJIT parameters with desired ranges,
-- see https://luajit.org/running.html#foot.
local LJ_PARAM = {
    ["callunroll"] = { 1, 3 },
    ["hotexit"] = { 1, 56 },
    ["hotloop"] = { 1, 56 },
    ["instunroll"] = { 1, 4 },
    ["loopunroll"] = { 1, 15 },
    ["maxirconst"] = { 1, 500 },
    ["maxmcode"] = { 1, 2048 },
    ["maxrecord"] = { 1, 4000 },
    ["maxside"] = { 1, 100 },
    ["maxsnap"] = { 1, 500 },
    ["maxtrace"]  = { 1, 1000 },
    ["recunroll"] = { 1, 2 },
    ["sizemcode"] = { 1, 64 },
    ["tryside"] = { 1, 4 },
}

local function random_lj_settings(fdp)
    local settings = {}
    for _, opt in ipairs(LJ_OPT) do
        local enabled = fdp:consume_boolean()
        table.insert(settings, enabled and opt or "-" .. opt)
    end

    for param, minmax in pairs(LJ_PARAM) do
        local min, max = unpack(minmax)
        local param_str = ("%s=%d"):format(param, fdp:consume_integer(min, max))
        table.insert(settings, param_str)
    end

    jit.opt.start(unpack(settings))
end

local function random_misc_settings(fdp)
    gc_random_action(fdp, GC_ACTIONS)
    if lua_version() == "LuaJIT" then
        local use_jit = fdp:consume_boolean()
        if not use_jit then
            jit.off()
            return
        end
        random_lj_settings(fdp)
    end
end

local function is_nan(v)
    return v ~= v
end

local function is_inf(v)
    return v == math.huge or v == -math.huge
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
    is_inf = is_inf,
    is_nan = is_nan,
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
    gc_generational = gc_generational,
    gc_incremental = gc_incremental,
    gc_param = gc_param,
    gc_random_action = gc_random_action,
    gc_setpause = gc_setpause,
    gc_setstepmul = gc_setstepmul,
    random_locale = random_locale,
    random_misc_settings = random_misc_settings,
}
