//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_COPY_BACKWARD_H
#define _LIBCPP___ALGORITHM_COPY_BACKWARD_H

#include <__config>
#include <__algorithm/unwrap_iter.h>
#include <__iterator/iterator_traits.h>
#include <cstring>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _BidirectionalIterator, class _OutputIterator>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
_OutputIterator
__copy_backward_constexpr(_BidirectionalIterator __first, _BidirectionalIterator __last, _OutputIterator __result)
{
    while (__first != __last)
        *--__result = *--__last;
    return __result;
}

template <class _BidirectionalIterator, class _OutputIterator>
inline _LIBCPP_INLINE_VISIBILITY
_OutputIterator
__copy_backward(_BidirectionalIterator __first, _BidirectionalIterator __last, _OutputIterator __result)
{
    return _VSTD::__copy_backward_constexpr(__first, __last, __result);
}

template <class _Tp, class _Up>
inline _LIBCPP_INLINE_VISIBILITY
typename enable_if
<
    is_same<typename remove_const<_Tp>::type, _Up>::value &&
    is_trivially_copy_assignable<_Up>::value,
    _Up*
>::type
__copy_backward(_Tp* __first, _Tp* __last, _Up* __result)
{
    const size_t __n = static_cast<size_t>(__last - __first);
    if (__n > 0)
    {
        __result -= __n;
        _VSTD::memmove(__result, __first, __n * sizeof(_Up));
    }
    return __result;
}

template <class _BidirectionalIterator1, class _BidirectionalIterator2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
_BidirectionalIterator2
copy_backward(_BidirectionalIterator1 __first, _BidirectionalIterator1 __last,
              _BidirectionalIterator2 __result)
{
    if (__libcpp_is_constant_evaluated()) {
        return _VSTD::__copy_backward_constexpr(__first, __last, __result);
    } else {
        return _VSTD::__rewrap_iter(__result,
            _VSTD::__copy_backward(_VSTD::__unwrap_iter(__first),
                                   _VSTD::__unwrap_iter(__last),
                                   _VSTD::__unwrap_iter(__result)));
    }
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_COPY_BACKWARD_H
