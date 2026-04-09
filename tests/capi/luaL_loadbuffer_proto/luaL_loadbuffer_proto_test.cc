/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright 2023-2026, Sergey Bronnikov.
 * Copyright 2022, Tarantool AUTHORS.
 */

#include <fstream>
#include <string>
#include <iostream>

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

#include "lua_grammar.pb.h"
#include "serializer.h"

#include <libprotobuf-mutator/port/protobuf.h>
#include <libprotobuf-mutator/src/libfuzzer/libfuzzer_macro.h>

#define PRINT_METRIC(desc, val, total)	\
		std::cout << (desc) << (val)	\
	              << " (" << (val) * 100 / (total) << "%)" \
	              << std::endl

#define UNUSED __attribute__((unused))

struct metrics {
	/* Per test run. */
	size_t total_num;
	size_t total_num_with_errors;
	size_t jit_trace_record;
	size_t jit_trace_abort;
	size_t jit_trace_start;
	size_t jit_trace_stop;
	size_t bc_num;
	size_t texit_num;

	/* Per test sample. */
	bool is_trace_abort;
	bool is_trace_start;
	bool is_trace_stop;
	bool is_trace_record;
	bool is_bc;
	bool is_texit;
};

static struct metrics metrics;

UNUSED static void
jit_attach(lua_State *L, void *func, const char *event)
{
	lua_getglobal(L, "jit");
	lua_getfield(L, -1, "attach");
	lua_pushcfunction(L, (lua_CFunction)func);
	if (event != NULL) {
		lua_pushstring(L, event);
	} else {
		lua_pushnil(L);
	}
	if (lua_pcall(L, 2, 0, 0)) {
		const char *msg = lua_tostring(L, -1);
		fprintf(stderr, "ERR: %s\n", msg);
		lua_error(L);
	}
}

/**
 * When a trace is being recorded.
 *
 * Arguments: tr, func, pc, depth, callee.
 */
UNUSED static int
record_cb(lua_State *L) {
	if (!metrics.is_trace_record) {
		metrics.jit_trace_record++;
		metrics.is_trace_record = true;
	}
	return 0;
}

/**
 * When a function has been compiled to bytecode.
 *
 * Arguments: func.
 */
UNUSED static int
bc_cb(lua_State *L) {
	if (!metrics.is_bc) {
		metrics.bc_num++;
		metrics.is_bc = true;
	}
	return 0;
}

/**
 * When a trace exits through a side exit.
 *
 * Arguments: tr, ex, ngpr, nfpr, ... .
 */
UNUSED static int
texit_cb(lua_State *L) {
	if (!metrics.is_texit) {
		metrics.texit_num++;
		metrics.is_texit = true;
	}
	return 0;
}

/**
 * When trace recording starts, stops or aborts.
 *
 * Arguments: what, tr, func, pc, otr, oex.
 */
UNUSED static int
trace_cb(lua_State *L) {
	const char *what = lua_tostring(L, 1);
	if (strcmp(what, "abort") == 0 && !metrics.is_trace_abort) {
		metrics.jit_trace_abort++;
		metrics.is_trace_abort = true;
	}
	if (strcmp(what, "start") == 0 && !metrics.is_trace_start) {
		metrics.jit_trace_start++;
		metrics.is_trace_start = true;
	}
	if (strcmp(what, "stop") == 0 && !metrics.is_trace_stop) {
		metrics.jit_trace_stop++;
		metrics.is_trace_stop = true;
	}
	return 0;
}

static inline void
print_metrics(struct metrics *metrics)
{
	if (metrics->total_num == 0)
		return;

	std::cout << "Total number of samples: "
		  << metrics->total_num << std::endl;
	PRINT_METRIC("Total number of samples with errors: ",
		     metrics->total_num_with_errors, metrics->total_num);
#ifdef LUAJIT
	PRINT_METRIC("Total number of samples with record traces: ",
		     metrics->jit_trace_record, metrics->total_num);
	PRINT_METRIC("Total number of samples with start traces: ",
		     metrics->jit_trace_start, metrics->total_num);
	PRINT_METRIC("Total number of samples with stop traces: ",
		     metrics->jit_trace_stop, metrics->total_num);
	PRINT_METRIC("Total number of samples with abort traces: ",
		     metrics->jit_trace_abort, metrics->total_num);
	PRINT_METRIC("Total number of samples with exit traces: ",
		     metrics->texit_num, metrics->total_num);
	PRINT_METRIC("Total number of samples with compiled bc: ",
		     metrics->bc_num, metrics->total_num);
#endif /* LUAJIT */
}

static inline void
metrics_increment_num_samples(struct metrics *metrics)
{
	metrics->total_num++;
}

static inline void
metrics_increment_num_error_samples(struct metrics *metrics)
{
	metrics->total_num_with_errors++;
}

UNUSED static void
profiler_cb(lua_State *L, void *data, int samples, int vmstate)
{
	(void)L;
	(void)data;
	/* Do nothing. */
}

