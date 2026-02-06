set(LPM_TARGET external.protobuf_mutator)
set(LPM_INSTALL_DIR ${CMAKE_CURRENT_BINARY_DIR}/${LPM_TARGET})
set(LPM_REPO https://github.com/google/libprotobuf-mutator.git)

set(LPM_INCLUDE_DIRS ${LPM_INSTALL_DIR}/include)
include_directories(${LPM_INCLUDE_DIRS})
include_directories(${LPM_INCLUDE_DIRS}/libprotobuf-mutator)
include_directories(${CMAKE_CURRENT_BINARY_DIR})

# this exact order due to dependencies of libraries
set(LPM_LIBRARIES protobuf-mutator-libfuzzer protobuf-mutator)

foreach(lib ${LPM_LIBRARIES})
  set(LIB_PATH ${LPM_INSTALL_DIR}/lib/lib${lib}.a)
  list(APPEND LPM_BUILD_BYPRODUCTS ${LIB_PATH})
  add_library(${lib} STATIC IMPORTED)
  set_property(TARGET ${lib} PROPERTY IMPORTED_LOCATION
               ${LIB_PATH})
  add_dependencies(${lib} ${LPM_TARGET})
endforeach(lib)

if (ENABLE_BUILD_PROTOBUF)
   include(SetProtobufDirs)
   SetProtobufDirs()
   message(STATUS "Build Protobuf library automatically")
endif (ENABLE_BUILD_PROTOBUF)

include (ExternalProject)
ExternalProject_Add(${LPM_TARGET}
  PREFIX ${LPM_TARGET}
  GIT_REPOSITORY ${LPM_REPO}
  GIT_TAG 212a7be
  UPDATE_COMMAND ""
  CONFIGURE_COMMAND ${CMAKE_COMMAND} ${LPM_INSTALL_DIR}/src/${LPM_TARGET}
        -G${CMAKE_GENERATOR}
        -DCMAKE_INSTALL_PREFIX=${LPM_INSTALL_DIR}
        -DCMAKE_BUILD_TYPE=Debug
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON
        -DCMAKE_C_COMPILER:FILEPATH=${CMAKE_C_COMPILER}
        -DCMAKE_CXX_COMPILER:FILEPATH=${CMAKE_CXX_COMPILER}
        -DLIB_PROTO_MUTATOR_DOWNLOAD_PROTOBUF=${ENABLE_BUILD_PROTOBUF}
        -DLIB_PROTO_MUTATOR_TESTING=OFF
        -DLIB_PROTO_MUTATOR_WITH_ASAN=${ENABLE_ASAN}
  BUILD_BYPRODUCTS ${LPM_BUILD_BYPRODUCTS} ${PROTOBUF_BUILD_BYPRODUCTS}
)

unset(LPM_TARGET)
unset(LPM_INSTALL_DIR)
unset(LPM_REPO)
unset(LIB_PATH)
