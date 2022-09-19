//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include <__config>
#include <cstdio>
#include <cstdlib>
#include <string>

// This file defines the legacy default debug handler and related mechanisms
// to set it. This is for backwards ABI compatibility with code that has been
// using this debug handler previously.

_LIBCPP_BEGIN_NAMESPACE_STD

struct _LIBCPP_TEMPLATE_VIS __libcpp_debug_info {
  _LIBCPP_EXPORTED_FROM_ABI string what() const;

  const char* __file_;
  int __line_;
  const char* __pred_;
  const char* __msg_;
};

std::string __libcpp_debug_info::what() const {
  string msg = __file_;
  msg += ":" + std::to_string(__line_) + ": _LIBCPP_ASSERT '";
  msg += __pred_;
  msg += "' failed. ";
  msg += __msg_;
  return msg;
}

_LIBCPP_NORETURN _LIBCPP_EXPORTED_FROM_ABI void __libcpp_abort_debug_function(__libcpp_debug_info const& info) {
  std::fprintf(stderr, "%s\n", info.what().c_str());
  std::abort();
}

typedef void (*__libcpp_debug_function_type)(__libcpp_debug_info const&);

_LIBCPP_EXPORTED_FROM_ABI
constinit __libcpp_debug_function_type __libcpp_debug_function = __libcpp_abort_debug_function;

_LIBCPP_EXPORTED_FROM_ABI
bool __libcpp_set_debug_function(__libcpp_debug_function_type __func) {
  __libcpp_debug_function = __func;
  return true;
}

_LIBCPP_END_NAMESPACE_STD
