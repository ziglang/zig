//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___UTILITY_NO_DESTROY_H
#define _LIBCPP___UTILITY_NO_DESTROY_H

#include <__config>
#include <__type_traits/is_constant_evaluated.h>
#include <__utility/forward.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

struct __uninitialized_tag {};

// This class stores an object of type _Tp but never destroys it.
//
// This is akin to using __attribute__((no_destroy)), except that it is possible
// to control the lifetime of the object with more flexibility by deciding e.g.
// whether to initialize the object at construction or to defer to a later
// initialization using __emplace.
template <class _Tp>
struct __no_destroy {
  _LIBCPP_CONSTEXPR_SINCE_CXX14 _LIBCPP_HIDE_FROM_ABI explicit __no_destroy(__uninitialized_tag) : __dummy_() {
    if (__libcpp_is_constant_evaluated()) {
      __dummy_ = char();
    }
  }
  _LIBCPP_HIDE_FROM_ABI ~__no_destroy() {
    // nothing
  }

  template <class... _Args>
  _LIBCPP_CONSTEXPR _LIBCPP_HIDE_FROM_ABI explicit __no_destroy(_Args&&... __args)
      : __obj_(std::forward<_Args>(__args)...) {}

  template <class... _Args>
  _LIBCPP_CONSTEXPR_SINCE_CXX14 _LIBCPP_HIDE_FROM_ABI _Tp& __emplace(_Args&&... __args) {
    new (&__obj_) _Tp(std::forward<_Args>(__args)...);
    return __obj_;
  }

  _LIBCPP_CONSTEXPR_SINCE_CXX14 _LIBCPP_HIDE_FROM_ABI _Tp& __get() { return __obj_; }
  _LIBCPP_CONSTEXPR_SINCE_CXX14 _LIBCPP_HIDE_FROM_ABI _Tp const& __get() const { return __obj_; }

private:
  union {
    _Tp __obj_;
    char __dummy_; // so we can initialize a member even with __uninitialized_tag for constexpr-friendliness
  };
};

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___UTILITY_NO_DESTROY_H
