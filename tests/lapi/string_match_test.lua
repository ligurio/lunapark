--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.4 – String Manipulation
https://www.lua.org/manual/5.3/manual.html#6.4

Synopsis: string.match(s, pattern [, init])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    os.setlocale(test_lib.random_locale(fdp), "all")
    local str = fdp:consume_string(test_lib.MAX_STR_LEN)
    local pattern = fdp:consume_string(test_lib.MAX_STR_LEN)
    local init = fdp:consume_integer(0, test_lib.MAX_INT)
    -- Avoid errors like "malformed pattern (ends with '%')".
    local ok, res = pcall(string.match, str, pattern, init)
    if not ok then
        return
    end
    -- Lua 5.4 Reference manual says, that "if it finds one, then
    -- match returns the captures from the pattern; otherwise it
    -- returns fail. If pattern specifies no captures, then the
    -- whole match is returned.". On practice with empty pattern
    -- `nil` is returned.
    assert(res == nil or type(res) == "string")
end

local args = {
    artifact_prefix = "string_match_",
}
luzer.Fuzz(TestOneInput, nil, args)
