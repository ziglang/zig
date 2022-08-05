//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PREV_PERMUTATION_H
#define _LIBCPP___ALGORITHM_PREV_PERMUTATION_H

#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__algorithm/reverse.h>
#include <__config>
#include <__iterator/iterator_traits.h>
#include <__utility/swap.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Compare, class _BidirectionalIterator>
_LIBCPP_CONSTEXPR_AFTER_CXX17 bool
__prev_permutation(_BidirectionalIterator __first, _BidirectionalIterator __last, _Compare __comp)
{
    _BidirectionalIterator __i = __last;
    if (__first == __last || __first == --__i)
        return false;
    while (true)
    {
        _BidirectionalIterator __ip1 = __i;
        if (__comp(*__ip1, *--__i))
        {
            _BidirectionalIterator __j = __last;
            while (!__comp(*--__j, *__i))
                ;
            swap(*__i, *__j);
            _VSTD::reverse(__ip1, __last);
            return true;
        }
        if (__i == __first)
        {
            _VSTD::reverse(__first, __last);
            return false;
        }
    }
}

template <class _BidirectionalIterator, class _Compare>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
bool
prev_permutation(_BidirectionalIterator __first, _BidirectionalIterator __last, _Compare __comp)
{
    typedef typename __comp_ref_type<_Compare>::type _Comp_ref;
    return _VSTD::__prev_permutation<_Comp_ref>(__first, __last, __comp);
}

template <class _BidirectionalIterator>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
bool
prev_permutation(_BidirectionalIterator __first, _BidirectionalIterator __last)
{
    return _VSTD::prev_permutation(__first, __last,
                                  __less<typename iterator_traits<_BidirectionalIterator>::value_type>());
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_PREV_PERMUTATION_H
