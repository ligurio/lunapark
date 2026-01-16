--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.5 – Table Manipulation,
https://www.lua.org/manual/5.1/manual.html#5.5

Synopsis: table.maxn(table)
]]

local luzer = require("luzer")
local test_lib = require("lib")

if test_lib.lua_current_version_ge_than(5, 3) then
    print("Unsupported version.")
    os.exit(0)
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local count = fdp:consume_integer(0, test_lib.MAX_INT64)
    local tbl = fdp:consume_strings(test_lib.MAX_STR_LEN, count)
    local maxn = table.maxn(tbl)
    assert(maxn == #tbl)
end

local args = {
    artifact_prefix = "table_maxn_",
}
luzer.Fuzz(TestOneInput, nil, args)
