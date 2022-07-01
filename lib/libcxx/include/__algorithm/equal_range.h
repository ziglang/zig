//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_EQUAL_RANGE_H
#define _LIBCPP___ALGORITHM_EQUAL_RANGE_H

#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__algorithm/half_positive.h>
#include <__algorithm/lower_bound.h>
#include <__algorithm/upper_bound.h>
#include <__config>
#include <iterator>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Compare, class _ForwardIterator, class _Tp>
_LIBCPP_CONSTEXPR_AFTER_CXX17 pair<_ForwardIterator, _ForwardIterator>
__equal_range(_ForwardIterator __first, _ForwardIterator __last, const _Tp& __value_, _Compare __comp)
{
    typedef typename iterator_traits<_ForwardIterator>::difference_type difference_type;
    difference_type __len = _VSTD::distance(__first, __last);
    while (__len != 0)
    {
        difference_type __l2 = _VSTD::__half_positive(__len);
        _ForwardIterator __m = __first;
        _VSTD::advance(__m, __l2);
        if (__comp(*__m, __value_))
        {
            __first = ++__m;
            __len -= __l2 + 1;
        }
        else if (__comp(__value_, *__m))
        {
            __last = __m;
            __len = __l2;
        }
        else
        {
            _ForwardIterator __mp1 = __m;
            return pair<_ForwardIterator, _ForwardIterator>
                   (
                      _VSTD::__lower_bound<_Compare>(__first, __m, __value_, __comp),
                      _VSTD::__upper_bound<_Compare>(++__mp1, __last, __value_, __comp)
                   );
        }
    }
    return pair<_ForwardIterator, _ForwardIterator>(__first, __first);
}

template <class _ForwardIterator, class _Tp, class _Compare>
_LIBCPP_NODISCARD_EXT inline
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
pair<_ForwardIterator, _ForwardIterator>
equal_range(_ForwardIterator __first, _ForwardIterator __last, const _Tp& __value_, _Compare __comp)
{
    typedef typename __comp_ref_type<_Compare>::type _Comp_ref;
    return _VSTD::__equal_range<_Comp_ref>(__first, __last, __value_, __comp);
}

template <class _ForwardIterator, class _Tp>
_LIBCPP_NODISCARD_EXT inline
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
pair<_ForwardIterator, _ForwardIterator>
equal_range(_ForwardIterator __first, _ForwardIterator __last, const _Tp& __value_)
{
    return _VSTD::equal_range(__first, __last, __value_,
                             __less<typename iterator_traits<_ForwardIterator>::value_type, _Tp>());
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_EQUAL_RANGE_H
