### PUC Rio Lua

1. "Re: More disciplined use of 'getstr' and 'tsslen'",
   https://marc.info/?l=lua-l&m=169289729129364&w=2#2
   https://github.com/lua/lua/commit/9b4f39ab14fb2e55345c3d23537d129dac23b091
1. Stack overflow in `getobjname`,
   https://marc.info/?l=lua-l&m=169867263111530&w=2,
   https://github.com/lua/lua/commit/7923dbbf72da303ca1cca17efd24725668992f15
1. Heap buffer overflow in `luaC_newobjdt`,
   https://marc.info/?l=lua-l&m=170274071304413&w=2
   https://github.com/lua/lua/commit/5853c37a83ec66ccb45094f9aeac23dfdbcde671
1. "heap-use-after-free" issue in `luaV_finishget`,
   https://groups.google.com/g/lua-l/c/s2hBcf8aLIU,
   https://oss-fuzz.com/testcase-detail/5350818532360192,
   https://github.com/lua/lua/commit/88a50ffa715483e7187c0d7d6caaf708ebacf756
1. Assertion in `luaK_codeABCk`,
   https://groups.google.com/g/lua-l/c/H0Iq-eAig94,
   https://oss-fuzz.com/testcase-detail/5166379907481600
1. An assertion is triggered in `lgc.c:freeobj()`,
   https://groups.google.com/g/lua-l/c/CCpPLX1ug3A,
   https://oss-fuzz.com/testcase-detail/6073198411579392,
   https://github.com/lua/lua/commit/f9e35627ed26dff4114a1d01ff113d8b4cc91ab5
1. UBsan: member access within null pointer of type 'struct TString',
   https://groups.google.com/g/lua-l/c/Kng6FGlPjmc,
   https://github.com/lua/lua/commit/6d53701c7a0dc4736d824fd891ee6f22265d0d68,
   https://oss-fuzz.com/testcase-detail/5557969930747904
1. Assertion failure of `A <= ((1<<8)-1) && B <= ((1<<8)-1) && C <= ((1<<8)-1) && (k & ~1) == 0`,
   https://groups.google.com/g/lua-l/c/F132crJ2D_8
   https://github.com/ligurio/lunapark/issues/155
1. An assertion is triggered in `luaK_storevar`,
   https://groups.google.com/g/lua-l/c/Cfb5Yn0aJEU
   https://issues.oss-fuzz.com/issues/455148340,
   https://oss-fuzz.com/testcase-detail/5818389013790720

### LuaJIT

1. ASSERT: `lj_obj_equal(tv, &tvk)`,
   https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=57435,
   https://github.com/LuaJIT/LuaJIT/issues/9
1. 0th register may be considered as `RID_NONE` in `asm_head_side`,
   https://github.com/LuaJIT/LuaJIT/issues/1016,
   https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=58555
1. Use-def analysis for VARG doesn't purge some dead JIT slots
   https://github.com/LuaJIT/LuaJIT/issues/1024
1. ASSERT: `itype2irt(tv) == ((IRType)(((&J->fold.ins)->t).irt & IRT_TYPE))`,
   https://github.com/LuaJIT/LuaJIT/issues/981,
   https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=57424
1. ASSERT: `bc_isret(((BCOp)((ins[-1])&0xff)))`,
   https://github.com/LuaJIT/LuaJIT/issues/913,
   https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=57548
1. Crash during parsing in the `predict_next()`,
   https://github.com/LuaJIT/LuaJIT/issues/1033
1. Incorrect PC value in a function `predict_next`,
   https://github.com/LuaJIT/LuaJIT/issues/1054
1. VM handler call on constructed testcase,
   https://github.com/LuaJIT/LuaJIT/issues/1087
1. Red zone overflow on trace compilation,
   https://github.com/LuaJIT/LuaJIT/issues/1116
1. `IR_NEWREF` is missing a NaN check,
   https://github.com/LuaJIT/LuaJIT/issues/1069
