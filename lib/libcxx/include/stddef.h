// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#if defined(__need_ptrdiff_t) || defined(__need_size_t) || \
    defined(__need_wchar_t) || defined(__need_NULL) || defined(__need_wint_t)

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
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
    max_align_t // C++11
    nullptr_t

*/

#include <__config>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#  if __has_include_next(<stddef.h>)
#    include_next <stddef.h>
#  endif

#ifdef __cplusplus
    typedef decltype(nullptr) nullptr_t;
#endif

#endif // _LIBCPP_STDDEF_H
