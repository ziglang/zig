//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PARTITION_H
#define _LIBCPP___ALGORITHM_PARTITION_H

#include <__config>
#include <__iterator/iterator_traits.h>
#include <__utility/swap.h>
#include <utility> // pair
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Predicate, class _ForwardIterator>
_LIBCPP_CONSTEXPR_AFTER_CXX17 _ForwardIterator
__partition(_ForwardIterator __first, _ForwardIterator __last, _Predicate __pred, forward_iterator_tag)
{
    while (true)
    {
        if (__first == __last)
            return __first;
        if (!__pred(*__first))
            break;
        ++__first;
    }
    for (_ForwardIterator __p = __first; ++__p != __last;)
    {
        if (__pred(*__p))
        {
            swap(*__first, *__p);
            ++__first;
        }
    }
    return __first;
}

template <class _Predicate, class _BidirectionalIterator>
_LIBCPP_CONSTEXPR_AFTER_CXX17 _BidirectionalIterator
__partition(_BidirectionalIterator __first, _BidirectionalIterator __last, _Predicate __pred,
            bidirectional_iterator_tag)
{
    while (true)
    {
        while (true)
        {
            if (__first == __last)
                return __first;
            if (!__pred(*__first))
                break;
            ++__first;
        }
        do
        {
            if (__first == --__last)
                return __first;
        } while (!__pred(*__last));
        swap(*__first, *__last);
        ++__first;
    }
}

template <class _ForwardIterator, class _Predicate>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
_ForwardIterator
partition(_ForwardIterator __first, _ForwardIterator __last, _Predicate __pred)
{
    return _VSTD::__partition<typename add_lvalue_reference<_Predicate>::type>
                            (__first, __last, __pred, typename iterator_traits<_ForwardIterator>::iterator_category());
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_PARTITION_H
