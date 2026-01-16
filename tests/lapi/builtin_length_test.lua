--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

2.5.5 – The Length Operator
https://www.lua.org/manual/5.1/manual.html

Table length computation overflows for sequences larger than
2^31 elements, https://www.lua.org/bugs.html#5.3.4-3
]]

local luzer = require("luzer")
local test_lib = require("lib")

local unpack = unpack or table.unpack

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)

    local str = fdp:consume_string(test_lib.MAX_STR_LEN)
    if str == nil then return -1 end
    local str_chars = {}
    str:gsub(".", function(c) table.insert(str_chars, c) end)

    assert(#str == select("#", unpack(str_chars)))
    assert(#str == string.len(str))
    assert(#str == str:len())
    assert(#str_chars == str:len())
end

local args = {
    artifact_prefix = "builtin_length_",
}
luzer.Fuzz(TestOneInput, nil, args)
