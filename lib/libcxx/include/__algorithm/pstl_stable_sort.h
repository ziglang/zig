//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_STABLE_SORT_H
#define _LIBCPP___ALGORITHM_PSTL_STABLE_SORT_H

#include <__algorithm/pstl_backend.h>
#include <__config>
#include <__functional/operations.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/is_execution_policy.h>
#include <__type_traits/remove_cvref.h>
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
          class _RandomAccessIterator,
          class _Comp                                         = less<>,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI optional<__empty> __stable_sort(
    _ExecutionPolicy&&, _RandomAccessIterator&& __first, _RandomAccessIterator&& __last, _Comp&& __comp = {}) noexcept {
  using _Backend = typename __select_backend<_RawPolicy>::type;
  return std::__pstl_stable_sort<_RawPolicy>(_Backend{}, std::move(__first), std::move(__last), std::move(__comp));
}

template <class _ExecutionPolicy,
          class _RandomAccessIterator,
          class _Comp                                         = less<>,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI void stable_sort(
    _ExecutionPolicy&& __policy, _RandomAccessIterator __first, _RandomAccessIterator __last, _Comp __comp = {}) {
  if (!std::__stable_sort(__policy, std::move(__first), std::move(__last), std::move(__comp)))
    std::__throw_bad_alloc();
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_PSTL_STABLE_SORT_H
