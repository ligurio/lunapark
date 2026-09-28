# The function sets the given variable in a parent scope to a
# string with hardware architecture name and this name should
# match to hardware architecture name used in a library name of
# libclang_rt.fuzzer_no_main: aarch64, x86_64, i386.
function(SetHwArchString outvar)
  set(HW_ARCH ${CMAKE_SYSTEM_PROCESSOR})
  # In a multilib build (`-m32`) CMAKE_SYSTEM_PROCESSOR is still the
  # host architecture, so pick the libFuzzer runtime library that
  # matches the target architecture instead. Runtime library names are
  # `i386` and `x86_64`.
  if(HW_ARCH MATCHES "x86_64|amd64")
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
      set(HW_ARCH "x86_64")
    else()
      set(HW_ARCH "i386")
    endif()
  elseif(HW_ARCH MATCHES "^i[3-6]86$")
    set(HW_ARCH "i386")
  endif()
  set(${outvar} ${HW_ARCH} PARENT_SCOPE)
endfunction()

# The function sets the given variable in a parent scope to a
# value with path to libclang_rt.fuzzer_no_main [1] library.
# The function raises a fatal message if C compiler is not Clang.
#
# $ clang-15 -print-file-name=libclang_rt.fuzzer_no_main-x86_64.a
# $ /usr/lib/llvm-15/lib/clang/15.0.7/lib/linux/libclang_rt.fuzzer_no_main-x86_64.a
#
# 1. https://llvm.org/docs/LibFuzzer.html#using-libfuzzer-as-a-library
function(SetLibFuzzerPath outvar)
  if (NOT CMAKE_C_COMPILER_ID STREQUAL "Clang")
    message(FATAL_ERROR "C compiler is not a Clang")
  endif ()

  SetHwArchString(HW_ARCH)
  # LibFuzzer library in the OSS Fuzz environment has another name.
  if (OSS_FUZZ)
    set(lib_name "libclang_rt.fuzzer_no_main.a")
  elseif (CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(lib_name "libclang_rt.fuzzer_no_main-${HW_ARCH}.a")
  else()
    message(FATAL_ERROR "Unsupported system: ${CMAKE_SYSTEM_NAME}")
  endif()

  string(REPLACE " " ";" CMAKE_C_FLAGS_LIST "${CMAKE_C_FLAGS}")
  execute_process(
    COMMAND ${CMAKE_C_COMPILER} ${CMAKE_C_FLAGS_LIST} "-print-file-name=${lib_name}"
    RESULT_VARIABLE CMD_ERROR
    OUTPUT_VARIABLE CMD_OUTPUT
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if (CMD_ERROR)
    message(FATAL_ERROR "${CMD_ERROR}")
  endif()

  if(NOT EXISTS ${CMD_OUTPUT})
    message(FATAL_ERROR "${lib_name} was not found.")
  endif()

  set(${outvar} ${CMD_OUTPUT} PARENT_SCOPE)
endfunction()

# The function unpack libFuzzer archive located at <LibFuzzerPath>
# to a directory <LibFuzzerDir> and return a path to a directory
# with libFuzzer's object files.
function(SetLibFuzzerObjDir outvar)
  set(LibFuzzerDir ${PROJECT_BINARY_DIR}/libFuzzer_unpacked)
  file(MAKE_DIRECTORY ${LibFuzzerDir})
  SetLibFuzzerPath(LibFuzzerPath)
  # Remove stale objects extracted from a runtime library built for a
  # different architecture (e.g. after switching from x86_64 to i386).
  file(GLOB LibFuzzerObjs "${LibFuzzerDir}/*.o")
  list(LENGTH LibFuzzerObjs LibFuzzerObjsLen)
  if(LibFuzzerObjsLen GREATER 0)
    file(REMOVE ${LibFuzzerObjs})
  endif()
  execute_process(
    COMMAND ${CMAKE_AR} x ${LibFuzzerPath} --output ${LibFuzzerDir}
    RESULT_VARIABLE CMD_ERROR
    OUTPUT_VARIABLE CMD_OUTPUT
    WORKING_DIRECTORY ${LibFuzzerDir}
  )
  if (CMD_ERROR)
    message(FATAL_ERROR "${CMD_ERROR}")
  endif()
  set(${outvar} ${LibFuzzerDir} PARENT_SCOPE)
endfunction()
