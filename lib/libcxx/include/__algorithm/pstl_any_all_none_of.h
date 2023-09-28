//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_ANY_ALL_NONE_OF_H
#define _LIBCPP___ALGORITHM_PSTL_ANY_ALL_NONE_OF_H

#include <__algorithm/pstl_find.h>
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
void __pstl_any_of(); // declaration needed for the frontend dispatch below

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Predicate,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI bool
any_of(_ExecutionPolicy&& __policy, _ForwardIterator __first, _ForwardIterator __last, _Predicate __pred) {
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardIterator);
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_any_of),
      [&](_ForwardIterator __g_first, _ForwardIterator __g_last, _Predicate __g_pred) {
        return std::find_if(__policy, __g_first, __g_last, __g_pred) != __g_last;
      },
      std::move(__first),
      std::move(__last),
      std::move(__pred));
}

template <class>
void __pstl_all_of(); // declaration needed for the frontend dispatch below

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Pred,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI bool
all_of(_ExecutionPolicy&& __policy, _ForwardIterator __first, _ForwardIterator __last, _Pred __pred) {
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardIterator);
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_all_of),
      [&](_ForwardIterator __g_first, _ForwardIterator __g_last, _Pred __g_pred) {
        return !std::any_of(__policy, __g_first, __g_last, [&](__iter_reference<_ForwardIterator> __value) {
          return !__g_pred(__value);
        });
      },
      std::move(__first),
      std::move(__last),
      std::move(__pred));
}

template <class>
void __pstl_none_of(); // declaration needed for the frontend dispatch below

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Pred,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI bool
none_of(_ExecutionPolicy&& __policy, _ForwardIterator __first, _ForwardIterator __last, _Pred __pred) {
  _LIBCPP_REQUIRE_CPP17_FORWARD_ITERATOR(_ForwardIterator);
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_none_of),
      [&](_ForwardIterator __g_first, _ForwardIterator __g_last, _Pred __g_pred) {
        return !std::any_of(__policy, __g_first, __g_last, __g_pred);
      },
      std::move(__first),
      std::move(__last),
      std::move(__pred));
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif // _LIBCPP___ALGORITHM_PSTL_ANY_ALL_NONE_OF_H
