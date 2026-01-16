/*
 * SPDX-License-Identifier: ISC
 *
 * Copyright 2023-2026, Sergey Bronnikov.
 */

/**
 * Each Lua C API function has an indicator like this: [-o, +p, x],
 * see "4.6 – Functions and Types" in Lua Reference Manual.
 *
 * The test pushes random Lua objects to a Lua stack, runs random Lua C API
 * functions and checks that executed function conforms to its function
 * indicator.
 */

#include <assert.h>
#include <stdint.h>

#include <fuzzer/FuzzedDataProvider.h>

#if defined(__cplusplus)
extern "C" {
#endif /* defined(__cplusplus) */

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#if defined(__cplusplus)
} /* extern "C" */
#endif /* defined(__cplusplus) */

#define ARRAY_SIZE(arr)     (sizeof(arr) / sizeof((arr)[0]))

static int max_str_len = 1;

static int
cfunction(lua_State *L) {
	lua_gettop(L);
	return 0;
}

#define TYPE_NAME_TORTURE "torture_test"
#define MT_FUNC_NAME_TORTURE "__torture"

static const luaL_Reg TORTURE_meta[] =
{
	{ MT_FUNC_NAME_TORTURE, cfunction },
	{ 0, 0 }
};

/* void lua_pushstring(lua_State *L, const char *s); */
/* [-0, +1, m] */
static void
__lua_pushstring(lua_State *L, FuzzedDataProvider *fdp)
{
	auto str = fdp->ConsumeRandomLengthString(max_str_len);
	int top = lua_gettop(L);
	lua_pushstring(L, str.c_str());
	assert(lua_gettop(L) == top + 1);
}

/* void lua_pushboolean(lua_State *L, int b); */
/* [-0, +1, -] */
static void
__lua_pushboolean(lua_State *L, FuzzedDataProvider *fdp)
{
	uint8_t n = fdp->ConsumeIntegral<uint8_t>();
	int top = lua_gettop(L);
	lua_pushboolean(L, n);
	assert(lua_gettop(L) == top + 1);
}

/* void lua_pop(lua_State *L, int n); */
/* [-n, +0, -] */
static void
__lua_pop(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t n = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_pop(L, n);
	assert(lua_gettop(L) == top - n);
}

/* int lua_isnumber(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_isnumber(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t n = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_isnumber(L, n);
	assert(lua_gettop(L) == top);
}

/* lua_Number lua_tonumber(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_tonumber(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t n = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_tonumber(L, n);
	assert(lua_gettop(L) == top);
}

/* lua_Number lua_tonumberx(lua_State *L, int index, int *isnum); */
/* [-0, +0, –] */
static void
__lua_tonumberx(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	auto index = fdp->ConsumeIntegralInRange(1, top);
	int isnum;
	lua_tonumberx(L, index, &isnum);
	assert(isnum == 0 || isnum == 1);
	assert(lua_gettop(L) == top);
}

/* int lua_checkstack(lua_State *L, int extra); */
/* [-0, +0, m] */
static void
__lua_checkstack(lua_State *L, FuzzedDataProvider *fdp)
{
	uint8_t n = fdp->ConsumeIntegral<uint8_t>();
	int rc = lua_checkstack(L, n);
	assert(rc != 0);
}

/* void lua_concat(lua_State *L, int n); */
/* [-n, +1, e] */
static void
__lua_concat(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t n = fdp->ConsumeIntegralInRange<uint8_t>(0, top);
	for (int i = 1; i <= n; i++) {
		int t = lua_type(L, -i);
		if (t != LUA_TNUMBER &&
		    t != LUA_TSTRING)
			return;
	}
	lua_concat(L, n);
	assert(lua_gettop(L) == top - n + 1);
}

/* int lua_gettop(lua_State *L); */
/* [-0, +0, -] */
static void
__lua_gettop(lua_State *L, FuzzedDataProvider *fdp)
{
	int rc = lua_gettop(L);
	assert(rc >= 0);
}

/* void lua_insert(lua_State *L, int index); */
/* [-1, +1, -] */
static void
__lua_insert(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_insert(L, index);
	assert(lua_gettop(L) == top - 1 + 1);
}

/* int lua_isboolean(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_isboolean(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	int rc = lua_isboolean(L, index);
	assert(rc == 0 || rc == 1);
}

/* int lua_iscfunction(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_iscfunction(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	int rc = lua_iscfunction(L, index);
	assert(rc == 0 || rc == 1);
}

/* int lua_isfunction(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_isfunction(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	int rc = lua_isfunction(L, index);
	assert(rc == 0 || rc == 1);
}

/* int lua_isnil(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_isnil(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	int rc = lua_isnil(L, index);
	assert(rc == 0 || rc == 1);
}

/* int lua_isnone(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_isnone(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	int rc = lua_isnone(L, index);
	assert(rc == 0 || rc == 1);
	assert(lua_gettop(L) == top);
}

/* int lua_isnoneornil(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_isnoneornil(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_isnoneornil(L, index);
	assert(lua_gettop(L) == top);
}

/* int lua_isstring(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_isstring(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	int rc = lua_isstring(L, index);
	assert(rc == 0 || rc == 1);
}

/* int lua_istable(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_istable(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	int rc = lua_istable(L, index);
	assert(rc == 0 || rc == 1);
}

/* void lua_pushinteger(lua_State *L, lua_Integer n); */
/* [-0, +1, -] */
static void
__lua_pushinteger(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t n = fdp->ConsumeIntegral<uint8_t>();
	lua_pushinteger(L, n);
	assert(lua_gettop(L) == top + 1);
}

/* void lua_pushlstring(lua_State *L, const char *s, size_t len); */
/* [-0, +1, m] */
static void
__lua_pushlstring(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	auto str = fdp->ConsumeRandomLengthString(max_str_len);
	lua_pushlstring(L, str.c_str(), str.size());
	assert(lua_gettop(L) == top + 1);
}

/* void lua_pushnil(lua_State *L); */
/* [-0, +1, -] */
static void
__lua_pushnil(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	lua_pushnil(L);
	assert(lua_gettop(L) == top + 1);
}

/* void lua_pushnumber(lua_State *L, lua_Number n); */
/* [-0, +1, -] */
static void
__lua_pushnumber(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t n = fdp->ConsumeIntegral<uint8_t>();
	lua_pushnumber(L, n);
	assert(lua_gettop(L) == top + 1);
}

