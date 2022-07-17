//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_MAX_H
#define _LIBCPP___ALGORITHM_MAX_H

#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__algorithm/max_element.h>
#include <__config>
#include <initializer_list>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp, class _Compare>
_LIBCPP_NODISCARD_EXT inline
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
const _Tp&
max(const _Tp& __a, const _Tp& __b, _Compare __comp)
{
    return __comp(__a, __b) ? __b : __a;
}

template <class _Tp>
_LIBCPP_NODISCARD_EXT inline
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
const _Tp&
max(const _Tp& __a, const _Tp& __b)
{
    return _VSTD::max(__a, __b, __less<_Tp>());
}

#ifndef _LIBCPP_CXX03_LANG

template<class _Tp, class _Compare>
_LIBCPP_NODISCARD_EXT inline
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
_Tp
max(initializer_list<_Tp> __t, _Compare __comp)
{
    typedef typename __comp_ref_type<_Compare>::type _Comp_ref;
    return *_VSTD::__max_element<_Comp_ref>(__t.begin(), __t.end(), __comp);
}

template<class _Tp>
_LIBCPP_NODISCARD_EXT inline
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
_Tp
max(initializer_list<_Tp> __t)
{
    return *_VSTD::max_element(__t.begin(), __t.end(), __less<_Tp>());
}

#endif // _LIBCPP_CXX03_LANG

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_MAX_H
