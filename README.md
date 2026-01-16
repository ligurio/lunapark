<table>
  <tr>
    <th>PUC Rio Lua</th>
    <td><a href="https://bugs.chromium.org/p/oss-fuzz/issues/list?sort=-opened&can=1&q=proj:lua"><img src="https://oss-fuzz-build-logs.storage.googleapis.com/badges/lua.svg"></a></td>
    <td><a href="https://github.com/ispras/oss-sydr-fuzz/tree/master/projects/lua"><img src="https://img.shields.io/static/v1?label=oss-sydr-fuzz&message=fuzzing&color=brightgreen"></a></td>
  </tr>
  <tr>
    <th>LuaJIT</th>
    <td></td>
    <td><a href="https://github.com/ispras/oss-sydr-fuzz/tree/master/projects/luajit"><img src="https://img.shields.io/static/v1?label=oss-sydr-fuzz&message=fuzzing&color=brightgreen"></a></td>
  </tr>
  <tr>
    <th>Tarantool</th>
    <td><a href="https://bugs.chromium.org/p/oss-fuzz/issues/list?sort=-opened&can=1&q=proj:tarantool"><img src="https://oss-fuzz-build-logs.storage.googleapis.com/badges/tarantool.svg"></a></td>
    <td><a href="https://github.com/ispras/oss-sydr-fuzz/tree/master/projects/tarantool"><img src="https://img.shields.io/static/v1?label=oss-sydr-fuzz&message=fuzzing&color=brightgreen"></a></td>
  </tr>
 </tr>
</table>

# lunapark

is a set of fuzzing tests for C implementations of Lua runtime (PUC Rio Lua and
LuaJIT).

<details>
<summary>If you are interested to know why it is called Lunapark</summary>
Originally, "lunapark," or more accurately "Luna Park," is a name
shared by dozens of currently operating and defunct amusement
parks. Usually, Luna Parks are small-scale attraction parks.
Fuzzing and debugging Lua runtimes (especially LuaJIT) is also,
in a sense, an attraction and unforgettable adventure.
Furthermore, the first word ("luna") in Russian means "moon," the
only natural satellite of Earth, and the programming language Lua
(pronounced LOO-ah) also means "moon" in Portuguese. That's why
the project was named "lunapark".
</details>

### Building

```sh
git clone https://github.com/ligurio/lunapark
cd lunapark
git clone https://github.com/ligurio/lunapark-corpus
CC=clang CXX=clang++ cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug -DUSE_LUA=ON [-DUSE_LUAJIT=ON]
cmake --build build --parallel
```

CMake options:

- `USE_LUA` enables building PUC Rio Lua.
- `USE_LUAJIT` enables building LuaJIT.
- `LUA_VERSION` could be a Git branch, tag or commit. By default `LUA_VERSION` is
`master` for PUC Rio Lua and `v2.1` for LuaJIT.
- `ENABLE_LUAJIT_RANDOM_RA` enables randomness in a register allocation. Option
is LuaJIT-specific.
- `ENABLE_ASAN` enables AddressSanitizer.
- `ENABLE_UBSAN` enables UndefinedBehaviorSanitizer.
- `ENABLE_COV` enables coverage instrumentation.
- `ENABLE_LUA_ASSERT` enables all assertions inside Lua source code.
- `ENABLE_LUA_APICHECK` enables consistency checks on the C API.
- `OSS_FUZZ` enables support of OSS Fuzz.
- `ENABLE_BUILD_PROTOBUF` enables building Protobuf library, otherwise system
  library is used.
- `ENABLE_INTERNAL_TESTS` enables internal tests.
- `ENABLE_LAPI_TESTS` enables Lua API tests.

### Running

```sh
cmake --build build --target test
cd build && RUNS=100000 ctest -R luaL_gsub_test --verbose
<snipped>
1: Done 100000 runs in 5 second(s)
```

### References

- [Lua 5.5 Reference Manual: 4 – The Application Program Interface](https://www.lua.org/manual/5.5/manual.html#4)
- [Lua 5.4 Reference Manual: 4 – The Application Program Interface](https://www.lua.org/manual/5.4/manual.html#4)
- [Lua 5.3 Reference Manual: 4 – The Application Program Interface](https://www.lua.org/manual/5.3/manual.html#4)
- [Lua 5.2 Reference Manual: 4 – The Application Program Interface](https://www.lua.org/manual/5.2/manual.html#4)
- [Lua 5.1 Reference Manual: 3 – The Application Program Interface](https://www.lua.org/manual/5.1/manual.html#3)

### Known Issues

Fuzzing can find a wide variety of problems, but not all problems
are considered bugs. Some problems are due to known limitations in
the implementation. This section contains a list of such
limitations in LuaJIT and PUC Rio Lua:

1. In LuaJIT, the build infrastructure includes a source code that
   contains memory leaks and other problems. For example,
   `src/host/buildvm.c` and `src/host/minilua.c`, these files are
   only used during the LuaJIT build process, and they are not
   a part of the LuaJIT itself. Memory leaks are suppressed in
   AddressSanitizer with a function `__lsan_is_turned_off()` that
   disallows leak checking for the program it is linked into.
1. In LuaJIT, a function `lj_str_new()` may read past a buffer end
   (so-called "dirty" read), and that's ok. Suppressed in
   AddressSanitizer with `__attribute__((no_sanitize_address))`.
1. In LuaJIT, bytecode input is unsafe; see [LuaJIT#847][LuaJIT#847]
   and [LuaJIT FAQ][LuaJIT FAQ]. The string "mode" controls
   whether the chunk can be text or binary (that is, a precompiled
   chunk). It may be the string "b" (only binary chunks),
   "t" (only text chunks), or "bt" (both binary and text). The
   default is "bt". PUC Rio Lua and LuaJIT both have bytecode and
   Lua source code parsers. It is desired to test both
   parsers; however, the LuaJIT bytecode parser failed with the
   assertion: LuaJIT ASSERT `lj_bcread.c:123: bcread_byte: buffer
   read overflow`, so with LuaJIT only text mode is used, and
   therefore only the text parser is tested.
1. The `debug` library is defined as unsafe. There are tons of ways
   to produce a crash with it. This library provides the functionality
   of the debug interface to Lua programs. Several of its functions
   violate basic assumptions about Lua code and therefore can
   compromise otherwise secure code. See [LuaJIT#1264][LuaJIT#1264]
   and [Lua 5.4 Reference Manual][refmanual54]. The `debug`
   functions are not a subject of testing, and these functions are
   used carefully.
1. In LuaJIT, there are a number of places with undefined behavior
   ("nonnull-attribute", "signed-integer-overflow", "bounds").
   These problems remain unfixed and suppressed in
   UndefinedBehavior Sanitizer.
1. In LuaJIT, there is a minimal C declaration parser, and it is not
   a validating C parser: "The parser ought to return correct
   results for properly formed C declarations, but it may accept
   some invalid declarations, too (and return nonsense)".

[LuaJIT#847]: https://github.com/LuaJIT/LuaJIT/issues/847
[LuaJIT#1264]: https://github.com/LuaJIT/LuaJIT/issues/1264
[LuaJIT FAQ]: https://luajit.org/faq.html#sandbox
[refmanual54]: https://www.lua.org/manual/5.4/manual.html#6.10

### License

Copyright (C) 2022-2025 [Sergey Bronnikov](https://bronevichok.ru/),
released under the ISC license. See a full Copyright Notice in the LICENSE file.