/* void lua_pushvalue(lua_State *L, int index); */
/* [-0, +1, -] */
static void
__lua_pushvalue(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_pushvalue(L, index);
	assert(lua_gettop(L) == top + 1);
}

/* void lua_remove(lua_State *L, int index); */
/* [-1, +0, -] */
static void
__lua_remove(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_remove(L, index);
	assert(lua_gettop(L) == top - 1);
}

/* void lua_replace(lua_State *L, int index); */
/* [-1, +0, -] */
static void
__lua_replace(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_replace(L, index);
	assert(lua_gettop(L) == top - 1);
}

/* void lua_setglobal(lua_State *L, const char *name); */
/* [-1, +0, e] */
static void
__lua_setglobal(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	auto str = fdp->ConsumeRandomLengthString(max_str_len);
	lua_setglobal(L, str.c_str());
	assert(lua_gettop(L) == top - 1);
}

/* void lua_settop(lua_State *L, int index); */
/* [-?, +?, -] */
static void
__lua_settop(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	int grow_slots = 2;
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top + grow_slots);
	lua_settop(L, index);
	assert(lua_gettop(L) == index);
}

/* int lua_status(lua_State *L); */
/* [-0, +0, -] */
static void
__lua_status(lua_State *L, FuzzedDataProvider *fdp)
{
	int rc = lua_status(L);
	assert(rc == 0 || rc == LUA_YIELD);
}

/* int lua_toboolean(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_toboolean(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	int rc = lua_toboolean(L, index);
	assert(rc == 0 || rc == 1);
}

/* lua_Integer lua_tointeger(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_tointeger(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_tointeger(L, index);
	assert(lua_gettop(L) == top);
}

/* lua_Integer lua_tointegerx(lua_State *L, int index, int *isnum); */
/* [-0, +0, –] */
static void
__lua_tointegerx(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	int isnum;
	lua_tointegerx(L, index, &isnum);
	assert(isnum == 0 || isnum == 1);
	assert(lua_gettop(L) == top);
}

/* const char *lua_tolstring(lua_State *L, int index, size_t *len); */
/* [-0, +0, m] */
static void
__lua_tolstring(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_tolstring(L, index, NULL);
	assert(lua_gettop(L) == top);
}

/* const char *lua_tostring(lua_State *L, int index); */
/* [-0, +0, m] */
static void
__lua_tostring(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_tostring(L, index);
	assert(lua_gettop(L) == top);
}

/* int lua_type(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_type(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	int type = lua_type(L, index);
	assert(type == LUA_TBOOLEAN       ||
	       type == LUA_TFUNCTION      ||
	       type == LUA_TLIGHTUSERDATA ||
	       type == LUA_TNIL           ||
	       type == LUA_TNUMBER        ||
	       type == LUA_TSTRING        ||
	       type == LUA_TTABLE         ||
	       type == LUA_TTHREAD        ||
	       type == LUA_TUSERDATA      ||
	       type == LUA_TNONE);
	assert(lua_gettop(L) == top);
}

/* void lua_getglobal(lua_State *L, const char *name); */
/* [-0, +1, e] */
static void
__lua_getglobal(lua_State *L, FuzzedDataProvider *fdp)
{
	auto name = fdp->ConsumeRandomLengthString(max_str_len);
	int top = lua_gettop(L);
	lua_getglobal(L, name.c_str());
	assert(lua_gettop(L) == top + 1);
}

/* const char *lua_setupvalue(lua_State *L, int funcindex, int n); */
/* [-(0|1), +0, –] */
static void
__lua_setupvalue(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	int funcindex = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	int n = fdp->ConsumeIntegral<uint8_t>();
	lua_setupvalue(L, funcindex, n);
	assert(lua_gettop(L) == top);
}

/* const char *lua_getupvalue(lua_State *L, int funcindex, int n); */
/* [-0, +(0|1), –] */
static void
__lua_getupvalue(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	int funcindex = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	int n = fdp->ConsumeIntegral<uint8_t>();
	lua_getupvalue(L, funcindex, n);
	assert(lua_gettop(L) == top || lua_gettop(L) == top + 1);
}

/* void *lua_touserdata(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_touserdata(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_touserdata(L, index);
	assert(lua_gettop(L) == top);
}

/* int lua_islightuserdata(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_islightuserdata(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	int rc = lua_islightuserdata(L, index);
	assert(rc == 0 || rc == 1);
}

/* int lua_isuserdata(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_isuserdata(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	int rc = lua_isuserdata(L, index);
	assert(rc == 0 || rc == 1);
}

/* int lua_isthread(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_isthread(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	int rc = lua_isthread(L, index);
	assert(rc == 0 || rc == 1);
}

/* int lua_pushthread(lua_State *L); */
/* [-0, +1, -] */
static void
__lua_pushthread(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	int rc = lua_pushthread(L);
	assert(rc == 1);
	assert(lua_gettop(L) == top + 1);
}

/* int lua_next(lua_State *L, int index); */
/* [-1, +(2|0), e] */
static void
__lua_next(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	if (!lua_istable(L, index))
		return;
	lua_pushnil(L);  /* first key */
	lua_next(L, index);
	assert(lua_gettop(L) - top - 1 <= 2);
}

/* int lua_getinfo(lua_State *L, const char *what, lua_Debug *ar); */
/* [-(0|1), +(0|1|2), m] */
static void
__lua_getinfo(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	lua_Debug ar;
	lua_pushcfunction(L, cfunction);
	const char *what = ">nSltufLr";
	lua_getinfo(L, what, &ar);
	assert(lua_gettop(L) >= top - 1 &&
	       lua_gettop(L) <= top + 2);
}

/* int lua_getstack(lua_State *L, int level, lua_Debug *ar); */
/* [-0, +0, –] */
static void
__lua_getstack(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	int level = fdp->ConsumeIntegral<int8_t>();
	lua_Debug ar;
	lua_getstack(L, level, &ar);
	assert(lua_gettop(L) == top);
}

/* void lua_pushcclosure(lua_State *L, lua_CFunction fn, int n); */
/* [-n, +1, m] */
static void
__lua_pushcclosure(lua_State *L, FuzzedDataProvider *fdp)
{
	/* Maximum n is 255 in lua_pushcclosure(3). */
	int n = fdp->ConsumeIntegralInRange<uint8_t>(1, 10);
	for (int i = 1; i < n; i++)
		lua_pushnumber(L, i);
	lua_pushcclosure(L, cfunction, n);
}

