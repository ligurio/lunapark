--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.6 – Table Manipulation,
https://www.lua.org/manual/5.3/manual.html#6.6

Synopsis: table.move(a1, f, e, t [,a2])
]]

local luzer = require("luzer")
local test_lib = require("lib")

if test_lib.lua_current_version_lt_than(5, 3) and
   test_lib.lua_version == "PUC Rio Lua" then
    print("Unsupported version.")
    os.exit(0)
end

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    local count = fdp:consume_integer(0, test_lib.MAX_INT)
    local a1 = fdp:consume_strings(test_lib.MAX_STR_LEN, count)
    local a2 = {}
    -- Move random items from the table `a1` to the table `a2`.
    -- Beware, `table.move()` works too slow with huge numbers.
    local MAX_N = 1000
    local f = fdp:consume_integer(-MAX_N, MAX_N)
    local e = fdp:consume_integer(-MAX_N, MAX_N)
    local t = fdp:consume_integer(-MAX_N, MAX_N)
    local res = table.move(a1, f, e, t, a2)
    assert(test_lib.arrays_equal(a2, res))
end

local args = {
    artifact_prefix = "table_move_",
}
luzer.Fuzz(TestOneInput, nil, args)
