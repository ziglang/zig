//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___MEMORY_SWAP_ALLOCATOR_H
#define _LIBCPP___MEMORY_SWAP_ALLOCATOR_H

#include <__config>
#include <__memory/allocator_traits.h>
#include <__type_traits/integral_constant.h>
#include <__utility/swap.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <typename _Alloc>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 void __swap_allocator(_Alloc& __a1, _Alloc& __a2, true_type)
#if _LIBCPP_STD_VER > 11
    _NOEXCEPT
#else
    _NOEXCEPT_(__is_nothrow_swappable<_Alloc>::value)
#endif
{
  using _VSTD::swap;
  swap(__a1, __a2);
}

template <typename _Alloc>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 void
__swap_allocator(_Alloc&, _Alloc&, false_type) _NOEXCEPT {}

template <typename _Alloc>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 void __swap_allocator(_Alloc& __a1, _Alloc& __a2)
#if _LIBCPP_STD_VER > 11
    _NOEXCEPT
#else
    _NOEXCEPT_(__is_nothrow_swappable<_Alloc>::value)
#endif
{
  _VSTD::__swap_allocator(
      __a1, __a2, integral_constant<bool, allocator_traits<_Alloc>::propagate_on_container_swap::value>());
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___MEMORY_SWAP_ALLOCATOR_H
