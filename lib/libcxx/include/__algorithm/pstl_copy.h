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
#include <__algorithm/pstl_transform.h>
#include <__config>
#include <__functional/identity.h>
#include <__iterator/iterator_traits.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/is_constant_evaluated.h>
#include <__type_traits/is_execution_policy.h>
#include <__type_traits/is_trivially_copyable.h>
#include <__type_traits/remove_cvref.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

// TODO: Use the std::copy/move shenanigans to forward to std::memmove

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _ForwardOutIterator,
          enable_if_t<is_execution_policy_v<__remove_cvref_t<_ExecutionPolicy>>, int> = 0>
_LIBCPP_HIDE_FROM_ABI _ForwardOutIterator
copy(_ExecutionPolicy&& __policy, _ForwardIterator __first, _ForwardIterator __last, _ForwardOutIterator __result) {
  return std::transform(__policy, __first, __last, __result, __identity());
}

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _ForwardOutIterator,
          class _Size,
          enable_if_t<is_execution_policy_v<__remove_cvref_t<_ExecutionPolicy>>, int> = 0>
_LIBCPP_HIDE_FROM_ABI _ForwardOutIterator
copy_n(_ExecutionPolicy&& __policy, _ForwardIterator __first, _Size __n, _ForwardOutIterator __result) {
  if constexpr (__has_random_access_iterator_category<_ForwardIterator>::value)
    return std::copy(__policy, __first, __first + __n, __result);
  else
    return std::copy_n(__first, __n, __result);
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif // _LIBCPP___ALGORITHM_PSTL_COPY_H
