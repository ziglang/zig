//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FUNCTIONAL_UNWRAP_REF_H
#define _LIBCPP___FUNCTIONAL_UNWRAP_REF_H

#include <__config>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp>
struct __unwrap_reference { typedef _LIBCPP_NODEBUG_TYPE _Tp type; };

template <class _Tp>
class reference_wrapper;

template <class _Tp>
struct __unwrap_reference<reference_wrapper<_Tp> > { typedef _LIBCPP_NODEBUG_TYPE _Tp& type; };

template <class _Tp>
struct decay;

#if _LIBCPP_STD_VER > 17
template <class _Tp>
struct unwrap_reference : __unwrap_reference<_Tp> { };

template <class _Tp>
using unwrap_reference_t = typename unwrap_reference<_Tp>::type;

template <class _Tp>
struct unwrap_ref_decay : unwrap_reference<typename decay<_Tp>::type> { };

template <class _Tp>
using unwrap_ref_decay_t = typename unwrap_ref_decay<_Tp>::type;
#endif // > C++17

template <class _Tp>
struct __unwrap_ref_decay
#if _LIBCPP_STD_VER > 17
    : unwrap_ref_decay<_Tp>
#else
    : __unwrap_reference<typename decay<_Tp>::type>
#endif
{ };

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___FUNCTIONAL_UNWRAP_REF_H
