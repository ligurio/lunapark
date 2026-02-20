#!/bin/bash -eu
#
# SPDX-License-Identifier: ISC
# Copyright 2023-2026, Sergey Bronnikov.
#
################################################################################

# Clean up potentially persistent build directory.
[[ -e $SRC/lunapark/build ]] && rm -rf $SRC/lunapark/build

cd $SRC/lunapark

# For some reason the linker will complain if address sanitizer is not used
# in introspector builds.
if [ "$SANITIZER" == "introspector" ]; then
  export CFLAGS="${CFLAGS} -fsanitize=address"
  export CXXFLAGS="${CXXFLAGS} -fsanitize=address"
fi

case $SANITIZER in
  address) SANITIZERS_ARGS="-DENABLE_ASAN=ON" ;;
  undefined) SANITIZERS_ARGS="-DENABLE_UBSAN=ON" ;;
  *) SANITIZERS_ARGS="" ;;
esac

: ${LD:="${CXX}"}
: ${LDFLAGS:="${CXXFLAGS}"}  # to make sure we link with sanitizer runtime

cmake_args=(
    -DUSE_LUAJIT=ON
    -DOSS_FUZZ=ON
    -DENABLE_LAPI_TESTS=ON
    $SANITIZERS_ARGS

    # C compiler
    -DCMAKE_C_COMPILER="${CC}"
    -DCMAKE_C_FLAGS="${CFLAGS}"

    # C++ compiler
    -DCMAKE_CXX_COMPILER="${CXX}"
    -DCMAKE_CXX_FLAGS="${CXXFLAGS}"

    # Linker
    -DCMAKE_LINKER="${LD}"
    -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS}"
    -DCMAKE_MODULE_LINKER_FLAGS="${LDFLAGS}"
    -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS}"
)

# To deal with a host filesystem from inside of container.
git config --global --add safe.directory '*'

# Build the project and fuzzers.
[[ -e build ]] && rm -rf build
cmake "${cmake_args[@]}" -S . -B build -G Ninja
cmake --build build --parallel

cp corpus/corpus/*.dict corpus/corpus/*.options $OUT/

# Copy the fuzzer executables, zip-ed corpora, option and
# dictionary files to $OUT.
#
# If a target program requires any additional runtime
# dependencies or artifacts such as seed corpus or a dictionary
# for libFuzzer or AFL, all these files should be placed
# in the same directory as the target executable and be included
# in the build archive. See ClusterFuzz documentation [1].
#
# 1. https://google.github.io/clusterfuzz/production-setup/build-pipeline/
for f in $(find build/tests/ -name '*_test' -type f);
do
  name=$(basename $f);
  module=$(echo $name | sed 's/_test//')
  corpus_dir="corpus/corpus/$name"
  echo "Copying for $module";
  cp $f $OUT/
  if [ -e "$corpus_dir" ]; then
    find "$corpus_dir" -mindepth 1 -maxdepth 1 | zip -@ -j --quiet $OUT/"$name"_seed_corpus.zip
  fi

  dict_path="corpus/$name.dict"
  if [ -e "$dict_path" ]; then
    zip -urj $OUT/"$name"_seed_corpus.zip "$dict_path"
  fi

  options_path="corpus/$name.options"
  if [ -e "$options_path" ]; then
    zip -urj $OUT/"$name"_seed_corpus.zip "$options_path"
  fi
done

# Code coverage is not supported.
if [[ "$SANITIZER" == "coverage" ]]; then
  exit
fi

LUA_RUNTIME_NAME=luajit
LUAJIT_PATH=build/luajit-v2.1/source/src/$LUA_RUNTIME_NAME
LUA_MODULES_DIR=lua_modules

apt install -y luarocks liblua5.1-0 liblua5.1-0-dev liblua5.1-0-dbg lua5.1

# Required by luzer installed using luarocks.
export OSS_FUZZ=1
luarocks install --lua-version 5.1 --server=https://luarocks.org/dev --tree=$LUA_MODULES_DIR luzer
unset OSS_FUZZ

cp tests/lapi/lib.lua $OUT

LUZER_TESTS_DIR="tests/lapi/"
# Generating test wrappers for luzer-based tests.
for test_path in $(find $LUZER_TESTS_DIR -name "*_test.lua" -type f);
do
  test_file=$(basename $test_path);
  test_name_we="${test_file%.*}";
  # The following tests made for the functions that unsupported by
  # LuaJIT.
  if [[ $test_name_we == "math_tointeger_test" ||
        $test_name_we == "math_ult_test" ||
        $test_name_we == "string_pack_test" ||
        $test_name_we == "string_packsize_test" ||
        $test_name_we == "string_unpack_test" ||
        $test_name_we == "table_pack_test" ||
        $test_name_we == "utf8_char_test" ||
        $test_name_we == "utf8_codepoint_test" ||
        $test_name_we == "utf8_codes_test" ||
        $test_name_we == "utf8_len_test" ||
        $test_name_we == "utf8_offset_test" ]]; then
    continue
  fi
  module_name=$(echo $test_name_we | sed 's/_test//' )
  "$SRC/compile_lua_fuzzer" "$LUA_RUNTIME_NAME" $test_file
  cp "$test_path" "$OUT/"
  corpus_dir="corpus/corpus/$test_name_we"
  if [ -e "$corpus_dir" ]; then
    zip -j $OUT/"$test_name_we"_seed_corpus.zip $corpus_dir/*
    echo "Build corpus '$OUT/"$test_name_we"_seed_corpus.zip' for the test '$test_name_we'"
  fi
done

cp $LUAJIT_PATH "$OUT/$LUA_RUNTIME_NAME"
cp -R $LUA_MODULES_DIR "$OUT/"
