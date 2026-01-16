--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.4 – String Manipulation
https://www.lua.org/manual/5.3/manual.html#6.4

Synopsis: string.packsize(fmt)
]]

local luzer = require("luzer")
local test_lib = require("lib")

-- The function `string.packsize()` is available since Lua 5.3.
if not test_lib.lua_current_version_ge_than(5, 3) then
    print("Unsupported version.")
    os.exit(0)
end

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    os.setlocale(test_lib.random_locale(fdp), "all")
    local fmt_str = fdp:consume_string(test_lib.MAX_STR_LEN)
    -- Avoid errors like "invalid format option 'R'".
    local ok, _ = pcall(string.packsize, fmt_str)
    if not ok then
        return
    end
    local size = string.packsize(fmt_str)
    assert(type(size) == "number")
end

local args = {
    artifact_prefix = "string_packsize_",
}
luzer.Fuzz(TestOneInput, nil, args)
