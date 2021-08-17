//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_MINMAX_H
#define _LIBCPP___ALGORITHM_MINMAX_H

#include <__config>
#include <__algorithm/comp.h>
#include <initializer_list>
#include <utility>


#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template<class _Tp, class _Compare>
_LIBCPP_NODISCARD_EXT inline
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
pair<const _Tp&, const _Tp&>
minmax(const _Tp& __a, const _Tp& __b, _Compare __comp)
{
    return __comp(__b, __a) ? pair<const _Tp&, const _Tp&>(__b, __a) :
                              pair<const _Tp&, const _Tp&>(__a, __b);
}

template<class _Tp>
_LIBCPP_NODISCARD_EXT inline
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
pair<const _Tp&, const _Tp&>
minmax(const _Tp& __a, const _Tp& __b)
{
    return _VSTD::minmax(__a, __b, __less<_Tp>());
}

#ifndef _LIBCPP_CXX03_LANG

template<class _Tp, class _Compare>
_LIBCPP_NODISCARD_EXT inline
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
pair<_Tp, _Tp>
minmax(initializer_list<_Tp> __t, _Compare __comp)
{
    typedef typename initializer_list<_Tp>::const_iterator _Iter;
    _Iter __first = __t.begin();
    _Iter __last  = __t.end();
    pair<_Tp, _Tp> __result(*__first, *__first);

    ++__first;
    if (__t.size() % 2 == 0)
    {
        if (__comp(*__first,  __result.first))
            __result.first  = *__first;
        else
            __result.second = *__first;
        ++__first;
    }

    while (__first != __last)
    {
        _Tp __prev = *__first++;
        if (__comp(*__first, __prev)) {
            if ( __comp(*__first, __result.first)) __result.first  = *__first;
            if (!__comp(__prev, __result.second))  __result.second = __prev;
            }
        else {
            if ( __comp(__prev, __result.first))    __result.first  = __prev;
            if (!__comp(*__first, __result.second)) __result.second = *__first;
            }

        __first++;
    }
    return __result;
}

template<class _Tp>
_LIBCPP_NODISCARD_EXT inline
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
pair<_Tp, _Tp>
minmax(initializer_list<_Tp> __t)
{
    return _VSTD::minmax(__t, __less<_Tp>());
}

#endif // _LIBCPP_CXX03_LANG

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_MINMAX_H