/* void lua_pushcfunction(lua_State *L, lua_CFunction f); */
/* [-0, +1, m] */
static void
__lua_pushcfunction(lua_State *L, FuzzedDataProvider *fdp)
{
	(void)fdp;
	int top = lua_gettop(L);
	lua_pushcfunction(L, cfunction);
	assert(lua_gettop(L) == top + 1);
}

/* int lua_getmetatable(lua_State *L, int index); */
/* [-0, +(0|1), -] */
static void
__lua_getmetatable(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_getmetatable(L, index);
	assert(lua_gettop(L) - top <= 1);
}

/* void lua_newtable(lua_State *L); */
/* [-0, +1, m] */
static void
__lua_newtable(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	lua_newtable(L);
	assert(lua_gettop(L) == top + 1);
}

/* lua_State *lua_newthread(lua_State *L); */
/* [-0, +1, m] */
static void
__lua_newthread(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	lua_newthread(L);
	assert(lua_gettop(L) == top + 1);
}

/* const char *lua_typename(lua_State *L, int tp); */
/* [-0, +0, -] */
static void
__lua_typename(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	const char* name = lua_typename(L, index);
	assert(name);
	assert(lua_gettop(L) == top);
}

static int gc_mode[] = {
	LUA_GCCOLLECT,
	LUA_GCCOUNT,
	LUA_GCCOUNTB,
	LUA_GCRESTART,
#if LUA_VERSION_NUM < 504
	LUA_GCSETPAUSE,
	LUA_GCSETSTEPMUL,
#endif /* LUA_VERSION_NUM */
	LUA_GCSTEP,
	LUA_GCSTOP,
#if LUA_VERSION_NUM > 501
	LUA_GCISRUNNING,
#elif LUA_VERSION_NUM > 503
	LUA_GCGEN,
	LUA_GCINC,
#endif /* LUA_VERSION_NUM */
};

/* int lua_gc(lua_State *L, int what, int data); */
/* [-0, +0, e] */
static void
__lua_gc(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t idx = fdp->ConsumeIntegralInRange<uint8_t>(0, ARRAY_SIZE(gc_mode) - 1);
#if LUA_VERSION_NUM > 503
	if (gc_mode[idx] == LUA_GCGEN) {
		uint8_t minor_mul = fdp->ConsumeIntegral<uint8_t>();
		uint8_t major_mul = fdp->ConsumeIntegral<uint8_t>();
		lua_gc(L, LUA_GCGEN, minor_mul, major_mul);
	} else if (gc_mode[idx] == LUA_GCINC) {
		uint8_t pause = fdp->ConsumeIntegral<uint8_t>();
		uint8_t step_mul = fdp->ConsumeIntegral<uint8_t>();
		uint8_t step_size = fdp->ConsumeIntegral<uint8_t>();
		lua_gc(L, LUA_GCINC, pause, step_mul, step_size);
	} else
		lua_gc(L, gc_mode[idx], 0);
#else
	lua_gc(L, gc_mode[idx], 0);
#endif /* LUA_VERSION_NUM */
	assert(lua_gettop(L) == top);
}

static int hook_mode[] = {
	0, /* Additional branch in Lua. */
	LUA_MASKCALL,
	LUA_MASKCOUNT,
	LUA_MASKLINE,
	LUA_MASKRET,
};

static void
Hook(lua_State *L, lua_Debug *ar)
{
	(void)L;
	(void)ar;
}

/* int lua_sethook(lua_State *L, lua_Hook f, int mask, int count); */
/* [-0, +0, -] */
static void
__lua_sethook(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t idx = fdp->ConsumeIntegralInRange<uint8_t>(0, ARRAY_SIZE(hook_mode) - 1);
	lua_sethook(L, Hook, hook_mode[idx], 1);
	assert(lua_gettop(L) == top);
}

/* lua_Hook lua_gethook(lua_State *L); */
/* [-0, +0, –] */
static void
__lua_gethook(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	lua_gethook(L);
	assert(lua_gettop(L) == top);
}

/* int lua_gethookcount(lua_State *L); */
/* [-0, +0, –] */
static void
__lua_gethookcount(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	int hook_count = lua_gethookcount(L);
	assert(hook_count >= 0);
	assert(lua_gettop(L) == top);
}

/* int lua_gethookmask(lua_State *L); */
/* [-0, +0, –] */
static void
__lua_gethookmask(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	int hook_mask = lua_gethookmask(L);
	assert(hook_mask >= 0);
	assert(lua_gettop(L) == top);
}

/* void lua_rawget(lua_State *L, int index); */
/* [-1, +1, -] */
static void
__lua_rawget(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	if (!lua_istable(L, index))
		return;
	uint8_t key = fdp->ConsumeIntegral<uint8_t>();
	lua_pushnumber(L, key);
	top = lua_gettop(L);
	lua_rawget(L, index);
	assert(lua_gettop(L) == top);
}

/* void lua_rawset(lua_State *L, int index); */
/* [-2, +0, m] */
static void
__lua_rawset(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	if (top == 0)
		return;
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	if (!lua_istable(L, index))
		return;
	uint8_t key = fdp->ConsumeIntegral<uint8_t>();
	uint8_t value = fdp->ConsumeIntegral<uint8_t>();
	lua_pushnumber(L, value);
	lua_pushnumber(L, key);
	top = lua_gettop(L);
	lua_rawset(L, index);
	assert(lua_gettop(L) == top - 2);
}

/* void lua_rawseti(lua_State *L, int index, lua_Integer i); */
/* [-1, +0, m] */
static void
__lua_rawseti(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	if (!lua_istable(L, index))
		return;
	int n = fdp->ConsumeIntegral<uint8_t>();
	__lua_pushnumber(L, fdp);
	top = lua_gettop(L);
	lua_rawseti(L, index, n);
	assert(lua_gettop(L) == top - 1);
}

/* int lua_rawgeti(lua_State *L, int index, lua_Integer n); */
/* [-0, +1, –] */
static void
__lua_rawgeti(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	if (!lua_istable(L, index))
		return;
	int i = fdp->ConsumeIntegral<uint8_t>();
	lua_rawgeti(L, index, i);
	assert(lua_gettop(L) == top + 1);
}

/* int lua_equal(lua_State *L, int index1, int index2); */
/* [-0, +0, e] */
#if LUA_VERSION_NUM == 501
static void
__lua_equal(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	if (top < 2)
		return;
	uint8_t index1 = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	uint8_t index2 = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_equal(L, index1, index2);
	assert(lua_gettop(L) == top);
}
#endif /* LUA_VERSION_NUM */

