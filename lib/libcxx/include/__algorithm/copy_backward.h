//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_COPY_BACKWARD_H
#define _LIBCPP___ALGORITHM_COPY_BACKWARD_H

#include <__algorithm/copy.h>
#include <__algorithm/iterator_operations.h>
#include <__algorithm/ranges_copy.h>
#include <__algorithm/unwrap_iter.h>
#include <__concepts/same_as.h>
#include <__config>
#include <__iterator/iterator_traits.h>
#include <__iterator/reverse_iterator.h>
#include <__ranges/subrange.h>
#include <__utility/move.h>
#include <__utility/pair.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _AlgPolicy, class _InputIterator, class _OutputIterator,
          __enable_if_t<is_same<_AlgPolicy, _ClassicAlgPolicy>::value, int> = 0>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 pair<_InputIterator, _OutputIterator>
__copy_backward(_InputIterator __first, _InputIterator __last, _OutputIterator __result) {
  auto __ret = std::__copy(
      __unconstrained_reverse_iterator<_InputIterator>(__last),
      __unconstrained_reverse_iterator<_InputIterator>(__first),
      __unconstrained_reverse_iterator<_OutputIterator>(__result));
  return pair<_InputIterator, _OutputIterator>(__ret.first.base(), __ret.second.base());
}

#if _LIBCPP_STD_VER > 17 && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)
template <class _AlgPolicy, class _Iter1, class _Sent1, class _Iter2,
          __enable_if_t<is_same<_AlgPolicy, _RangeAlgPolicy>::value, int> = 0>
_LIBCPP_HIDE_FROM_ABI constexpr pair<_Iter1, _Iter2> __copy_backward(_Iter1 __first, _Sent1 __last, _Iter2 __result) {
  auto __last_iter     = _IterOps<_AlgPolicy>::next(__first, std::move(__last));
  auto __reverse_range = std::__reverse_range(std::ranges::subrange(std::move(__first), __last_iter));
  auto __ret           = ranges::copy(std::move(__reverse_range), std::make_reverse_iterator(__result));
  return std::make_pair(__last_iter, __ret.out.base());
}
#endif // _LIBCPP_STD_VER > 17 && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

template <class _BidirectionalIterator1, class _BidirectionalIterator2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17 _BidirectionalIterator2
copy_backward(_BidirectionalIterator1 __first, _BidirectionalIterator1 __last, _BidirectionalIterator2 __result) {
  return std::__copy_backward<_ClassicAlgPolicy>(__first, __last, __result).second;
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_COPY_BACKWARD_H
