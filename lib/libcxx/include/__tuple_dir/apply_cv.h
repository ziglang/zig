//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TUPLE_APPLY_CV_H
#define _LIBCPP___TUPLE_APPLY_CV_H

#include <__config>
#include <__type_traits/is_const.h>
#include <__type_traits/is_reference.h>
#include <__type_traits/is_volatile.h>
#include <__type_traits/remove_reference.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#ifndef _LIBCPP_CXX03_LANG

_LIBCPP_BEGIN_NAMESPACE_STD

template <bool _ApplyLV, bool _ApplyConst, bool _ApplyVolatile>
struct __apply_cv_mf;
template <>
struct __apply_cv_mf<false, false, false> {
  template <class _Tp> using __apply = _Tp;
};
template <>
struct __apply_cv_mf<false, true, false> {
  template <class _Tp> using __apply _LIBCPP_NODEBUG = const _Tp;
};
template <>
struct __apply_cv_mf<false, false, true> {
  template <class _Tp> using __apply _LIBCPP_NODEBUG = volatile _Tp;
};
template <>
struct __apply_cv_mf<false, true, true> {
  template <class _Tp> using __apply _LIBCPP_NODEBUG = const volatile _Tp;
};
template <>
struct __apply_cv_mf<true, false, false> {
  template <class _Tp> using __apply _LIBCPP_NODEBUG = _Tp&;
};
template <>
struct __apply_cv_mf<true, true, false> {
  template <class _Tp> using __apply _LIBCPP_NODEBUG = const _Tp&;
};
template <>
struct __apply_cv_mf<true, false, true> {
  template <class _Tp> using __apply _LIBCPP_NODEBUG = volatile _Tp&;
};
template <>
struct __apply_cv_mf<true, true, true> {
  template <class _Tp> using __apply _LIBCPP_NODEBUG = const volatile _Tp&;
};
template <class _Tp, class _RawTp = __libcpp_remove_reference_t<_Tp> >
using __apply_cv_t _LIBCPP_NODEBUG = __apply_cv_mf<
    is_lvalue_reference<_Tp>::value,
    is_const<_RawTp>::value,
    is_volatile<_RawTp>::value>;

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP_CXX03_LANG

#endif // _LIBCPP___TUPLE_APPLY_CV_H
