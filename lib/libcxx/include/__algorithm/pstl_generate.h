//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_GENERATE_H
#define _LIBCPP___ALGORITHM_PSTL_GENERATE_H

#include <__algorithm/pstl_backend.h>
#include <__algorithm/pstl_for_each.h>
#include <__algorithm/pstl_frontend_dispatch.h>
#include <__config>
#include <__iterator/cpp17_iterator_concepts.h>
#include <__iterator/iterator_traits.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/is_execution_policy.h>
#include <__type_traits/remove_cvref.h>
#include <__utility/move.h>
#include <optional>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

template <class>
void __pstl_generate();

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Generator,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI optional<__empty>
__generate(_ExecutionPolicy&& __policy, _ForwardIterator&& __first, _ForwardIterator&& __last, _Generator&& __gen) {
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardIterator);
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_generate, _RawPolicy),
      [&__policy](_ForwardIterator __g_first, _ForwardIterator __g_last, _Generator __g_gen) {
        return std::__for_each(
            __policy, std::move(__g_first), std::move(__g_last), [&](__iter_reference<_ForwardIterator> __element) {
              __element = __g_gen();
            });
      },
      std::move(__first),
      std::move(__last),
      std::move(__gen));
}

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Generator,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI void
generate(_ExecutionPolicy&& __policy, _ForwardIterator __first, _ForwardIterator __last, _Generator __gen) {
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardIterator);
  if (!std::__generate(__policy, std::move(__first), std::move(__last), std::move(__gen)))
    std::__throw_bad_alloc();
}

template <class>
void __pstl_generate_n();

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Size,
          class _Generator,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI optional<__empty>
__generate_n(_ExecutionPolicy&& __policy, _ForwardIterator&& __first, _Size&& __n, _Generator&& __gen) {
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_generate_n, _RawPolicy),
      [&__policy](_ForwardIterator __g_first, _Size __g_n, _Generator __g_gen) {
        return std::__for_each_n(
            __policy, std::move(__g_first), std::move(__g_n), [&](__iter_reference<_ForwardIterator> __element) {
              __element = __g_gen();
            });
      },
      std::move(__first),
      __n,
      std::move(__gen));
}

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Size,
          class _Generator,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI void
generate_n(_ExecutionPolicy&& __policy, _ForwardIterator __first, _Size __n, _Generator __gen) {
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardIterator);
  if (!std::__generate_n(__policy, std::move(__first), std::move(__n), std::move(__gen)))
    std::__throw_bad_alloc();
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_PSTL_GENERATE_H
