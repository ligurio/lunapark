--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.5 – Table Manipulation,
https://www.lua.org/manual/5.1/manual.html#5.5

table.remove removes last element of a table when given an
out-of-bound index, https://www.lua.org/bugs.html#5.1.2-10

Synopsis: table.remove(list [, pos])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    local count = fdp:consume_integer(1, test_lib.MAX_INT)
    local tbl = fdp:consume_strings(test_lib.MAX_STR_LEN, count)

    local indices_count = fdp:consume_integer(0, #tbl)
    local min_index = 0
    -- PUC Rio Lua 5.2+ raises an error "position out of bounds"
    -- when `pos` is equal to 0 and table is not empty.
    if test_lib.lua_current_version_ge_than(5, 2) then
        min_index = 1
    end
    local indices = fdp:consume_integers(min_index, count, indices_count)
    for _, idx in ipairs(indices) do
        local old_v = tbl[idx]
        assert(table.remove(tbl, idx) == old_v)
        assert(tbl[idx] == nil)
    end
end

local args = {
    artifact_prefix = "table_remove_",
}
luzer.Fuzz(TestOneInput, nil, args)
