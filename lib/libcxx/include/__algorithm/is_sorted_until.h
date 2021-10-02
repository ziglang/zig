//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_IS_SORTED_UNTIL_H
#define _LIBCPP___ALGORITHM_IS_SORTED_UNTIL_H

#include <__config>
#include <__algorithm/comp.h>
#include <__iterator/iterator_traits.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _ForwardIterator, class _Compare>
_LIBCPP_NODISCARD_EXT _LIBCPP_CONSTEXPR_AFTER_CXX17 _ForwardIterator
is_sorted_until(_ForwardIterator __first, _ForwardIterator __last, _Compare __comp)
{
    if (__first != __last)
    {
        _ForwardIterator __i = __first;
        while (++__i != __last)
        {
            if (__comp(*__i, *__first))
                return __i;
            __first = __i;
        }
    }
    return __last;
}

template<class _ForwardIterator>
_LIBCPP_NODISCARD_EXT inline
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
_ForwardIterator
is_sorted_until(_ForwardIterator __first, _ForwardIterator __last)
{
    return _VSTD::is_sorted_until(__first, __last, __less<typename iterator_traits<_ForwardIterator>::value_type>());
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_IS_SORTED_UNTIL_H
