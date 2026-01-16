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

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local max_len = fdp:consume_integer(1, MAX_INT)
    local s = fdp:consume_string(max_len)
    local i = fdp:consume_integer(0, MAX_INT)
    local j = fdp:consume_integer(0, MAX_INT)
    local lax = fdp:consume_boolean()
    os.setlocale(test_lib.random_locale(fdp), "all")
    pcall(utf8.len, s, i, j, lax)
end

local args = {
    artifact_prefix = "utf8_len_",
}
luzer.Fuzz(TestOneInput, nil, args)
