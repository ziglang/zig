//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_SORT_HEAP_H
#define _LIBCPP___ALGORITHM_SORT_HEAP_H

#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__algorithm/iterator_operations.h>
#include <__algorithm/pop_heap.h>
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
void __sort_heap(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare&& __comp) {
  using _CompRef = typename __comp_ref_type<_Compare>::type;
  _CompRef __comp_ref = __comp;

  using difference_type = typename iterator_traits<_RandomAccessIterator>::difference_type;
  for (difference_type __n = __last - __first; __n > 1; --__last, (void) --__n)
    std::__pop_heap<_AlgPolicy>(__first, __last, __comp_ref, __n);
}

template <class _RandomAccessIterator, class _Compare>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17
void sort_heap(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp) {
  static_assert(std::is_copy_constructible<_RandomAccessIterator>::value, "Iterators must be copy constructible.");
  static_assert(std::is_copy_assignable<_RandomAccessIterator>::value, "Iterators must be copy assignable.");

  std::__sort_heap<_ClassicAlgPolicy>(std::move(__first), std::move(__last), __comp);
}

template <class _RandomAccessIterator>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17
void sort_heap(_RandomAccessIterator __first, _RandomAccessIterator __last) {
  std::sort_heap(std::move(__first), std::move(__last),
      __less<typename iterator_traits<_RandomAccessIterator>::value_type>());
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_SORT_HEAP_H
