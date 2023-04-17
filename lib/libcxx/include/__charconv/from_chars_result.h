// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___CHARCONV_FROM_CHARS_RESULT_H
#define _LIBCPP___CHARCONV_FROM_CHARS_RESULT_H

#include <__config>
#include <__errc>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 14

struct _LIBCPP_TYPE_VIS from_chars_result
{
    const char* ptr;
    errc ec;
#  if _LIBCPP_STD_VER > 17
    _LIBCPP_HIDE_FROM_ABI friend bool operator==(const from_chars_result&, const from_chars_result&) = default;
#  endif
};

#endif // _LIBCPP_STD_VER > 14

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___CHARCONV_FROM_CHARS_RESULT_H
