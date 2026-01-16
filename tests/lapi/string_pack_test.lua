--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.4 – String Manipulation
https://www.lua.org/manual/5.3/manual.html#6.4

Synopsis: string.pack(fmt, v1, v2, ...)
]]

local luzer = require("luzer")
local test_lib = require("lib")

-- The function `string.pack()` is available since Lua 5.3.
if not test_lib.lua_current_version_ge_than(5, 3) then
    print("Unsupported version.")
    os.exit(0)
end

local ignored_msgs = {
    "invalid format option",
}

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    os.setlocale(test_lib.random_locale(fdp), "all")
    local fmt_str = fdp:consume_string(test_lib.MAX_STR_LEN)
    if fdp:remaining_bytes() == 0 then
        return -1
    end
    local n = fdp:consume_integer(1, test_lib.MAX_INT)
    local values = fdp:consume_strings(test_lib.MAX_STR_LEN,  n)
    local err_handler = test_lib.err_handler(ignored_msgs)
    local ok, _ = xpcall(string.pack, err_handler, fmt_str,
                         table.unpack(values))
    if not ok then return end
end

local args = {
    artifact_prefix = "string_pack_",
}
luzer.Fuzz(TestOneInput, nil, args)