/**
 * Get an error message from the stack, and report it to std::cerr.
 * Remove the message from the stack.
 */
static inline void
report_error(lua_State *L, const std::string &prefix)
{
	metrics_increment_num_error_samples(&metrics);
	const char *verbose = ::getenv("LUA_FUZZER_VERBOSE");
	if (!verbose)
		return;

	const char *errmsg = lua_tostring(L, 1);
	std::string err_str = errmsg ? errmsg : "(null)";
	/* Pop error message from stack. */
	lua_pop(L, 1);
	std::cerr << prefix << " error: " << err_str << std::endl;
}

void
sig_handler(int signo, siginfo_t *info, void *context)
{
	print_metrics(&metrics);
}

__attribute__((constructor))
static void
setup(void)
{
	metrics = {};
	struct sigaction act = {};
	act.sa_flags = SA_SIGINFO;
	act.sa_sigaction = &sig_handler;
	sigaction(SIGUSR1, &act, NULL);
}

__attribute__((destructor))
static void
teardown(void)
{
	print_metrics(&metrics);
}

UNUSED static inline void
reset_lj_metrics(struct metrics *metrics)
{
	metrics->is_trace_start = false;
	metrics->is_trace_stop = false;
	metrics->is_trace_abort = false;
	metrics->is_trace_record = false;
	metrics->is_bc = false;
	metrics->is_texit = false;
}

UNUSED static void
enable_lj_metrics(lua_State *L, struct metrics *metrics)
{
	reset_lj_metrics(metrics);
	jit_attach(L, (void *)bc_cb, "bc");
	jit_attach(L, (void *)record_cb, "record");
	jit_attach(L, (void *)texit_cb, "texit");
	jit_attach(L, (void *)trace_cb, "trace");
}

UNUSED static void
disable_lj_metrics(lua_State *L, struct metrics *metrics)
{
	jit_attach(L, (void *)bc_cb, NULL);
	jit_attach(L, (void *)record_cb, NULL);
	jit_attach(L, (void *)texit_cb, NULL);
	jit_attach(L, (void *)trace_cb, NULL);
}

DEFINE_PROTO_FUZZER(const lua_grammar::Block &message)
{
	lua_State *L = luaL_newstate();
	if (!L)
		return;

	std::string code = luajit_fuzzer::MainBlockToString(message);

	if (::getenv("LPM_DUMP_NATIVE_INPUT") && code.size() != 0) {
		std::cout << "-------------------------" << std::endl;
		std::cout << code << std::endl;
	}

	luaL_openlibs(L);

#ifdef LUAJIT
	enable_lj_metrics(L, &metrics);

	/* See https://luajit.org/running.html. */
	luaL_dostring(L, "jit.opt.start('hotloop=1')");
	luaL_dostring(L, "jit.opt.start('hotexit=1')");
	luaL_dostring(L, "jit.opt.start('recunroll=1')");
	luaL_dostring(L, "jit.opt.start('callunroll=1')");

	/*
	 * The `mode` argument is a string holding options:
	 * f - Profile with precision down to the function level.
	 * l - Profile with precision down to the line level.
	 * i<number> - Sampling interval in milliseconds (default 10ms).
	 */
	char mode[] = "fli15";
	size_t depth = 5;
	int len = 5;

	/* Start profiler. */
	luaJIT_profile_start(L, mode, (luaJIT_profile_callback)profiler_cb, NULL);

	/*
	 * Function allows taking stack dumps in an efficient manner, returns a
	 * string with a stack dump for the thread (coroutine), formatted according
	 * to the fmt argument:
	 *   p - Preserve the full path for module names.
	 *   f - Dump the function name if it can be derived.
	 *   F - Ditto, but dump module:name.
	 *   l - Dump module:line.
	 *   Z - Zap the following characters for the last dumped frame.
	 */
	luaJIT_profile_dumpstack(L, "pfFlz", len, &depth);
#endif /* LUAJIT */

	std::size_t hash = std::hash<std::string>{}(code);
	std::ofstream out("/tmp/corpus/" + std::to_string(hash) + ".lua");
	out << code;
	out.close();

	if (luaL_loadbuffer(L, code.c_str(), code.size(), "fuzz") != LUA_OK) {
		report_error(L, "luaL_loadbuffer()");
		goto end;
	}

	/*
	 * Using lua_pcall (protected call) to catch errors due to
	 * wrong semantics of some generated code chunks.
	 * Mostly, generated code is not semantically correct, so it is
	 * needed to describe Lua semantics for more interesting
	 * results and fuzzer tests.
	 */
	if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
		report_error(L, "lua_pcall()");
		goto end;
	}

end:
	metrics_increment_num_samples(&metrics);
	/* Disable debugging hook. */
#ifdef LUAJIT
	disable_lj_metrics(L, &metrics);
	/* Stop profiler. */
	luaJIT_profile_stop(L);
#endif /* LUAJIT */

	lua_settop(L, 0);
	lua_close(L);
}
