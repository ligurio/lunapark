--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.4 – String Manipulation
https://www.lua.org/manual/5.3/manual.html#6.4

Performance issue for reg expression with "$",
https://github.com/LuaJIT/LuaJIT/issues/118

LuaJIT's gsub does not work with zero bytes in the pattern string,
https://github.com/LuaJIT/LuaJIT/issues/860

gsub may go wild when wrongly called without its third argument
and with a large subject,
https://www.lua.org/bugs.html#5.1.2-9

Synopsis: string.gsub(s, pattern, repl [, n])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    local str = fdp:consume_string(test_lib.MAX_STR_LEN)
    local pattern = fdp:consume_string(test_lib.MAX_STR_LEN)
    local repl = fdp:consume_string(test_lib.MAX_STR_LEN)
    local n = fdp:consume_integer(0, test_lib.MAX_INT)

    os.setlocale(test_lib.random_locale(fdp), "all")
    -- Avoid errors like "malformed pattern (missing ']')".
    local ok, res = pcall(string.gsub, str, pattern, repl, n)
    if ok then
        assert(type(res) == "string")
    end
end

local args = {
    artifact_prefix = "string_gsub_",
}
luzer.Fuzz(TestOneInput, nil, args)
