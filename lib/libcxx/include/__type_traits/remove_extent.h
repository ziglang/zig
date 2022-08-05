//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_REMOVE_EXTENT_H
#define _LIBCPP___TYPE_TRAITS_REMOVE_EXTENT_H

#include <__config>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp> struct _LIBCPP_TEMPLATE_VIS remove_extent
    {typedef _Tp type;};
template <class _Tp> struct _LIBCPP_TEMPLATE_VIS remove_extent<_Tp[]>
    {typedef _Tp type;};
template <class _Tp, size_t _Np> struct _LIBCPP_TEMPLATE_VIS remove_extent<_Tp[_Np]>
    {typedef _Tp type;};

#if _LIBCPP_STD_VER > 11
template <class _Tp> using remove_extent_t = typename remove_extent<_Tp>::type;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_REMOVE_EXTENT_H
