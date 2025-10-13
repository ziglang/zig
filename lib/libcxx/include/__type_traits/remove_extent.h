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

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp>
struct _LIBCPP_NO_SPECIALIZATIONS remove_extent {
  using type _LIBCPP_NODEBUG = __remove_extent(_Tp);
};

#ifdef _LIBCPP_COMPILER_GCC
template <class _Tp>
using __remove_extent_t _LIBCPP_NODEBUG = typename remove_extent<_Tp>::type;
#else
template <class _Tp>
using __remove_extent_t _LIBCPP_NODEBUG = __remove_extent(_Tp);
#endif

#if _LIBCPP_STD_VER >= 14
template <class _Tp>
using remove_extent_t = __remove_extent_t<_Tp>;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_REMOVE_EXTENT_H
