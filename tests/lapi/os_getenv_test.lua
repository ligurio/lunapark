--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.9 – Operating System Facilities
https://www.lua.org/manual/5.3/manual.html#6.9

Synopsis: os.getenv(varname)
]]

local luzer = require("luzer")

local function TestOneInput(buf)
    local v = os.getenv(buf)
    assert(type(v) == "string" or v == nil)
end

local args = {
    artifact_prefix = "os_getenv_",
}
luzer.Fuzz(TestOneInput, nil, args)
