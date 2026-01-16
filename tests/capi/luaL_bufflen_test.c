/*
 * SPDX-License-Identifier: ISC
 *
 * Copyright 2023-2026, Sergey Bronnikov.
 */

#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	lua_State *L = luaL_newstate();
	if (L == NULL)
		return 0;

	luaL_Buffer buf;
	char *s = luaL_buffinitsize(L, &buf, size);
	memcpy(s, data, size);

	luaL_pushresultsize(&buf, size);

	assert(luaL_bufflen(&buf) == size);

	lua_settop(L, 0);
	lua_close(L);

	return 0;
}
