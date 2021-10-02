//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PUSH_HEAP_H
#define _LIBCPP___ALGORITHM_PUSH_HEAP_H

#include <__config>
#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__iterator/iterator_traits.h>
#include <__utility/move.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Compare, class _RandomAccessIterator>
_LIBCPP_CONSTEXPR_AFTER_CXX11 void
__sift_up(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp,
          typename iterator_traits<_RandomAccessIterator>::difference_type __len)
{
    typedef typename iterator_traits<_RandomAccessIterator>::value_type value_type;
    if (__len > 1)
    {
        __len = (__len - 2) / 2;
        _RandomAccessIterator __ptr = __first + __len;
        if (__comp(*__ptr, *--__last))
        {
            value_type __t(_VSTD::move(*__last));
            do
            {
                *__last = _VSTD::move(*__ptr);
                __last = __ptr;
                if (__len == 0)
                    break;
                __len = (__len - 1) / 2;
                __ptr = __first + __len;
            } while (__comp(*__ptr, __t));
            *__last = _VSTD::move(__t);
        }
    }
}

template <class _RandomAccessIterator, class _Compare>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
void
push_heap(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp)
{
    typedef typename __comp_ref_type<_Compare>::type _Comp_ref;
    _VSTD::__sift_up<_Comp_ref>(__first, __last, __comp, __last - __first);
}

template <class _RandomAccessIterator>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
void
push_heap(_RandomAccessIterator __first, _RandomAccessIterator __last)
{
    _VSTD::push_heap(__first, __last, __less<typename iterator_traits<_RandomAccessIterator>::value_type>());
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_PUSH_HEAP_H
