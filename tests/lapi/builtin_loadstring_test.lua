--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

PIL: "8 – Compilation, Execution, and Errors"
https://www.lua.org/pil/8.html

Maliciously crafted precompiled code can crash Lua,
https://www.lua.org/bugs.html#5.1.3-5

Maliciously crafted precompiled code can blow the C stack,
https://www.lua.org/bugs.html#5.1.3-6

Code validator may reject (maliciously crafted) correct code,
https://www.lua.org/bugs.html#5.1.3-7

Maliciously crafted precompiled code can inject invalid boolean
values into Lua code,
https://www.lua.org/bugs.html#5.1.3-8

Synopsis: loadstring(string [, chunkname])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local chunk = buf
    if test_lib.lua_version() == "LuaJIT" then
        -- LuaJIT ASSERT lj_bcread.c:123: bcread_byte: buffer read overflow.
        local pattern = "[^%z\1-\127][\128-\255][\192-\255][\128-\191]"
        chunk = string.gsub(chunk, pattern, "")
    end
    local ok, res = pcall(loadstring, chunk)
    if ok then
        pcall(res)
    end
end

local args = {
    artifact_prefix = "builtin_loadstring_",
}
-- lj_bcread.c:123: bcread_byte: buffer read overflow
if test_lib.lua_version() == "LuaJIT" then
    args.only_ascii = 1
end
luzer.Fuzz(TestOneInput, nil, args)
