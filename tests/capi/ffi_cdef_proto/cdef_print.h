/*
 * SPDX-License-Identifier: ISC
 *
 * Copyright 2023-2026, Sergey Bronnikov
 */
#pragma once

#include <string>

#include "cdef.pb.h"

namespace ffi_cdef_proto {

/**
 * Fuzzing parameters:
 *
 * kMaxStrLength - upper bound for generating string literals and identifiers.
 * kMaxIdentifiers - max number of unique generated identifiers.
 * kDefaultIdent - default name for identifier.
 *
 * Default values were chosen arbitrary but not too big for better readability
 * of generated code samples.
 */
constexpr std::size_t kMaxCounterValue = 5;
constexpr size_t kMaxStrLength = 20;
constexpr size_t kMaxIdentifiers = 10;
constexpr char kDefaultIdent[] = "Name";

/**
 * Entry point for the serializer. Generates a C declarations from a
 * protobuf message.
 */
std::string
MainDefinitionsToString(const cdef::Declarations &def);

} /* namespace ffi_cdef_proto */
