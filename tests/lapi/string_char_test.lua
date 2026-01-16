--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.4 – String Manipulation
https://www.lua.org/manual/5.3/manual.html#6.4

string.char bug,
https://github.com/LuaJIT/LuaJIT/issues/375

Fix string.char() recording with no arguments,
https://github.com/LuaJIT/LuaJIT/commit/dfa692b7

Synopsis: string.char(...)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local unpack = unpack or table.unpack

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    os.setlocale(test_lib.random_locale(fdp), "all")
    -- `n` must be less than UINT_MAX and there are at least extra
    -- free stack slots in the stack, otherwise an error
    -- "too many results to unpack" is raised, see <ltablib.c>.
    local MAX_CHARS_NUM = 1024
    local n = fdp:consume_integer(1, MAX_CHARS_NUM)
    local CHAR_MAX = 255
    local chs = fdp:consume_integers(0, CHAR_MAX, n)
    local str = string.char(unpack(chs))
    -- Returns a string with length equal to the number of
    -- arguments.
    assert(#str == n)
end

local args = {
    artifact_prefix = "string_char_",
}
luzer.Fuzz(TestOneInput, nil, args)
