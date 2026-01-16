--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.4 – String Manipulation
https://www.lua.org/manual/5.3/manual.html#6.4

string.dump(table.foreach) will trigger an assert,
https://github.com/LuaJIT/LuaJIT/issues/1038

An emergency collection when handling an error while loading the upvalues of a function can cause a segfault,
https://github.com/lua/lua/commit/422ce50d2e8856ed789d1359c673122dbb0088ea

Synopsis: string.dump(function [, strip])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    os.setlocale(test_lib.random_locale(fdp), "all")
    local str = fdp:consume_string(test_lib.MAX_STR_LEN)
    local strip = fdp:consume_boolean()
    local ok, func = pcall(loadstring, str)
    if not ok or func == nil then
        return
    end
    local res = string.dump(func, strip)
    assert(#res ~= 0)
end

local args = {
    artifact_prefix = "string_dump_",
}
-- LuaJIT ASSERT lj_bcread.c:123: bcread_byte: buffer read overflow.
if test_lib.lua_version() == "LuaJIT" then
    args["only_ascii"] = 1
end
luzer.Fuzz(TestOneInput, nil, args)
