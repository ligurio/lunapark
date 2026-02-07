set(CFLAGS -Wall -Wextra -Wpedantic -Wno-unused-parameter)

if (ENABLE_COV)
  string(JOIN " " CODE_COVERAGE_FLAGS
    -fcoverage-mapping
    -fprofile-arcs
    -fprofile-instr-generate
    -ftest-coverage
  )
  AppendFlags(CFLAGS ${CODE_COVERAGE_FLAGS})
  AppendFlags(LDFLAGS ${CODE_COVERAGE_FLAGS})
endif()

set(LIB_LUA_MUTATE lua_mutate)
add_library(${LIB_LUA_MUTATE} STATIC mutate.c)
target_link_libraries(${LIB_LUA_MUTATE} PRIVATE ${LUA_LIBRARIES} ${LDFLAGS})
target_include_directories(${LIB_LUA_MUTATE} PRIVATE ${LUA_INCLUDE_DIR})
target_compile_options(${LIB_LUA_MUTATE} PRIVATE ${CFLAGS})
add_dependencies(${LIB_LUA_MUTATE} ${LUA_LIBRARIES})

set(LIB_LUA_CROSSOVER lua_crossover)
add_library(${LIB_LUA_CROSSOVER} STATIC crossover.c)
target_link_libraries(${LIB_LUA_CROSSOVER} PRIVATE ${LUA_LIBRARIES} ${LDFLAGS})
target_include_directories(${LIB_LUA_CROSSOVER} PRIVATE ${LUA_INCLUDE_DIR})
target_compile_options(${LIB_LUA_CROSSOVER} PRIVATE ${CFLAGS})
add_dependencies(${LIB_LUA_CROSSOVER} ${LUA_LIBRARIES})

if (ENABLE_INTERNAL_TESTS)
  add_subdirectory(tests)
endif()
