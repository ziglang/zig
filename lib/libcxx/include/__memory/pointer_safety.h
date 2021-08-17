// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___MEMORY_POINTER_SAFETY_H
#define _LIBCPP___MEMORY_POINTER_SAFETY_H

#include <__config>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_CXX03_LANG)

enum class pointer_safety : unsigned char {
  relaxed,
  preferred,
  strict
};

inline _LIBCPP_INLINE_VISIBILITY
pointer_safety get_pointer_safety() _NOEXCEPT {
  return pointer_safety::relaxed;
}

_LIBCPP_FUNC_VIS void declare_reachable(void* __p);
_LIBCPP_FUNC_VIS void declare_no_pointers(char* __p, size_t __n);
_LIBCPP_FUNC_VIS void undeclare_no_pointers(char* __p, size_t __n);
_LIBCPP_FUNC_VIS void* __undeclare_reachable(void* __p);

template <class _Tp>
inline _LIBCPP_INLINE_VISIBILITY
_Tp*
undeclare_reachable(_Tp* __p)
{
    return static_cast<_Tp*>(__undeclare_reachable(__p));
}

#endif // !C++03

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___MEMORY_POINTER_SAFETY_H
