//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___LOCALE_DIR_GET_C_LOCALE_H
#define _LIBCPP___LOCALE_DIR_GET_C_LOCALE_H

#include <__config>
#include <__locale_dir/locale_base_api.h>

#if _LIBCPP_HAS_LOCALIZATION

#  if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#    pragma GCC system_header
#  endif

_LIBCPP_BEGIN_NAMESPACE_STD

// FIXME: This should really be part of the locale base API

#  if defined(__APPLE__) || defined(__FreeBSD__)
#    define _LIBCPP_GET_C_LOCALE 0
#  elif defined(__NetBSD__)
#    define _LIBCPP_GET_C_LOCALE LC_C_LOCALE
#  else
#    define _LIBCPP_GET_C_LOCALE __cloc()
// Get the C locale object
_LIBCPP_EXPORTED_FROM_ABI __locale::__locale_t __cloc();
#    define __cloc_defined
#  endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP_HAS_LOCALIZATION

#endif // _LIBCPP___LOCALE_DIR_GET_C_LOCALE_H
