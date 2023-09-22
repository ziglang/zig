//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_FILL_H
#define _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_FILL_H

#include <__algorithm/fill.h>
#include <__algorithm/pstl_backends/cpu_backends/backend.h>
#include <__config>
#include <__iterator/iterator_traits.h>
#include <__type_traits/is_execution_policy.h>
#include <__utility/terminate_on_exception.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Index, class _DifferenceType, class _Tp>
_LIBCPP_HIDE_FROM_ABI _Index __simd_fill_n(_Index __first, _DifferenceType __n, const _Tp& __value) noexcept {
  _PSTL_USE_NONTEMPORAL_STORES_IF_ALLOWED
  _PSTL_PRAGMA_SIMD
  for (_DifferenceType __i = 0; __i < __n; ++__i)
    __first[__i] = __value;
  return __first + __n;
}

template <class _ExecutionPolicy, class _ForwardIterator, class _Tp>
_LIBCPP_HIDE_FROM_ABI void
__pstl_fill(__cpu_backend_tag, _ForwardIterator __first, _ForwardIterator __last, const _Tp& __value) {
  if constexpr (__is_parallel_execution_policy_v<_ExecutionPolicy> &&
                __has_random_access_iterator_category<_ForwardIterator>::value) {
    std::__terminate_on_exception([&] {
      __par_backend::__parallel_for(
          __first, __last, [&__value](_ForwardIterator __brick_first, _ForwardIterator __brick_last) {
            std::__pstl_fill<__remove_parallel_policy_t<_ExecutionPolicy>>(
                __cpu_backend_tag{}, __brick_first, __brick_last, __value);
          });
    });
  } else if constexpr (__is_unsequenced_execution_policy_v<_ExecutionPolicy> &&
                       __has_random_access_iterator_category<_ForwardIterator>::value) {
    std::__simd_fill_n(__first, __last - __first, __value);
  } else {
    std::fill(__first, __last, __value);
  }
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif // _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_FILL_H
