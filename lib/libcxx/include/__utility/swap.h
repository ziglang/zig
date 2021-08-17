//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___UTILITY_SWAP_H
#define _LIBCPP___UTILITY_SWAP_H

#include <__config>
#include <__utility/declval.h>
#include <__utility/move.h>
#include <type_traits>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#ifndef _LIBCPP_CXX03_LANG
template <class _Tp>
using __swap_result_t = typename enable_if<is_move_constructible<_Tp>::value && is_move_assignable<_Tp>::value>::type;
#else
template <class>
using __swap_result_t = void;
#endif

template <class _Tp>
inline _LIBCPP_INLINE_VISIBILITY __swap_result_t<_Tp> _LIBCPP_CONSTEXPR_AFTER_CXX17 swap(_Tp& __x, _Tp& __y)
    _NOEXCEPT_(is_nothrow_move_constructible<_Tp>::value&& is_nothrow_move_assignable<_Tp>::value) {
  _Tp __t(_VSTD::move(__x));
  __x = _VSTD::move(__y);
  __y = _VSTD::move(__t);
}

template <class _Tp, size_t _Np>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 typename enable_if<__is_swappable<_Tp>::value>::type
swap(_Tp (&__a)[_Np], _Tp (&__b)[_Np]) _NOEXCEPT_(__is_nothrow_swappable<_Tp>::value) {
  for (size_t __i = 0; __i != _Np; ++__i) {
    swap(__a[__i], __b[__i]);
  }
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___UTILITY_SWAP_H
