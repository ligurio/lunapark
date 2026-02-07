find_program(LLVM_COV llvm-cov)
find_program(LLVM_PROFDATA llvm-profdata)

set(target_name "coverage-report")
if(NOT LLVM_PROFDATA AND NOT LLVM_COV)
  set(MESSAGE "${target_name} is a dummy target")
  add_custom_target(${target_name}
    COMMAND ${CMAKE_COMMAND} -E cmake_echo_color --red ${MESSAGE}
    COMMENT ${MESSAGE}
  )
  message(WARNING "Either `llvm-profdata' or `llvm-cov` not found, "
                  "so target ${target_name} is dummy.")
  return()
endif()

set(CODE_COVERAGE_DIR "${PROJECT_BINARY_DIR}/coverage")
set(CODE_COVERAGE_HTML_REPORT ${CODE_COVERAGE_DIR}/index.html)
list(APPEND CODE_COVERAGE_FLAGS
  -fcoverage-mapping
  -fprofile-instr-generate
)

# Clang Version 18.1.0 was the first release with full, native
# support for MC/DC coverage analysis using the source-based code
# coverage feature.
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang" AND
   CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL "18.1")
  list(APPEND CODE_COVERAGE_FLAGS
    -fcoverage-mcdc
  )
endif()

file(MAKE_DIRECTORY ${CODE_COVERAGE_DIR})

list(APPEND LLVM_COV_PROFRAW_MASK
  ${PROJECT_BINARY_DIR}/tests/capi/*.profraw
  ${PROJECT_BINARY_DIR}/tests/lapi/*.profraw
)
set(LLVM_COV_PROFDATA ${PROJECT_BINARY_DIR}/tests/default.profdata)

list(APPEND LLVM_COV_FLAGS
  -instr-profile=${LLVM_COV_PROFDATA}
  -output-dir=${CODE_COVERAGE_DIR}
  --show-branches=count
  --show-expansions
  --show-mcdc
  --show-mcdc-summary
)

# XXX: This variable is defined in BuildLua.cmake and
# BuildLuaJIT.cmake. However, these modules are included after
# CodeCoverage.cmake, so not available.
set(LUA_EXECUTABLE ${PROJECT_BINARY_DIR}/luajit-v2.1/source/src/luajit)
if(USE_LUA)
  set(LUA_EXECUTABLE ${PROJECT_BINARY_DIR}/lua-master/source/lua)
endif()

add_custom_target(${target_name}
  COMMAND ${LLVM_PROFDATA} merge -sparse ${LLVM_COV_PROFRAW_MASK}
    -o ${LLVM_COV_PROFDATA}
  COMMAND ${LLVM_COV} show --format=html ${LLVM_COV_FLAGS} ${LUA_EXECUTABLE}
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  COMMENT "Generating HTML code coverage report in ${CODE_COVERAGE_DIR}"
)

add_custom_target(coverage-reset
  COMMENT "Reset code coverage counters"
  COMMAND ${CMAKE_COMMAND} -E rm -f ${LLVM_COV_PROFRAW_MASK} ${LLVM_COV_PROFDATA}
)

message(STATUS "Code coverage HTML report: ${CODE_COVERAGE_HTML_REPORT}")
