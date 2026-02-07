macro(build_lua LUA_VERSION)
    set(LUA_SOURCE_DIR ${PROJECT_BINARY_DIR}/lua-${LUA_VERSION}/source)
    set(LUA_BINARY_DIR ${PROJECT_BINARY_DIR}/lua-${LUA_VERSION}/work)

    set(LUA_PATCH_PATH ${PROJECT_SOURCE_DIR}/patches/puc-rio-lua.patch)

    set(CFLAGS "${CMAKE_C_FLAGS} -fno-omit-frame-pointer")
    if (ENABLE_LUA_ASSERT)
        AppendFlags(CFLAGS -DLUAI_ASSERT)
    endif()
    if (ENABLE_LUA_APICHECK)
        AppendFlags(CFLAGS -DLUA_USE_APICHECK)
    endif()
    if(NOT ENABLE_CBMC_PROOFS)
        AppendFlags(CFLAGS -fsanitize=fuzzer-no-link)
        AppendFlags(LDFLAGS -fsanitize=fuzzer-no-link)
    endif()
    if (OSS_FUZZ)
        AppendFlags(LDFLAGS ${CFLAGS})
    endif()

    if (CMAKE_BUILD_TYPE STREQUAL "Debug")
        AppendFlags(CFLAGS ${CMAKE_C_FLAGS_DEBUG})
        AppendFlags(LDFLAGS ${CMAKE_C_FLAGS_DEBUG})
    endif()

    if (ENABLE_ASAN)
        string(JOIN " " ASAN_FLAGS
          -fsanitize=address
          -fsanitize=pointer-subtract
          -fsanitize=pointer-compare
        )
        AppendFlags(CFLAGS ${ASAN_FLAGS})
        AppendFlags(LDFLAGS -fsanitize=address)
    endif()

    if (ENABLE_UBSAN)
        string(JOIN "," NO_SANITIZE_FLAGS
            # lvm.c:luaV_execute()
            float-divide-by-zero
            # lgc.c:sweepstep()
            implicit-integer-sign-change
            # lvm.c:luaV_execute()
            integer-divide-by-zero
            # The object size sanitizer has no effect at -O0.
            object-size
            # lstring.c:luaS_hash()
            shift
            # lstring.c:luaS_hash()
            unsigned-integer-overflow
            # lstring.c:luaS_hash()
            unsigned-shift-base
        )
        string(JOIN " " ASAN_FLAGS
          -fsanitize=undefined
          -fno-sanitize-recover=undefined
          -fno-sanitize=${NO_SANITIZE_FLAGS}
        )
        AppendFlags(CFLAGS ${UBSAN_FLAGS})
        AppendFlags(LDFLAGS ${UBSAN_FLAGS})
    endif()

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

    if(ENABLE_LAPI_TESTS)
        # "relocation R_X86_64_PC32 against symbol `lua_isnumber'
        # can not be used when making a shared object; recompile
        # with -fPIC".
        AppendFlags(CFLAGS -fPIC)
        AppendFlags(CFLAGS -DLUA_USE_DLOPEN)
        # `io.popen()` is not supported by default, it is enabled
        # by `LUA_USE_POSIX` flag. Required by a function `random_locale()`.
        AppendFlags(CFLAGS -DLUA_USE_POSIX)
        AppendFlags(LDFLAGS -lstdc++)
    endif()

    include(ExternalProject)

    set(LUA_LIBRARY ${PROJECT_BINARY_DIR}/lua-${LUA_VERSION}/source/liblua.a)
    set(LUA_EXECUTABLE ${LUA_SOURCE_DIR}/lua)

    ExternalProject_Add(patched-lua
        GIT_REPOSITORY https://github.com/lua/lua
        GIT_TAG ${LUA_VERSION}
        GIT_PROGRESS TRUE
        GIT_SHALLOW FALSE
        GIT_REMOTE_UPDATE_STRATEGY REBASE

        SOURCE_DIR ${LUA_SOURCE_DIR}
        BINARY_DIR ${LUA_BINARY_DIR}
        DOWNLOAD_DIR ${LUA_BINARY_DIR}
        TMP_DIR ${LUA_BINARY_DIR}/tmp
        STAMP_DIR ${LUA_BINARY_DIR}/stamp

        PATCH_COMMAND git reset --hard && cd <SOURCE_DIR> && patch -p1 -i ${LUA_PATCH_PATH}
        CONFIGURE_COMMAND ""
        BUILD_COMMAND cd <SOURCE_DIR> && make -j CC=${CMAKE_C_COMPILER}
                                                 MYCFLAGS=${CFLAGS}
                                                 MYLDFLAGS=${LDFLAGS}
                                                 LF_PATH=${LibFuzzerObjDir}
        INSTALL_COMMAND ""

        BUILD_BYPRODUCTS ${LUA_LIBRARY} ${LUA_EXECUTABLE}
    )

    add_library(bundled-liblua STATIC IMPORTED GLOBAL)
    set_target_properties(bundled-liblua PROPERTIES
      IMPORTED_LOCATION ${LUA_LIBRARY})
    add_dependencies(bundled-liblua patched-lua)

    set(LUA_LIBRARIES bundled-liblua)
    set(LUA_INCLUDE_DIR ${PROJECT_BINARY_DIR}/lua-${LUA_VERSION}/source/)
    set(LUA_VERSION_STRING "PUC Rio Lua ${LUA_VERSION}")

    unset(LUA_BINARY_DIR)
    unset(LUA_PATCH_PATH)
endmacro(build_lua)
