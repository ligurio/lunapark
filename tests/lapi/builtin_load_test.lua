--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

Loading a corrupted binary file can segfault,
https://github.com/lua/lua/commit/ab859fe59b464a038a45552921cb2b23892343af

Long string can be collected while its contents is being read when
loading a binary file,
https://github.com/lua/lua/commit/6bc0f13505bf5d4f613d725fe008c79e72f83ddf

Long brackets with a huge number of '=' overflow some internal buffer arithmetic.

Chunk with too many lines may crash Lua,
https://www.lua.org/bugs.html#5.2.3-3

An emergency collection when handling an error while loading the
upvalues of a function can cause a segfault,
https://www.lua.org/bugs.html#5.4.0-3
https://github.com/lua/lua/commit/422ce50d2e8856ed789d1359c673122dbb0088ea

load and loadfile return wrong result when given an environment
for a binary chunk with no upvalues,
https://www.lua.org/bugs.html#5.2.1-4

When loading a file, Lua may call the reader function again after
it returned end of input,
https://www.lua.org/bugs.html#5.1.5-2

Maliciously crafted precompiled code can crash Lua,
https://www.lua.org/bugs.html#5.1.4-1

Synopsis: load(func [, chunkname])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local mode = fdp:oneof({"t", "b"})
    -- LuaJIT ASSERT lj_bcread.c:123: bcread_byte: buffer read overflow.
    if test_lib.lua_version() == "LuaJIT" then
        mode = "t"
    end
    local func = load(buf, "luzer", mode)
    pcall(func)
end

local args = {
    artifact_prefix = "builtin_load_",
}
luzer.Fuzz(TestOneInput, nil, args)
