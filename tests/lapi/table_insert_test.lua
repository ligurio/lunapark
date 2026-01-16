--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.5 – Table Manipulation,
https://www.lua.org/manual/5.1/manual.html#5.5

Synopsis: table.insert(list, [pos,] value)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local MAX_INT = test_lib.MAX_INT

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    local str = fdp:consume_string(test_lib.MAX_STR_LEN)
    local tbl = {}
    str:gsub(".", function(c)
        -- The `pos` value cannot be negative in PUC Rio Lua 5.2+
        -- and in LuaJIT `table.insert()` works too slow with huge
        -- `pos` values.
        local MAX_POS = #tbl + 1
        if test_lib.lua_version() == "LuaJIT" then
            MAX_POS = MAX_INT
        end
        local pos = fdp:consume_integer(1, MAX_POS)
        table.insert(tbl, pos, c)
    end)
end

local args = {
    artifact_prefix = "table_insert_",
}
luzer.Fuzz(TestOneInput, nil, args)
