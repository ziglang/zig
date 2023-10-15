//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_CLAMP_H
#define _LIBCPP___ALGORITHM_CLAMP_H

#include <__algorithm/comp.h>
#include <__assert>
#include <__config>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER >= 17
template<class _Tp, class _Compare>
_LIBCPP_NODISCARD_EXT inline
_LIBCPP_INLINE_VISIBILITY constexpr
const _Tp&
clamp(const _Tp& __v, const _Tp& __lo, const _Tp& __hi, _Compare __comp)
{
    _LIBCPP_ASSERT_UNCATEGORIZED(!__comp(__hi, __lo), "Bad bounds passed to std::clamp");
    return __comp(__v, __lo) ? __lo : __comp(__hi, __v) ? __hi : __v;

}

template<class _Tp>
_LIBCPP_NODISCARD_EXT inline
_LIBCPP_INLINE_VISIBILITY constexpr
const _Tp&
clamp(const _Tp& __v, const _Tp& __lo, const _Tp& __hi)
{
    return _VSTD::clamp(__v, __lo, __hi, __less<>());
}
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_CLAMP_H
