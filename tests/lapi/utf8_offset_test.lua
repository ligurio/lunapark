--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.5 – UTF-8 Support
https://www.lua.org/manual/5.3/manual.html#6.5

Synopsis: utf8.offset(s, n [, i])
]]

local luzer = require("luzer")
local test_lib = require("lib")
local MAX_INT = test_lib.MAX_INT
local MIN_INT = test_lib.MIN_INT

-- The function is introduced in Lua 5.3.
if test_lib.lua_current_version_lt_than(5, 3) then
    print("Unsupported version.")
    os.exit()
end

local function collect_codes(s, lax)
    local codes = {}
    for pos, _ in utf8.codes(s, lax) do
        codes[#codes + 1] = pos
    end
    return codes
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    local max_len = fdp:consume_integer(0, MAX_INT)
    local s = fdp:consume_string(max_len)
    local n = fdp:consume_integer(MIN_INT, MAX_INT)
    local i = fdp:consume_integer(1, MAX_INT)
    local lax = fdp:consume_boolean()
    os.setlocale(test_lib.random_locale(fdp), "all")

    pcall(function()
        local codes_ok, codes = pcall(collect_codes, s, lax)

        local off = utf8.offset(s, n, i)

        if off ~= nil then
            assert(type(off) == "number" and off >= 1 and off <= #s + 1)
            if n == 0 then
                assert(off <= i, "n=0 must not return offset after i")
            end
        end

        if not codes_ok then return end

        -- Identity n=0: returns the start of the character at
        -- byte position `i`.
        local off0 = utf8.offset(s, 0, i)
        if off0 ~= nil then
            assert(off0 >= 1 and off0 <= #s + 1)
            -- The character after off0 must start after i or not exist
            local next_off = utf8.offset(s, 1, off0)
            if next_off ~= nil then
                assert(i < next_off,
                       "n=0 must return char start, not a byte inside char")
            end
        end

        -- Each i-th character position from utf8.codes matches utf8.offset(s, i)
        for idx = 1, #codes do
            local expected_pos = codes[idx]
            local off_idx = utf8.offset(s, idx)
            assert(off_idx == expected_pos,
                   ("offset(s, %d) = %d, codes pos = %d"):format(
                       idx, off_idx, expected_pos))
            assert(off_idx >= 1 and off_idx <= #s)

            -- n=0 on any byte of this character must return
            -- off_idx.
            local next_pos = codes[idx + 1] or (#s + 1)
            local char_len = next_pos - expected_pos
            for byte_off = off_idx, off_idx + char_len - 1 do
                local off_start = utf8.offset(s, 0, byte_off)
                assert(off_start == off_idx,
                       ("n=0 inside char: offset(s,0,%d) = %d, expected %d")
                       :format(byte_off, off_start, off_idx))
            end
        end

        -- `nil` after the last character.
        assert(utf8.offset(s, #codes + 1) == nil)
        assert(utf8.offset(s, #codes + 2) == nil)

        -- Negative n: the start of the last character if -1.
        local last_off = utf8.offset(s, -1)
        if last_off ~= nil then
            assert(last_off == codes[#codes],
                   "offset(s, -1) must point to start of last char")
        end
    end)
end

local args = {
    artifact_prefix = "utf8_offset_",
}
luzer.Fuzz(TestOneInput, nil, args)
