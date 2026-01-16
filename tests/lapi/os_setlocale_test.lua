--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.9 – Operating System Facilities
https://www.lua.org/manual/5.3/manual.html#6.9

Synopsis: os.setlocale(locale [, category])
]]

local luzer = require("luzer")
local test_lib = require("lib")

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local locale = fdp:consume_string(test_lib.MAX_STR_LEN)
    local category = fdp:oneof({
        "all", "collate", "ctype", "monetary", "numeric", "time",
    })
    local locale_string = os.setlocale(locale, category)
    assert(type(locale_string) == "string" or
           locale_string == nil)
end

local args = {
    artifact_prefix = "os_setlocale_",
}
luzer.Fuzz(TestOneInput, nil, args)
