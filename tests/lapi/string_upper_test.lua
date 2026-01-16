--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.4 – String Manipulation
https://www.lua.org/manual/5.3/manual.html#6.4

Synopsis: string.upper(s)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    os.setlocale(test_lib.random_locale(fdp), "all")
    local a_code = string.byte("a")
    local str = fdp:consume_string(1, test_lib.MAX_STR_LEN)
    local str_uppercase = str:upper()
    for i = 1, #str do
        local code = string.byte(string.sub(str_uppercase, i, i))
        assert(code < a_code or code > a_code + 25)
    end
end

local args = {
    artifact_prefix = "string_upper_",
}
luzer.Fuzz(TestOneInput, nil, args)
