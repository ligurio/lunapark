--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.4 – String Manipulation
https://www.lua.org/manual/5.3/manual.html#6.4

Synopsis: string.lower(s)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf, _)
    local fdp = luzer.FuzzedDataProvider(buf)
    os.setlocale(test_lib.random_locale(fdp), "all")
    local lower_bound = string.byte("A")
    local upper_bound = string.byte("A") + 25
    local ch_code = fdp:consume_integer(lower_bound, upper_bound)
    local ch_uppercase = string.char(ch_code)
    local ch = string.upper(string.lower(ch_uppercase))
    assert(ch == ch_uppercase)

    local str = fdp:consume_string(1, test_lib.MAX_STR_LEN)
    local str_lowercase = str:lower()
    assert(str_lowercase == str_lowercase:upper():lower())
end

local args = {
    artifact_prefix = "string_lower_",
}
luzer.Fuzz(TestOneInput, nil, args)
