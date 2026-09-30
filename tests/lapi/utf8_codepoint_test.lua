--[=[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.5 – UTF-8 Support
https://www.lua.org/manual/5.3/manual.html#6.5

Synopsis: utf8.codepoint(s [, i [, j [, lax]]])
]]=]

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
    local i = fdp:consume_integer(0, MAX_INT)
    local j = fdp:consume_integer(0, MAX_INT)
    local lax = fdp:consume_boolean()
    os.setlocale(test_lib.random_locale(fdp), "all")
    pcall(function()
        local cps = {utf8.codepoint(s, i, j, lax)}

        for _, cp in ipairs(cps) do
            assert(type(cp) == "number" and cp == math.floor(cp),
                   "not an integer code point")
            assert(cp >= 0, "negative code point")
        end

        if test_lib.lua_current_version_ge_than(5, 4) then
            if not lax then
                for _, cp in ipairs(cps) do
                    assert(cp <= 0x10FFFF, "code point out of range")
                    assert(cp < 0xD800 or cp > 0xDFFF, "surrogate code point")
                end
            end

            local codes_ok, positions, codes = pcall(function()
                local pos, cp = {}, {}
                for p, c in utf8.codes(s) do
                    pos[#pos + 1] = p
                    cp[#cp + 1] = c
                end
                return pos, cp
            end)

            if not lax and codes_ok and i >= 1 and j <= #s then
                local n = 0
                for idx, pos in ipairs(positions) do
                    if pos >= i and pos <= j then
                        n = n + 1
                        assert(cps[n] == codes[idx],
                               "code point mismatch with utf8.codes")
                    end
                end
                assert(n == #cps, "unexpected number of code points")

                for idx, pos in ipairs(positions) do
                    if pos >= i and pos <= j then
                        local next_pos = positions[idx + 1] or #s + 1
                        assert(utf8.char(codes[idx]) ==
                                   s:sub(pos, next_pos - 1),
                               "utf8.char roundtrip failed")
                    end
                end
            end
        end
    end)
end

local args = {
    artifact_prefix = "utf8_codepoint_",
}
luzer.Fuzz(TestOneInput, nil, args)
