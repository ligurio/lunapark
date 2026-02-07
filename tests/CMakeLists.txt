set(DEFAULT_RUNS_NUMBER 5)

string(JOIN " " LIBFUZZER_OPTS
  -mutate_depth=20
  -print_final_stats=1
  -print_pcs=1
  -reduce_inputs=1
  -reload=1
  -report_slow_units=5
  -runs=$\{RUNS:-${DEFAULT_RUNS_NUMBER}\}
  -use_value_profile=1
  -workers=${CMAKE_BUILD_PARALLEL_LEVEL}
)

if(ENABLE_COV)
  string(JOIN " " LIBFUZZER_OPTS
    ${LIBFUZZER_OPTS}
    -ignore_ooms=1
    -ignore_timeouts=1
    -ignore_crashes=1
    -timeout=1
  )
endif()

set(CORPUS_BASE_PATH ${PROJECT_SOURCE_DIR}/corpus)
if(IS_LUAJIT)
  set(CORPUS_BASE_PATH ${CORPUS_BASE_PATH}/corpus)
endif()

add_subdirectory(capi)
if(ENABLE_LAPI_TESTS)
  add_subdirectory(lapi)
endif()
