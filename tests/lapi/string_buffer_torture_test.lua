--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

String Buffer Library,
https://luajit.org/ext_buffer.html

Recording of buffer:set can anchor wrong object,
https://github.com/LuaJIT/LuaJIT/issues/1125

String buffer methods may be called one extra time after loop,
https://github.com/LuaJIT/LuaJIT/issues/755

Traceexit in recff_buffer_method_put and recff_buffer_method_get
might redo work, https://github.com/LuaJIT/LuaJIT/issues/798

Invalid bufput_bufstr fold over lj_serialize_encode,
https://github.com/LuaJIT/LuaJIT/issues/799

COW buffer might not copy,
https://github.com/LuaJIT/LuaJIT/issues/816

String buffer API,
https://github.com/LuaJIT/LuaJIT/issues/14

Add missing GC steps to string buffer methods,
https://github.com/LuaJIT/LuaJIT/commit/9c3df68a
]]

local luzer = require("luzer")
local test_lib = require("lib")

-- LuaJIT only.
if test_lib.lua_version() ~= "LuaJIT" then
    print("Unsupported version.")
    os.exit(0)
end

local ffi = require("ffi")
local has_string_buf, string_buf = pcall(require, "string.buffer")
if not has_string_buf then
    print("Unsupported version.")
    os.exit(0)
end
local unpack = unpack or table.unpack

local MAX_N = 1e2

local function random_objects(self)
    local obj_type = self.fdp:oneof({
        "number",
        "string",
    })
    -- `count` must be less than UINT_MAX and there are at least
    -- extra free stack slots in the stack, otherwise an error
    -- "too many results to unpack" is raised, see <ltablib.c>.
    local count = self.fdp:consume_integer(1, 1024)
    local objects
    if obj_type == "string" then
        objects = self.fdp:consume_strings(self.MAX_N, count)
    elseif obj_type == "number" then
        objects = self.fdp:consume_numbers(
            test_lib.MIN_INT64, test_lib.MAX_INT64, count)
    else
        assert(nil, "object type is unsupported")
    end

    return objects
end

-- Reset (empty) the buffer. The allocated buffer space is not
-- freed and may be reused.
-- Usage: buf = buf:reset()
local function buffer_reset(self)
    self.buf:reset()
end

-- Appends the formatted arguments to the buffer. The format
-- string supports the same options as `string.format()`.
-- Usage: buf = buf:putf(format, ...)
local function buffer_putf(self)
    local str = self.fdp:consume_string(self.MAX_N)
    self.buf:putf("%s", str)
end

-- Appends the given `len` number of bytes from the memory pointed
-- to by the FFI cdata object to the buffer. The object needs to
-- be convertible to a (constant) pointer.
-- Usage: buf = buf:putcdata(cdata, len)
local function buffer_putcdata(self)
    local n = self.fdp:consume_integer(1, 255)
    local cdata = ffi.new("uint8_t[?]", 1, n)
    self.buf:putcdata(cdata, ffi.sizeof(cdata))
end

-- This method allows zero-copy consumption of a string or an FFI
-- cdata object as a buffer. It stores a reference to the passed
-- string `str` or the FFI cdata object in the buffer. Any buffer
-- space originally allocated is freed. This is not an append
-- operation, unlike the buf:put*() methods.
local function buffer_set(self)
    local str = self.fdp:consume_string(self.MAX_N)
    self.buf:set(str)
end

-- Appends a string str, a number num or any object obj with
-- a `__tostring` metamethod to the buffer. Multiple arguments are
-- appended in the given order. Appending a buffer to a buffer is
-- possible and short-circuited internally. But it still involves
-- a copy. Better combine the buffer writes to use a single buffer.
-- Usage: buf = buf:put([str | num | obj] [, ...])
local function buffer_put(self)
    local objects = self:random_objects()
    local buf = self.buf:put(unpack(objects))
    assert(type(buf) == "userdata")
end

-- Consumes the buffer data and returns one or more strings. If
-- called without arguments, the whole buffer data is consumed.
-- If called with a number, up to len bytes are consumed. A `nil`
-- argument consumes the remaining buffer space (this only makes
-- sense as the last argument). Multiple arguments consume the
-- buffer data in the given order.
-- Note: a zero length or no remaining buffer data returns an
-- empty string and not nil.
-- Usage: str, ... = buf:get([ len|nil ] [,...])
local function buffer_get(self)
    local len = self.fdp:consume_integer(0, self.MAX_N)
    local str = self.buf:get(len)
    assert(type(str) == "string")
end

local function buffer_tostring(self)
    local str = self.buf:tostring()
    assert(type(str) == "string")
end

-- The commit method appends the `used` bytes of the previously
-- returned write space to the buffer data.
-- Usage: buf = buf:commit(used)
local function buffer_commit(self)
    local used = self.fdp:consume_integer(0, self.MAX_N)
    -- The function may throw an error "number out of range".
    local _, _ = pcall(self.buf.commit, self.buf, used)
