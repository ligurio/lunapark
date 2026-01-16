--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.4 – String Manipulation
https://www.lua.org/manual/5.3/manual.html#6.4

stack-buffer-overflow in lj_strfmt_wfnum,
https://github.com/LuaJIT/LuaJIT/issues/1149
string.format("%7g",0x1.144399609d407p+401)

string.format %c bug,
https://github.com/LuaJIT/LuaJIT/issues/378

string.format doesn't take current locale decimal separator into account,
https://github.com/LuaJIT/LuaJIT/issues/673

string.format("%f") can cause a buffer overflow (only when
'lua_Number' is long double!),
https://www.lua.org/bugs.html#5.3.0-1

string.format may get buffer as an argument when there are missing
arguments and format string is too long,
https://www.lua.org/bugs.html#5.1.4-7

string.format("%") may read past the string,
https://www.lua.org/bugs.html#5.1.1-3

Option '%q' in string.formatE does not handle '\r' correctly,
https://www.lua.org/bugs.html#5.1-4

FFI: Support FFI numbers in string.format() and buf:putf(),
https://github.com/LuaJIT/LuaJIT/commit/1b7171c3

[0014] CRASH detected in lj_ir_kgc due to a fault at or
near 0x00007ff7f3274008 leading to SIGSEGV,
https://github.com/LuaJIT/LuaJIT/issues/1203

Synopsis: string.format(formatstring, ...)
]]


local luzer = require("luzer")
local test_lib = require("lib")

local specifiers = {
    "a",
    "A",
    "c",
    "d",
    "e",
    "E",
    "f",
    "g",
    "G",
    "i",
    "o",
    "p",
    "q",
    "s",
    "u",
    "x",
    "X",
}

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    local spec = fdp:oneof(specifiers)
    local format_string = ("%%%s"):format(spec)
    local str = fdp:consume_string(test_lib.MAX_STR_LEN)

    os.setlocale(test_lib.random_locale(fdp), "all")
    local ok, res = pcall(string.format, format_string, str)
    assert(type(res) == "string")
    if ok then
        assert((format_string):format(str) == string.format(format_string, str))
    end
end

local args = {
    artifact_prefix = "string_format_",
}
luzer.Fuzz(TestOneInput, nil, args)
