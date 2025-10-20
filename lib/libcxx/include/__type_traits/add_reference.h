//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_ADD_REFERENCE_H
#define _LIBCPP___TYPE_TRAITS_ADD_REFERENCE_H

#include <__config>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp>
struct _LIBCPP_NO_SPECIALIZATIONS add_lvalue_reference {
  using type _LIBCPP_NODEBUG = __add_lvalue_reference(_Tp);
};

#ifdef _LIBCPP_COMPILER_GCC
template <class _Tp>
using __add_lvalue_reference_t _LIBCPP_NODEBUG = typename add_lvalue_reference<_Tp>::type;
#else
template <class _Tp>
using __add_lvalue_reference_t _LIBCPP_NODEBUG = __add_lvalue_reference(_Tp);
#endif

#if _LIBCPP_STD_VER >= 14
template <class _Tp>
using add_lvalue_reference_t = __add_lvalue_reference_t<_Tp>;
#endif

template <class _Tp>
struct _LIBCPP_NO_SPECIALIZATIONS add_rvalue_reference {
  using type _LIBCPP_NODEBUG = __add_rvalue_reference(_Tp);
};

#ifdef _LIBCPP_COMPILER_GCC
template <class _Tp>
using __add_rvalue_reference_t _LIBCPP_NODEBUG = typename add_rvalue_reference<_Tp>::type;
#else
template <class _Tp>
using __add_rvalue_reference_t _LIBCPP_NODEBUG = __add_rvalue_reference(_Tp);
#endif

#if _LIBCPP_STD_VER >= 14
template <class _Tp>
using add_rvalue_reference_t = __add_rvalue_reference_t<_Tp>;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_ADD_REFERENCE_H
