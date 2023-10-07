//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_TRANSFORM_H
#define _LIBCPP___ALGORITHM_PSTL_TRANSFORM_H

#include <__algorithm/pstl_backend.h>
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

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _ForwardOutIterator,
          class _UnaryOperation,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI _ForwardOutIterator transform(
    _ExecutionPolicy&&,
    _ForwardIterator __first,
    _ForwardIterator __last,
    _ForwardOutIterator __result,
    _UnaryOperation __op) {
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardIterator);
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardOutIterator);
  _LIBCPP_REQUIRE_CPP17_OUTPUT_ITERATOR(_ForwardOutIterator, decltype(__op(*__first)));
  using _Backend = typename __select_backend<_RawPolicy>::type;
  return std::__pstl_transform<_RawPolicy>(
      _Backend{}, std::move(__first), std::move(__last), std::move(__result), std::move(__op));
}

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _ForwardOutIterator,
          class _BinaryOperation,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI _ForwardOutIterator transform(
    _ExecutionPolicy&&,
    _ForwardIterator1 __first1,
    _ForwardIterator1 __last1,
    _ForwardIterator2 __first2,
    _ForwardOutIterator __result,
    _BinaryOperation __op) {
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardIterator1);
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardIterator2);
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardOutIterator);
  _LIBCPP_REQUIRE_CPP17_OUTPUT_ITERATOR(_ForwardOutIterator, decltype(__op(*__first1, *__first2)));
  using _Backend = typename __select_backend<_RawPolicy>::type;
  return std::__pstl_transform<_RawPolicy>(
      _Backend{}, std::move(__first1), std::move(__last1), std::move(__first2), std::move(__result), std::move(__op));
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif // _LIBCPP___ALGORITHM_PSTL_TRANSFORM_H
