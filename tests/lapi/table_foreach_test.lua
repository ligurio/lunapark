--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.4 – Table Manipulation,
https://www.lua.org/manual/5.0/manual.html#5.4

Bad loop initialization in table.foreach(),
https://github.com/LuaJIT/LuaJIT/issues/844

string.dump(table.foreach) will trigger an assert,
https://github.com/LuaJIT/LuaJIT/issues/1038

Synopsis: table.foreach(table, f)
]]

local luzer = require("luzer")
local test_lib = require("lib")

-- Function `table.foreach` is deprecated in Lua 5.1.
if test_lib.lua_current_version_ge_than(5, 2) then
    print("Unsupported version.")
    os.exit(0)
end

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    local count = fdp:consume_integer(1, test_lib.MAX_INT)
    local tbl = fdp:consume_strings(test_lib.MAX_STR_LEN, count)
    local i = 0
    local fn = function(_idx, _v) i = i + 1 end
    table.foreach(tbl, fn)
    assert(#tbl == i)
end

local args = {
    artifact_prefix = "table_foreach_",
}
luzer.Fuzz(TestOneInput, nil, args)
