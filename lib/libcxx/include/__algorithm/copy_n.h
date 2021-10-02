//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_COPY_N_H
#define _LIBCPP___ALGORITHM_COPY_N_H

#include <__config>
#include <__algorithm/copy.h>
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

template<class _InputIterator, class _Size, class _OutputIterator>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
typename enable_if
<
    __is_cpp17_input_iterator<_InputIterator>::value &&
   !__is_cpp17_random_access_iterator<_InputIterator>::value,
    _OutputIterator
>::type
copy_n(_InputIterator __first, _Size __orig_n, _OutputIterator __result)
{
    typedef decltype(_VSTD::__convert_to_integral(__orig_n)) _IntegralSize;
    _IntegralSize __n = __orig_n;
    if (__n > 0)
    {
        *__result = *__first;
        ++__result;
        for (--__n; __n > 0; --__n)
        {
            ++__first;
            *__result = *__first;
            ++__result;
        }
    }
    return __result;
}

template<class _InputIterator, class _Size, class _OutputIterator>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
typename enable_if
<
    __is_cpp17_random_access_iterator<_InputIterator>::value,
    _OutputIterator
>::type
copy_n(_InputIterator __first, _Size __orig_n, _OutputIterator __result)
{
    typedef decltype(_VSTD::__convert_to_integral(__orig_n)) _IntegralSize;
    _IntegralSize __n = __orig_n;
    return _VSTD::copy(__first, __first + __n, __result);
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_COPY_N_H
