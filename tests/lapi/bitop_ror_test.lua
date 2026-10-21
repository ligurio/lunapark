--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

Synopsis: bit.ror(x, n)
]]

local luzer = require("luzer")
local test_lib = require("lib")

if test_lib.lua_version() ~= "LuaJIT" then
    print("Unsupported version.")
    os.exit(0)
end

local ror = bit.ror
local tobit = bit.tobit
local bnot = bit.bnot

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    local MAX_INT = test_lib.MAX_INT
    local MIN_INT = test_lib.MIN_INT
    local x = fdp:consume_integer(MIN_INT, MAX_INT)
    ---@type integer
    local n = fdp:consume_integer(MIN_INT, MAX_INT)
    local res = ror(x, n)
    assert(type(res) == "number")

    -- For any valid displacement, the following identity holds
    -- [1]:
    --
    -- 1. https://www.lua.org/manual/5.2/manual.html
    assert(ror(x, n) == ror(x, n % 32))

    -- Zero and full-word rotate.
    assert(ror(x, 0) == tobit(x))
    assert(ror(x, 32) == tobit(x))

    -- Composability: ror(ror(x, 1), n-1) == ror(x, n)
    if n > 0 then
        assert(ror(ror(x, 1), n - 1) == ror(x, n))
    end

    -- Inverse: double rotate yields original.
    assert(ror(ror(x, n), -n) == tobit(x))

    -- Commutation with NOT.
    assert(ror(bnot(x), n) == bnot(ror(x, n)))
end

local args = {
    artifact_prefix = "bitop_ror_",
}
luzer.Fuzz(TestOneInput, nil, args)
