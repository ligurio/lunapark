--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.4 – String Manipulation
https://www.lua.org/manual/5.3/manual.html#6.4

Synopsis: string.sub(s, i [, j])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    os.setlocale(test_lib.random_locale(fdp), "all")
    local str_len = test_lib.MAX_STR_LEN
    local middle_str = fdp:consume_string(str_len)
    local left_str = fdp:consume_string(str_len)
    local right_str = fdp:consume_string(str_len)
    local str = left_str .. middle_str .. right_str
    assert(middle_str == string.sub(str, #left_str + 1, #left_str + #middle_str))
end

local args = {
    artifact_prefix = "string_sub_",
}
luzer.Fuzz(TestOneInput, nil, args)
