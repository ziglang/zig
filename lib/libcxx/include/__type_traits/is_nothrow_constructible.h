//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_IS_NOTHROW_CONSTRUCTIBLE_H
#define _LIBCPP___TYPE_TRAITS_IS_NOTHROW_CONSTRUCTIBLE_H

#include <__config>
#include <__type_traits/integral_constant.h>
#include <__type_traits/is_constructible.h>
#include <__type_traits/is_reference.h>
#include <__utility/declval.h>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

// GCC is disabled due to https://gcc.gnu.org/bugzilla/show_bug.cgi?id=106611
#if __has_builtin(__is_nothrow_constructible) && !defined(_LIBCPP_COMPILER_GCC)

template < class _Tp, class... _Args>
struct _LIBCPP_TEMPLATE_VIS is_nothrow_constructible
    : public integral_constant<bool, __is_nothrow_constructible(_Tp, _Args...)> {};
#else

template <bool, bool, class _Tp, class... _Args>
struct __libcpp_is_nothrow_constructible;

template <class _Tp, class... _Args>
struct __libcpp_is_nothrow_constructible</*is constructible*/ true, /*is reference*/ false, _Tp, _Args...>
    : public integral_constant<bool, noexcept(_Tp(std::declval<_Args>()...))> {};

template <class _Tp>
void __implicit_conversion_to(_Tp) noexcept {}

template <class _Tp, class _Arg>
struct __libcpp_is_nothrow_constructible</*is constructible*/ true, /*is reference*/ true, _Tp, _Arg>
    : public integral_constant<bool, noexcept(std::__implicit_conversion_to<_Tp>(std::declval<_Arg>()))> {};

template <class _Tp, bool _IsReference, class... _Args>
struct __libcpp_is_nothrow_constructible</*is constructible*/ false, _IsReference, _Tp, _Args...> : public false_type {
};

template <class _Tp, class... _Args>
struct _LIBCPP_TEMPLATE_VIS is_nothrow_constructible
    : __libcpp_is_nothrow_constructible<is_constructible<_Tp, _Args...>::value,
                                        is_reference<_Tp>::value,
                                        _Tp,
                                        _Args...> {};

template <class _Tp, size_t _Ns>
struct _LIBCPP_TEMPLATE_VIS is_nothrow_constructible<_Tp[_Ns]>
    : __libcpp_is_nothrow_constructible<is_constructible<_Tp>::value, is_reference<_Tp>::value, _Tp> {};

#endif // __has_builtin(__is_nothrow_constructible)

#if _LIBCPP_STD_VER >= 17
template <class _Tp, class... _Args>
inline constexpr bool is_nothrow_constructible_v = is_nothrow_constructible<_Tp, _Args...>::value;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_IS_NOTHROW_CONSTRUCTIBLE_H
