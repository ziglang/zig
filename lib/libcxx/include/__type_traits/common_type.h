//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_COMMON_TYPE_H
#define _LIBCPP___TYPE_TRAITS_COMMON_TYPE_H

#include <__config>
#include <__type_traits/conditional.h>
#include <__type_traits/decay.h>
#include <__type_traits/is_same.h>
#include <__type_traits/remove_cvref.h>
#include <__type_traits/void_t.h>
#include <__utility/declval.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17
// Let COND_RES(X, Y) be:
template <class _Tp, class _Up>
using __cond_type = decltype(false ? declval<_Tp>() : declval<_Up>());

template <class _Tp, class _Up, class = void>
struct __common_type3 {};

// sub-bullet 4 - "if COND_RES(CREF(D1), CREF(D2)) denotes a type..."
template <class _Tp, class _Up>
struct __common_type3<_Tp, _Up, void_t<__cond_type<const _Tp&, const _Up&>>>
{
    using type = remove_cvref_t<__cond_type<const _Tp&, const _Up&>>;
};

template <class _Tp, class _Up, class = void>
struct __common_type2_imp : __common_type3<_Tp, _Up> {};
#else
template <class _Tp, class _Up, class = void>
struct __common_type2_imp {};
#endif

// sub-bullet 3 - "if decay_t<decltype(false ? declval<D1>() : declval<D2>())> ..."
template <class _Tp, class _Up>
struct __common_type2_imp<_Tp, _Up,
                          typename __void_t<decltype(
                                            true ? declval<_Tp>() : declval<_Up>()
                                            )>::type>
{
  typedef _LIBCPP_NODEBUG typename decay<decltype(
                         true ? declval<_Tp>() : declval<_Up>()
                         )>::type type;
};

template <class, class = void>
struct __common_type_impl {};

// Clang provides variadic templates in C++03 as an extension.
#if !defined(_LIBCPP_CXX03_LANG) || defined(__clang__)
# define _LIBCPP_OPTIONAL_PACK(...) , __VA_ARGS__
template <class... _Tp>
struct __common_types;
template <class... _Tp>
struct _LIBCPP_TEMPLATE_VIS common_type;
#else
# define _LIBCPP_OPTIONAL_PACK(...)
struct __no_arg;
template <class _Tp, class _Up, class = __no_arg>
struct __common_types;
template <class _Tp = __no_arg, class _Up = __no_arg, class _Vp = __no_arg,
          class _Unused = __no_arg>
struct common_type {
  static_assert(sizeof(_Unused) == 0,
                "common_type accepts at most 3 arguments in C++03");
};
#endif // _LIBCPP_CXX03_LANG

template <class _Tp, class _Up>
struct __common_type_impl<
    __common_types<_Tp, _Up>,
    typename __void_t<typename common_type<_Tp, _Up>::type>::type>
{
  typedef typename common_type<_Tp, _Up>::type type;
};

template <class _Tp, class _Up, class _Vp _LIBCPP_OPTIONAL_PACK(class... _Rest)>
struct __common_type_impl<
    __common_types<_Tp, _Up, _Vp _LIBCPP_OPTIONAL_PACK(_Rest...)>,
    typename __void_t<typename common_type<_Tp, _Up>::type>::type>
    : __common_type_impl<__common_types<typename common_type<_Tp, _Up>::type,
                                        _Vp _LIBCPP_OPTIONAL_PACK(_Rest...)> > {
};

// bullet 1 - sizeof...(Tp) == 0

template <>
struct _LIBCPP_TEMPLATE_VIS common_type<> {};

// bullet 2 - sizeof...(Tp) == 1

template <class _Tp>
struct _LIBCPP_TEMPLATE_VIS common_type<_Tp>
    : public common_type<_Tp, _Tp> {};

// bullet 3 - sizeof...(Tp) == 2

// sub-bullet 1 - "If is_same_v<T1, D1> is false or ..."
template <class _Tp, class _Up>
struct _LIBCPP_TEMPLATE_VIS common_type<_Tp, _Up>
    : conditional<
        _IsSame<_Tp, typename decay<_Tp>::type>::value && _IsSame<_Up, typename decay<_Up>::type>::value,
        __common_type2_imp<_Tp, _Up>,
        common_type<typename decay<_Tp>::type, typename decay<_Up>::type>
    >::type
{};

// bullet 4 - sizeof...(Tp) > 2

template <class _Tp, class _Up, class _Vp _LIBCPP_OPTIONAL_PACK(class... _Rest)>
struct _LIBCPP_TEMPLATE_VIS
    common_type<_Tp, _Up, _Vp _LIBCPP_OPTIONAL_PACK(_Rest...)>
    : __common_type_impl<
          __common_types<_Tp, _Up, _Vp _LIBCPP_OPTIONAL_PACK(_Rest...)> > {};

#undef _LIBCPP_OPTIONAL_PACK

#if _LIBCPP_STD_VER > 11
template <class ..._Tp> using common_type_t = typename common_type<_Tp...>::type;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_COMMON_TYPE_H
