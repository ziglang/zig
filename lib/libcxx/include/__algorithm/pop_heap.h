//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_POP_HEAP_H
#define _LIBCPP___ALGORITHM_POP_HEAP_H

#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__algorithm/iterator_operations.h>
#include <__algorithm/push_heap.h>
#include <__algorithm/sift_down.h>
#include <__assert>
#include <__config>
#include <__iterator/iterator_traits.h>
#include <__utility/move.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _AlgPolicy, class _Compare, class _RandomAccessIterator>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11
void __pop_heap(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare& __comp,
    typename iterator_traits<_RandomAccessIterator>::difference_type __len) {
  _LIBCPP_ASSERT(__len > 0, "The heap given to pop_heap must be non-empty");

  using _CompRef = typename __comp_ref_type<_Compare>::type;
  _CompRef __comp_ref = __comp;

  using value_type = typename iterator_traits<_RandomAccessIterator>::value_type;
  if (__len > 1) {
    value_type __top = _IterOps<_AlgPolicy>::__iter_move(__first);  // create a hole at __first
    _RandomAccessIterator __hole = std::__floyd_sift_down<_AlgPolicy>(__first, __comp_ref, __len);
    --__last;

    if (__hole == __last) {
      *__hole = std::move(__top);
    } else {
      *__hole = _IterOps<_AlgPolicy>::__iter_move(__last);
      ++__hole;
      *__last = std::move(__top);
      std::__sift_up<_AlgPolicy>(__first, __hole, __comp_ref, __hole - __first);
    }
  }
}

template <class _RandomAccessIterator, class _Compare>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17
void pop_heap(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp) {
  static_assert(std::is_copy_constructible<_RandomAccessIterator>::value, "Iterators must be copy constructible.");
  static_assert(std::is_copy_assignable<_RandomAccessIterator>::value, "Iterators must be copy assignable.");

  typename iterator_traits<_RandomAccessIterator>::difference_type __len = __last - __first;
  std::__pop_heap<_ClassicAlgPolicy>(std::move(__first), std::move(__last), __comp, __len);
}

template <class _RandomAccessIterator>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17
void pop_heap(_RandomAccessIterator __first, _RandomAccessIterator __last) {
  std::pop_heap(std::move(__first), std::move(__last),
      __less<typename iterator_traits<_RandomAccessIterator>::value_type>());
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_POP_HEAP_H
