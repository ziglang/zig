//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___NUMERIC_PSTL_TRANSFORM_REDUCE_H
#define _LIBCPP___NUMERIC_PSTL_TRANSFORM_REDUCE_H

#include <__algorithm/pstl_backend.h>
#include <__algorithm/pstl_frontend_dispatch.h>
#include <__config>
#include <__functional/operations.h>
#include <__numeric/transform_reduce.h>
#include <__type_traits/is_execution_policy.h>
#include <__utility/move.h>
#include <optional>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _Tp,
          class _BinaryOperation1,
          class _BinaryOperation2,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI optional<_Tp> __transform_reduce(
    _ExecutionPolicy&&,
    _ForwardIterator1&& __first1,
    _ForwardIterator1&& __last1,
    _ForwardIterator2&& __first2,
    _Tp&& __init,
    _BinaryOperation1&& __reduce,
    _BinaryOperation2&& __transform) noexcept {
  using _Backend = typename __select_backend<_RawPolicy>::type;
  return std::__pstl_transform_reduce<_RawPolicy>(
      _Backend{},
      std::move(__first1),
      std::move(__last1),
      std::move(__first2),
      std::move(__init),
      std::move(__reduce),
      std::move(__transform));
}

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _Tp,
          class _BinaryOperation1,
          class _BinaryOperation2,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI _Tp transform_reduce(
    _ExecutionPolicy&& __policy,
    _ForwardIterator1 __first1,
    _ForwardIterator1 __last1,
    _ForwardIterator2 __first2,
    _Tp __init,
    _BinaryOperation1 __reduce,
    _BinaryOperation2 __transform) {
  auto __res = std::__transform_reduce(
      __policy,
      std::move(__first1),
      std::move(__last1),
      std::move(__first2),
      std::move(__init),
      std::move(__reduce),
      std::move(__transform));

  if (!__res)
    std::__throw_bad_alloc();
  return *std::move(__res);
}

// This overload doesn't get a customization point because it's trivial to detect (through e.g.
// __desugars_to) when specializing the more general variant, which should always be preferred
template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _Tp,
          enable_if_t<is_execution_policy_v<__remove_cvref_t<_ExecutionPolicy>>, int> = 0>
_LIBCPP_HIDE_FROM_ABI _Tp transform_reduce(
    _ExecutionPolicy&& __policy,
    _ForwardIterator1 __first1,
    _ForwardIterator1 __last1,
    _ForwardIterator2 __first2,
    _Tp __init) {
  return std::transform_reduce(__policy, __first1, __last1, __first2, __init, plus{}, multiplies{});
}

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Tp,
          class _BinaryOperation,
          class _UnaryOperation,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI optional<__remove_cvref_t<_Tp>> __transform_reduce(
    _ExecutionPolicy&&,
    _ForwardIterator&& __first,
    _ForwardIterator&& __last,
    _Tp&& __init,
    _BinaryOperation&& __reduce,
    _UnaryOperation&& __transform) noexcept {
  using _Backend = typename __select_backend<_RawPolicy>::type;
  return std::__pstl_transform_reduce<_RawPolicy>(
      _Backend{},
      std::move(__first),
      std::move(__last),
      std::move(__init),
      std::move(__reduce),
      std::move(__transform));
}

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Tp,
          class _BinaryOperation,
          class _UnaryOperation,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI _Tp transform_reduce(
    _ExecutionPolicy&& __policy,
    _ForwardIterator __first,
    _ForwardIterator __last,
    _Tp __init,
    _BinaryOperation __reduce,
    _UnaryOperation __transform) {
  auto __res = std::__transform_reduce(
      __policy, std::move(__first), std::move(__last), std::move(__init), std::move(__reduce), std::move(__transform));
  if (!__res)
    std::__throw_bad_alloc();
  return *std::move(__res);
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_POP_MACROS

#endif // _LIBCPP___NUMERIC_PSTL_TRANSFORM_REDUCE_H
