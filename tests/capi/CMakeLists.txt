add_library(fuzzer_config INTERFACE)

target_compile_options(
    fuzzer_config
    INTERFACE
        $<$<NOT:$<BOOL:${OSS_FUZZ}>>:
        -fsanitize=fuzzer
        >
        $<$<BOOL:${OSS_FUZZ}>:
        ${CXX}
        ${CXXFLAGS}
        >
)

# `-lc++` is required by Centipede.
# Some references are defined in `libc++` and used by Centipede,
# so -lc++ needs to come after centipede's lib.
target_link_libraries(
    fuzzer_config
    INTERFACE
        $<$<NOT:$<BOOL:${OSS_FUZZ}>>:
        -fsanitize=fuzzer
        >
        $<$<BOOL:${OSS_FUZZ}>:
        $ENV{LIB_FUZZING_ENGINE}
        -lc++
        >
)

message(STATUS "Add Lua C API test suite")

# The following condition looks unnecessary, it was added to fix
# an issue for Sydr: in the Lua external project in the build
# system the explicit build command is used:
# BUILD_COMMAND cd <SOURCE_DIR> && make -j CC=${CMAKE_C_COMPILER} CFLAGS=${CFLAGS} LDFLAGS=${LDFLAGS},
# which use only flags for Lua build, which were explicitly
# declared earlier, so we need to add `-g` to CFLAGS by ourselves.
# See [1].
#
# 1. https://github.com/ligurio/lunapark/pull/6#discussion_r1185003511
if (CMAKE_BUILD_TYPE STREQUAL "Debug")
  AppendFlags(LDFLAGS ${CMAKE_C_FLAGS_DEBUG})
endif()

if (ENABLE_ASAN)
  AppendFlags(LDFLAGS -fsanitize=address)
endif()

if (ENABLE_UBSAN)
  AppendFlags(LDFLAGS -fsanitize=undefined)
endif()

if (ENABLE_COV)
  AppendFlags(LDFLAGS -fprofile-instr-generate -fcoverage-mapping)
endif()

function(create_test)
  cmake_parse_arguments(
    FUZZ
    ""
    "FILENAME"
    "SOURCES;LIBRARIES"
    ${ARGN}
  )
  get_filename_component(test_name ${FUZZ_FILENAME} NAME_WE)
  add_executable(${test_name} ${FUZZ_SOURCES})
  target_link_libraries(${test_name} PUBLIC
    fuzzer_config
    ${FUZZ_LIBRARIES}
    ${LUA_LIBRARIES}
    ${LDFLAGS}
  )
  target_include_directories(${test_name} PRIVATE ${LUA_INCLUDE_DIR})
  target_compile_options(${test_name} PRIVATE -Wall -Wextra -Wpedantic -Wno-unused-parameter -g)
  add_dependencies(${test_name} ${LUA_LIBRARIES})
  string(REPLACE "_test" "" test_prefix ${test_name})
  set(LIBFUZZER_OPTS "${LIBFUZZER_OPTS} -artifact_prefix=${test_name}_")
  if (IS_LUAJIT AND (${test_name} STREQUAL "lua_dump_test"))
    set(LIBFUZZER_OPTS "${LIBFUZZER_OPTS} -only_ascii=1")
  endif ()
  if (IS_LUAJIT AND (${test_name} STREQUAL "lua_load_test"))
    set(LIBFUZZER_OPTS "${LIBFUZZER_OPTS} -only_ascii=1")
  endif ()
  set(dict_path ${CORPUS_BASE_PATH}/${test_name}.dict)
  set(corpus_path ${CORPUS_BASE_PATH}/${test_prefix})
  if(IS_LUAJIT)
    set(corpus_path ${CORPUS_BASE_PATH}/${test_name})
  endif()
  if (EXISTS ${dict_path})
    set(LIBFUZZER_OPTS "${LIBFUZZER_OPTS} -dict=${dict_path}")
  endif ()
  if (EXISTS ${corpus_path})
    set(LIBFUZZER_OPTS "${LIBFUZZER_OPTS} ${corpus_path}")
  endif ()
  add_test(NAME ${test_name}
           COMMAND ${SHELL} -c "$<TARGET_FILE:${test_name}> ${LIBFUZZER_OPTS}"
  )
  if(ENABLE_COV)
    list(APPEND TEST_ENV
      LLVM_PROFILE_FILE=${test_name}.%1m.%p.profraw
    )
  endif()
  if (USE_LUA)
    list(APPEND TEST_ENV
      ASAN_OPTIONS='detect_invalid_pointer_pairs=2'
    )
  endif()
  set_tests_properties(${test_name} PROPERTIES
    LABELS capi
    ENVIRONMENT "${TEST_ENV}"
  )

  if (IS_LUAJIT)
    target_compile_definitions(${test_name} PUBLIC LUAJIT)
  endif()
endfunction()

list(APPEND LUAJIT_BLACKLIST_TESTS
  # These Lua C functions are unsupported by LuaJIT.
  luaL_addgsub_test
  luaL_bufflen_test
  luaL_buffsub_test
  luaL_buffaddr_test
  lua_stringtonumber_test
  # Disabled because assertion is triggered
  # LuaJIT ASSERT lj_bcread.c:123: bcread_byte: buffer read overflow.
  luaL_dostring_test
  luaL_loadbuffer_test
  luaL_loadstring_test
)

file(GLOB tests LIST_DIRECTORIES false ${CMAKE_CURRENT_SOURCE_DIR} *.c *.cc)
foreach(filename ${tests})
  get_filename_component(test_name ${filename} NAME_WE)
  if (IS_LUAJIT AND (${test_name} IN_LIST LUAJIT_BLACKLIST_TESTS))
    continue()
  endif ()
  if (${test_name} IN_LIST BLACKLIST_TESTS)
    continue()
  endif ()
  create_test(FILENAME ${test_name}
    SOURCES ${filename}
  )
endforeach()

include(ProtobufMutator)
add_subdirectory(luaL_loadbuffer_proto)
if(IS_LUAJIT)
  add_subdirectory(ffi_cdef_proto)
endif ()
