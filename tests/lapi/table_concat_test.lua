--[=[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.5 – Table Manipulation,
https://www.lua.org/manual/5.1/manual.html#5.5

Infinite loop on table lookup,
https://github.com/LuaJIT/LuaJIT/issues/494

Synopsis: table.concat(list [, sep [, i [, j]]])
--]=]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    local str = fdp:consume_string(test_lib.MAX_STR_LEN)
    local tbl_size = #str
    if tbl_size == 0 then return -1 end

    -- Split string to a table.
    local tbl = {}
    str:gsub(".", function(c)
        table.insert(tbl, c)
    end)
    assert(#tbl == tbl_size)

    -- Join table to a string.
    local j = fdp:consume_integer(1, tbl_size)
    local i = fdp:consume_integer(1, j)
    local sep = ""
    assert(string.sub(str, i, j) == table.concat(tbl, sep, i, j))
end

local args = {
    artifact_prefix = "table_concat_",
}
luzer.Fuzz(TestOneInput, nil, args)
