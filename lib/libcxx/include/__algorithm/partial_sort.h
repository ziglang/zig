//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PARTIAL_SORT_H
#define _LIBCPP___ALGORITHM_PARTIAL_SORT_H

#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__algorithm/iterator_operations.h>
#include <__algorithm/make_heap.h>
#include <__algorithm/sift_down.h>
#include <__algorithm/sort_heap.h>
#include <__config>
#include <__debug>
#include <__debug_utils/randomize_range.h>
#include <__iterator/iterator_traits.h>
#include <__utility/move.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _AlgPolicy, class _Compare, class _RandomAccessIterator, class _Sentinel>
_LIBCPP_CONSTEXPR_AFTER_CXX17
_RandomAccessIterator __partial_sort_impl(
    _RandomAccessIterator __first, _RandomAccessIterator __middle, _Sentinel __last, _Compare&& __comp) {
  if (__first == __middle) {
    return _IterOps<_AlgPolicy>::next(__middle, __last);
  }

  std::__make_heap<_AlgPolicy>(__first, __middle, __comp);

  typename iterator_traits<_RandomAccessIterator>::difference_type __len = __middle - __first;
  _RandomAccessIterator __i = __middle;
  for (; __i != __last; ++__i)
  {
      if (__comp(*__i, *__first))
      {
          _IterOps<_AlgPolicy>::iter_swap(__i, __first);
          std::__sift_down<_AlgPolicy>(__first, __comp, __len, __first);
      }

  }
  std::__sort_heap<_AlgPolicy>(std::move(__first), std::move(__middle), __comp);

  return __i;
}

template <class _AlgPolicy, class _Compare, class _RandomAccessIterator, class _Sentinel>
_LIBCPP_CONSTEXPR_AFTER_CXX17
_RandomAccessIterator __partial_sort(_RandomAccessIterator __first, _RandomAccessIterator __middle, _Sentinel __last,
                                     _Compare& __comp) {
  if (__first == __middle)
      return _IterOps<_AlgPolicy>::next(__middle, __last);

  std::__debug_randomize_range<_AlgPolicy>(__first, __last);

  using _Comp_ref = typename __comp_ref_type<_Compare>::type;
  auto __last_iter = std::__partial_sort_impl<_AlgPolicy>(__first, __middle, __last, static_cast<_Comp_ref>(__comp));

  std::__debug_randomize_range<_AlgPolicy>(__middle, __last);

  return __last_iter;
}

template <class _RandomAccessIterator, class _Compare>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
void
partial_sort(_RandomAccessIterator __first, _RandomAccessIterator __middle, _RandomAccessIterator __last,
             _Compare __comp)
{
  static_assert(std::is_copy_constructible<_RandomAccessIterator>::value, "Iterators must be copy constructible.");
  static_assert(std::is_copy_assignable<_RandomAccessIterator>::value, "Iterators must be copy assignable.");

  (void)std::__partial_sort<_ClassicAlgPolicy>(std::move(__first), std::move(__middle), std::move(__last), __comp);
}

template <class _RandomAccessIterator>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
void
partial_sort(_RandomAccessIterator __first, _RandomAccessIterator __middle, _RandomAccessIterator __last)
{
    _VSTD::partial_sort(__first, __middle, __last,
                        __less<typename iterator_traits<_RandomAccessIterator>::value_type>());
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_PARTIAL_SORT_H
