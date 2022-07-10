//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PARTIAL_SORT_H
#define _LIBCPP___ALGORITHM_PARTIAL_SORT_H

#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__algorithm/make_heap.h>
#include <__algorithm/sift_down.h>
#include <__algorithm/sort_heap.h>
#include <__config>
#include <__iterator/iterator_traits.h>
#include <__utility/swap.h>

#if defined(_LIBCPP_DEBUG_RANDOMIZE_UNSPECIFIED_STABILITY)
#  include <__algorithm/shuffle.h>
#endif

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Compare, class _RandomAccessIterator>
_LIBCPP_CONSTEXPR_AFTER_CXX17 void
__partial_sort(_RandomAccessIterator __first, _RandomAccessIterator __middle, _RandomAccessIterator __last,
               _Compare __comp)
{
    if (__first == __middle)
        return;
    _VSTD::__make_heap<_Compare>(__first, __middle, __comp);
    typename iterator_traits<_RandomAccessIterator>::difference_type __len = __middle - __first;
    for (_RandomAccessIterator __i = __middle; __i != __last; ++__i)
    {
        if (__comp(*__i, *__first))
        {
            swap(*__i, *__first);
            _VSTD::__sift_down<_Compare>(__first, __comp, __len, __first);
        }
    }
    _VSTD::__sort_heap<_Compare>(__first, __middle, __comp);
}

template <class _RandomAccessIterator, class _Compare>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
void
partial_sort(_RandomAccessIterator __first, _RandomAccessIterator __middle, _RandomAccessIterator __last,
             _Compare __comp)
{
  _LIBCPP_DEBUG_RANDOMIZE_RANGE(__first, __last);
  typedef typename __comp_ref_type<_Compare>::type _Comp_ref;
  _VSTD::__partial_sort<_Comp_ref>(__first, __middle, __last, __comp);
  _LIBCPP_DEBUG_RANDOMIZE_RANGE(__middle, __last);
}

template <class _RandomAccessIterator>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
void
partial_sort(_RandomAccessIterator __first, _RandomAccessIterator __middle, _RandomAccessIterator __last)
{
    _VSTD::partial_sort(__first, __middle, __last,
                        __less<typename iterator_traits<_RandomAccessIterator>::value_type>());
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_PARTIAL_SORT_H