/* int lua_lessthan(lua_State *L, int index1, int index2); */
/* [-0, +0, e] */
#if LUA_VERSION_NUM == 501
static void
__lua_lessthan(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index1 = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	int type1 = lua_type(L, index1);
	switch (type1) {
	case LUA_TNUMBER:
		__lua_pushnumber(L, fdp);
		break;
	case LUA_TSTRING:
		__lua_pushstring(L, fdp);
		break;
	default:
		return;
	}
	int rc = lua_lessthan(L, index1, -1);
	assert(rc == 0 || rc == 1);
}
#endif /* LUA_VERSION_NUM */

/* size_t lua_objlen(lua_State *L, int index); */
/* [-0, +0, -] */
#if LUA_VERSION_NUM < 503
static void
__lua_objlen(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
#if LUA_VERSION_NUM == 501
	lua_objlen(L, index);
#else
	lua_rawlen(L, index);
#endif /* LUA_VERSION_NUM */
	assert(lua_gettop(L) == top);
}
#endif /* LUA_VERSION_NUM */

#if LUA_VERSION_NUM > 501
static int cmp_op[] = {
	LUA_OPEQ,
	LUA_OPLE,
	LUA_OPLT,
};
#endif /* LUA_VERSION_NUM */

/* int lua_compare(lua_State *L, int index1, int index2, int op); */
/* [-0, +0, e] */
#if LUA_VERSION_NUM > 501
static void
__lua_compare(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index1 = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	uint8_t index2 = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	if ((lua_type(L, index1) != LUA_TNUMBER) ||
	    (lua_type(L, index2) != LUA_TNUMBER))
		return;
	int op_idx = fdp->ConsumeIntegralInRange<uint8_t>(0, ARRAY_SIZE(cmp_op) - 1);
	int rc = lua_compare(L, index1, index2, cmp_op[op_idx]);
	assert(rc == 0 || rc == 1);
	assert(lua_gettop(L) == top);
}
#endif /* LUA_VERSION_NUM */

/* size_t lua_rawlen(lua_State *L, int index); */
/* [-0, +0, –] */
#if LUA_VERSION_NUM > 501
static void
__lua_rawlen(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_rawlen(L, index);
	assert(lua_gettop(L) == top);
}
#endif /* LUA_VERSION_NUM */

/* void lua_getfenv(lua_State *L, int index); */
/* [-0, +1, -] */
#if LUA_VERSION_NUM == 501
static void
__lua_getfenv(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_getfenv(L, index);
	assert(lua_gettop(L) == top + 1);
}
#endif /* LUA_VERSION_NUM */

/* int lua_setfenv(lua_State *L, int index); */
/* [-1, +0, -] */
#if LUA_VERSION_NUM == 501
static void
__lua_setfenv(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	if (!lua_istable(L, -1))
		return;
	lua_setfenv(L, index);
	assert(lua_gettop(L) == top - 1);
}
#endif /* LUA_VERSION_NUM */

/* int lua_absindex(lua_State *L, int idx); */
/* [-0, +0, –] */
#if LUA_VERSION_NUM > 501
static void
__lua_absindex(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	/*
	 * One can refer to any element in the stack by using an index:
	 * A positive index represents an absolute stack position
	 * (starting at 1); a negative index represents an offset
	 * relative to the top of the stack.
	 */
	int8_t index = fdp->ConsumeIntegralInRange<int8_t>(-top, top);
	int idx = lua_absindex(L, index);
	assert(idx > 0);
	assert(lua_gettop(L) == top);
}
#endif /* LUA_VERSION_NUM */

#if LUA_VERSION_NUM > 501
static int arith_op[] = {
	LUA_OPADD,
	LUA_OPSUB,
	LUA_OPMUL,
	LUA_OPDIV,
	LUA_OPMOD,
	LUA_OPPOW,
	LUA_OPUNM,
#if LUA_VERSION_NUM > 502
	LUA_OPBNOT,
	LUA_OPBAND,
	LUA_OPBOR,
	LUA_OPBXOR,
	LUA_OPSHL,
	LUA_OPSHR,
#endif /* LUA_VERSION_NUM */
};
#endif /* LUA_VERSION_NUM */

/* void lua_arith(lua_State *L, int op); */
/* [-(2|1), +1, e] */
#if LUA_VERSION_NUM > 501
static void
__lua_arith(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	if ((lua_type(L, 1) != LUA_TNUMBER) ||
	    (lua_type(L, 2) != LUA_TNUMBER))
		return;
	int op_idx = fdp->ConsumeIntegralInRange<uint8_t>(0, ARRAY_SIZE(arith_op) - 1);
	int op = arith_op[op_idx];

	/* Handle division by zero. */
	lua_pushnumber(L, 0);
	if ((op == LUA_OPMOD ||
	     op == LUA_OPDIV) && lua_rawequal(L, 2, -1))
		return;
	lua_pop(L, 1);

	lua_arith(L, op);
	assert(lua_gettop(L) <= top - 1 + 1);
}
#endif /* LUA_VERSION_NUM */

/* void lua_setmetatable(lua_State *L, int index); */
/* [-1, +0, –] */
static void
__lua_setmetatable(lua_State *L, FuzzedDataProvider *fdp)
{
	luaL_getmetatable(L, TYPE_NAME_TORTURE);
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_setmetatable(L, index);
	assert(lua_gettop(L) == top - 1);
}

/* void luaL_setmetatable(lua_State *L, const char *tname); */
/* [-0, +0, –] */
static void
__luaL_setmetatable(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	luaL_setmetatable(L, TYPE_NAME_TORTURE);
	assert(lua_gettop(L) == top);
}

/* int lua_isyieldable(lua_State *L); */
/* [-0, +0, –] */
#if LUA_VERSION_NUM > 502 || defined(LUAJIT)
static void
__lua_isyieldable(lua_State *L, FuzzedDataProvider *fdp)
{
	(void)fdp;
	int rc = lua_isyieldable(L);
	assert(rc == 0 || rc == 1);
}
#endif /* LUA_VERSION_NUM */

/* int lua_cpcall(lua_State *L, lua_CFunction func, void *ud); */
/* [-0, +(0|1), -] */
#if LUA_VERSION_NUM == 501
static void
__lua_cpcall(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	int rc = lua_cpcall(L, cfunction, NULL);
	assert(rc == 0);
	assert(lua_gettop(L) - top <= 1);
}
#endif /* LUA_VERSION_NUM */

