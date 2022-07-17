// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___RANGES_ENABLE_VIEW_H
#define _LIBCPP___RANGES_ENABLE_VIEW_H

#include <__config>
#include <concepts>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_CONCEPTS)

namespace ranges {

struct view_base { };

template<class _Derived>
  requires is_class_v<_Derived> && same_as<_Derived, remove_cv_t<_Derived>>
class view_interface;

template<class _Op, class _Yp>
  requires is_convertible_v<_Op*, view_interface<_Yp>*>
void __is_derived_from_view_interface(const _Op*, const view_interface<_Yp>*);

template <class _Tp>
inline constexpr bool enable_view = derived_from<_Tp, view_base> ||
  requires { ranges::__is_derived_from_view_interface((_Tp*)nullptr, (_Tp*)nullptr); };

} // namespace ranges

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___RANGES_ENABLE_VIEW_H
