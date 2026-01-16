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

	luaL_openlibs(L);

	char *str = malloc(size + 1);
	if (str == NULL)
		return 0;
	memcpy(str, data, size);
	str[size] = '\0';

#ifdef LUAJIT
	/* See https://luajit.org/running.html. */
	luaL_dostring(L, "jit.opt.start('hotloop=1')");
	luaL_dostring(L, "jit.opt.start('hotexit=1')");
	luaL_dostring(L, "jit.opt.start('recunroll=1')");
	luaL_dostring(L, "jit.opt.start('callunroll=1')");
#endif /* LUAJIT */

	if (luaL_loadstring(L, str) != LUA_OK) {
		goto end;
	}

	lua_pcall(L, 0, 0, 0);

end:
	free(str);
	lua_settop(L, 0);
	lua_close(L);

	return 0;
}
