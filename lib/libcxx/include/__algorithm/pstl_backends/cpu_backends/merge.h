//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_MERGE_H
#define _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_MERGE_H

#include <__algorithm/merge.h>
#include <__algorithm/pstl_backends/cpu_backends/backend.h>
#include <__config>
#include <__iterator/iterator_traits.h>
#include <__type_traits/is_execution_policy.h>
#include <__utility/move.h>
#include <__utility/terminate_on_exception.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _ForwardOutIterator,
          class _Comp>
_LIBCPP_HIDE_FROM_ABI _ForwardOutIterator __pstl_merge(
    __cpu_backend_tag,
    _ForwardIterator1 __first1,
    _ForwardIterator1 __last1,
    _ForwardIterator2 __first2,
    _ForwardIterator2 __last2,
    _ForwardOutIterator __result,
    _Comp __comp) {
  if constexpr (__is_parallel_execution_policy_v<_ExecutionPolicy> &&
                __has_random_access_iterator_category<_ForwardIterator1>::value &&
                __has_random_access_iterator_category<_ForwardIterator2>::value &&
                __has_random_access_iterator_category<_ForwardOutIterator>::value) {
    return std::__terminate_on_exception([&] {
      __par_backend::__parallel_merge(
          __first1,
          __last1,
          __first2,
          __last2,
          __result,
          __comp,
          [](_ForwardIterator1 __g_first1,
             _ForwardIterator1 __g_last1,
             _ForwardIterator2 __g_first2,
             _ForwardIterator2 __g_last2,
             _ForwardOutIterator __g_result,
             _Comp __g_comp) {
            return std::__pstl_merge<__remove_parallel_policy_t<_ExecutionPolicy>>(
                __cpu_backend_tag{},
                std::move(__g_first1),
                std::move(__g_last1),
                std::move(__g_first2),
                std::move(__g_last2),
                std::move(__g_result),
                std::move(__g_comp));
          });
      return __result + (__last1 - __first1) + (__last2 - __first2);
    });
  } else {
    return std::merge(__first1, __last1, __first2, __last2, __result, __comp);
  }
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif // _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_MERGE_H
