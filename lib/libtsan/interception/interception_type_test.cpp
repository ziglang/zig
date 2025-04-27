//===-- interception_type_test.cpp ------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file is a part of AddressSanitizer, an address sanity checker.
//
// Compile-time tests of the internal type definitions.
//===----------------------------------------------------------------------===//

#include "interception.h"
#include "sanitizer_common/sanitizer_type_traits.h"

#if __has_include(<sys/types.h>)
#  include <sys/types.h>
#endif
#include <stddef.h>
#include <stdint.h>

COMPILER_CHECK((__sanitizer::is_same<__sanitizer::uptr, ::uintptr_t>::value));
COMPILER_CHECK((__sanitizer::is_same<__sanitizer::sptr, ::intptr_t>::value));
COMPILER_CHECK((__sanitizer::is_same<__sanitizer::usize, ::size_t>::value));
COMPILER_CHECK((__sanitizer::is_same<::PTRDIFF_T, ::ptrdiff_t>::value));
COMPILER_CHECK((__sanitizer::is_same<::SIZE_T, ::size_t>::value));
#if !SANITIZER_WINDOWS
// No ssize_t on Windows.
COMPILER_CHECK((__sanitizer::is_same<::SSIZE_T, ::ssize_t>::value));
#endif
// TODO: These are not actually the same type on Linux (long vs long long)
COMPILER_CHECK(sizeof(::INTMAX_T) == sizeof(intmax_t));
COMPILER_CHECK(sizeof(::UINTMAX_T) == sizeof(uintmax_t));

#if SANITIZER_GLIBC || SANITIZER_ANDROID
COMPILER_CHECK(sizeof(::OFF64_T) == sizeof(off64_t));
#endif

// The following are the cases when pread (and friends) is used instead of
// pread64. In those cases we need OFF_T to match off_t. We don't care about the
// rest (they depend on _FILE_OFFSET_BITS setting when building an application).
#if !SANITIZER_WINDOWS && (SANITIZER_ANDROID || !defined _FILE_OFFSET_BITS || \
                           _FILE_OFFSET_BITS != 64)
COMPILER_CHECK(sizeof(::OFF_T) == sizeof(off_t));
#endif
