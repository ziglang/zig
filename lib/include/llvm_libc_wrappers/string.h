//===-- Wrapper for C standard string.h declarations on the GPU -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef __CLANG_LLVM_LIBC_WRAPPERS_STRING_H__
#define __CLANG_LLVM_LIBC_WRAPPERS_STRING_H__

#if !defined(_OPENMP) && !defined(__HIP__) && !defined(__CUDA__)
#error "This file is for GPU offloading compilation only"
#endif

// FIXME: The GNU headers provide C++ standard compliant headers when in C++
// mode and the LLVM libc does not. We cannot enable memchr, strchr, strchrnul,
// strpbrk, strrchr, strstr, or strcasestr until this is addressed.
#include_next <string.h>

#if __has_include(<llvm-libc-decls/string.h>)

#if defined(__HIP__) || defined(__CUDA__)
#define __LIBC_ATTRS __attribute__((device))
#endif

#pragma omp begin declare target

#include <llvm-libc-decls/string.h>

#pragma omp end declare target

#undef __LIBC_ATTRS

#endif

#endif // __CLANG_LLVM_LIBC_WRAPPERS_STRING_H__
