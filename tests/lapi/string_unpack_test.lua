--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.4 – String Manipulation
https://www.lua.org/manual/5.3/manual.html#6.4

Synopsis: string.unpack(fmt, s [, pos])
]]

local luzer = require("luzer")
local test_lib = require("lib")

-- The function `string.unpack()` is available since Lua 5.3.
if not test_lib.lua_current_version_ge_than(5, 3) then
    print("Unsupported version.")
    os.exit(0)
end

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    os.setlocale(test_lib.random_locale(fdp), "all")
    local str = fdp:consume_string(1, test_lib.MAX_STR_LEN)
    local fmt_str = fdp:consume_string(1, test_lib.MAX_STR_LEN)

    local ok, _ = pcall(string.unpack, fmt_str, str)
    if not ok then
        return
    end
    local values = { string.unpack(fmt_str, str) }
    local nvalues = #values
    -- Last return value is the next position, exclude it.
    if nvalues <= 1 then
        return
    end
    ---@diagnostic disable-next-line: param-type-mismatch
    local packed = string.pack(fmt_str, table.unpack(values, 1, nvalues - 1))
    if #packed == 0 then
        return
    end
    local values2 = { string.unpack(fmt_str, packed) }
    for i = 1, nvalues - 1 do
        assert(values[i] == values2[i])
    end
    local ok_size, size = pcall(string.packsize, fmt_str)
    if ok_size then
        assert(#packed == size)
    end
end

local args = {
    -- Avoid errors like "invalid format option '�'" is expected".
    only_ascii = 1,
    artifact_prefix = "string_unpack_",
}
luzer.Fuzz(TestOneInput, nil, args)
