// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMAT_ERROR_H
#define _LIBCPP___FORMAT_FORMAT_ERROR_H

#include <__config>
#include <stdexcept>

#ifdef _LIBCPP_NO_EXCEPTIONS
#include <cstdlib>
#endif

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

class _LIBCPP_EXCEPTION_ABI format_error : public runtime_error {
public:
  _LIBCPP_HIDE_FROM_ABI explicit format_error(const string& __s)
      : runtime_error(__s) {}
  _LIBCPP_HIDE_FROM_ABI explicit format_error(const char* __s)
      : runtime_error(__s) {}
  virtual ~format_error() noexcept;
};

_LIBCPP_NORETURN inline _LIBCPP_HIDE_FROM_ABI void
__throw_format_error(const char* __s) {
#ifndef _LIBCPP_NO_EXCEPTIONS
  throw format_error(__s);
#else
  (void)__s;
  _VSTD::abort();
#endif
}

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FORMAT_FORMAT_ERROR_H
