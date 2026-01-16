--[[
SPDX-License-Identifier: ISC
Copyright (c) 2026, Sergey Bronnikov.

LuaJIT profiler,
https://luajit.org/ext_profiler.html
]]

local luzer = require("luzer")
local test_lib = require("lib")

if test_lib.lua_version() ~= "LuaJIT" then
    print("Unsupported version.")
    os.exit(0)
end

local sysprof = require("jit.profile")

local MAX_INT = test_lib.MAX_INT
local MIN_INT = test_lib.MIN_INT

local SYSPROF_DEFAULT_INTERVAL = 1 -- ms

local SYSPROF_OPTIONS = {
    "f", -- Profile with precision down to the function level.
    "l", -- Profile with precision down to the line level.
    "i", -- Sampling interval in milliseconds (default 10ms).
}

local DUMPSTACK_FMT = {
    "p", -- Preserve the full path for module names.
    "f", -- Dump the function name if it can be derived.
    "F", -- Ditto, but dump module:name.
    "l", -- Dump module:line.
    "Z", -- Zap the following characters for the last dumped frame.
}

local function sysprof_dumpstack(fdp)
    local fmt = fdp:oneof(DUMPSTACK_FMT)
    local depth = fdp:consume_integer(MIN_INT, MAX_INT)
    local dump = sysprof.dumpstack(fmt, depth)
    assert(dump)
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local chunk = fdp:consume_string(test_lib.MAX_STR_LEN)
    -- LuaJIT ASSERT lj_bcread.c:123: bcread_byte: buffer read
    -- overflow.
    local func = load(chunk, "luzer", "t")

    local sysprof_option = fdp:oneof(SYSPROF_OPTIONS)
    if sysprof_option == "i" then
        sysprof_option = ("i%d"):format(SYSPROF_DEFAULT_INTERVAL)
    end
    local cb = function(_thread, _samples, _vmstate)
        -- Nope.
    end

    sysprof.start(sysprof_option, cb)
    pcall(func)
    sysprof_dumpstack(fdp)
    sysprof.stop()
end

local args = {
    artifact_prefix = "jit_p_test",
}
luzer.Fuzz(TestOneInput, nil, args)
