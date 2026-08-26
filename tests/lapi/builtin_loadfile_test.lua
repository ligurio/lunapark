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
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    local chunk_filename = os.tmpname()
    local fh = io.open(chunk_filename, "w")
    assert(fh ~= nil)
    local chunk = fdp:remaining_bytes()
    if test_lib.lua_version() == "LuaJIT" then
        -- LuaJIT ASSERT lj_bcread.c:123: bcread_byte: buffer read overflow.
        local pattern = "[^%z\1-\127][\128-\255][\192-\255][\128-\191]"
        chunk = string.gsub(chunk, pattern, "")
    end
    fh:write(chunk)
    fh:close()

    pcall(function()
        local fn, err = loadfile(chunk_filename)
        if fn ~= nil then
            -- The compiled chunk must be a function; execute it.
            assert(type(fn) == "function")
            pcall(fn)
        else
            -- On failure loadfile returns a string error message.
            assert(type(err) == "string")
        end
    end)

    -- Loading a missing file must return nil plus an error message.
    local missing = chunk_filename .. ".missing"
    if not test_lib.is_file_exist(missing) then
        local fn, err = loadfile(missing)
        assert(fn == nil)
        assert(type(err) == "string")
    end

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
