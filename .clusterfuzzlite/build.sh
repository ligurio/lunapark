#!/bin/bash -eu
#
# SPDX-License-Identifier: ISC
# Copyright 2023, Sergey Bronnikov.
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
