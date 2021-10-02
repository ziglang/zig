//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PARTIAL_SORT_COPY_H
#define _LIBCPP___ALGORITHM_PARTIAL_SORT_COPY_H

#include <__config>
#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__algorithm/make_heap.h>
#include <__algorithm/sift_down.h>
#include <__algorithm/sort_heap.h>
#include <__iterator/iterator_traits.h>
#include <type_traits> // swap

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Compare, class _InputIterator, class _RandomAccessIterator>
_LIBCPP_CONSTEXPR_AFTER_CXX17 _RandomAccessIterator
__partial_sort_copy(_InputIterator __first, _InputIterator __last,
                    _RandomAccessIterator __result_first, _RandomAccessIterator __result_last, _Compare __comp)
{
    _RandomAccessIterator __r = __result_first;
    if (__r != __result_last)
    {
        for (; __first != __last && __r != __result_last; ++__first, (void) ++__r)
            *__r = *__first;
        _VSTD::__make_heap<_Compare>(__result_first, __r, __comp);
        typename iterator_traits<_RandomAccessIterator>::difference_type __len = __r - __result_first;
        for (; __first != __last; ++__first)
            if (__comp(*__first, *__result_first))
            {
                *__result_first = *__first;
                _VSTD::__sift_down<_Compare>(__result_first, __r, __comp, __len, __result_first);
            }
        _VSTD::__sort_heap<_Compare>(__result_first, __r, __comp);
    }
    return __r;
}

template <class _InputIterator, class _RandomAccessIterator, class _Compare>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
_RandomAccessIterator
partial_sort_copy(_InputIterator __first, _InputIterator __last,
                  _RandomAccessIterator __result_first, _RandomAccessIterator __result_last, _Compare __comp)
{
    typedef typename __comp_ref_type<_Compare>::type _Comp_ref;
    return _VSTD::__partial_sort_copy<_Comp_ref>(__first, __last, __result_first, __result_last, __comp);
}

template <class _InputIterator, class _RandomAccessIterator>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
_RandomAccessIterator
partial_sort_copy(_InputIterator __first, _InputIterator __last,
                  _RandomAccessIterator __result_first, _RandomAccessIterator __result_last)
{
    return _VSTD::partial_sort_copy(__first, __last, __result_first, __result_last,
                                   __less<typename iterator_traits<_RandomAccessIterator>::value_type>());
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_PARTIAL_SORT_COPY_H
