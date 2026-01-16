--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.4 – String Manipulation
https://www.lua.org/manual/5.3/manual.html#6.4

read overflow in 'l_strcmp',
https://github.com/lua/lua/commit/f623b969325be736297bc1dff48e763c08778243

Synopsis: string.rep(s, n [, sep])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    os.setlocale(test_lib.random_locale(fdp), "all")
    -- Huge length leads to slow units.
    local n = fdp:consume_integer(1, test_lib.MAX_STR_LEN)
    local s = fdp:consume_string(test_lib.MAX_STR_LEN)
    local sep = fdp:consume_string(test_lib.MAX_STR_LEN)
    local len = string.len(string.rep(s, n, sep))
    assert(len == #s * n + #sep * (n - 1))
end

local args = {
    artifact_prefix = "string_rep_",
}
luzer.Fuzz(TestOneInput, nil, args)
