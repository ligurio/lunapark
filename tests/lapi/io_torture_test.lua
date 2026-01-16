--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

5.7 – Input and Output Facilities
https://www.lua.org/manual/5.1/manual.html#5.7
https://www.lua.org/pil/21.3.html

Synopsis:

io.close([file])
io.flush()
io.open(filename [, mode])
io.read(...)
io.tmpfile()
io.write(...)
file:seek([whence] [, offset])
file:setvbuf(mode [, size])
]]

local luzer = require("luzer")
local test_lib = require("lib")

-- The maximum file size is 1Mb (1000 * 1000).
local MAX_N = 1e3

local unpack = unpack or table.unpack

local function io_seek(self)
    local SEEK_MODE = {
        "set", -- Base is position 0 (beginning of the file).
        "cur", -- Base is current position.
        "end", -- Base is end of file.
    }
    local mode = self.fdp:oneof(SEEK_MODE)
    local offset = self.fdp:consume_integer(0, self.MAX_N)
    self.fh:seek(mode, offset)
end

local function io_flush(self)
    self.fh:flush()
end

local function io_setvbuf(self)
    local VBUF_MODE = {
        "no",   -- No buffering.
        "full", -- Full buffering.
        "line", -- Line buffering.
    }
    local mode = self.fdp:oneof(VBUF_MODE)
    local size = self.fdp:consume_integer(0, self.MAX_N)
    self.fh:setvbuf(mode, size)
end

local function io_write(self)
    local str = self.fdp:consume_string(self.MAX_N)
    self.fh:write(str)
end

local READ_FORMAT = {
    "*n", -- Reads a number.
    "*a", -- Reads the whole file, starting at the current
          -- position.
    "*l", -- Reads the next line (skipping the end of line),
          -- returning nil on end of file.
}
if test_lib.lua_current_version_ge_than(5, 2) or
   test_lib.lua_version() == "LuaJIT" then
    -- "*L" reads the next line keeping the end of line
    -- (if present), returning nil on end of file.
    table.insert(READ_FORMAT, "*L")
end

local function io_read(self)
    local n_formats = self.fdp:consume_integer(1, self.MAX_N)
    -- Build a table with formats, which specify what to read. For
    -- each format, the function returns a string (or a number)
    -- with the characters read, or `nil` if it cannot read data
    -- with the specified format. When called without formats, it
    -- uses a default format that reads the entire next line.
    local read_formats = {}
    for _ = 1, n_formats do
        local format_is_size = self.fdp:consume_boolean()
        if format_is_size then
            -- As a special case, `io.read(0)` works as a test for
            -- end of file: It returns an empty string if there is
            -- more to be read or `nil` otherwise.
            local size = self.fdp:consume_integer(0, test_lib.MAX_INT64)
            table.insert(read_formats, size)
        else
            local format = self.fdp:oneof(READ_FORMAT)
            table.insert(read_formats, format)
        end
    end
    local _ = self.fh:read(unpack(read_formats))
end

local function io_close(self)
    self.fh:close()
end

local io_methods = {
    io_flush,
    io_read,
    io_seek,
    io_setvbuf,
    io_write,
}

local function io_random_op(self)
    local io_method = self.fdp:oneof(io_methods)
    io_method(self)
end

local function io_new(fdp)
    local fh = io.tmpfile()
    return {
        close = io_close,
        fdp = fdp,
        fh = fh,
        random_operation = io_random_op,
        MAX_N = MAX_N,
    }
end

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    local nops = fdp:consume_integer(1, MAX_N)
    local fh = io_new(fdp)
    for _ = 1, nops do
        fh:random_operation()
    end
    fh:close()
end

local args = {
    artifact_prefix = "io_torture_",
}
luzer.Fuzz(TestOneInput, nil, args)
