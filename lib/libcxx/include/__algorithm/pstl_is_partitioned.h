//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_IS_PARITTIONED
#define _LIBCPP___ALGORITHM_PSTL_IS_PARITTIONED

#include <__algorithm/pstl_any_all_none_of.h>
#include <__algorithm/pstl_backend.h>
#include <__algorithm/pstl_find.h>
#include <__algorithm/pstl_frontend_dispatch.h>
#include <__config>
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
void __pstl_is_partitioned();

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Predicate,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI optional<bool> __is_partitioned(
    _ExecutionPolicy&& __policy, _ForwardIterator&& __first, _ForwardIterator&& __last, _Predicate&& __pred) {
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_is_partitioned, _RawPolicy),
      [&__policy](_ForwardIterator __g_first, _ForwardIterator __g_last, _Predicate __g_pred) {
        __g_first = std::find_if_not(__policy, __g_first, __g_last, __g_pred);
        if (__g_first == __g_last)
          return true;
        ++__g_first;
        return std::none_of(__policy, __g_first, __g_last, __g_pred);
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
_LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI bool
is_partitioned(_ExecutionPolicy&& __policy, _ForwardIterator __first, _ForwardIterator __last, _Predicate __pred) {
  auto __res = std::__is_partitioned(__policy, std::move(__first), std::move(__last), std::move(__pred));
  if (!__res)
    std::__throw_bad_alloc();
  return *std::move(__res);
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_PSTL_IS_PARITTIONED
