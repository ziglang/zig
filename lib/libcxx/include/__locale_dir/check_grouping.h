//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___LOCALE_DIR_CHECK_GROUPING_H
#define _LIBCPP___LOCALE_DIR_CHECK_GROUPING_H

#include <__config>
#include <__fwd/string.h>
#include <ios>

#if _LIBCPP_HAS_LOCALIZATION

#  if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#    pragma GCC system_header
#  endif

_LIBCPP_BEGIN_NAMESPACE_STD

_LIBCPP_EXPORTED_FROM_ABI void
__check_grouping(const string& __grouping, unsigned* __g, unsigned* __g_end, ios_base::iostate& __err);

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP_HAS_LOCALIZATION

#endif // _LIBCPP___LOCALE_DIR_CHECK_GROUPING_H
