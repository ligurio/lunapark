--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.5 – Table Manipulation,
https://www.lua.org/manual/5.2/manual.html#6.5

Synopsis: table.pack(...)
]]

local luzer = require("luzer")
local test_lib = require("lib")

if test_lib.lua_current_version_lt_than(5, 2) then
    print("Unsupported version.")
    os.exit(0)
end

local unpack = unpack or table.unpack

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    -- Beware, huge number triggers 'too many results to unpack'.
    local MAX_N = 1000
    local count = fdp:consume_integer(1, MAX_N)
    local tbl = fdp:consume_integers(test_lib.MIN_INT, test_lib.MAX_INT, count)
    local packed = table.pack(unpack(tbl))
    assert(#packed == #tbl)
    assert(test_lib.arrays_equal(packed, tbl))
end

local args = {
    artifact_prefix = "table_pack_",
}
luzer.Fuzz(TestOneInput, nil, args)
