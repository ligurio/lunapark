include(BuildLuzer)
include(MakeLuaPath)

if(NOT LUA_EXECUTABLE)
  message(FATAL_ERROR "${LUA_EXECUTABLE} is not found.")
endif()

lapi_tests_make_lua_path(LUA_CPATH
  PATHS
  ${LUZER_LUA_CPATH}
)

lapi_tests_make_lua_path(LUA_PATH
  PATHS
  ${LUZER_LUA_PATH}
  ${CMAKE_CURRENT_SOURCE_DIR}/?.lua
)

list(APPEND TEST_ENV
  "LUA_PATH=${LUA_PATH}"
  "LUA_CPATH=${LUA_CPATH}"
  ASAN_OPTIONS=detect_odr_violation=0
  LD_DYNAMIC_WEAK=1
)

function(create_test)
  cmake_parse_arguments(
    FUZZ
    ""
    "FILENAME"
    ""
    ${ARGN}
  )
  get_filename_component(test_name ${FUZZ_FILENAME} NAME_WE)
  string(REPLACE "_test" "" test_prefix ${test_name})
  set(dict_path ${PROJECT_SOURCE_DIR}/corpus/${test_prefix}.dict)
  set(corpus_path ${PROJECT_SOURCE_DIR}/corpus/${test_prefix})
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
    COMMAND ${SHELL} -c "${LUA_EXECUTABLE} ${FUZZ_FILENAME} ${LIBFUZZER_OPTS}"
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  )
  if(ENABLE_COV)
    list(APPEND TEST_ENV
      LLVM_PROFILE_FILE=${test_name}.%1m.%p.profraw
    )
  endif()
  set_tests_properties(${test_name} PROPERTIES
    LABELS "lapi"
    ENVIRONMENT "${TEST_ENV}"
    DEPENDS ${LUA_EXECUTABLE} ${LUZER_LIBRARY}
  )
endfunction()

message(STATUS "Add Lua API test suite")
file(GLOB tests LIST_DIRECTORIES false ${CMAKE_CURRENT_SOURCE_DIR}/*_test.lua)
foreach(filename ${tests})
  create_test(FILENAME ${filename})
endforeach()

if (NOT OSS_FUZZ)
  # The test `package_require_test` is dangerous, because it
  # modifies paths used by `require` to search for loaders.
  set_tests_properties(package_require_test PROPERTIES
    DISABLED TRUE
  )
endif()