/* void lua_gettable(lua_State *L, int index); */
/* [-1, +1, e] */
static void
__lua_gettable(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	if (!lua_istable(L, index))
		return;
	uint8_t key = fdp->ConsumeIntegral<uint8_t>();
	lua_pushnumber(L, key);
	lua_gettable(L, index);
	assert(lua_gettop(L) == top + 1);
}

/* void lua_rotate(lua_State *L, int idx, int n); */
/* [-0, +0, –] */
#if LUA_VERSION_NUM > 502
static void
__lua_rotate(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	int min_n = 1;
	uint8_t idx = fdp->ConsumeIntegralInRange<uint8_t>(1, top - min_n);
	uint8_t n = fdp->ConsumeIntegralInRange<uint8_t>(1, top - idx);
	lua_rotate(L, idx, n);
	assert(lua_gettop(L) == top);
}
#endif /* LUA_VERSION_NUM */

/* void lua_seti(lua_State *L, int index, lua_Integer n); */
/* [-1, +0, e] */
#if LUA_VERSION_NUM > 502
static void
__lua_seti(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	if (!lua_istable(L, index))
		return;
	int n = fdp->ConsumeIntegral<uint8_t>();
	__lua_pushnumber(L, fdp);
	top = lua_gettop(L);
	lua_seti(L, index, n);
	assert(lua_gettop(L) == top - 1);
}
#endif /* LUA_VERSION_NUM */

/* int lua_geti(lua_State *L, int index, lua_Integer i); */
/* [-0, +1, e] */
#if LUA_VERSION_NUM > 502
static void
__lua_geti(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	if (!lua_istable(L, index))
		return;
	int i = fdp->ConsumeIntegral<uint8_t>();
	lua_geti(L, index, i);
	assert(lua_gettop(L) == top + 1);
}
#endif /* LUA_VERSION_NUM */

/* void lua_getuservalue(lua_State *L, int index); */
/* [-0, +1, –] */
#if LUA_VERSION_NUM > 501 && LUA_VERSION_NUM < 504
static void
__lua_getuservalue(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	int index = fdp->ConsumeIntegral<uint8_t>();
	lua_getuservalue(L, index);
	assert(lua_gettop(L) == top + 1);
}
#endif /* LUA_VERSION_NUM */

/* void lua_setuservalue(lua_State *L, int index); */
/* [-1, +0, –] */
#if LUA_VERSION_NUM > 501 && LUA_VERSION_NUM < 504
static void
__lua_setuservalue(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_setuservalue(L, index);
	assert(lua_gettop(L) == top);
}
#endif /* LUA_VERSION_NUM */

/* void lua_xmove(lua_State *from, lua_State *to, int n); */
/* [-?, +?, -] */
static void
__lua_xmove(lua_State *L, FuzzedDataProvider *fdp)
{
	lua_State *co1 = lua_newthread(L);
	lua_State *co2 = lua_newthread(L);
	__lua_pushnumber(co1, fdp);
	lua_xmove(co1, co2, 1);
	lua_settop(co1, 0);
	lua_settop(co2, 0);
}

/* void lua_register(lua_State *L, const char *name, lua_CFunction f); */
/* [-0, +0, e] */
static void
__lua_register(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	lua_register(L, "cfunction", cfunction);
	assert(lua_gettop(L) == top);
}

/**
 * Lua 5.1: int lua_resume(lua_State *L, int narg);
 * Lua 5.3: int lua_resume(lua_State *L, lua_State *from, int nargs);
 * Lua 5.2: int lua_resume(lua_State *L, lua_State *from, int nargs);
 * Lua 5.4: int lua_resume(lua_State *L, lua_State *from, int nargs, int *nresults);
 * [-?, +?, -]
 */
static void
__lua_resume(lua_State *L, FuzzedDataProvider *fdp)
{
	lua_State *co = lua_newthread(L);
	lua_pushcfunction(co, cfunction);
	int res = -1;
#if LUA_VERSION_NUM == 501
	res = lua_resume(L, 0);
#elif LUA_VERSION_NUM == 503 || LUA_VERSION_NUM == 502
	res = lua_resume(co, L, 0);
#else
	int nres;
	res = lua_resume(co, L, 0, &nres);
#endif /* LUA_VERSION_NUM */
	/* assert(res == LUA_OK); */
	(void)res;
	lua_settop(co, 0);
}

/* void lua_setfield(lua_State *L, int index, const char *k); */
/* [-1, +0, e] */
static void
__lua_setfield(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	if (lua_type(L, index) != LUA_TTABLE)
		return;
	auto k = fdp->ConsumeRemainingBytesAsString();
	lua_setfield(L, index, k.c_str());
	assert(lua_gettop(L) == top - 1);
}

/* const void *lua_topointer(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_topointer(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	const void *p = lua_topointer(L, index);
	/*
	 * The value can be a userdata, a table, a thread, or a function;
	 * otherwise, lua_topointer returns NULL.
	 */
	int type = lua_type(L, index);
	if (type == LUA_TUSERDATA  ||
	    type == LUA_TTHREAD    ||
	    type == LUA_TTABLE     ||
#if LUA_VERSION_NUM > 503 || defined(LUAJIT)
	    type == LUA_TSTRING    ||
#endif /* LUA_VERSION_NUM */
	    type == LUA_TFUNCTION)
		assert(p);
	else
		assert(p == NULL);
	assert(lua_gettop(L) == top);
}

/* lua_CFunction lua_tocfunction(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_tocfunction(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_tocfunction(L, index);
	assert(lua_gettop(L) == top);
}

/* void lua_settable(lua_State *L, int index); */
/* [-2, +0, e] */
static void
__lua_settable(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	lua_createtable(L, 0, 1);

	lua_pushstring(L, "language");
	lua_pushstring(L, "Lua");
	lua_settable(L, -3);

	assert(lua_gettop(L) == top + 1);
}

/* void lua_getfield(lua_State *L, int index, const char *k); */
/* [-0, +1, e] */
static void
__lua_getfield(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	if (lua_type(L, index) != LUA_TTABLE)
		return;
	auto k = fdp->ConsumeRemainingBytesAsString();
	lua_getfield(L, index, k.c_str());
	assert(lua_gettop(L) == top + 1);
}

/* void *lua_newuserdata(lua_State *L, size_t size); */
/* [-0, +1, m] */
static void
__lua_newuserdata(lua_State *L, FuzzedDataProvider *fdp)
{
	uint8_t size = fdp->ConsumeIntegral<uint8_t>();
	lua_newuserdata(L, size);
}

