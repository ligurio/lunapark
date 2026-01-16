--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.1 – Basic Functions
https://www.lua.org/manual/5.1/manual.html

Synopsis: loadfile([filename])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local chunk_filename = os.tmpname()
    local fh = io.open(chunk_filename, "w")
    local chunk = buf
    if test_lib.lua_version() == "LuaJIT" then
        -- LuaJIT ASSERT lj_bcread.c:123: bcread_byte: buffer read overflow.
        local pattern = "[^%z\1-\127][\128-\255][\192-\255][\128-\191]"
        chunk = string.gsub(chunk, pattern, "")
    end
    fh:write(chunk)
    fh:close()

    pcall(loadfile, chunk_filename)

    os.remove(chunk_filename)
end

local args = {
    artifact_prefix = "builtin_loadfile_",
}
-- lj_bcread.c:123: bcread_byte: buffer read overflow
if test_lib.lua_version() == "LuaJIT" then
    args.only_ascii = 1
end
luzer.Fuzz(TestOneInput, nil, args)
