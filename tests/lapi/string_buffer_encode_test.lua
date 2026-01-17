--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

String Buffer Library,
https://luajit.org/ext_buffer.html

ITERN deoptimization might skip elements,
https://github.com/LuaJIT/LuaJIT/issues/727

buffer.decode() may produce ill-formed cdata resulting in invalid
memory accesses, https://github.com/LuaJIT/LuaJIT/issues/795

Add missing GC steps to string buffer methods,
https://github.com/LuaJIT/LuaJIT/commit/9c3df68a

Fix string buffer method recording,
https://github.com/LuaJIT/LuaJIT/commit/bfd07653
]]

local luzer = require("luzer")
local test_lib = require("lib")

-- LuaJIT only.
if test_lib.lua_version() ~= "LuaJIT" then
    print("Unsupported version.")
    os.exit(0)
end

local has_string_buf, string_buf = pcall(require, "string.buffer")
if not has_string_buf then
    print("Unsupported version.")
    os.exit(0)
end

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    local obj = fdp:consume_string(test_lib.MAX_STR_LEN)
    local buf_size = fdp:consume_integer(1, test_lib.MAX_STR_LEN)
    local b = string_buf.new(buf_size)
    local decoded, err = pcall(b.decode, obj)
    if err then
        return
    end
    local encoded = b:encode(decoded)
    assert(obj == encoded)
    b:reset()
    b:free()
end

local args = {
    artifact_prefix = "string_buffer_encode_",
}
luzer.Fuzz(TestOneInput, nil, args)