/* const char *lua_pushfstring(lua_State *L, const char *fmt, ...); */
/* [-0, +1, m] */
static void
__lua_pushfstring(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	auto arg1 = fdp->ConsumeRandomLengthString(max_str_len);
	auto arg2 = fdp->ConsumeRandomLengthString(max_str_len);
	auto arg3 = fdp->ConsumeRandomLengthString(max_str_len);
	auto arg4 = fdp->ConsumeRandomLengthString(max_str_len);
	auto arg5 = fdp->ConsumeRandomLengthString(max_str_len);
	char fmt_str[] = "%s %f %p %d %c";
	lua_pushfstring(L, fmt_str, arg1.c_str(), arg2.c_str(),
	                            arg3.c_str(), arg4.c_str(),
	                            arg5.c_str());
	assert(lua_gettop(L) == top + 1);
}

/* lua_State *lua_tothread(lua_State *L, int index); */
/* [-0, +0, -] */
static void
__lua_tothread(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t index = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_tothread(L, index);
	assert(lua_gettop(L) == top);
}

/* lua_Number luaL_checknumber(lua_State *L, int narg); */
/* [-0, +0, v] */
static void
__luaL_checknumber(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t narg = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	/*
	 * Functions called luaL_check* always raise an error
	 * if the check is not satisfied.
	 */
	if (lua_type(L, narg) != LUA_TNUMBER)
		return;
	luaL_checknumber(L, narg);
	assert(lua_gettop(L) == top);
}

/* lua_Integer luaL_checkinteger(lua_State *L, int arg); */
/* [-0, +0, v] */
static void
__luaL_checkinteger(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t arg = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	/*
	 * Functions called luaL_check* always raise an error
	 * if the check is not satisfied.
	 */
	if (lua_type(L, arg) != LUA_TNUMBER)
		return;
	luaL_checkinteger(L, arg);
	assert(lua_gettop(L) == top);
}

/* const char *luaL_checkstring(lua_State *L, int arg); */
/* [-0, +0, v] */
static void
__luaL_checkstring(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t arg = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	/*
	 * Functions called luaL_check* always raise an error
	 * if the check is not satisfied.
	 */
	if (lua_type(L, arg) != LUA_TSTRING)
		return;
	luaL_checkstring(L, arg);
	assert(lua_gettop(L) == top);
}

/* void luaL_checktype(lua_State *L, int arg, int t); */
/* [-0, +0, v] */
static void
__luaL_checktype(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t arg = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	/*
	 * Functions called luaL_check* always raise an error
	 * if the check is not satisfied.
	 */
	int type = lua_type(L, arg);
	luaL_checktype(L, arg, type);
	assert(lua_gettop(L) == top);
}

/* void luaL_checkany(lua_State *L, int arg); */
/* [-0, +0, v] */
static void
__luaL_checkany(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t arg = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	/*
	 * Functions called luaL_check* always raise an error
	 * if the check is not satisfied.
	 */
	luaL_checkany(L, arg);
	assert(lua_gettop(L) == top);
}

/* int lua_getiuservalue(lua_State *L, int index, int n); */
/* [-0, +1, –] */
#if LUA_VERSION_NUM > 503
static void
__lua_getiuservalue(lua_State *L, FuzzedDataProvider *fdp)
{
	lua_newuserdatauv(L, 1, 0);
	__lua_pushnumber(L, fdp);
	int n = 1;
	lua_setiuservalue(L, -2, n);
	int top = lua_gettop(L);
	lua_getiuservalue(L, -1, n);
	assert(lua_gettop(L) == top + 1);
}
#endif /* LUA_VERSION_NUM */

/* int lua_setiuservalue(lua_State *L, int index, int n); */
/* [-1, +0, –] */
#if LUA_VERSION_NUM > 503
static void
__lua_setiuservalue(lua_State *L, FuzzedDataProvider *fdp)
{
	__lua_newuserdata(L, fdp);
	__lua_pushnumber(L, fdp);
	uint8_t n = fdp->ConsumeIntegral<uint8_t>();
	int top = lua_gettop(L);
	lua_setiuservalue(L, -2, n);
	assert(lua_gettop(L) == top - 1);
}
#endif /* LUA_VERSION_NUM */

/* void *lua_upvalueid(lua_State *L, int funcindex, int n); */
/* [-0, +0, –] */
static void
__lua_upvalueid(lua_State *L, FuzzedDataProvider *fdp)
{
	int funcindex = -1;
	lua_Debug ar;
	lua_pushcfunction(L, cfunction);
	int n = fdp->ConsumeIntegral<uint8_t>();
	lua_setupvalue(L, funcindex, n);
	assert(lua_getinfo(L, ">u", &ar) == 1);
	if (ar.nups == 0)
		return;
	int top = lua_gettop(L);
	void *p = lua_upvalueid(L, funcindex, n);
	assert(p);
	assert(lua_gettop(L) == top);
}

/* int lua_rawequal(lua_State *L, int index1, int index2); */
/* [-0, +0, –] */
static void
__lua_rawequal(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	if (top < 2)
		return;
	uint8_t index1 = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	uint8_t index2 = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	lua_rawequal(L, index1, index2);
	assert(lua_gettop(L) == top);
}

/* void luaL_traceback(lua_State *L, lua_State *L1, const char *msg, int level); */
/* [-0, +1, m] */
static void
__luaL_traceback(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	auto buf = fdp->ConsumeRandomLengthString(max_str_len);
	luaL_traceback(L, L, buf.c_str(), 1);
	assert(lua_gettop(L) == top + 1);
}

/* const char *lua_tolstring(lua_State *L, int index, size_t *len); */
/* [-0, +0, m] */
/* const char *luaL_tolstring(lua_State *L, int idx, size_t *len); */
/* [-0, +1, e] */
static void
__luaL_tolstring(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	auto idx = fdp->ConsumeIntegralInRange(1, top);
#if LUA_VERSION_NUM < 503
	lua_tolstring(L, idx, NULL);
	assert(lua_gettop(L) == top);
#else
	luaL_tolstring(L, idx, NULL);
	assert(lua_gettop(L) == top + 1);
#endif /* LUA_VERSION_NUM */
}

/* void lua_copy(lua_State *L, int fromidx, int toidx); */
/* [-0, +0, –] */
#if LUA_VERSION_NUM > 501 || defined(LUAJIT)
static void
__lua_copy(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	uint8_t fromidx = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	uint8_t toidx = fdp->ConsumeIntegralInRange<uint8_t>(1, top);
	if (fromidx == toidx)
		return;
	lua_copy(L, fromidx, toidx);
	assert(lua_gettop(L) == top);
}
#endif /* LUA_VERSION_NUM */

