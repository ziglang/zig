//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_IS_MEMBER_FUNCTION_POINTER_H
#define _LIBCPP___TYPE_TRAITS_IS_MEMBER_FUNCTION_POINTER_H

#include <__config>
#include <__type_traits/integral_constant.h>
#include <__type_traits/is_function.h>
#include <__type_traits/remove_cv.h>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp> struct __libcpp_is_member_pointer {
  enum {
    __is_member = false,
    __is_func = false,
    __is_obj = false
  };
};
template <class _Tp, class _Up> struct __libcpp_is_member_pointer<_Tp _Up::*> {
  enum {
    __is_member = true,
    __is_func = is_function<_Tp>::value,
    __is_obj = !__is_func,
  };
};

#if __has_builtin(__is_member_function_pointer)

template<class _Tp>
struct _LIBCPP_TEMPLATE_VIS is_member_function_pointer
    : _BoolConstant<__is_member_function_pointer(_Tp)> { };

#if _LIBCPP_STD_VER > 14
template <class _Tp>
inline constexpr bool is_member_function_pointer_v = __is_member_function_pointer(_Tp);
#endif

#else // __has_builtin(__is_member_function_pointer)

template <class _Tp> struct _LIBCPP_TEMPLATE_VIS is_member_function_pointer
    : public _BoolConstant< __libcpp_is_member_pointer<typename remove_cv<_Tp>::type>::__is_func > {};

#if _LIBCPP_STD_VER > 14
template <class _Tp>
inline constexpr bool is_member_function_pointer_v = is_member_function_pointer<_Tp>::value;
#endif

#endif // __has_builtin(__is_member_function_pointer)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_IS_MEMBER_FUNCTION_POINTER_H
