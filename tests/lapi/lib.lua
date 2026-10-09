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

-- Lua 5.1 spells `load` as `loadstring`; since 5.2 `load` takes a
-- string.
local loadstring = type(loadstring) == "function" and loadstring or load

-- Dispatched for tables since Lua 5.1, so they need no runtime
-- probe.
local MM_ALWAYS = {
    __add = true,
    __call = true,
    __concat = true,
    __div = true,
    __eq = true,
    __index = true,
    __le = true,
    __lt = true,
    __metatable = true,
    __mode = true,
    __mod = true,
    __mul = true,
    __newindex = true,
    __pow = true,
    __sub = true,
    __tostring = true,
    __unm = true,
}

-- The six bitwise metamethods were all introduced together
-- (Lua 5.3) and are all absent from LuaJIT, so they share
-- a single probe.
local BITWISE_MM = {
    __band = true,
    __bnot = true,
    __bor = true,
    __bxor = true,
    __shl = true,
    __shr = true,
}

-- Compiles and runs a snippet, returning false when it does not
-- compile. Needed only for probes that use syntax absent from
-- older Lua versions (`//`, bitwise operators, `<close>`).
local function probe_chunk(code)
    local chunk = loadstring(code)
    if chunk == nil then
        return false
    end
    local ok, res = pcall(chunk)
    return ok and res == true
end

local MM_PROBES = {
    __len = function()
        local t = setmetatable({}, {
            __len = function() return 42 end,
        })
        return #t == 42
    end,
    __gc = function()
        local hit = false
        local function make()
            setmetatable({}, {
                __gc = function() hit = true end,
            })
        end
        make()
        collectgarbage("collect")
        collectgarbage("collect")
        return hit
    end,
    __pairs = function()
        local hit = false
        local t = setmetatable({}, {
            __pairs = function(tt)
                hit = true
                return next, tt, nil
            end,
        })
        for _ in pairs(t) do end
        return hit
    end,
    __ipairs = function()
        local hit = false
        local t = setmetatable({}, {
            __ipairs = function(tt)
                hit = true
                return function() return nil end, tt, 0
            end,
        })
        for _ in ipairs(t) do end
        return hit
    end,
    __name = function()
        local t = setmetatable({}, {
            __name = "MMProbe"
        })
        return tostring(t):find("MMProbe", 1, true) ~= nil
    end,
    -- `//` does not parse before Lua 5.3; LuaJIT has the `&`
    -- syntax but no bit operator metamethods, so the snippets
    -- exercise the metamethod dispatch rather than the syntax.
    __idiv = function()
        return probe_chunk([[
            local t = setmetatable({}, {
                __idiv = function() return 42 end
            })
            return t // 1 == 42
        ]])
    end,
    __band = function()
        return probe_chunk([[
            local t = setmetatable({}, {
                __band = function() return 42 end
            })
            return t & 1 == 42
        ]])
    end,
    -- `<close>` does not parse before Lua 5.4.
    __close = function()
        return probe_chunk([[
            local h = false
            do local x <close> = setmetatable({}, {
                __close = function() h = true end
            })
            end
            return h
        ]])
    end,
}

local MM_SUPPORT = {}

-- `has_mm(name)` reports whether the running Lua implementation
-- dispatches the metamethod `name` for tables. `name` is the
-- metatable event key (e.g. "__len", "__pairs").
--
-- Metamethods dispatched since Lua 5.1 are always reported as
-- supported and need no runtime probe. The rest are probed by
-- building a table with the candidate metamethod and running the
-- corresponding operation; probe results are cached on the first
-- call for a name. Most probes are plain functions, but a few use
-- `load`, because the syntax they exercise (`//`, bitwise
-- operators, `<close>`) does not parse in older Lua versions.
--
-- Support matrix for metamethods
--
--     Metamethod     5.1  5.2  5.3  5.4  LuaJIT
--     -----------------------------------------
--     __add          Yes  Yes  Yes  Yes  Yes
--     __band         No   No   Yes  Yes  No
--     __bnot         No   No   Yes  Yes  No
--     __bor          No   No   Yes  Yes  No
--     __bxor         No   No   Yes  Yes  No
--     __call         Yes  Yes  Yes  Yes  Yes
--     __close        No   No   No   Yes  No
--     __concat       Yes  Yes  Yes  Yes  Yes
--     __div          Yes  Yes  Yes  Yes  Yes
--     __eq           Yes  Yes  Yes  Yes  Yes
--     __gc           No   Yes  Yes  Yes  No
--     __idiv         No   No   Yes  Yes  No
--     __index        Yes  Yes  Yes  Yes  Yes
--     __ipairs       No   Yes  Yes* No   No*
--     __len          No   Yes  Yes  Yes  No*
--     __le           Yes  Yes  Yes  Yes  Yes
--     __lt           Yes  Yes  Yes  Yes  Yes
--     __metatable    Yes  Yes  Yes  Yes  Yes
--     __mode         Yes  Yes  Yes  Yes  Yes
--     __mod          Yes  Yes  Yes  Yes  Yes
--     __mul          Yes  Yes  Yes  Yes  Yes
--     __name         No   No   Yes  Yes  No
--     __newindex     Yes  Yes  Yes  Yes  Yes
--     __pairs        No   Yes  Yes  Yes  No*
--     __pow          Yes  Yes  Yes  Yes  Yes
--     __shl          No   No   Yes  Yes  No
--     __shr          No   No   Yes  Yes  No
--     __sub          Yes  Yes  Yes  Yes  Yes
--     __tostring     Yes  Yes  Yes  Yes  Yes
--     __unm          Yes  Yes  Yes  Yes  Yes
--
--     * `__ipairs` is deprecated in Lua 5.3 and removed in
--       Lua 5.4.
--     * LuaJIT "Yes" for `__len`/`__pairs`/`__ipairs` only when
--       it is built with LUA52COMPAT; the probe detects the
--       actual build.

local function has_mm(name)
    ---@diagnostic disable-next-line: unnecessary-if
    if MM_ALWAYS[name] then
        return true
    end
    local key = BITWISE_MM[name] and "__band" or name
    local probe = MM_PROBES[key]
    if probe == nil then
        error("has_mm: unknown metamethod " .. tostring(name))
    end
    if MM_SUPPORT[key] == nil then
        MM_SUPPORT[key] = probe()
    end
    return MM_SUPPORT[key]
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
        ---@type string
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
        -- `load` accepts a reader function or a Lua literal chunk
        -- type, not a dynamically built string; the call is valid.
        ---@diagnostic disable-next-line: param-type-mismatch
        return assert(load(chunk))()
    end
end

---@param x number
---@param y number
---@return number
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

local function gc_random_action(fdp, gc_actions)
    local gc_action = fdp:oneof(gc_actions)
    pcall(gc_action, fdp)
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

local function is_file_exist(path)
    local file = io.open(path, "r")
    if file then
        file:close()
    end
    return file ~= nil
end

return {
    approx_equal = approx_equal,
    arrays_equal = arrays_equal,
    bitwise_op = bitwise_op,
    has_mm = has_mm,
    is_file_exist = is_file_exist,
    is_inf = is_inf,
    is_nan = is_nan,
    loadstring = loadstring,
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
