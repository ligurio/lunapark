--[=[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.5 – UTF-8 Support
https://www.lua.org/manual/5.3/manual.html#6.5

Synopsis: utf8.len(s [, i [, j [, lax]]])
]]=]

local luzer = require("luzer")
local test_lib = require("lib")
local MAX_INT = test_lib.MAX_INT

-- The function is introduced in Lua 5.3.
if test_lib.lua_current_version_lt_than(5, 3) then
    print("Unsupported version.")
    os.exit()
end

local unpack = unpack or table.unpack

-- Positions `i` and `j` of `utf8.len` are byte positions: the call
-- counts codepoints whose encoding starts between `i` and `j`.
-- Lua 5.4+ treats surrogates (U+D800..U+DFFF) as invalid UTF-8,
-- while Lua 5.3 does not, therefore codepoints are restricted to
-- Unicode scalar values to keep assertions version-independent.
local function scalar_value(fdp)
    local cp = fdp:consume_integer(0, 0x10FFFF - 0x800)
    if cp >= 0xD800 then
        cp = cp + 0x800
    end
    return cp
end

-- Counts codepoints in `starts` (byte positions of codepoint
-- encodings in ascending order) whose position is in `[i, j]`.
local function count_in_range(starts, i, j)
    local count = 0
    for _, pos in ipairs(starts) do
        if pos >= i and pos <= j then
            count = count + 1
        elseif pos > j then
            break
        end
    end
    return count
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    os.setlocale(test_lib.random_locale(fdp), "all")

    -- Part 1: `s` is valid UTF-8 by construction, positions `i` and
    -- `j` are always in range, so `utf8.len` must not raise an error
    -- and the result is fully predictable.
    local cps = {}
    local n = fdp:consume_integer(1, 20)
    for _ = 1, n do
        cps[#cps + 1] = scalar_value(fdp)
    end
    local s = utf8.char(unpack(cps))
    local nbytes = #s
    local starts = {}
    for pos in utf8.codes(s) do
        table.insert(starts, pos)
    end
    -- The default `i`/`j` cover the whole string.
    assert(utf8.len(s) == #starts)
    assert(utf8.len(s, 1, nbytes) == #starts)

    local i = fdp:consume_integer(1, nbytes)
    local j = fdp:consume_integer(1, nbytes)
    if i > j then
        i, j = j, i
    end
    local res, pos = utf8.len(s, i, j)
    local starts_at_i = false
    for _, p in ipairs(starts) do
        if p == i then
            starts_at_i = true
            break
        end
    end
    if starts_at_i then
        -- `i` is the first byte of a codepoint: the result is the
        -- number of codepoints that start in `[i, j]`.
        assert(type(res) == "number")
        assert(res == count_in_range(starts, i, j))
        assert(pos == nil)
    else
        -- `i` points to a continuation byte: `utf8.len` reports an
        -- invalid sequence at position `i`.
        assert(res == nil)
        assert(pos == i)
    end

    -- Part 2: arbitrary byte strings with arbitrary positions and
    -- `lax` mode. `utf8.len` raises an error when `i`/`j` are out of
    -- bounds, which is an expected behavior, and returns `nil` plus
    -- the position of an invalid byte otherwise.
    local max_len = fdp:consume_integer(0, MAX_INT)
    local s2 = fdp:consume_string(max_len)
    local i2 = fdp:consume_integer(-#s2 - 1, #s2 + 1)
    local j2 = fdp:consume_integer(-#s2 - 1, #s2 + 1)
    local lax = fdp:consume_boolean()
    local ok, result, pos2 = pcall(utf8.len, s2, i2, j2, lax)
    if not ok then
        return
    end
    if result then
        assert(type(result) == "number")
        assert(result == math.floor(result))
        assert(result >= 0 and result <= #s2)
    else
        assert(type(pos2) == "number")
        assert(pos2 >= 1 and pos2 <= #s2 + 1)
    end
end

local args = {
    artifact_prefix = "utf8_len_",
}
luzer.Fuzz(TestOneInput, nil, args)
