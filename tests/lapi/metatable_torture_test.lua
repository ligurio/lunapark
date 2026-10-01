--[[
SPDX-License-Identifier: ISC
Copyright (c) 2026, Sergey Bronnikov.

Metatables and Metamethods,
https://www.lua.org/manual/5.4/manual.html#2.4

The test is inspired by the two-phase approach of the
semantic-aware grammar fuzzer OverrideFuzz [1], and its
observation that Lua benefits most from its pervasive metamethod
dispatch. The declaration phase constructs tables with metatables,
the execution phase routes operations (index, newindex, call,
arithmetic, concatenation, comparison, length, iteration,
tostring, garbage collection) through the metamethod dispatch.

1. https://github.com/Nambers/OverrideFuzz

Known bugs regressed by this test:

- Write barrier not properly executed in some updates through
  `__newindex`, https://www.lua.org/bugs.html#5.5.0-8
- New metatable in an all-weak table can fool the GC,
  https://www.lua.org/bugs.html#5.4.8-1
- An emergency GC can collect the `__newindex` of a metatable
  (if the metatable is a weak table) while that field is being used
  in a table update, https://www.lua.org/bugs.html#5.4.7-5
- Tricky _PROMPT may trigger an undefined behavior (`__tostring`),
  https://www.lua.org/bugs.html#5.4.6-9
- Yielding in a `__close` metamethod called when returning vararg
  results mess up the returned values,
  https://www.lua.org/bugs.html#5.4.3-3
- Finalizers should not be able to invoke the GC,
  https://www.lua.org/bugs.html#5.4.3-10
- Finalizers can be called with an invalid stack,
  https://www.lua.org/bugs.html#5.4.3-11
- Old finalized object may not be visited by GC,
  https://www.lua.org/bugs.html#5.4.0-1
- Errors in finalizers need a valid 'pc' to produce an error message,
  https://www.lua.org/bugs.html#5.4.0-6
- Suspended `__le` metamethod can give wrong result,
  https://www.lua.org/bugs.html#5.3.0-3
- luaV_settable may invalidate a reference to a table and try to
  reuse it, https://www.lua.org/bugs.html#5.1.4-4
- State not restored during recording if `__concat` metamethod
  throws an error, https://github.com/LuaJIT/LuaJIT/issues/1234.
- State is not restored during recording `__concat` metamethod in
  case of the OOM, https://github.com/LuaJIT/LuaJIT/issues/1298.
- Recording of `__concat` in GC64 mode,
  https://github.com/LuaJIT/LuaJIT/issues/839.
- pcall as metamethod can overflow stack,
  https://github.com/LuaJIT/LuaJIT/issues/1048.
]]

local luzer = require("luzer")
local test_lib = require("lib")

local IS_LUAJIT = test_lib.lua_version() == "LuaJIT"
local GE_5_2 = test_lib.lua_current_version_ge_than(5, 2)
local GE_5_3 = test_lib.lua_current_version_ge_than(5, 3)
local GE_5_4 = test_lib.lua_current_version_ge_than(5, 4)

-- LuaJIT (a Lua 5.1 dialect) implements the `__len`, `__gc` and
-- `__le` metamethods for tables.
local HAS_52_EXT = GE_5_2 or IS_LUAJIT
-- The `__pairs`/`__ipairs` metamethods, the floor division and
-- bitwise operators are available in Lua 5.3+ only.
local HAS_53_MM = GE_5_3 and not IS_LUAJIT
-- To-be-closed variables and the `__close` metamethod are available
-- in Lua 5.4+ only.
local HAS_54_MM = GE_5_4

-- PRIMITIVES feeds `random_operand()` when it deliberately
-- mismatches operand types to force the dispatch through
-- error/fallback paths. METAVALUES supplies the values
-- metamethods may legally return. KEYS are the keys used for
-- (raw) indexing and table updates.
local PRIMITIVES = {
    true, false, 0, 1, -1, 0.5, math.huge, "str", function() end,
}
local METAVALUES = { 0, 1, -1, 3.14, math.huge, "meta", "" }
local KEYS = { 1, 2, 0, -1, 100, "x", "y", "k", "length", "a", "b" }

