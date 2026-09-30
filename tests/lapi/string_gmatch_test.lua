--[=[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.4 – String Manipulation
https://www.lua.org/manual/5.3/manual.html#6.4

GC64: string.gmatch crash,
https://github.com/LuaJIT/LuaJIT/issues/300

gmatch iterator fails when called from a coroutine different from
the one that created it,
https://www.lua.org/bugs.html#5.3.2-3

Synopsis: string.gmatch(s, pattern [, init])
]=]

local luzer = require("luzer")
local test_lib = require("lib")

-- `string.gmatch()` gained its `init` parameter in Lua 5.4;
-- LuaJIT and older Lua versions ignore it.
local gmatch_has_init = false
do
    local probe_ok, probe_it = pcall(string.gmatch, "a1b2", "%d", 3)
    if probe_ok then
        local _, first = pcall(probe_it)
        gmatch_has_init = first == "2"
    end
end

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    os.setlocale(test_lib.random_locale(fdp), "all")
    local s = fdp:consume_string(test_lib.MAX_STR_LEN)
    local pattern = fdp:consume_string(test_lib.MAX_STR_LEN)
    local init = fdp:consume_integer(0, test_lib.MAX_INT)

    -- `string.gmatch()` compiles the pattern lazily, on the first
    -- call of the iterator, so a malformed pattern is reported
    -- during iteration, not when the iterator is created.
    local ok, it = pcall(string.gmatch, s, pattern, init)
    if not ok then
        return
    end

    -- Exercise the iterator by collecting all matches. Errors
    -- caused by malformed patterns are reported here and are
    -- ignored; native crashes still propagate to the test.
    local matches = {}
    local iter_ok = pcall(function()
        for match in it do
            table.insert(matches, match)
        end
    end)
    if not iter_ok then
        return
    end

    -- Metamorphic: the first `gmatch` match equals the
    -- `string.match()` result. Patterns starting with `^` are
    -- skipped: `gmatch` gives the anchor a different meaning.
    if pattern:sub(1, 1) == "^" then
        return
    end

    local match_ok, match_result = pcall(
        string.match, s, pattern, gmatch_has_init and init or 1)
    if not match_ok then
        return
    end
    if #matches > 0 then
        assert(matches[1] == match_result)
    else
        assert(match_result == nil)
    end
end

local args = {
    artifact_prefix = "string_gmatch_",
}
luzer.Fuzz(TestOneInput, nil, args)
