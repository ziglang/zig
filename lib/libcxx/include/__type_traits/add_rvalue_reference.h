//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_ADD_RVALUE_REFERENCE_H
#define _LIBCPP___TYPE_TRAITS_ADD_RVALUE_REFERENCE_H

#include <__config>
#include <__type_traits/is_referenceable.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp, bool = __is_referenceable<_Tp>::value> struct __add_rvalue_reference_impl            { typedef _LIBCPP_NODEBUG _Tp   type; };
template <class _Tp                                       > struct __add_rvalue_reference_impl<_Tp, true> { typedef _LIBCPP_NODEBUG _Tp&& type; };

template <class _Tp> struct _LIBCPP_TEMPLATE_VIS add_rvalue_reference
{typedef _LIBCPP_NODEBUG typename __add_rvalue_reference_impl<_Tp>::type type;};

#if _LIBCPP_STD_VER > 11
template <class _Tp> using add_rvalue_reference_t = typename add_rvalue_reference<_Tp>::type;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_ADD_RVALUE_REFERENCE_H
