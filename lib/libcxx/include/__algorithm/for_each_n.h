// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_FOR_EACH_N_H
#define _LIBCPP___ALGORITHM_FOR_EACH_N_H

#include <__config>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 14

template <class _InputIterator, class _Size, class _Function>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 _InputIterator for_each_n(_InputIterator __first,
                                                                                         _Size __orig_n,
                                                                                         _Function __f) {
  typedef decltype(_VSTD::__convert_to_integral(__orig_n)) _IntegralSize;
  _IntegralSize __n = __orig_n;
  while (__n > 0) {
    __f(*__first);
    ++__first;
    --__n;
  }
  return __first;
}

#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_FOR_EACH_N_H
