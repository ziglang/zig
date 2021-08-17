// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ITERATOR_PREV_H
#define _LIBCPP___ITERATOR_PREV_H

#include <__config>
#include <__debug>
#include <__function_like.h>
#include <__iterator/advance.h>
#include <__iterator/concepts.h>
#include <__iterator/incrementable_traits.h>
#include <__iterator/iterator_traits.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _InputIter>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    typename enable_if<__is_cpp17_input_iterator<_InputIter>::value, _InputIter>::type
    prev(_InputIter __x, typename iterator_traits<_InputIter>::difference_type __n = 1) {
  _LIBCPP_ASSERT(__n <= 0 || __is_cpp17_bidirectional_iterator<_InputIter>::value,
                 "Attempt to prev(it, n) with a positive n on a non-bidirectional iterator");
  _VSTD::advance(__x, -__n);
  return __x;
}

#if !defined(_LIBCPP_HAS_NO_RANGES)

namespace ranges {
struct __prev_fn final : private __function_like {
  _LIBCPP_HIDE_FROM_ABI
  constexpr explicit __prev_fn(__tag __x) noexcept : __function_like(__x) {}

  template <bidirectional_iterator _Ip>
  _LIBCPP_HIDE_FROM_ABI
  constexpr _Ip operator()(_Ip __x) const {
    --__x;
    return __x;
  }

  template <bidirectional_iterator _Ip>
  _LIBCPP_HIDE_FROM_ABI
  constexpr _Ip operator()(_Ip __x, iter_difference_t<_Ip> __n) const {
    ranges::advance(__x, -__n);
    return __x;
  }

  template <bidirectional_iterator _Ip>
  _LIBCPP_HIDE_FROM_ABI
  constexpr _Ip operator()(_Ip __x, iter_difference_t<_Ip> __n, _Ip __bound) const {
    ranges::advance(__x, -__n, __bound);
    return __x;
  }
};

inline constexpr auto prev = __prev_fn(__function_like::__tag());
} // namespace ranges

#endif // !defined(_LIBCPP_HAS_NO_RANGES)

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ITERATOR_PREV_H
