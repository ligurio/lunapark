--[=[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

Synopsis: collectgarbage([opt [, arg]])
]]=]

local luzer = require("luzer")
local test_lib = require("lib")

local MAX_INT = test_lib.MAX_INT

local WEAK_MODES = { "k", "v", "kv" }

local function gc_collect()
    collectgarbage("collect")
end

local function gc_stop(_fdp)
    collectgarbage("stop")
end

local function gc_restart(_fdp)
    collectgarbage("restart")
end

local function gc_count(_fdp)
    local count = collectgarbage("count")
    assert(type(count) == "number")
    assert(count >= 0)
end

local function gc_step(fdp)
    local step_size = 0
    local set_step_size = fdp:boolean()
    if set_step_size then
        step_size = fdp:consume_integer(0, 1000)
    end
    collectgarbage("step", step_size)
end

local function gc_isrunning(_fdp)
    local res = collectgarbage("isrunning")
    assert(type(res) == "boolean")
end

-- Create large allocations to raise GC threshold, then nil them
-- out so GCdebt accumulates.
local function workload_gc_pressure(fdp)
    local n = fdp:consume_integer(1, 500)
    local t = {} -- luacheck: no unused
    for i = 1, n do
        t[i] = string.rep("x", fdp:consume_integer(1, 1000))
    end
    -- Immediately nil to create garbage pressure.
    for i = 1, n do
        t[i] = nil
    end
end

-- Weak table with keys only referenced by the weak table.
-- Insert enough keys to fill hash part, then trigger `rehash()`.
-- During `luaH_resize()` in PUC Rio Lua the allocation of newhash
-- can trigger GC, which sweeps the weak keys while `reinserthash()`
-- still reads them.
local function workload_weak_rehash(fdp)
    local t = setmetatable({}, { __mode = "k" })
    local n = fdp:consume_integer(10, 300)
    for i = 1, n do
        t[{}] = i
    end
    t[{}] = fdp:consume_integer(0, 1000)
end

-- Fill weak table, clear references, then force GC.
local function workload_weak_clear(fdp)
    local mode = fdp:oneof(WEAK_MODES)
    local t = setmetatable({}, { __mode = mode })
    local keys = {} -- luacheck: no unused
    local n = fdp:consume_integer(1, 100)
    for i = 1, n do
        local k = {}
        t[k] = {}
        keys[i] = k
    end
    -- Clear external references to keys.
    for i = 1, n do
        keys[i] = nil
    end
    gc_step(fdp)
    -- After GC with weak mode 'k', keys should be gone.
    if mode == "k" or mode == "kv" then
        local count = 0
        for _ in pairs(t) do
            count = count + 1
        end
        assert(count <= 1)
    end
end

-- __gc finalizer that calls `collectgarbage("step")`.
-- When the finalizer runs during GC sweep, it triggers
-- another GC step. This can collide with table rehashing.
local function workload_finalizer_rehash(fdp)
    --- @type userdata?
    local fin = newproxy(true) -- luacheck: no unused
    local fin_called = false
    getmetatable(fin).__gc = function()
        if not fin_called then
            fin_called = true
            gc_step(fdp)
        end
    end

    local t = setmetatable({}, { __mode = "k" })
    local n = fdp:consume_integer(10, 200)
    for i = 1, n do
        t[{}] = i -- luacheck: no unused
    end
    fin = nil -- luacheck: no unused
    gc_step(fdp)
    t[{}] = fdp:consume_integer(0, 1000)
end

-- Coroutine with GC interaction.
local function workload_coroutine(fdp)
    local held = {} -- luacheck: no unused
    local co = coroutine.create(function()
        held[1] = {}
        held[2] = string.rep("x", 100)
        coroutine.yield()
    end)
    coroutine.resume(co)
    gc_step(fdp)
    coroutine.resume(co)
end

local GC_ACTIONS = {
    gc_collect,
    gc_stop,
    gc_restart,
    gc_count,
    gc_step,

    workload_coroutine,
    workload_finalizer_rehash,
    workload_gc_pressure,
    workload_weak_clear,
    workload_weak_rehash,
}
if test_lib.lua_version() == "LuaJIT" then
    table.insert(GC_ACTIONS, test_lib.gc_setpause)
    table.insert(GC_ACTIONS, test_lib.gc_setstepmul)
else
    table.insert(GC_ACTIONS, test_lib.gc_param)
    table.insert(GC_ACTIONS, test_lib.gc_generational)
    table.insert(GC_ACTIONS, test_lib.gc_incremental)
    table.insert(GC_ACTIONS, gc_isrunning)
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    local nops = fdp:consume_integer(1, MAX_INT)
    for _ = 1, nops do
        test_lib.gc_random_action(fdp, GC_ACTIONS)
    end
end

local args = {
    artifact_prefix = "builtin_collectgarbage_",
}
luzer.Fuzz(TestOneInput, nil, args)
