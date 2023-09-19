//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_SORT_H
#define _LIBCPP___ALGORITHM_PSTL_SORT_H

#include <__algorithm/pstl_backend.h>
#include <__algorithm/pstl_frontend_dispatch.h>
#include <__algorithm/pstl_stable_sort.h>
#include <__config>
#include <__functional/operations.h>
#include <__type_traits/is_execution_policy.h>
#include <__type_traits/remove_cvref.h>
#include <__utility/forward.h>
#include <__utility/move.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

template <class>
void __pstl_sort();

template <class _ExecutionPolicy,
          class _RandomAccessIterator,
          class _Comp,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI void
sort(_ExecutionPolicy&& __policy, _RandomAccessIterator __first, _RandomAccessIterator __last, _Comp __comp) {
  std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_sort),
      [&__policy](_RandomAccessIterator __g_first, _RandomAccessIterator __g_last, _Comp __g_comp) {
        std::stable_sort(__policy, std::move(__g_first), std::move(__g_last), std::move(__g_comp));
      },
      std::move(__first),
      std::move(__last),
      std::move(__comp));
}

template <class _ExecutionPolicy,
          class _RandomAccessIterator,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI void
sort(_ExecutionPolicy&& __policy, _RandomAccessIterator __first, _RandomAccessIterator __last) {
  std::sort(std::forward<_ExecutionPolicy>(__policy), std::move(__first), std::move(__last), less{});
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif // _LIBCPP___ALGORITHM_PSTL_SORT_H
