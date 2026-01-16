/*
 * SPDX-License-Identifier: ISC
 *
 * Copyright 2023-2026, Sergey Bronnikov.
 */

extern "C"
{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#ifdef LUAJIT
#include "luajit.h"
#endif /* LUAJIT */
#include <signal.h>
#include <unistd.h>
}

#include "cdef.pb.h"
#include "cdef_print.h"

#include <libprotobuf-mutator/port/protobuf.h>
#include <libprotobuf-mutator/src/libfuzzer/libfuzzer_macro.h>

/**
 * Get an error message from the stack, and report it to std::cerr.
 * Remove the message from the stack.
 */
static inline void
report_error(lua_State *L, const std::string &prefix)
{
	const char *verbose = ::getenv("LUA_FUZZER_VERBOSE");
	if (!verbose)
		return;

	std::string err_str = lua_tostring(L, 1);
	/* Pop error message from stack. */
	lua_pop(L, 1);
	std::cerr << prefix << " error: " << err_str << std::endl;
}

DEFINE_PROTO_FUZZER(const cdef::Declarations &message)
{
	lua_State *L = luaL_newstate();
	if (!L)
		return;

	std::string cdef = ffi_cdef_proto::MainDefinitionsToString(message);
	std::string chunk = "local ffi = require('ffi')\n";
	chunk += "ffi.cdef[[\n";
	chunk += cdef;
	chunk += "]]\n";

	if (::getenv("LPM_DUMP_NATIVE_INPUT") && chunk.size() != 0) {
		std::cout << "-------------------------" << std::endl;
		std::cout << chunk << std::endl;
	}

	luaL_openlibs(L);

	if (luaL_loadbuffer(L, chunk.c_str(), chunk.size(), "fuzz") != LUA_OK) {
		report_error(L, "luaL_loadbuffer()");
		goto end;
	}

	/*
	 * Using lua_pcall (protected call) to catch errors due to
	 * wrong semantics of some generated C code chunks.
	 */
	if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
		report_error(L, "lua_pcall()");
		goto end;
	}

end:
	lua_settop(L, 0);
	lua_close(L);
}
