//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_FILL_H
#define _LIBCPP___ALGORITHM_PSTL_FILL_H

#include <__algorithm/fill_n.h>
#include <__algorithm/pstl_for_each.h>
#include <__algorithm/pstl_frontend_dispatch.h>
#include <__config>
#include <__iterator/cpp17_iterator_concepts.h>
#include <__iterator/iterator_traits.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/is_execution_policy.h>
#include <__type_traits/remove_cvref.h>
#include <__utility/move.h>
#include <__utility/terminate_on_exception.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

template <class>
void __pstl_fill(); // declaration needed for the frontend dispatch below

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Tp,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI void
fill(_ExecutionPolicy&& __policy, _ForwardIterator __first, _ForwardIterator __last, const _Tp& __value) {
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardIterator);
  std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_fill),
      [&](_ForwardIterator __g_first, _ForwardIterator __g_last, const _Tp& __g_value) {
        std::for_each(__policy, __g_first, __g_last, [&](__iter_reference<_ForwardIterator> __element) {
          __element = __g_value;
        });
      },
      std::move(__first),
      std::move(__last),
      __value);
}

template <class>
void __pstl_fill_n(); // declaration needed for the frontend dispatch below

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _SizeT,
          class _Tp,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI void
fill_n(_ExecutionPolicy&& __policy, _ForwardIterator __first, _SizeT __n, const _Tp& __value) {
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardIterator);
  std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_fill_n),
      [&](_ForwardIterator __g_first, _SizeT __g_n, const _Tp& __g_value) {
        if constexpr (__has_random_access_iterator_category<_ForwardIterator>::value)
          std::fill(__policy, __g_first, __g_first + __g_n, __g_value);
        else
          std::fill_n(__g_first, __g_n, __g_value);
      },
      std::move(__first),
      __n,
      __value);
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif // _LIBCPP___ALGORITHM_PSTL_FILL_H
