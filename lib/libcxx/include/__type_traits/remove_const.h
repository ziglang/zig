//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_REMOVE_CONST_H
#define _LIBCPP___TYPE_TRAITS_REMOVE_CONST_H

#include <__config>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp> struct _LIBCPP_TEMPLATE_VIS remove_const            {typedef _Tp type;};
template <class _Tp> struct _LIBCPP_TEMPLATE_VIS remove_const<const _Tp> {typedef _Tp type;};
#if _LIBCPP_STD_VER > 11
template <class _Tp> using remove_const_t = typename remove_const<_Tp>::type;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_REMOVE_CONST_H