1. Heap-use-after-free in `lj_gc_finalize_cdata` on access to `CTState->finalizer`,
   https://github.com/LuaJIT/LuaJIT/issues/1168
1. Down-recursion of a side trace may corrupt the host stack,
   https://github.com/LuaJIT/LuaJIT/issues/1169
1. GC64 mode may overflow the `LJ_MAX_JSLOTS` limit for a stitched trace.,
   https://github.com/LuaJIT/LuaJIT/issues/1173
1. State not restored during recording if `__concat` metamethod throws an error,
   https://github.com/LuaJIT/LuaJIT/issues/1234
   https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=69897
1. Uninitialized `cts->L` and error handling issues in `recff_cdata_arith`,
   https://github.com/LuaJIT/LuaJIT/issues/1224
1. OOM errors during GC step raising in the context of a JIT trace,
   https://github.com/LuaJIT/LuaJIT/issues/1247,
   https://github.com/tarantool/tarantool/issues/10290
1. stack-buffer-overflow in `narrow_conv_backprop`,
   https://github.com/LuaJIT/LuaJIT/issues/1262,
   https://oss-fuzz.com/testcase?key=6250635821907968
1. Incorrect recording of `getmetatable()` for IO handlers,
   https://github.com/LuaJIT/LuaJIT/issues/1279
1. Uninitialized read in `predict_next()`,
   https://oss-fuzz.com/testcase-detail/5091141278564352
   https://github.com/LuaJIT/LuaJIT/issues/1226
1. State is not restored during recording `__concat` metamethod in case of the OOM,
   https://github.com/LuaJIT/LuaJIT/issues/1298,
   https://issues.oss-fuzz.com/issues/372358472
1. Unsinking the table with `IRFL_TAB_NOMM` leads to the assertion failure,
   https://github.com/LuaJIT/LuaJIT/issues/1052
1. Multi-concat recording doesn't handle vararg/protected frames,
   https://github.com/LuaJIT/LuaJIT/issues/1164
1. Incorrect narrowing for huge numbers,
   https://github.com/LuaJIT/LuaJIT/issues/1236
1. Assertion failure when flushing already flushed trace,
   https://github.com/LuaJIT/LuaJIT/issues/1345
1. Read from already collected string data in case of the error in loadfile,
   https://github.com/LuaJIT/LuaJIT/issues/1353,
   https://github.com/tarantool/security/issues/144,
   https://issues.oss-fuzz.com/issues/407592872
1. JIT slots overflow for side-trace after up-recursion,
   https://github.com/LuaJIT/LuaJIT/issues/1358,
   https://github.com/tarantool/security/issues/145
1. Stack overflow in error handler during stack overflow,
   https://github.com/LuaJIT/LuaJIT/issues/1152,
   https://issues.oss-fuzz.com/issues/394126186,
   https://github.com/tarantool/security/issues/143

### Tarantool

1. Assertion `'ls->p < ls->pe'` failed: `lj_bcread.c:122: uint32_t bcread_byte(LexState *)`,
   https://github.com/tarantool/tarantool/issues/4824
1. Fix narrowing of unary minus,
   https://github.com/tarantool/tarantool/issues/6976
1. ASSERT: `lj_obj_equal(tv, &tvk)`,
   https://github.com/LuaJIT/LuaJIT/issues/9
   https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=57435
1. Recording of `__concat` in GC64 mode,
   https://github.com/LuaJIT/LuaJIT/issues/839
1. Heap buffer overflow in the `lj_strfmt_pushvf` on stack overflow,
   https://issues.oss-fuzz.com/issues/394126186,
   https://github.com/tarantool/security/issues/143
1. `IR_NEWREF` is missing a NaN check,
   https://issues.oss-fuzz.com/issues/42529868
   https://github.com/LuaJIT/LuaJIT/issues/1069

### Related issues

1. https://www.lua.org/bugs.html
1. https://github.com/google/oss-fuzz-vulns/tree/main/vulns/lua
1. https://oss-fuzz.com/testcases?project=lua&open=yes
1. https://github.com/tarantool/tarantool/wiki/Fuzzing