-- The set of arithmetic and bitwise metamethods. make_metamethod
-- treats them uniformly (see the `__call`/ARITH_MM branch), while
-- new_state gates which of them are actually offered per version.
local ARITH_MM = {
    __add = true,
    __band = true,
    __bnot = true,
    __bor = true,
    __bxor = true,
    __div = true,
    __idiv = true,
    __mod = true,
    __mul = true,
    __pow = true,
    __shl = true,
    __shr = true,
    __sub = true,
    __unm = true,
}

-- The operators are compiled dynamically because their syntax
-- (`//`, `&`, `|`, `~`, `<<`, `>>`) does not exist in Lua versions
-- older than 5.3, so they cannot appear literally in the source.
local function compile_binop(op)
    local chunk = load(("return function(a, b) return a %s b end"):format(op))
    return assert(chunk)()
end

local function compile_unop(op)
    local chunk = load(("return function(a) return %s a end"):format(op))
    return assert(chunk)()
end

-- Picks a random operand from the pool of tables built so far, so
-- operations chain across previously created objects.
local function random_object(self)
    return self.fdp:oneof(self.objects)
end

local function random_operand(self)
    -- Deliberately mismatch types (OverrideFuzz's "respect type"
    -- heuristic) to force the dispatch through error/fallback paths.
    if self.fdp:consume_probability() < self.mismatch_prob then
        return self.fdp:oneof(PRIMITIVES)
    end
    return random_object(self)
end

local function random_key(self)
    return self.fdp:oneof(KEYS)
end

-- Produces an operation that declares a random object as a
-- to-be-closed variable, so `__close` runs when the scope exits.
local function make_op_close()
    -- The `<close>` attribute is a Lua 5.4 syntax extension.
    local chunk = "return function(obj) local t <close> = obj end"
    local close = assert(load(chunk))()
    return function(self)
        local obj = random_object(self)
        pcall(close, obj)
    end
end

