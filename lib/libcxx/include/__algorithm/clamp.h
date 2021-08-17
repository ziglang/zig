//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_CLAMP_H
#define _LIBCPP___ALGORITHM_CLAMP_H

#include <__config>
#include <__debug>
#include <__algorithm/comp.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 14
// clamp
template<class _Tp, class _Compare>
_LIBCPP_NODISCARD_EXT inline
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR
const _Tp&
clamp(const _Tp& __v, const _Tp& __lo, const _Tp& __hi, _Compare __comp)
{
    _LIBCPP_ASSERT(!__comp(__hi, __lo), "Bad bounds passed to std::clamp");
    return __comp(__v, __lo) ? __lo : __comp(__hi, __v) ? __hi : __v;

}

template<class _Tp>
_LIBCPP_NODISCARD_EXT inline
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR
const _Tp&
clamp(const _Tp& __v, const _Tp& __lo, const _Tp& __hi)
{
    return _VSTD::clamp(__v, __lo, __hi, __less<_Tp>());
}
#endif

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_CLAMP_H
