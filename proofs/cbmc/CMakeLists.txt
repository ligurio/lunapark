find_program(CBMC_BIN cbmc)
find_program(CBMC_VIEWER_BIN cbmc-viewer)

list(APPEND GENERAL_CBMC_OPTS
  --bounds-check
  --conversion-check
  --div-by-zero-check
  --drop-unused-functions
  --float-overflow-check
  --flush
  --fpa
  --malloc-fail-null
  --malloc-may-fail
  --memory-cleanup-check
  --memory-leak-check
  --nan-check
  --object-bits 16
  --pointer-check
  --pointer-overflow-check
  --pointer-primitive-check
  --refine
  --signed-overflow-check
  --stack-trace
  --trace
  --undefined-shift-check
  --unsigned-overflow-check
  --verbosity 10
  --z3
)

set(DEFAULT_TIMEOUT 30)
set(CBMC_REPORT_PATH ${CMAKE_CURRENT_BINARY_DIR}/report)

file(MAKE_DIRECTORY ${CBMC_REPORT_PATH})

list(APPEND DEFAULT_LUA_CBMC_OPTS
  ${GENERAL_CBMC_OPTS}
)

list(APPEND DEFAULT_LUAJIT_CBMC_OPTS
  ${GENERAL_CBMC_OPTS}
)

if(USE_LUA)
  set(DEFAULT_CBMC_OPTS ${DEFAULT_LUA_CBMC_OPTS})
elseif (USE_LUAJIT)
  set(DEFAULT_CBMC_OPTS ${DEFAULT_LUAJIT_CBMC_OPTS})
endif()

set(PROOF_TARGETS "")
set(PROOF_REPORTS "")

function(create_proof)
  cmake_parse_arguments(
    CBMC
    ""
    "FILENAME"
    ""
    ${ARGN}
  )

  get_filename_component(test_name ${CBMC_FILENAME} NAME_WE)
  message(STATUS "Building a proof ${test_name}")

  # Build a CBMC proof binary.
  add_executable(${test_name} ${CBMC_FILENAME})
  target_link_libraries(${test_name} PUBLIC ${LUA_LIBRARIES})
  target_include_directories(${test_name} PRIVATE
    ${LUA_INCLUDE_DIR} ${CMAKE_CURRENT_SOURCE_DIR})
  target_compile_options(${test_name} PRIVATE
    -Wall -Wextra -Wpedantic -Wno-unused-parameter -g)
  add_dependencies(${test_name} ${LUA_LIBRARIES})

  # Create a CTest-based test.
  set(proof_name "${test_name}_proof")
  string(JOIN " " CBMC_COMMAND
    ${CBMC_BIN}
    $<TARGET_FILE:${test_name}>
    ${DEFAULT_CBMC_OPTS}
    # Notice that `--cover location` cannot be used together
    # with `--unwinding-assertions`.)
    --unwinding-assertions
  )
  add_test(NAME ${proof_name}
    COMMAND ${SHELL} -c "${CBMC_COMMAND}"
  )
  set_tests_properties(${proof_name} PROPERTIES
    LABELS proof
    TIMEOUT ${DEFAULT_TIMEOUT}
  )
  set(PROOF_TARGETS ${PROOF_TARGETS} ${test_name} PARENT_SCOPE)
  set(PROOF_REPORTS ${PROOF_REPORTS} ${test_name}-report PARENT_SCOPE)

  set(PROPERTY_REPORT ${test_name}_property.json)
  set(COVERAGE_REPORT ${test_name}_coverage.json)
  set(RESULT_REPORT ${test_name}_result.json)

  add_custom_target(${RESULT_REPORT}
    COMMAND ${CBMC_BIN} $<TARGET_FILE:${test_name}>
      ${DEFAULT_CBMC_OPTS} --unwinding-assertions --trace --json-ui > ${RESULT_REPORT} || (exit 0)
    DEPENDS ${test_name}
    BYPRODUCTS ${RESULT_REPORT}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Build ${RESULT_REPORT}"
  )

  add_custom_target(${PROPERTY_REPORT}
    COMMAND ${CBMC_BIN} $<TARGET_FILE:${test_name}>
      ${DEFAULT_CBMC_OPTS} --unwinding-assertions --show-properties --json-ui > ${PROPERTY_REPORT}
    DEPENDS ${test_name}
    BYPRODUCTS ${PROPERTY_REPORT}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Build ${PROPERTY_REPORT}"
  )

  add_custom_target(${COVERAGE_REPORT}
    COMMAND ${CBMC_BIN} $<TARGET_FILE:${test_name}>
      ${DEFAULT_CBMC_OPTS} --cover location --json-ui > ${COVERAGE_REPORT}
    DEPENDS ${test_name}
    BYPRODUCTS ${COVERAGE_REPORT}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Build ${COVERAGE_REPORT}"
  )

  list(APPEND CBMC_VIEWER_COMMAND
    ${CBMC_VIEWER_BIN}
    --goto $<TARGET_FILE:${test_name}>
    --result ${RESULT_REPORT}
    --coverage ${COVERAGE_REPORT}
    --property ${PROPERTY_REPORT}
    --reportdir ${CBMC_REPORT_PATH}/${test_name}
    --srcdir ${LUA_INCLUDE_DIR}
    --wkdir ${LUA_INCLUDE_DIR}
  )

  add_custom_target(${test_name}-report
    COMMAND ${CBMC_VIEWER_COMMAND}
    DEPENDS ${RESULT_REPORT} ${PROPERTY_REPORT} ${COVERAGE_REPORT}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Build CBMC code coverage report for ${test_name}"
  )
endfunction()

##################################################################
# Lua C API functions
##################################################################

create_proof(FILENAME luaL_makeseed.c)

add_custom_target(build_cbmc_proofs
  DEPENDS ${PROOF_TARGETS}
  COMMENT "Building CBMC proofs"
)
add_custom_target(build_cbmc_reports
  DEPENDS ${PROOF_REPORTS}
  COMMENT "Building CBMC reports"
)
