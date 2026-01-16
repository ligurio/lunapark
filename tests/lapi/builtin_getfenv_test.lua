--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

debug.getfenv does not check whether it has an argument,
https://www.lua.org/bugs.html#5.1.4-5

module may change the environment of a C function,
https://www.lua.org/bugs.html#5.1.3-11

UBSan warning for too big/small getfenv/setfenv level,
https://github.com/LuaJIT/LuaJIT/issues/1329

Synopsis: getfenv([f])
]]

local luzer = require("luzer")
local test_lib = require("lib")

-- Lua 5.2: Functions setfenv and getfenv were removed, because
-- of the changes in environments.
if test_lib.lua_current_version_ge_than(5, 2) then
    print("Unsupported version.")
    os.exit(0)
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local level = fdp:consume_integer(0, test_lib.MAX_INT)
    local fenv, err = pcall(getfenv, level)
    if err then
        return -1
    end
    local magic_str = fdp:consume_string(test_lib.MAX_STR_LEN)
    fenv["magic"] = magic_str
    setfenv(level, fenv)
    assert(getfenv(level).magic == magic_str)
end

local args = {
    artifact_prefix = "builtin_getfenv_",
}
luzer.Fuzz(TestOneInput, nil, args)
