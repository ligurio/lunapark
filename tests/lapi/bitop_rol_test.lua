--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Wrong code generation for constants in bitwise operations,
https://github.com/lua/lua/commit/c764ca71a639f5585b5f466bea25dc42b855a4b0

Synopsis: bit.rol(x, n)
]]

local luzer = require("luzer")
local test_lib = require("lib")

if test_lib.lua_version() ~= "LuaJIT" then
    print("Unsupported version.")
    os.exit(0)
end

local rol = bit.rol

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local MAX_INT = test_lib.MAX_INT
    local MIN_INT = test_lib.MIN_INT
    local x = fdp:consume_integer(MIN_INT, MAX_INT)
    local n = fdp:consume_integer(MIN_INT, MAX_INT)
    local res = rol(x, n)
    assert(type(res) == "number")

    -- For any valid displacement, the following identity holds [1]:
    --
    -- 1. https://www.lua.org/manual/5.2/manual.html
    assert(rol(x, n) == rol(x, n % 32))
end

local args = {
    artifact_prefix = "bitop_rol_",
}
luzer.Fuzz(TestOneInput, nil, args)
