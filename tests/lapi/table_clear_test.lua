--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Double-emitting of IR_NEWREF for the same key on the snap replay,
https://github.com/LuaJIT/LuaJIT/issues/1128

X86/X64 load fusion conflict detection doesn't detect table.clear,
https://github.com/LuaJIT/LuaJIT/issues/1117

Problem of HREFK with table.clear,
https://github.com/LuaJIT/LuaJIT/issues/792

Add support for freeing memory manually,
https://github.com/LuaJIT/LuaJIT/issues/620

Synopsis: table.clear(tbl)
]]

local luzer = require("luzer")
local test_lib = require("lib")

if test_lib.lua_version() ~= "LuaJIT" then
    print("Unsupported version.")
    os.exit(0)
end

local table_clear = require("table.clear")

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local count = fdp:consume_integer(0, test_lib.MAX_INT64)
    local tbl = fdp:consume_strings(test_lib.MAX_STR_LEN, count)
    table_clear(tbl)
    -- Make sure the table is empty.
    local n_items = 0
    for _ in pairs(tbl) do
        n_items = n_items + 1
    end
    assert(n_items == 0)
end

local args = {
    artifact_prefix = "table_clear_",
}
luzer.Fuzz(TestOneInput, nil, args)
