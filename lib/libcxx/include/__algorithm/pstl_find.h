//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_FIND_H
#define _LIBCPP___ALGORITHM_PSTL_FIND_H

#include <__algorithm/comp.h>
#include <__algorithm/find.h>
#include <__algorithm/pstl_backend.h>
#include <__algorithm/pstl_frontend_dispatch.h>
#include <__config>
#include <__iterator/cpp17_iterator_concepts.h>
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

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Predicate,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI optional<__remove_cvref_t<_ForwardIterator>>
__find_if(_ExecutionPolicy&&, _ForwardIterator&& __first, _ForwardIterator&& __last, _Predicate&& __pred) noexcept {
  using _Backend = typename __select_backend<_RawPolicy>::type;
  return std::__pstl_find_if<_RawPolicy>(_Backend{}, std::move(__first), std::move(__last), std::move(__pred));
}

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Predicate,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI _ForwardIterator
find_if(_ExecutionPolicy&& __policy, _ForwardIterator __first, _ForwardIterator __last, _Predicate __pred) {
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardIterator);
  auto __res = std::__find_if(__policy, std::move(__first), std::move(__last), std::move(__pred));
  if (!__res)
    std::__throw_bad_alloc();
  return *std::move(__res);
}

template <class>
void __pstl_find_if_not();

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Predicate,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI optional<__remove_cvref_t<_ForwardIterator>>
__find_if_not(_ExecutionPolicy&& __policy, _ForwardIterator&& __first, _ForwardIterator&& __last, _Predicate&& __pred) {
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_find_if_not, _RawPolicy),
      [&](_ForwardIterator&& __g_first, _ForwardIterator&& __g_last, _Predicate&& __g_pred)
          -> optional<__remove_cvref_t<_ForwardIterator>> {
        return std::__find_if(
            __policy, __g_first, __g_last, [&](__iter_reference<__remove_cvref_t<_ForwardIterator>> __value) {
              return !__g_pred(__value);
            });
      },
      std::move(__first),
      std::move(__last),
      std::move(__pred));
}

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Predicate,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI _ForwardIterator
find_if_not(_ExecutionPolicy&& __policy, _ForwardIterator __first, _ForwardIterator __last, _Predicate __pred) {
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardIterator);
  auto __res = std::__find_if_not(__policy, std::move(__first), std::move(__last), std::move(__pred));
  if (!__res)
    std::__throw_bad_alloc();
  return *std::move(__res);
}

template <class>
void __pstl_find();

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Tp,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI optional<__remove_cvref_t<_ForwardIterator>>
__find(_ExecutionPolicy&& __policy, _ForwardIterator __first, _ForwardIterator __last, const _Tp& __value) noexcept {
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_find, _RawPolicy),
      [&](_ForwardIterator __g_first, _ForwardIterator __g_last, const _Tp& __g_value) -> optional<_ForwardIterator> {
        return std::find_if(
            __policy, __g_first, __g_last, [&](__iter_reference<__remove_cvref_t<_ForwardIterator>> __element) {
              return __element == __g_value;
            });
      },
      std::move(__first),
      std::move(__last),
      __value);
}

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Tp,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI _ForwardIterator
find(_ExecutionPolicy&& __policy, _ForwardIterator __first, _ForwardIterator __last, const _Tp& __value) {
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardIterator);
  auto __res = std::__find(__policy, std::move(__first), std::move(__last), __value);
  if (!__res)
    std::__throw_bad_alloc();
  return *std::move(__res);
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_PSTL_FIND_H
