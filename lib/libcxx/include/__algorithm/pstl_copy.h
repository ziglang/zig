//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_COPY_H
#define _LIBCPP___ALGORITHM_PSTL_COPY_H

#include <__algorithm/copy_n.h>
#include <__algorithm/pstl_backend.h>
#include <__algorithm/pstl_frontend_dispatch.h>
#include <__algorithm/pstl_transform.h>
#include <__config>
#include <__functional/identity.h>
#include <__iterator/concepts.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/is_constant_evaluated.h>
#include <__type_traits/is_execution_policy.h>
#include <__type_traits/is_trivially_copyable.h>
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

// TODO: Use the std::copy/move shenanigans to forward to std::memmove

template <class>
void __pstl_copy();

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _ForwardOutIterator,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI optional<_ForwardOutIterator>
__copy(_ExecutionPolicy&& __policy,
       _ForwardIterator&& __first,
       _ForwardIterator&& __last,
       _ForwardOutIterator&& __result) noexcept {
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_copy, _RawPolicy),
      [&__policy](_ForwardIterator __g_first, _ForwardIterator __g_last, _ForwardOutIterator __g_result) {
        return std::__transform(__policy, __g_first, __g_last, __g_result, __identity());
      },
      std::move(__first),
      std::move(__last),
      std::move(__result));
}

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _ForwardOutIterator,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI _ForwardOutIterator
copy(_ExecutionPolicy&& __policy, _ForwardIterator __first, _ForwardIterator __last, _ForwardOutIterator __result) {
  auto __res = std::__copy(__policy, std::move(__first), std::move(__last), std::move(__result));
  if (!__res)
    std::__throw_bad_alloc();
  return *std::move(__res);
}

template <class>
void __pstl_copy_n();

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _ForwardOutIterator,
          class _Size,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI optional<_ForwardOutIterator> __copy_n(
    _ExecutionPolicy&& __policy, _ForwardIterator&& __first, _Size&& __n, _ForwardOutIterator&& __result) noexcept {
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_copy_n, _RawPolicy),
      [&__policy](
          _ForwardIterator __g_first, _Size __g_n, _ForwardOutIterator __g_result) -> optional<_ForwardIterator> {
        if constexpr (__has_random_access_iterator_category_or_concept<_ForwardIterator>::value)
          return std::__copy(__policy, std::move(__g_first), std::move(__g_first + __g_n), std::move(__g_result));
        else
          return std::copy_n(__g_first, __g_n, __g_result);
      },
      std::move(__first),
      std::move(__n),
      std::move(__result));
}

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _ForwardOutIterator,
          class _Size,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI _ForwardOutIterator
copy_n(_ExecutionPolicy&& __policy, _ForwardIterator __first, _Size __n, _ForwardOutIterator __result) {
  auto __res = std::__copy_n(__policy, std::move(__first), std::move(__n), std::move(__result));
  if (!__res)
    std::__throw_bad_alloc();
  return *std::move(__res);
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_PSTL_COPY_H
