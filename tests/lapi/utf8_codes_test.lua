--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.5 – UTF-8 Support
https://www.lua.org/manual/5.3/manual.html#6.5

'utf8.codes' does not raise an error on spurious continuation bytes,
https://github.com/lua/lua/commit/a1089b415a3f5c753aa1b40758ffdaf28d5701b0

Synopsis: utf8.codes(s [, lax])
]]

local luzer = require("luzer")
local test_lib = require("lib")
local MAX_INT = test_lib.MAX_INT

-- The function is introduced in Lua 5.3.
if test_lib.lua_current_version_lt_than(5, 3) then
    print("Unsupported version.")
    os.exit()
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    local max_len = fdp:consume_integer(1, MAX_INT)
    local s = fdp:consume_string(max_len)
    local lax = fdp:consume_boolean()
    os.setlocale(test_lib.random_locale(fdp), "all")
    pcall(function()
        local last_pos = 0
        for pos, code in utf8.codes(s, lax) do
            assert(code >= 0 and code <= 0x10FFFF, "bad code point")
            assert(code < 0xD800 or code > 0xDFFF, "surrogate")
            assert(pos > last_pos, "pos not monotonic")
            last_pos = pos
        end
        assert(last_pos == #s + 1, "did not consume all input")
    end)
end

local args = {
    artifact_prefix = "utf8_codes_",
}
luzer.Fuzz(TestOneInput, nil, args)
