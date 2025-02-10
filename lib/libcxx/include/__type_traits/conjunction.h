//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_CONJUNCTION_H
#define _LIBCPP___TYPE_TRAITS_CONJUNCTION_H

#include <__config>
#include <__type_traits/integral_constant.h>
#include <__type_traits/is_same.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <bool>
struct _AndImpl;

template <>
struct _AndImpl<true> {
  template <class _Res, class _First, class... _Rest>
  using _Result _LIBCPP_NODEBUG =
      typename _AndImpl<bool(_First::value) && sizeof...(_Rest) != 0>::template _Result<_First, _Rest...>;
};

template <>
struct _AndImpl<false> {
  template <class _Res, class...>
  using _Result _LIBCPP_NODEBUG = _Res;
};

// _And always performs lazy evaluation of its arguments.
//
// However, `_And<_Pred...>` itself will evaluate its result immediately (without having to
// be instantiated) since it is an alias, unlike `conjunction<_Pred...>`, which is a struct.
// If you want to defer the evaluation of `_And<_Pred...>` itself, use `_Lazy<_And, _Pred...>`.
template <class... _Args>
using _And _LIBCPP_NODEBUG = typename _AndImpl<sizeof...(_Args) != 0>::template _Result<true_type, _Args...>;

template <bool... _Preds>
struct __all_dummy;

template <bool... _Pred>
struct __all : _IsSame<__all_dummy<_Pred...>, __all_dummy<((void)_Pred, true)...> > {};

#if _LIBCPP_STD_VER >= 17

template <class... _Args>
struct _LIBCPP_NO_SPECIALIZATIONS conjunction : _And<_Args...> {};

template <class... _Args>
_LIBCPP_NO_SPECIALIZATIONS inline constexpr bool conjunction_v = _And<_Args...>::value;

#endif // _LIBCPP_STD_VER >= 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_CONJUNCTION_H
