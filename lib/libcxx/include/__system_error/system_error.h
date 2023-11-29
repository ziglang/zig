// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___SYSTEM_ERROR_SYSTEM_ERROR_H
#define _LIBCPP___SYSTEM_ERROR_SYSTEM_ERROR_H

#include <__config>
#include <__system_error/error_category.h>
#include <__system_error/error_code.h>
#include <stdexcept>
#include <string>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

class _LIBCPP_EXPORTED_FROM_ABI system_error : public runtime_error {
  error_code __ec_;

public:
  system_error(error_code __ec, const string& __what_arg);
  system_error(error_code __ec, const char* __what_arg);
  system_error(error_code __ec);
  system_error(int __ev, const error_category& __ecat, const string& __what_arg);
  system_error(int __ev, const error_category& __ecat, const char* __what_arg);
  system_error(int __ev, const error_category& __ecat);
  _LIBCPP_HIDE_FROM_ABI system_error(const system_error&) _NOEXCEPT = default;
  ~system_error() _NOEXCEPT override;

  _LIBCPP_HIDE_FROM_ABI const error_code& code() const _NOEXCEPT { return __ec_; }

private:
  static string __init(const error_code&, string);
};

_LIBCPP_NORETURN _LIBCPP_EXPORTED_FROM_ABI void __throw_system_error(int __ev, const char* __what_arg);

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___SYSTEM_ERROR_SYSTEM_ERROR_H