end

-- The reserve method reserves at least `size` bytes of write
-- space in the buffer. It returns an `uint8_t *` FFI cdata
-- pointer `ptr` that points to this space. The space returned by
-- `buf:reserve()` starts at the returned pointer and ends before
-- len bytes after that.
-- Usage: ptr, len = buf:reserve(size)
local function buffer_reserve(self)
    local size = self.fdp:consume_integer(0, self.MAX_N)
    local ptr, len = self.buf:reserve(size)
    assert(type(ptr) == "cdata")
    assert(ffi.typeof(ptr) == ffi.typeof("uint8_t *"))
    assert(type(len) == "number")
end

-- Skips (consumes) `len` bytes from the buffer up to the current
-- length of the buffer data.
-- Usage: buf = buf:skip(len)
local function buffer_skip(self)
    local len = self.fdp:consume_integer(0, self.MAX_N)
    local buf = self.buf:skip(len)
    assert(type(buf) == "userdata")
end

-- Returns an uint8_t * FFI cdata pointer ptr that points to the
-- buffer data. The length of the buffer data in bytes is returned
-- in `len`. The space returned by `buf:ref()` starts at the
-- returned pointer and ends before len bytes after that.
-- Synopsis: ptr, len = buf:ref()
local function buffer_ref(self)
    local ptr, len = self.buf:ref()
    assert(type(ptr) == "cdata")
    assert(ffi.typeof(ptr) == ffi.typeof("uint8_t *"))
    assert(type(len) == "number")
end

-- Returns the current length of the buffer data in bytes.
local function buffer_len(self)
    return #self.buf
end

-- The Lua concatenation operator `..` also accepts buffers, just
-- like strings or numbers. It always returns a string and not
-- a buffer.
local function buffer_concat(self)
    local str = self.fdp:consume_string(1, self.MAX_N)
    local buf = self.buf .. str
    assert(type(buf) == "string")
end

-- Serializes (encodes) the Lua object `obj`. The stand-alone
-- function returns a string `str`. The buffer method appends the
-- encoding to the buffer. `obj` can be any of the supported Lua
-- types - it doesn't need to be a Lua table.
-- This function may throw an error when attempting to serialize
-- unsupported object types, circular references or deeply nested
-- tables.
-- Usage:
--   str = buffer.encode(obj)
--   buf = buf:encode(obj)
local function buffer_encode(self)
    local objects = self:random_objects()
    local ptr = self.buf:encode(objects)
    assert(type(ptr) == "userdata")
end

-- The stand-alone function deserializes (decodes) the string
-- `str`, the buffer method deserializes one object from the
-- buffer. Both return a Lua object `obj`.
-- The returned object may be any of the supported Lua types -
-- even `nil`. This function may throw an error when fed with
-- malformed or incomplete encoded data. The stand-alone function
-- throws when there's left-over data after decoding a single
-- top-level object. The buffer method leaves any left-over data
-- in the buffer.
-- Usage:
--   obj = buffer.decode(str)
--   obj = buf:decode()
local function buffer_decode(self)
    local str = self.fdp:consume_string(0, self.MAX_N)
    -- The function may throw an error "unexpected end of buffer".
    local _, _ = pcall(self.buf.decode, self.buf, str)
end

-- The buffer space of the buffer object is freed. The object
-- itself remains intact, empty and may be reused.
local function buffer_free(self)
    self.buf:free()
    assert(#self.buf == 0)
end

local buffer_methods = {
    buffer_commit,
    buffer_concat,
    buffer_decode,
    buffer_encode,
    buffer_get,
    buffer_len,
    buffer_put,
    buffer_putcdata,
    buffer_putf,
    buffer_ref,
    buffer_reserve,
    buffer_reset,
    buffer_set,
    buffer_skip,
    buffer_tostring,
}

local function buffer_random_op(self)
    local buffer_method = self.fdp:oneof(buffer_methods)
    buffer_method(self)
end

local function buffer_new(fdp)
    local buf_size = fdp:consume_integer(1, MAX_N)
    local b = string_buf.new(buf_size)
    return {
        buf = b,
        fdp = fdp,
        free = buffer_free,
        random_objects = random_objects,
        random_operation = buffer_random_op,
        MAX_N = MAX_N,
    }
end

local function TestOneInput(buf, _size)
    local fdp = luzer.FuzzedDataProvider(buf)
    local nops = fdp:consume_number(1, MAX_N)
    local b = buffer_new(fdp)
    for _ = 1, nops do
        b:random_operation()
    end
    b:free()
end

local args = {
    artifact_prefix = "string_buffer_torture_",
}
luzer.Fuzz(TestOneInput, nil, args)
