//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_FOR_EACH_N_SEGMENT_H
#define _LIBCPP___ALGORITHM_FOR_EACH_N_SEGMENT_H

#include <__config>
#include <__iterator/iterator_traits.h>
#include <__iterator/segmented_iterator.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

// __for_each_n_segment optimizes linear iteration over segmented iterators. It processes a segmented
// input range [__first, __first + __n) by applying the functor __func to each element within the segment.
// The return value of __func is ignored, and the function returns an iterator pointing to one past the
// last processed element in the input range.

template <class _SegmentedIterator, class _Size, class _Functor>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 _SegmentedIterator
__for_each_n_segment(_SegmentedIterator __first, _Size __orig_n, _Functor __func) {
  static_assert(__is_segmented_iterator<_SegmentedIterator>::value &&
                    __has_random_access_iterator_category<
                        typename __segmented_iterator_traits<_SegmentedIterator>::__local_iterator>::value,
                "__for_each_n_segment only works with segmented iterators with random-access local iterators");
  if (__orig_n <= 0)
    return __first;

  using _Traits        = __segmented_iterator_traits<_SegmentedIterator>;
  using __local_iter_t = typename _Traits::__local_iterator;
  using __difference_t = typename std::iterator_traits<__local_iter_t>::difference_type;
  __difference_t __n   = __orig_n;
  auto __seg           = _Traits::__segment(__first);
  auto __local_first   = _Traits::__local(__first);
  __local_iter_t __local_last;

  while (__n > 0) {
    __local_last    = _Traits::__end(__seg);
    auto __seg_size = __local_last - __local_first;
    if (__n <= __seg_size) {
      __local_last = __local_first + __n;
      __func(__local_first, __local_last);
      break;
    }
    __func(__local_first, __local_last);
    __n -= __seg_size;
    __local_first = _Traits::__begin(++__seg);
  }

  return _Traits::__compose(__seg, __local_last);
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_FOR_EACH_N_SEGMENT_H
