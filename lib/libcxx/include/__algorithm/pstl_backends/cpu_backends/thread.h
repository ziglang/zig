//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_THREAD_H
#define _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_THREAD_H

#include <__assert>
#include <__config>
#include <__utility/empty.h>
#include <__utility/move.h>
#include <cstddef>
#include <optional>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

// This backend implementation is for testing purposes only and not meant for production use. This will be replaced
// by a proper implementation once the PSTL implementation is somewhat stable.

_LIBCPP_BEGIN_NAMESPACE_STD

namespace __par_backend {
inline namespace __thread_cpu_backend {

template <class _RandomAccessIterator, class _Fp>
_LIBCPP_HIDE_FROM_ABI optional<__empty>
__parallel_for(_RandomAccessIterator __first, _RandomAccessIterator __last, _Fp __f) {
  __f(__first, __last);
  return __empty{};
}

template <class _Index, class _UnaryOp, class _Tp, class _BinaryOp, class _Reduce>
_LIBCPP_HIDE_FROM_ABI optional<_Tp>
__parallel_transform_reduce(_Index __first, _Index __last, _UnaryOp, _Tp __init, _BinaryOp, _Reduce __reduce) {
  return __reduce(std::move(__first), std::move(__last), std::move(__init));
}

template <class _RandomAccessIterator, class _Compare, class _LeafSort>
_LIBCPP_HIDE_FROM_ABI optional<__empty> __parallel_stable_sort(
    _RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp, _LeafSort __leaf_sort) {
  __leaf_sort(__first, __last, __comp);
  return __empty{};
}

_LIBCPP_HIDE_FROM_ABI inline void __cancel_execution() {}

template <class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _RandomAccessIterator3,
          class _Compare,
          class _LeafMerge>
_LIBCPP_HIDE_FROM_ABI optional<__empty> __parallel_merge(
    _RandomAccessIterator1 __first1,
    _RandomAccessIterator1 __last1,
    _RandomAccessIterator2 __first2,
    _RandomAccessIterator2 __last2,
    _RandomAccessIterator3 __outit,
    _Compare __comp,
    _LeafMerge __leaf_merge) {
  __leaf_merge(__first1, __last1, __first2, __last2, __outit, __comp);
  return __empty{};
}

} // namespace __thread_cpu_backend
} // namespace __par_backend

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && && _LIBCPP_STD_VER >= 17

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_THREAD_H
