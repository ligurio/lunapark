--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.5 – UTF-8 Support
https://www.lua.org/manual/5.3/manual.html#6.5

Synopsis: utf8.char(...)
]]

local luzer = require("luzer")
local test_lib = require("lib")
local MAX_INT = test_lib.MAX_INT
local MIN_INT = test_lib.MIN_INT
local LUA_54 = test_lib.lua_current_version_ge_than(5, 4)

-- The function is introduced in Lua 5.3.
if test_lib.lua_current_version_lt_than(5, 3) then
    print("Unsupported version.")
    os.exit()
end

local unpack = unpack or table.unpack

-- utf8.char() accepts codepoints in the range [0, MAX_CP]:
-- in Lua 5.3 the range is [0, 0x10FFFF], in Lua 5.4+ it is
-- [0, 0x7FFFFFFF].
local MAX_CP = LUA_54 and 0x7FFFFFFF or 0x10FFFF

-- A number of bytes occupied by a codepoint in its UTF-8 encoding.
local function utf8_bytes(c)
    if c < 0x80 then
        return 1
    elseif c < 0x800 then
        return 2
    elseif c < 0x10000 then
        return 3
    elseif c < 0x200000 then
        return 4
    elseif c < 0x4000000 then
        return 5
    else
        return 6
    end
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    -- Limit count to prevent error "too many results to unpack".
    local MAX_N = 1000
    local count = fdp:consume_integer(1, MAX_N)
    local chars = fdp:consume_integers(MIN_INT, MAX_INT, count)
    os.setlocale(test_lib.random_locale(fdp), "all")

    -- utf8.char() succeeds iff every argument is a codepoint
    -- representable in UTF-8, otherwise it raises an error.
    local all_valid = true
    local expected_len = 0
    for _, c in ipairs(chars) do
        if c < 0 or c > MAX_CP then
            all_valid = false
            break
        end
        expected_len = expected_len + utf8_bytes(c)
    end

    local ok, res = pcall(utf8.char, unpack(chars))
    if not all_valid then
        assert(not ok)
        return
    end
    assert(ok)
    assert(type(res) == "string")
    -- #res is a length in bytes, each codepoint contributes
    -- utf8_bytes(c) bytes to the result.
    assert(#res == expected_len)
    -- Round-trip: decoding of the result must return the original
    -- codepoints. In Lua 5.4+ utf8.codes requires lax mode to
    -- accept codepoints above 0x10FFFF produced by utf8.char().
    local decoded = {}
    for _, cp in utf8.codes(res, LUA_54) do
        table.insert(decoded, cp)
    end
    assert(test_lib.arrays_equal(decoded, chars))
end

local args = {
    artifact_prefix = "utf8_char_",
}
luzer.Fuzz(TestOneInput, nil, args)