/* void luaL_checkversion(lua_State *L); */
/* [-0, +0, v] */
#if LUA_VERSION_NUM > 501
static void
__luaL_checkversion(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	luaL_checkversion(L);
	assert(top == lua_gettop(L));
}
#endif /* LUA_VERSION_NUM */

/* size_t lua_stringtonumber(lua_State *L, const char *s); */
/* [-0, +1, –] */
#if LUA_VERSION_NUM > 502
static void
__lua_stringtonumber(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	auto str = fdp->ConsumeRandomLengthString(max_str_len);
	size_t sz = lua_stringtonumber(L, str.c_str());
	if (sz == 0) {
		assert(lua_gettop(L) == top);
	} else {
		assert(lua_gettop(L) == top + 1);
		assert(lua_isnumber(L, -1) == 1);
	}
}
#endif /* LUA_VERSION_NUM */

/* int lua_rawgetp(lua_State *L, int index, const void *p); */
/* [-0, +1, –] */
#if LUA_VERSION_NUM > 501
static void
__lua_rawgetp(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	auto idx = fdp->ConsumeIntegralInRange(1, top);
	if (lua_type(L, idx) != LUA_TTABLE)
		return;
	void *p = malloc(1);
	lua_rawgetp(L, idx, p);
	free(p);
	assert(lua_gettop(L) == top + 1);
}
#endif /* LUA_VERSION_NUM */

/* void lua_len(lua_State *L, int index); */
/* [-0, +1, e] */
#if LUA_VERSION_NUM > 501
static void
__lua_len(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	auto idx = fdp->ConsumeIntegralInRange(1, top);
	if (lua_type(L, idx) != LUA_TTABLE &&
	    lua_type(L, idx) != LUA_TSTRING)
		return;
	lua_len(L, idx);
	assert(lua_gettop(L) == top + 1);
}
#endif /* LUA_VERSION_NUM */

/* lua_Integer luaL_len(lua_State *L, int index); */
/* [-0, +0, e] */
#if LUA_VERSION_NUM > 501
static void
__luaL_len(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	auto index = fdp->ConsumeIntegralInRange(1, top);
	int type = lua_type(L, index);
	if (type == LUA_TFUNCTION  ||
	    type == LUA_TTHREAD    ||
	    type == LUA_TNUMBER    ||
	    type == LUA_TBOOLEAN   ||
	    type == LUA_TNIL       ||
	    type == LUA_TUSERDATA)
		return;
	luaL_len(L, index);
	assert(lua_gettop(L) == top);
}
#endif /* LUA_VERSION_NUM */

/* lua_Alloc lua_getallocf(lua_State *L, void **ud); */
/* [-0, +0, –] */
static void
__lua_getallocf(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	void *state;
	lua_getallocf(L, &state);
	assert(lua_gettop(L) == top);
}

/* int luaL_ref(lua_State *L, int t); */
/* [-1, +0, e] */
static void
__luaL_ref(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	auto idx = fdp->ConsumeIntegralInRange(1, top);
	if (lua_type(L, idx) != LUA_TTABLE)
		return;
	luaL_ref(L, idx);
	assert(lua_gettop(L) == top - 1);
}

/* void luaL_checkstack(lua_State *L, int sz, const char *msg); */
/* [-0, +0, v] */
static void
__luaL_checkstack(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	int sz = top + 1;
	char err_msg[] = "shit happens";
	luaL_checkstack(L, sz, err_msg);
	assert(lua_gettop(L) == top);
}

/* const lua_Number *lua_version(lua_State *L); */
/* [-0, +0, v] */
#if LUA_VERSION_NUM > 501 || defined(LUAJIT)
static void
__lua_version(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
#if LUA_VERSION_NUM < 504
	const lua_Number *v = lua_version(L);
	assert(v);
#else
	lua_Number v = lua_version(L);
	assert(v != 0);
#endif /* LUA_VERSION_NUM */
	assert(lua_gettop(L) == top);
}
#endif /* LUA_VERSION_NUM */

/* int luaL_getmetafield(lua_State *L, int obj, const char *e); */
/* [-0, +(0|1), e] */
static void
__luaL_getmetafield(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	auto obj = fdp->ConsumeIntegralInRange(1, top);
	const char e[] = "xxx";
	luaL_getmetafield(L, obj, e);
	assert(lua_gettop(L) == top || lua_gettop(L) == top + 1);
}

/* void lua_call(lua_State *L, int nargs, int nresults); */
/* [-(nargs+1), +nresults, e] */
static void
__lua_call(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	/* Function to be called. */
	lua_pushcfunction(L, cfunction);
	int nargs = 0;
	int nresults = 0;
	lua_call(L, nargs, nresults);
	assert(lua_gettop(L) == top + nresults - nargs);
}

/* int lua_pcall(lua_State *L, int nargs, int nresults, int msgh); */
/* [-(nargs + 1), +(nresults|1), –] */
static void
__lua_pcall(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	/* Function to be called. */
	lua_pushcfunction(L, cfunction);
	int nargs = 0;
	int nresults = 0;
	int res = lua_pcall(L, nargs, nresults, 0);
	assert(res == LUA_OK);
	assert(lua_gettop(L) == top + nresults - nargs);
}

/* int luaL_loadstring(lua_State *L, const char *s); */
/* [-0, +1, m] */
static void
__luaL_loadstring(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	int res = luaL_loadstring(L, "a = a + 1");
	assert(res == LUA_OK);
	assert(lua_gettop(L) == top + 1);
}

/* int luaL_callmeta(lua_State *L, int obj, const char *e); */
/* [-0, +(0|1), e] */
static void
__luaL_callmeta(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	auto obj = fdp->ConsumeIntegralInRange(1, top);
	luaL_callmeta(L, obj, MT_FUNC_NAME_TORTURE);
	assert(lua_gettop(L) == top || lua_gettop(L) == top + 1);
}

/* void luaL_where(lua_State *L, int lvl); */
/* [-0, +1, m] */
static void
__luaL_where(lua_State *L, FuzzedDataProvider *fdp)
{
	int top = lua_gettop(L);
	luaL_where(L, 1);
	assert(lua_gettop(L) == top + 1);
}

typedef void
(*lua_func)(lua_State *L, FuzzedDataProvider *fdp);

