// -*- C++ -*-
//===--------------------------- stddef.h ---------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#if defined(__need_ptrdiff_t) || defined(__need_size_t) || \
    defined(__need_wchar_t) || defined(__need_NULL) || defined(__need_wint_t)

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

#include_next <stddef.h>

#elif !defined(_LIBCPP_STDDEF_H)
#define _LIBCPP_STDDEF_H

/*
    stddef.h synopsis

Macros:

    offsetof(type,member-designator)
    NULL

Types:

    ptrdiff_t
    size_t
    max_align_t
    nullptr_t

*/

#include <__config>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

#include_next <stddef.h>

#ifdef __cplusplus

extern "C++" {
#include <__nullptr>
using std::nullptr_t;
}

// Re-use the compiler's <stddef.h> max_align_t where possible.
#if !defined(__CLANG_MAX_ALIGN_T_DEFINED) && !defined(_GCC_MAX_ALIGN_T) && \
    !defined(__DEFINED_max_align_t) && !defined(__NetBSD__)
typedef long double max_align_t;
#endif

#endif

#endif  // _LIBCPP_STDDEF_H
