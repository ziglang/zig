//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_ROTATE_COPY_H
#define _LIBCPP___ALGORITHM_PSTL_ROTATE_COPY_H

#include <__algorithm/pstl_backend.h>
#include <__algorithm/pstl_copy.h>
#include <__algorithm/pstl_frontend_dispatch.h>
#include <__type_traits/is_execution_policy.h>
#include <optional>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

template <class>
void __pstl_rotate_copy();

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _ForwardOutIterator,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI optional<_ForwardOutIterator>
__rotate_copy(_ExecutionPolicy&& __policy,
              _ForwardIterator&& __first,
              _ForwardIterator&& __middle,
              _ForwardIterator&& __last,
              _ForwardOutIterator&& __result) noexcept {
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_rotate_copy, _RawPolicy),
      [&__policy](_ForwardIterator __g_first,
                  _ForwardIterator __g_middle,
                  _ForwardIterator __g_last,
                  _ForwardOutIterator __g_result) -> optional<_ForwardOutIterator> {
        auto __result_mid =
            std::__copy(__policy, _ForwardIterator(__g_middle), std::move(__g_last), std::move(__g_result));
        if (!__result_mid)
          return nullopt;
        return std::__copy(__policy, std::move(__g_first), std::move(__g_middle), *std::move(__result_mid));
      },
      std::move(__first),
      std::move(__middle),
      std::move(__last),
      std::move(__result));
}

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _ForwardOutIterator,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI _ForwardOutIterator rotate_copy(
    _ExecutionPolicy&& __policy,
    _ForwardIterator __first,
    _ForwardIterator __middle,
    _ForwardIterator __last,
    _ForwardOutIterator __result) {
  auto __res =
      std::__rotate_copy(__policy, std::move(__first), std::move(__middle), std::move(__last), std::move(__result));
  if (!__res)
    std::__throw_bad_alloc();
  return *__res;
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_PSTL_ROTATE_COPY_H