static lua_func push_func[] = {
	&__lua_newtable,
	&__lua_newthread,
	&__lua_pushboolean,
	&__lua_pushcfunction,
	&__lua_pushinteger,
	&__lua_pushlstring,
	&__lua_pushnil,
	&__lua_pushnumber,
	&__lua_pushstring,
};

static void
lua_pushrandom(lua_State *L, FuzzedDataProvider *fdp)
{
	uint8_t idx = fdp->ConsumeIntegralInRange<uint8_t>(0, ARRAY_SIZE(push_func) - 1);

	push_func[idx](L, fdp);

	bool is_set_mt = fdp->ConsumeBool();
	if (is_set_mt) {
		luaL_getmetatable(L, TYPE_NAME_TORTURE);
		lua_setmetatable(L, -2);
	}
}

/* void lua_createtable(lua_State *L, int narr, int nrec); */
/* [-0, +1, m] */
static void
__lua_createtable(lua_State *L, FuzzedDataProvider *fdp)
{
	int nrows = fdp->ConsumeIntegral<uint8_t>();
	/* XXX: Lua associative arrays. */
	lua_createtable(L, nrows, 0);
	for (int i = 0; i < nrows; i++) {
		lua_pushnumber(L, i);
		lua_rawseti(L, -2, i + 1);
	}
	assert(lua_gettop(L) != 0);
}

static lua_func func[] = {
	&__lua_call,
	&__lua_checkstack,
	&__lua_concat,
	&__lua_createtable,
	&__lua_gc,
	&__lua_getallocf,
	&__lua_getfield,
	&__lua_getglobal,
	&__lua_gethook,
	&__lua_gethookcount,
	&__lua_gethookmask,
	&__lua_getinfo,
	&__lua_getmetatable,
	&__lua_getstack,
	&__lua_gettable,
	&__lua_gettop,
	&__lua_getupvalue,
	&__lua_insert,
	&__lua_isboolean,
	&__lua_iscfunction,
	&__lua_isfunction,
	&__lua_islightuserdata,
	&__lua_isnil,
	&__lua_isnone,
	&__lua_isnoneornil,
	&__lua_isnumber,
	&__lua_isstring,
	&__lua_istable,
	&__lua_isthread,
	&__lua_isuserdata,
	&__luaL_callmeta,
	&__luaL_checkany,
	&__luaL_checkinteger,
	&__luaL_checknumber,
	&__luaL_checkstack,
	&__luaL_checkstring,
	&__luaL_checktype,
	&__luaL_getmetafield,
	&__luaL_loadstring,
	&__luaL_ref,
	&__luaL_tolstring,
	&__luaL_traceback,
	&__luaL_where,
	&__lua_newtable,
	&__lua_newthread,
	&__lua_newuserdata,
	&__lua_next,
	&__lua_pcall,
	&__lua_pop,
	&__lua_pushboolean,
	&__lua_pushcclosure,
	&__lua_pushcfunction,
	&__lua_pushfstring,
	&__lua_pushinteger,
	&__lua_pushlstring,
	&__lua_pushnil,
	&__lua_pushnumber,
	&__lua_pushstring,
	&__lua_pushthread,
	&__lua_pushvalue,
	&__lua_rawequal,
	&__lua_rawget,
	&__lua_rawgeti,
	&__lua_rawset,
	&__lua_rawseti,
	&__lua_register,
	&__lua_remove,
	&__lua_replace,
	&__lua_resume,
	&__lua_setfield,
	&__lua_setglobal,
	&__lua_setmetatable,
	&__lua_settable,
	&__lua_settop,
	&__lua_setupvalue,
	&__lua_status,
	&__lua_toboolean,
	&__lua_tocfunction,
	&__lua_tointeger,
	&__lua_tointegerx,
	&__lua_tolstring,
	&__lua_tonumber,
	&__lua_topointer,
	&__lua_tostring,
	&__lua_tothread,
	&__lua_touserdata,
	&__lua_type,
	&__lua_typename,
	&__lua_upvalueid,
	&__lua_xmove,
#if LUA_VERSION_NUM == 501
	&__lua_cpcall,
	&__lua_equal,
	&__lua_getfenv,
	&__lua_lessthan,
	&__lua_objlen,
	&__lua_setfenv,
#endif /* LUA_VERSION_NUM */
#if LUA_VERSION_NUM > 501
	&__lua_absindex,
	&__lua_arith,
	&__lua_compare,
	&__lua_copy,
	&__luaL_checkversion,
	&__lua_len,
	&__luaL_len,
	&__luaL_setmetatable,
	&__lua_rawgetp,
	&__lua_rawlen,
	&__lua_tonumberx,
	&__lua_version,
#endif /* LUA_VERSION_NUM */
#if LUA_VERSION_NUM > 502
	&__lua_geti,
	&__lua_isyieldable,
	&__lua_rotate,
	&__lua_seti,
	&__lua_stringtonumber,
#endif /* LUA_VERSION_NUM */
#if LUA_VERSION_NUM > 503
	&__lua_getiuservalue,
	&__lua_setiuservalue,
#endif /* LUA_VERSION_NUM */
#if LUA_VERSION_NUM > 501 && LUA_VERSION_NUM < 504
	&__lua_setuservalue,
	&__lua_getuservalue,
#endif /* LUA_VERSION_NUM */
#ifdef LUAJIT
	&__lua_copy,
	&__lua_isyieldable,
	&__luaL_setmetatable,
	&__lua_tonumberx,
	&__lua_version,
#endif /* LUAJIT */
};

extern "C" int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	lua_State *L = luaL_newstate();
	if (L == NULL)
		return 0;

#if LUA_VERSION_NUM == 501
	luaL_register(L, TYPE_NAME_TORTURE, TORTURE_meta);
#else
	luaL_newmetatable(L, TYPE_NAME_TORTURE);
	luaL_setfuncs(L, TORTURE_meta, 0);
#endif /* LUA_VERSION_NUM */

	FuzzedDataProvider fdp(data, size);
	int start_slots = 2;
	for (int i = 1; i <= start_slots; i++)
		if (fdp.remaining_bytes() != 0)
			lua_pushrandom(L, &fdp);

	if (lua_gettop(L) != 0 &&
	    fdp.remaining_bytes() != 0) {
		__lua_gc(L, &fdp);
		__lua_sethook(L, &fdp);
		uint8_t idx = fdp.ConsumeIntegralInRange<uint8_t>(0, ARRAY_SIZE(func) - 1);
		func[idx](L, &fdp);
	}

	lua_settop(L, 0);
	lua_close(L);

	return 0;
}
