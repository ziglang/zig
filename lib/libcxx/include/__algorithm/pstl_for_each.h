//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_FOR_EACH_H
#define _LIBCPP___ALGORITHM_PSTL_FOR_EACH_H

#include <__algorithm/for_each.h>
#include <__algorithm/for_each_n.h>
#include <__algorithm/pstl_backend.h>
#include <__algorithm/pstl_frontend_dispatch.h>
#include <__config>
#include <__iterator/concepts.h>
#include <__iterator/cpp17_iterator_concepts.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/is_execution_policy.h>
#include <__type_traits/remove_cvref.h>
#include <__type_traits/void_t.h>
#include <__utility/empty.h>
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
          class _ForwardIterator,
          class _Function,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI optional<__empty>
__for_each(_ExecutionPolicy&&, _ForwardIterator&& __first, _ForwardIterator&& __last, _Function&& __func) noexcept {
  using _Backend = typename __select_backend<_RawPolicy>::type;
  return std::__pstl_for_each<_RawPolicy>(_Backend{}, std::move(__first), std::move(__last), std::move(__func));
}

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Function,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI void
for_each(_ExecutionPolicy&& __policy, _ForwardIterator __first, _ForwardIterator __last, _Function __func) {
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardIterator);
  if (!std::__for_each(__policy, std::move(__first), std::move(__last), std::move(__func)))
    std::__throw_bad_alloc();
}

template <class>
void __pstl_for_each_n(); // declaration needed for the frontend dispatch below

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Size,
          class _Function,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI optional<__empty>
__for_each_n(_ExecutionPolicy&& __policy, _ForwardIterator&& __first, _Size&& __size, _Function&& __func) noexcept {
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_for_each_n, _RawPolicy),
      [&](_ForwardIterator __g_first, _Size __g_size, _Function __g_func) -> optional<__empty> {
        if constexpr (__has_random_access_iterator_category_or_concept<_ForwardIterator>::value) {
          std::for_each(__policy, std::move(__g_first), __g_first + __g_size, std::move(__g_func));
          return __empty{};
        } else {
          std::for_each_n(std::move(__g_first), __g_size, std::move(__g_func));
          return __empty{};
        }
      },
      std::move(__first),
      std::move(__size),
      std::move(__func));
}

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Size,
          class _Function,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI void
for_each_n(_ExecutionPolicy&& __policy, _ForwardIterator __first, _Size __size, _Function __func) {
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardIterator);
  auto __res = std::__for_each_n(__policy, std::move(__first), std::move(__size), std::move(__func));
  if (!__res)
    std::__throw_bad_alloc();
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_PSTL_FOR_EACH_H
