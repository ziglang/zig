// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___CHARCONV_TO_CHARS_RESULT_H
#define _LIBCPP___CHARCONV_TO_CHARS_RESULT_H

#include <__config>
#include <__errc>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#ifndef _LIBCPP_CXX03_LANG

struct _LIBCPP_TYPE_VIS to_chars_result
{
    char* ptr;
    errc ec;
#  if _LIBCPP_STD_VER > 17
    _LIBCPP_HIDE_FROM_ABI friend bool operator==(const to_chars_result&, const to_chars_result&) = default;
#  endif
};

#endif // _LIBCPP_CXX03_LANG

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___CHARCONV_TO_CHARS_RESULT_H
