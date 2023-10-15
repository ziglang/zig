//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_APPLY_CV_H
#define _LIBCPP___TYPE_TRAITS_APPLY_CV_H

#include <__config>
#include <__type_traits/is_const.h>
#include <__type_traits/is_volatile.h>
#include <__type_traits/remove_reference.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp,
          bool = is_const<__libcpp_remove_reference_t<_Tp> >::value,
          bool = is_volatile<__libcpp_remove_reference_t<_Tp> >::value>
struct __apply_cv_impl {
  template <class _Up>
  using __apply _LIBCPP_NODEBUG = _Up;
};

template <class _Tp>
struct __apply_cv_impl<_Tp, true, false> {
  template <class _Up>
  using __apply _LIBCPP_NODEBUG = const _Up;
};

template <class _Tp>
struct __apply_cv_impl<_Tp, false, true> {
  template <class _Up>
  using __apply _LIBCPP_NODEBUG = volatile _Up;
};

template <class _Tp>
struct __apply_cv_impl<_Tp, true, true> {
  template <class _Up>
  using __apply _LIBCPP_NODEBUG = const volatile _Up;
};

template <class _Tp>
struct __apply_cv_impl<_Tp&, false, false> {
  template <class _Up>
  using __apply _LIBCPP_NODEBUG = _Up&;
};

template <class _Tp>
struct __apply_cv_impl<_Tp&, true, false> {
  template <class _Up>
  using __apply _LIBCPP_NODEBUG = const _Up&;
};

template <class _Tp>
struct __apply_cv_impl<_Tp&, false, true> {
  template <class _Up>
  using __apply _LIBCPP_NODEBUG = volatile _Up&;
};

template <class _Tp>
struct __apply_cv_impl<_Tp&, true, true> {
  template <class _Up>
  using __apply _LIBCPP_NODEBUG = const volatile _Up&;
};

template <class _Tp, class _Up>
using __apply_cv_t _LIBCPP_NODEBUG = typename __apply_cv_impl<_Tp>::template __apply<_Up>;

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_APPLY_CV_H
