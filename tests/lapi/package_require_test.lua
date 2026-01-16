--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.3 – Modules
https://www.lua.org/manual/5.1/manual.html#5.3

PIL: 15 – Packages
https://www.lua.org/pil/15.html

Synopsis: require(modname)
]]

local luzer = require("luzer")
local test_lib = require("lib")

local MAX_STR_LEN = test_lib.MAX_STR_LEN
local MAX_PATH_NUM = 10

local function build_path(fdp)
    local count = fdp:consume_integer(0, MAX_PATH_NUM)
    local paths = fdp:consume_strings(MAX_STR_LEN, count)
    local path_str = table.concat(paths, ";")
    local enable_def_path = fdp:consume_boolean()
    return enable_def_path and path_str or path_str .. ";;"
end

local function TestOneInput(buf)
    -- Save paths used by `require` to search for a Lua loader.
    local old_path = package.path
    local old_cpath = package.cpath

    local fdp = luzer.FuzzedDataProvider(buf)
    local path = build_path(fdp)
    package.path = path
    local cpath = build_path(fdp)
    package.cpath = cpath

    local module_name = fdp:consume_string(MAX_STR_LEN)
    -- If there is any error loading or running the module, or if
    -- it cannot find any loader for the module, then require
    -- signals an error,
    -- https://www.lua.org/manual/5.1/manual.html#pdf-require.
    pcall(require, module_name)

    -- Teardown.
    package.path = old_path
    package.cpath = old_cpath
end

local args = {
    artifact_prefix = "package_require_",
}
luzer.Fuzz(TestOneInput, nil, args)
