//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_HAS_UNIQUE_OBJECT_REPRESENTATION_H
#define _LIBCPP___TYPE_TRAITS_HAS_UNIQUE_OBJECT_REPRESENTATION_H

#include <__config>
#include <__type_traits/integral_constant.h>
#include <__type_traits/remove_all_extents.h>
#include <__type_traits/remove_cv.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER >= 17

template <class _Tp>
struct _LIBCPP_TEMPLATE_VIS has_unique_object_representations
    : public integral_constant<bool, __has_unique_object_representations(remove_cv_t<remove_all_extents_t<_Tp>>)> {};

template <class _Tp>
inline constexpr bool has_unique_object_representations_v = has_unique_object_representations<_Tp>::value;

#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_HAS_UNIQUE_OBJECT_REPRESENTATION_H
