set(LUA_PREAMBLE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/preamble.lua")
if (NOT EXISTS "${LUA_PREAMBLE_PATH}")
   message(FATAL "File '${LUA_PREAMBLE_PATH}' is not found.")
endif ()

set(test_lua_sources)
lua_source(test_lua_sources preamble.lua preamble_lua)
set_source_files_properties(${CMAKE_CURRENT_BINARY_DIR}/preamble.lua.c
    PROPERTIES COMPILE_OPTIONS "-Wno-overlength-strings")

add_custom_target(generate_test_lua_sources
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}/tests/capi/luaL_loadbuffer_proto/
    DEPENDS ${test_lua_sources})
set_property(DIRECTORY PROPERTY ADDITIONAL_MAKE_CLEAN_FILES ${test_lua_sources})

set(test_name luaL_loadbuffer_proto_test)

add_library(lua_grammar-proto)

foreach(lib ${LPM_LIBRARIES})
    find_library(${lib} REQUIRED_FILES)
endforeach(lib)

protobuf_generate(LANGUAGE cpp
                  TARGET lua_grammar-proto
                  PROTOS lua_grammar.proto)

target_link_libraries(lua_grammar-proto
                      ${PROTOBUF_LIBRARIES})

create_test(FILENAME ${test_name}
            SOURCES luaL_loadbuffer_proto_test.cc
                    serializer.cc
                    ${CMAKE_CURRENT_BINARY_DIR}/preamble.lua.c
            LIBRARIES lua_grammar-proto ${LPM_LIBRARIES})

target_include_directories(${test_name} PUBLIC ${CMAKE_CURRENT_BINARY_DIR} ${LUA_INCLUDE_DIR})
add_dependencies(${test_name} ${LPM_LIBRARIES} lua_grammar-proto)
