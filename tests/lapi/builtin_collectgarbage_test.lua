--[=[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

Synopsis: collectgarbage([opt [, arg]])
]]=]

local luzer = require("luzer")
local test_lib = require("lib")

local unpack = unpack or table.unpack

local gc_mode = {
    "collect",
    "count",
    "restart",
    "step",
    "stop",
}

if test_lib.lua_version() == "LuaJIT" then
    table.insert(gc_mode, "setpause")
    table.insert(gc_mode, "setstepmul")
else
    table.insert(gc_mode, "isrunning")
    table.insert(gc_mode, "incremental")
    table.insert(gc_mode, "generational")
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local mode = fdp:oneof(gc_mode)
    local MAX_INT = test_lib.MAX_INT
    local arg = {}
    if mode == "step" or
       mode == "setpause" or
       mode == "setstepmul" then
        table.insert(arg, fdp:consume_integer(0, MAX_INT))
    end
    -- This option can be followed by two numbers: the
    -- garbage-collector minor multiplier and the major multiplier.
    if mode == "generational" then
        table.insert(arg, fdp:consume_integer(0, MAX_INT))
    end
    -- This option can be followed by three numbers: the
    -- garbage-collector pause, the step multiplier, and the step
    -- size
    if mode == "incremental" then
        table.insert(arg, fdp:consume_integer(0, MAX_INT))
    end
    collectgarbage(mode, unpack(arg))
end

local args = {
    artifact_prefix = "builtin_collectgarbage_",
}
luzer.Fuzz(TestOneInput, nil, args)
