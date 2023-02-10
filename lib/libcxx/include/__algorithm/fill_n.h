//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_FILL_N_H
#define _LIBCPP___ALGORITHM_FILL_N_H

#include <__config>
#include <__iterator/iterator_traits.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

// fill_n isn't specialized for std::memset, because the compiler already optimizes the loop to a call to std::memset.

template <class _OutputIterator, class _Size, class _Tp>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
_OutputIterator
__fill_n(_OutputIterator __first, _Size __n, const _Tp& __value)
{
    for (; __n > 0; ++__first, (void) --__n)
        *__first = __value;
    return __first;
}

template <class _OutputIterator, class _Size, class _Tp>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
_OutputIterator
fill_n(_OutputIterator __first, _Size __n, const _Tp& __value)
{
   return _VSTD::__fill_n(__first, _VSTD::__convert_to_integral(__n), __value);
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_FILL_N_H
