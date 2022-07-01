// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___UTILITY_MOVE_H
#define _LIBCPP___UTILITY_MOVE_H

#include <__config>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR typename remove_reference<_Tp>::type&&
move(_Tp&& __t) _NOEXCEPT {
  typedef _LIBCPP_NODEBUG typename remove_reference<_Tp>::type _Up;
  return static_cast<_Up&&>(__t);
}

#ifndef _LIBCPP_CXX03_LANG
template <class _Tp>
using __move_if_noexcept_result_t =
    typename conditional<!is_nothrow_move_constructible<_Tp>::value && is_copy_constructible<_Tp>::value, const _Tp&,
                         _Tp&&>::type;
#else // _LIBCPP_CXX03_LANG
template <class _Tp>
using __move_if_noexcept_result_t = const _Tp&;
#endif

template <class _Tp>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11 __move_if_noexcept_result_t<_Tp>
move_if_noexcept(_Tp& __x) _NOEXCEPT {
  return _VSTD::move(__x);
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___UTILITY_MOVE_H
