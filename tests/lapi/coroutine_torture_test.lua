--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

2.6 – Coroutines
https://www.lua.org/manual/5.3/manual.html#2.6

Computation of stack limit when entering a coroutine is wrong,
https://github.com/lua/lua/commit/e1d8770f12542d34a3e32b825c95b93f8a341ee1

C-stack overflow with deep nesting of coroutine.close,
https://www.lua.org/bugs.html#5.4.4-9

C stack overflow (again),
https://github.com/lua/lua/commit/34affe7a63fc5d842580a9f23616d057e17dfe27

When a coroutine tries to resume a non-suspended coroutine,
it can do some mess (and break C assertions) before detecting the error,
https://www.lua.org/bugs.html#5.3.3-4

debug.getlocal on a coroutine suspended in a hook can crash the interpreter,
https://www.lua.org/bugs.html#5.3.0-2

Suspended __le metamethod can give wrong result,
https://www.lua.org/bugs.html#5.3.0-3

Resuming the running coroutine makes it unyieldable,
https://www.lua.org/bugs.html#5.2.2-8

pcall may not restore previous error function when inside coroutines,
https://www.lua.org/bugs.html#5.2.1-2

Wrong handling of nCcalls in coroutines,
https://www.lua.org/bugs.html#5.2.0-4

coroutine.resume pushes element without ensuring stack size,
https://www.lua.org/bugs.html#5.1.3-2

Recursive coroutines may overflow C stack,
https://www.lua.org/bugs.html#5.1.2-4

Stand-alone interpreter shows incorrect error message when the
"message" is a coroutine,
https://www.lua.org/bugs.html#5.1.2-12

Debug hooks may get wrong when mixed with coroutines,
https://www.lua.org/bugs.html#5.1-7

Values held in open upvalues of suspended threads may be
incorrectly collected,
https://www.lua.org/bugs.html#5.0.2-3

Attempt to resume a running coroutine crashes Lua,
https://www.lua.org/bugs.html#5.0-2

debug.getlocal on a coroutine suspended in a hook can crash the interpreter,
https://www.lua.org/bugs.html#5.3.0-2

debug.sethook/gethook may overflow the thread's stack,
https://www.lua.org/bugs.html#5.1.2-13

Memory hoarding when creating Lua hooks for coroutines,
https://www.lua.org/bugs.html#5.2.0-1

Synopsis:

coroutine.close(co)
coroutine.create(f)
coroutine.isyieldable([co])
coroutine.resume(co [, val1, ...])
coroutine.running()
coroutine.status(co)
coroutine.wrap(f)
coroutine.yield(...)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local CORO_OBJECTS = {}

-- The function `coroutine.isyieldable()` is checked together with
-- `coroutine.yield()`, `coroutine.status()` is used inside the
-- target function.
local CORO_ACTION_NAME = {
    "create",
    "resume",
    "running",
    "yield",
}
-- `coroutine.close()` is introduced in the Lua 5.4,
-- https://www.lua.org/manual/5.4/manual.html#pdf-coroutine.close.
if test_lib.lua_current_version_ge_than(5, 4) then
    table.insert(CORO_ACTION_NAME, "close")
end

-- Forward declaration.
local coro_function

local function hook_func(_event)
    -- Accessing Locals,
    -- https://www.lua.org/pil/23.1.1.html.
    local level = 2
    local i = 1
    while true do
        local name, _ = debug.getlocal(level, i)
        if not name then break end
        i = i + 1
    end
    -- Accessing Upvalues,
    -- https://www.lua.org/pil/23.1.2.html.
    local func = debug.getinfo(level).func
    i = 1
    while true do
        local name, _ = debug.getupvalue(func, i)
        if not name then break end
        i = i + 1
    end
end

local function sethook(co, fdp)
    local set_hook = fdp:consume_boolean()
    local hook_args = {}
    if not set_hook then
        return
    end
    table.insert(hook_args, hook_func)
    table.insert(hook_args, fdp:oneof({"c", "r", "l"}))
    debug.sethook(co, unpack(hook_args))
end

local function coro_random_action(fdp, coro_max_number)
    local action = fdp:oneof(CORO_ACTION_NAME)
    if action == "create" and #CORO_OBJECTS < coro_max_number then
        local co = coroutine.create(coro_function)
        table.insert(CORO_OBJECTS, co)
        return
    end
    action = fdp:oneof(CORO_ACTION_NAME)
    local co, co_idx = fdp:oneof(CORO_OBJECTS)
    sethook(co, fdp)
    if coroutine.status(co) == "dead" then
        table.remove(CORO_OBJECTS, co_idx)
        return
    elseif action == "close" then
        coroutine.close(co)
    elseif action == "yield" and coroutine.isyieldable(co) then
        coroutine.yield(co)
    elseif action == "resume" then
        coroutine.resume(co)
    elseif action == "running" then
        local c = coroutine.running()
        assert(c == nil or type(c) == "thread")
    end
end

coro_function = function(fdp, coro_max_number)
    local MAX_N = 1000
    local iter = fdp:consume_integer(1, MAX_N)
    for _ = 1, iter do
        coro_random_action(fdp, coro_max_number)
    end
end

local function TestOneInput(buf, _size)
    CORO_OBJECTS = {}
    local fdp = luzer.FuzzedDataProvider(buf)
    local MAX_N = 1000
    local coro_max_number = fdp:consume_integer(1, MAX_N)
    local co = coroutine.create(coro_function)
    table.insert(CORO_OBJECTS, co)
    -- The function `coroutine.resume` starts the execution of
    -- a coroutine, changing its state from suspended to running.
    coroutine.resume(co, fdp, coro_max_number)
end

local args = {
    artifact_prefix = "coroutine_",
}
luzer.Fuzz(TestOneInput, nil, args)
