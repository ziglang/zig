//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___UTILITY_IN_PLACE_H
#define _LIBCPP___UTILITY_IN_PLACE_H

#include <__config>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 14

struct _LIBCPP_TYPE_VIS in_place_t {
    explicit in_place_t() = default;
};
_LIBCPP_INLINE_VAR constexpr in_place_t in_place{};

template <class _Tp>
struct _LIBCPP_TEMPLATE_VIS in_place_type_t {
    explicit in_place_type_t() = default;
};
template <class _Tp>
_LIBCPP_INLINE_VAR constexpr in_place_type_t<_Tp> in_place_type{};

template <size_t _Idx>
struct _LIBCPP_TEMPLATE_VIS in_place_index_t {
    explicit in_place_index_t() = default;
};
template <size_t _Idx>
_LIBCPP_INLINE_VAR constexpr in_place_index_t<_Idx> in_place_index{};

template <class _Tp> struct __is_inplace_type_imp : false_type {};
template <class _Tp> struct __is_inplace_type_imp<in_place_type_t<_Tp>> : true_type {};

template <class _Tp>
using __is_inplace_type = __is_inplace_type_imp<__uncvref_t<_Tp>>;

template <class _Tp> struct __is_inplace_index_imp : false_type {};
template <size_t _Idx> struct __is_inplace_index_imp<in_place_index_t<_Idx>> : true_type {};

template <class _Tp>
using __is_inplace_index = __is_inplace_index_imp<__uncvref_t<_Tp>>;

#endif // _LIBCPP_STD_VER > 14

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___UTILITY_IN_PLACE_H
