/*
 * SPDX-License-Identifier: ISC
 *
 * Copyright 2023-2026, Sergey Bronnikov.
 */

#include "lua.h"
#include "lauxlib.h"

/* unsigned int luaL_makeseed (lua_State *L); */
/* [-0, +0, -] */
static void
__luaL_makeseed(lua_State *L)
{
	luaL_makeseed(L);
}

int
main()
{
	__luaL_makeseed(NULL);

	return 0;
}
