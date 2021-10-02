//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_MAKE_HEAP_H
#define _LIBCPP___ALGORITHM_MAKE_HEAP_H

#include <__config>
#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__algorithm/sift_down.h>
#include <__iterator/iterator_traits.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Compare, class _RandomAccessIterator>
_LIBCPP_CONSTEXPR_AFTER_CXX11 void
__make_heap(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp)
{
    typedef typename iterator_traits<_RandomAccessIterator>::difference_type difference_type;
    difference_type __n = __last - __first;
    if (__n > 1)
    {
        // start from the first parent, there is no need to consider children
        for (difference_type __start = (__n - 2) / 2; __start >= 0; --__start)
        {
            _VSTD::__sift_down<_Compare>(__first, __last, __comp, __n, __first + __start);
        }
    }
}

template <class _RandomAccessIterator, class _Compare>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
void
make_heap(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp)
{
    typedef typename __comp_ref_type<_Compare>::type _Comp_ref;
    _VSTD::__make_heap<_Comp_ref>(__first, __last, __comp);
}

template <class _RandomAccessIterator>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
void
make_heap(_RandomAccessIterator __first, _RandomAccessIterator __last)
{
    _VSTD::make_heap(__first, __last, __less<typename iterator_traits<_RandomAccessIterator>::value_type>());
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_MAKE_HEAP_H
