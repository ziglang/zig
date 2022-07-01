// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___MBSTATE_T_H
#define _LIBCPP___MBSTATE_T_H

#include <__config>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

// TODO(ldionne):
// The goal of this header is to provide mbstate_t without having to pull in
// <wchar.h> or <uchar.h>. This is necessary because we need that type even
// when we don't have (or try to provide) support for wchar_t, because several
// types like std::fpos are defined in terms of mbstate_t.
//
// This is a gruesome hack, but I don't know how to make it cleaner for
// the time being.

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
#   include <wchar.h> // for mbstate_t
#elif __has_include(<bits/types/mbstate_t.h>)
#   include <bits/types/mbstate_t.h> // works on most Unixes
#elif __has_include(<sys/_types/_mbstate_t.h>)
#   include <sys/_types/_mbstate_t.h> // works on Darwin
#else
#   error "The library was configured without support for wide-characters, but we don't know how to get the definition of mbstate_t without <wchar.h> on your platform."
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

using ::mbstate_t _LIBCPP_USING_IF_EXISTS;

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___MBSTATE_T_H
