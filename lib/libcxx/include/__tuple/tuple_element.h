//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TUPLE_TUPLE_ELEMENT_H
#define _LIBCPP___TUPLE_TUPLE_ELEMENT_H

#include <__config>
#include <__tuple/tuple_indices.h>
#include <__tuple/tuple_types.h>
#include <__type_traits/add_const.h>
#include <__type_traits/add_cv.h>
#include <__type_traits/add_volatile.h>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <size_t _Ip, class _Tp>
struct _LIBCPP_TEMPLATE_VIS tuple_element;

template <size_t _Ip, class _Tp>
struct _LIBCPP_TEMPLATE_VIS tuple_element<_Ip, const _Tp> {
  typedef _LIBCPP_NODEBUG typename add_const<typename tuple_element<_Ip, _Tp>::type>::type type;
};

template <size_t _Ip, class _Tp>
struct _LIBCPP_TEMPLATE_VIS tuple_element<_Ip, volatile _Tp> {
  typedef _LIBCPP_NODEBUG typename add_volatile<typename tuple_element<_Ip, _Tp>::type>::type type;
};

template <size_t _Ip, class _Tp>
struct _LIBCPP_TEMPLATE_VIS tuple_element<_Ip, const volatile _Tp> {
  typedef _LIBCPP_NODEBUG typename add_cv<typename tuple_element<_Ip, _Tp>::type>::type type;
};

#ifndef _LIBCPP_CXX03_LANG

#  if !__has_builtin(__type_pack_element)

namespace __indexer_detail {

template <size_t _Idx, class _Tp>
struct __indexed {
  using type _LIBCPP_NODEBUG = _Tp;
};

template <class _Types, class _Indexes>
struct __indexer;

template <class... _Types, size_t... _Idx>
struct __indexer<__tuple_types<_Types...>, __tuple_indices<_Idx...>> : __indexed<_Idx, _Types>... {};

template <size_t _Idx, class _Tp>
__indexed<_Idx, _Tp> __at_index(__indexed<_Idx, _Tp> const&);

} // namespace __indexer_detail

template <size_t _Idx, class... _Types>
using __type_pack_element _LIBCPP_NODEBUG = typename decltype(__indexer_detail::__at_index<_Idx>(
    __indexer_detail::__indexer< __tuple_types<_Types...>,
                                 typename __make_tuple_indices<sizeof...(_Types)>::type >{}))::type;
#  endif

template <size_t _Ip, class... _Types>
struct _LIBCPP_TEMPLATE_VIS tuple_element<_Ip, __tuple_types<_Types...> > {
  static_assert(_Ip < sizeof...(_Types), "tuple_element index out of range");
  typedef _LIBCPP_NODEBUG __type_pack_element<_Ip, _Types...> type;
};

#  if _LIBCPP_STD_VER >= 14
template <size_t _Ip, class... _Tp>
using tuple_element_t _LIBCPP_NODEBUG = typename tuple_element<_Ip, _Tp...>::type;
#  endif

#endif // _LIBCPP_CXX03_LANG

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TUPLE_TUPLE_ELEMENT_H