-- Generates a random implementation of a named metamethod. The
-- variants are chosen to exercise distinct dispatch results:
-- returning a pooled object (forwarding access), returning a
-- constant/derived value, writing back into `side` instead of the
-- target table, or raising an error. `__gc` and `__close` only
-- record that they ran by bumping counters in `self.side`.
local function make_metamethod(self, name)
    local fdp = self.fdp
    local objects = self.objects
    local side = self.side

    -- An object may proxy to any of the tables built earlier, so a
    -- chain of `__index` lookups can span several objects.
    local function pool_object()
        if #objects > 0 then
            return objects[fdp:consume_integer(1, #objects)]
        end
        return nil
    end

    if name == "__index" then
        -- A table or a function is allowed; function kinds below
        -- return a pooled object, the requested key itself, the
        -- result of a proxied lookup, nil, or raise an error.
        local kind = fdp:consume_integer(1, 5)
        if kind == 1 then
            local v = pool_object()
            return function() return v end
        elseif kind == 2 then
            return function(_, k) return k end
        elseif kind == 3 then
            local proxy = pool_object()
            return function(_, k) return proxy[k] end
        elseif kind == 4 then
            return function() return nil end
        else
            return function() error("__index error") end
        end
    elseif name == "__newindex" then
        -- Writing into `side` (kind 1) decouples the stored value
        -- from the target table, whereas kind 2 writes back into
        -- the target table itself through a rawset.
        local kind = fdp:consume_integer(1, 4)
        if kind == 1 then
            return function(_, k, v) rawset(side, k, v) end
        elseif kind == 2 then
            return function(t, k, v) rawset(t, k, v) end
        elseif kind == 3 then
            return function() end
        else
            return function() error("__newindex error") end
        end
    elseif name == "__call" or ARITH_MM[name] or name == "__concat" then
        -- Result-producing metamethods may return any type, so the
        -- caller only verifies that the operation does not crash.
        local kind = fdp:consume_integer(1, 4)
        if kind == 1 then
            local v = pool_object()
            return function() return v end
        elseif kind == 2 then
            return function() return fdp:oneof(METAVALUES) end
        elseif kind == 3 then
            return function() return tostring(fdp:consume_boolean()) end
        else
            return function() error(name .. " error") end
        end
    elseif name == "__len" then
        -- The `#` operator requires a number back, which op_len asserts.
        local n = fdp:consume_integer(0, 10)
        return function() return n end
    elseif name == "__eq" or name == "__lt" or name == "__le" then
        -- Any result of a comparison metamethod is converted to a
        -- boolean (nil counts as false); op_cmp/op_cmp_le assert
        -- that a successful comparison yields a boolean.
        local kind = fdp:consume_integer(1, 3)
        if kind == 1 then
            return function() return fdp:consume_boolean() end
        elseif kind == 2 then
            return function() return nil end
        else
            return function() error(name .. " error") end
        end
    elseif name == "__tostring" then
        -- `tostring` requires a string back; assert in
        -- `op_tostring()`.
        local kind = fdp:consume_integer(1, 3)
        if kind == 1 then
            return function() return "meta" end
        elseif kind == 2 then
            local v = pool_object()
            return function() return tostring(v) end
        else
            return function() error("__tostring error") end
        end
    elseif name == "__pairs" then
        -- Lua 5.3 `pairs` calls `__pairs` which must return a
        -- custom iterator function, the state, and the initial
        -- control value.
        local kind = fdp:consume_integer(1, 2)
        if kind == 1 then
            return function(t) return next, t, nil end
        else
            return function() error("__pairs error") end
        end
    elseif name == "__ipairs" then
        -- Lua 5.3 `ipairs` calls `__ipairs`, which must return
        -- the same three values as a generic-for iterator.
        local kind = fdp:consume_integer(1, 2)
        if kind == 1 then
            return function(t)
                return function(t2, i)
                    i = i + 1
                    local v = t2[i]
                    if v ~= nil then
                        return i, v
                    end
                end, t, 0
            end
        else
            return function() error("__ipairs error") end
        end
    elseif name == "__gc" then
        -- A finalizer may only record its run, never touch the
        -- target.
        return function() side.gc_count = (side.gc_count or 0) + 1 end
    elseif name == "__close" then
        if fdp:consume_boolean() then
            return function()
                side.close_count = (side.close_count or 0) + 1
            end
        else
            return function() error("__close error") end
        end
    end
end

-- Builds one more table with a fully random metatable and appends
-- it to the object pool: optionally weak (`__mode`), optionally
-- protected (`__metatable`), with a random subset of the
-- candidate metamethods filled in. A metatable without
-- metamethods is valid too.
local function build_object(self)
    local objects = self.objects
    local fdp = self.fdp
    local mt = {}
    if fdp:consume_boolean() then
        mt.__mode = fdp:oneof({ "k", "v", "kv" })
    end
    if fdp:consume_boolean() then
        mt.__metatable = fdp:oneof({ "protected", { protected = true } })
    end
    for _, name in ipairs(self.mm_candidates) do
        if fdp:consume_boolean() then
            mt[name] = make_metamethod(self, name)
        end
    end
    table.insert(objects, setmetatable({}, mt))
end

-- The operation below runs one random read/write/other statement
-- against a random object inside pcall. Every statement routes
-- through one or more metamethods (e.g. `obj[key]` through
-- `__index`), and a failure inside a metamethod must surface as a
-- plain Lua error rather than corrupting the VM state.

-- Table read, dispatches to `__index`.
local function op_index(self)
    local obj = random_object(self)
    local key = random_key(self)
    pcall(function() return obj[key] end)
end

-- Chained read and call, dispatches to `__index` and then `__call`.
local function op_index_call(self)
    local obj = random_object(self)
    local key = random_key(self)
    pcall(function() return obj[key]() end)
end

-- Table update, dispatches to `__newindex`.
local function op_newindex(self)
    local obj = random_object(self)
    local key = random_key(self)
    local v = random_operand(self)
    pcall(function() obj[key] = v end)
end

-- Table call, dispatches to `__call`.
local function op_call(self)
    local obj = random_object(self)
    local a = random_operand(self)
    local b = random_operand(self)
    pcall(function() return obj(a, b) end)
end

-- Binary arithmetic/bitwise operation, dispatches to the matching
-- arithmetic metamethod on either operand.
local function op_arith(self)
    local op = self.fdp:oneof(self.arith_ops)
    local a = random_operand(self)
    local b = random_operand(self)
    pcall(function() return op(a, b) end)
end

-- Unary minus dispatches to `__unm`, and the Lua 5.3+ bitwise
-- `~` to `__bnot`; `not` is included for good measure but has no
-- metamethod and always yields a boolean.
local function op_unm(self)
    local op = self.fdp:oneof(self.unary_ops)
    local a = random_operand(self)
    pcall(function() return op(a) end)
end

-- Concatenation, dispatches to `__concat`.
local function op_concat(self)
    local a = random_operand(self)
    local b = random_operand(self)
    -- A `__concat` metamethod may legally return a value of any
    -- type, so only the absence of a crash is checked.
    pcall(function() return a .. b end)
end

-- Length operator, dispatches to `__len`; a result must be a
-- number.
local function op_len(self)
    local obj = random_object(self)
    local ok, res = pcall(function() return #obj end)
    if ok then
        assert(type(res) == "number")
    end
end

-- Equality and less-than comparisons, dispatch to `__eq`/`__lt`;
-- a successful result must be a boolean.
local function op_cmp(self)
    local op = self.fdp:oneof({ "==", "<" })
    local a = random_operand(self)
    local b = random_operand(self)
    local ok, res = pcall(function()
        if op == "==" then
            return a == b
        else
            return a < b
        end
    end)
    if ok then
        assert(type(res) == "boolean")
    end
end

-- Less-or-equal comparison, dispatches to `__le`; a successful
-- result must be a boolean.
local function op_cmp_le(self)
    local a = random_operand(self)
    local b = random_operand(self)
    local ok, res = pcall(function() return a <= b end)
    if ok then
        assert(type(res) == "boolean")
    end
end

-- Iteration with `pairs`, dispatches to `__pairs` (Lua 5.3) or
-- falls back to `next` in Lua 5.4+.
local function op_pairs(self)
    local obj = random_object(self)
    -- In Lua 5.4+ `pairs` iterates a table with `next`, which is
    -- bounded by the number of entries. The `__pairs` metamethod
    -- (Lua 5.3) may return a custom iterator, so the loop is
    -- bounded defensively to avoid a hang.
    pcall(function()
        local n = 0
        for _ in pairs(obj) do
            n = n + 1
            if n > 1000 then
                break
            end
        end
    end)
end

-- Iteration with `ipairs`, dispatches to `__ipairs` (Lua 5.3) or
-- reads through `__index` in Lua 5.4+.
local function op_ipairs(self)
    local obj = random_object(self)
    -- In Lua 5.4+ `ipairs` reads elements through `__index`. A table
    -- whose `__index` metamethod always returns a value makes the
    -- iterator run forever, so the loop must be bounded.
    pcall(function()
        local n = 0
        for _ in ipairs(obj) do
            n = n + 1
            if n > 1000 then
                break
            end
        end
    end)
end

-- Raw traversal with `next`: unlike `pairs`, it never consults
-- metatables, exercising the underlying table state directly.
local function op_next(self)
    local obj = random_object(self)
    pcall(function()
        local k = next(obj)
        if k ~= nil then
            next(obj, k)
        end
    end)
end

-- String conversion, dispatches to `__tostring`; a successful
-- result must be a string.
local function op_tostring(self)
    local obj = random_object(self)
    local ok, res = pcall(function() return tostring(obj) end)
    if ok then
        assert(type(res) == "string")
    end
end

-- Reading the metatable honors the `__metatable` protection field,
-- which may shadow the real metatable with an arbitrary value.
local function op_getmetatable(self)
    local obj = random_object(self)
    local res = getmetatable(obj)
    assert(res == nil or type(res) == "table" or type(res) == "string")
end

-- Replacing the metatable with a fresh one changes all subsequent
-- metamethod dispatch on the object.
local function op_setmetatable(self)
    local obj = random_object(self)
    local mt = self.fdp:oneof(self.alt_mts)
    pcall(function() setmetatable(obj, mt) end)
end

-- `rawget` bypasses `__index` entirely.
local function op_rawget(self)
    local obj = random_object(self)
    local key = random_key(self)
    pcall(function() return rawget(obj, key) end)
end

-- `rawset` bypasses `__newindex` entirely.
local function op_rawset(self)
    local obj = random_object(self)
    local key = random_key(self)
    local v = random_operand(self)
    pcall(function() rawset(obj, key, v) end)
end

-- Triggers collection interleaved with the other operations to
-- stress finalizers (`__gc`) and the write barrier at arbitrary
-- points of the dispatch.
local function op_gc(self)
    pcall(function()
        if self.fdp:consume_boolean() then
            collectgarbage("collect")
        else
            collectgarbage("step")
        end
    end)
end

-- Builds the whole fuzzing state out of the input bytes: the shared
-- object pool (`objects`) and side-effect sink (`side`), the pool of
-- ready-made alternative metatables (`alt_mts`), the version-gated
-- list of metamethods a metatable may receive (`mm_candidates`), the
-- operator tables (`arith_ops`/`unary_ops`), and finally the flat
-- list of operations (`ops`) executed by TestOneInput.
local function new_state(fdp)
    local self = {
        fdp = fdp,
        objects = {},
        side = {},
        mismatch_prob = 0.2,
        n_objects = fdp:consume_integer(1, 6),
        nops = fdp:consume_integer(1, 100),
        -- Replacing the metatable of an object is as interesting as
        -- building a new one, so op_setmetatable picks from these.
        alt_mts = {
            {},
            { __index = function() return "alt" end },
            { __newindex = function() end },
        },
    }
    -- A weak metatable is occasionally offered as an alternative: it
    -- lets the GC reclaim live fields, which regressed in bug 5.4.8-1.
    if fdp:consume_boolean() then
        table.insert(self.alt_mts, { __mode = "v" })
    end

    -- The base set is available in every supported Lua version;
    -- the following blocks extend it with the metamethods introduced
    -- in later versions.
    local mm = {
        "__add",
        "__call",
        "__concat",
        "__div",
        "__eq",
        "__index",
        "__lt",
        "__mod",
        "__mul",
        "__newindex",
        "__pow",
        "__sub",
        "__tostring",
        "__unm",
    }
    if HAS_52_EXT then
        table.insert(mm, "__len")
        table.insert(mm, "__gc")
        table.insert(mm, "__le")
    end
    if HAS_53_MM then
        table.insert(mm, "__idiv")
        table.insert(mm, "__pairs")
        table.insert(mm, "__ipairs")
        table.insert(mm, "__band")
        table.insert(mm, "__bor")
        table.insert(mm, "__bxor")
        table.insert(mm, "__bnot")
        table.insert(mm, "__shl")
        table.insert(mm, "__shr")
    end
    if HAS_54_MM then
        table.insert(mm, "__close")
    end
    self.mm_candidates = mm

    -- The base operators exist in every supported Lua version; the
    -- Lua 5.3+ bitwise and floor-division operators are compiled on
    -- the fly rather than written literally in the source.
    local arith_ops = {
        function(a, b) return a + b end,
        function(a, b) return a - b end,
        function(a, b) return a * b end,
        function(a, b) return a / b end,
        function(a, b) return a % b end,
        function(a, b) return a ^ b end,
    }
    if HAS_53_MM then
        for _, op in ipairs({ "//", "&", "|", "~", "<<", ">>" }) do
            table.insert(arith_ops, compile_binop(op))
        end
    end
    self.arith_ops = arith_ops

    local unary_ops = {
        function(a) return -a end,
        function(a) return not a end,
    }
    if HAS_53_MM then
        table.insert(unary_ops, compile_unop("~"))
    end
    self.unary_ops = unary_ops

    -- Every op runs against random objects and catches its own
    -- errors, so the driver may pick and execute them in any order.
    local ops = {
        op_arith,
        op_call,
        op_cmp,
        op_concat,
        op_gc,
        op_getmetatable,
        op_index,
        op_index_call,
        op_ipairs,
        op_newindex,
        op_next,
        op_pairs,
        op_rawget,
        op_rawset,
        op_setmetatable,
        op_tostring,
        op_unm,
    }
    if HAS_52_EXT then
        table.insert(ops, op_len)
        table.insert(ops, op_cmp_le)
    end
    if HAS_54_MM then
        table.insert(ops, make_op_close())
    end
    self.ops = ops
    return self
end

-- The fuzz driver follows the two-phase scheme described in the
-- header: first build a random set of tables with metatables,
-- then execute a random sequence of operations over them. A final
-- full collection flushes the finalizers (`__gc`) of the objects
-- created during the run.
local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    local self = new_state(fdp)
    for _ = 1, self.n_objects do
        build_object(self)
    end
    for _ = 1, self.nops do
        local op = fdp:oneof(self.ops)
        op(self)
    end
    collectgarbage("collect")
end

local args = {
    artifact_prefix = "metatable_torture_",
}
luzer.Fuzz(TestOneInput, nil, args)
