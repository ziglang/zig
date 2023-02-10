// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ITERATOR_NEXT_H
#define _LIBCPP___ITERATOR_NEXT_H

#include <__assert>
#include <__config>
#include <__iterator/advance.h>
#include <__iterator/concepts.h>
#include <__iterator/incrementable_traits.h>
#include <__iterator/iterator_traits.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _InputIter>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    typename enable_if<__is_cpp17_input_iterator<_InputIter>::value, _InputIter>::type
    next(_InputIter __x, typename iterator_traits<_InputIter>::difference_type __n = 1) {
  _LIBCPP_ASSERT(__n >= 0 || __is_cpp17_bidirectional_iterator<_InputIter>::value,
                 "Attempt to next(it, n) with negative n on a non-bidirectional iterator");

  _VSTD::advance(__x, __n);
  return __x;
}

#if _LIBCPP_STD_VER > 17 && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

// [range.iter.op.next]

namespace ranges {
namespace __next {

struct __fn {
  template <input_or_output_iterator _Ip>
  _LIBCPP_HIDE_FROM_ABI
  constexpr _Ip operator()(_Ip __x) const {
    ++__x;
    return __x;
  }

  template <input_or_output_iterator _Ip>
  _LIBCPP_HIDE_FROM_ABI
  constexpr _Ip operator()(_Ip __x, iter_difference_t<_Ip> __n) const {
    ranges::advance(__x, __n);
    return __x;
  }

  template <input_or_output_iterator _Ip, sentinel_for<_Ip> _Sp>
  _LIBCPP_HIDE_FROM_ABI constexpr _Ip operator()(_Ip __x, _Sp __bound_sentinel) const {
    ranges::advance(__x, __bound_sentinel);
    return __x;
  }

  template <input_or_output_iterator _Ip, sentinel_for<_Ip> _Sp>
  _LIBCPP_HIDE_FROM_ABI constexpr _Ip operator()(_Ip __x, iter_difference_t<_Ip> __n, _Sp __bound_sentinel) const {
    ranges::advance(__x, __n, __bound_sentinel);
    return __x;
  }
};

} // namespace __next

inline namespace __cpo {
  inline constexpr auto next = __next::__fn{};
} // namespace __cpo
} // namespace ranges

#endif // _LIBCPP_STD_VER > 17 && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ITERATOR_NEXT_H
