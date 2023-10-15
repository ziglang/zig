// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _PSTL_GLUE_ALGORITHM_IMPL_H
#define _PSTL_GLUE_ALGORITHM_IMPL_H

#include <__config>
#include <functional>

#include "algorithm_fwd.h"
#include "execution_defs.h"
#include "numeric_fwd.h" /* count and count_if use __pattern_transform_reduce */
#include "utils.h"

#include "execution_impl.h"

namespace std {

// [alg.find.end]
template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator1>
find_end(_ExecutionPolicy&& __exec,
         _ForwardIterator1 __first,
         _ForwardIterator1 __last,
         _ForwardIterator2 __s_first,
         _ForwardIterator2 __s_last,
         _BinaryPredicate __pred) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first, __s_first);

  return __pstl::__internal::__pattern_find_end(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __s_first, __s_last, __pred);
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator1>
find_end(_ExecutionPolicy&& __exec,
         _ForwardIterator1 __first,
         _ForwardIterator1 __last,
         _ForwardIterator2 __s_first,
         _ForwardIterator2 __s_last) {
  return std::find_end(std::forward<_ExecutionPolicy>(__exec), __first, __last, __s_first, __s_last, std::equal_to<>());
}

// [alg.find_first_of]
template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator1> find_first_of(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first,
    _ForwardIterator1 __last,
    _ForwardIterator2 __s_first,
    _ForwardIterator2 __s_last,
    _BinaryPredicate __pred) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first, __s_first);

  return __pstl::__internal::__pattern_find_first_of(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __s_first, __s_last, __pred);
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator1>
find_first_of(_ExecutionPolicy&& __exec,
              _ForwardIterator1 __first,
              _ForwardIterator1 __last,
              _ForwardIterator2 __s_first,
              _ForwardIterator2 __s_last) {
  return std::find_first_of(
      std::forward<_ExecutionPolicy>(__exec), __first, __last, __s_first, __s_last, std::equal_to<>());
}

// [alg.adjacent_find]
template <class _ExecutionPolicy, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
adjacent_find(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType;
  return __pstl::__internal::__pattern_adjacent_find(
      __dispatch_tag,
      std::forward<_ExecutionPolicy>(__exec),
      __first,
      __last,
      std::equal_to<_ValueType>(),
      /*first_semantic*/ false);
}

template <class _ExecutionPolicy, class _ForwardIterator, class _BinaryPredicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
adjacent_find(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last, _BinaryPredicate __pred) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);
  return __pstl::__internal::__pattern_adjacent_find(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __pred, /*first_semantic*/ false);
}

// [alg.count]

// Implementation note: count and count_if call the pattern directly instead of calling std::transform_reduce
// so that we do not have to include <numeric>.

template <class _ExecutionPolicy, class _ForwardIterator, class _Tp>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy,
                                                 typename iterator_traits<_ForwardIterator>::difference_type>
count(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last, const _Tp& __value) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType;
  return __pstl::__internal::__pattern_count(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, [&__value](const _ValueType& __x) {
        return __value == __x;
      });
}

template <class _ExecutionPolicy, class _ForwardIterator, class _Predicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy,
                                                 typename iterator_traits<_ForwardIterator>::difference_type>
count_if(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last, _Predicate __pred) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);
  return __pstl::__internal::__pattern_count(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __pred);
}

// [alg.search]

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator1>
search(_ExecutionPolicy&& __exec,
       _ForwardIterator1 __first,
       _ForwardIterator1 __last,
       _ForwardIterator2 __s_first,
       _ForwardIterator2 __s_last,
       _BinaryPredicate __pred) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first, __s_first);

  return __pstl::__internal::__pattern_search(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __s_first, __s_last, __pred);
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator1>
search(_ExecutionPolicy&& __exec,
       _ForwardIterator1 __first,
       _ForwardIterator1 __last,
       _ForwardIterator2 __s_first,
       _ForwardIterator2 __s_last) {
  return std::search(std::forward<_ExecutionPolicy>(__exec), __first, __last, __s_first, __s_last, std::equal_to<>());
}

template <class _ExecutionPolicy, class _ForwardIterator, class _Size, class _Tp, class _BinaryPredicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
search_n(_ExecutionPolicy&& __exec,
         _ForwardIterator __first,
         _ForwardIterator __last,
         _Size __count,
         const _Tp& __value,
         _BinaryPredicate __pred) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  return __pstl::__internal::__pattern_search_n(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __count, __value, __pred);
}

template <class _ExecutionPolicy, class _ForwardIterator, class _Size, class _Tp>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator> search_n(
    _ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last, _Size __count, const _Tp& __value) {
  return std::search_n(
      std::forward<_ExecutionPolicy>(__exec),
      __first,
      __last,
      __count,
      __value,
      std::equal_to<typename iterator_traits<_ForwardIterator>::value_type>());
}

// [alg.copy]

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _Predicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2>
copy_if(_ExecutionPolicy&& __exec,
        _ForwardIterator1 __first,
        _ForwardIterator1 __last,
        _ForwardIterator2 __result,
        _Predicate __pred) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first, __result);

  return __pstl::__internal::__pattern_copy_if(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __result, __pred);
}

// [alg.swap]

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2> swap_ranges(
    _ExecutionPolicy&& __exec, _ForwardIterator1 __first1, _ForwardIterator1 __last1, _ForwardIterator2 __first2) {
  typedef typename iterator_traits<_ForwardIterator1>::reference _ReferenceType1;
  typedef typename iterator_traits<_ForwardIterator2>::reference _ReferenceType2;

  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first1, __first2);

  return __pstl::__internal::__pattern_walk2(
      __dispatch_tag,
      std::forward<_ExecutionPolicy>(__exec),
      __first1,
      __last1,
      __first2,
      [](_ReferenceType1 __x, _ReferenceType2 __y) {
        using std::swap;
        swap(__x, __y);
      });
}

// [alg.generate]
template <class _ExecutionPolicy, class _ForwardIterator, class _Generator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, void>
generate(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last, _Generator __g) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  __pstl::__internal::__pattern_generate(__dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __g);
}

template <class _ExecutionPolicy, class _ForwardIterator, class _Size, class _Generator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
generate_n(_ExecutionPolicy&& __exec, _ForwardIterator __first, _Size __count, _Generator __g) {
  if (__count <= 0)
    return __first;

  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  return __pstl::__internal::__pattern_generate_n(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __count, __g);
}

// [alg.remove]

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _Predicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2> remove_copy_if(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first,
    _ForwardIterator1 __last,
    _ForwardIterator2 __result,
    _Predicate __pred) {
  return std::copy_if(std::forward<_ExecutionPolicy>(__exec), __first, __last, __result, std::not_fn(__pred));
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _Tp>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2>
remove_copy(_ExecutionPolicy&& __exec,
            _ForwardIterator1 __first,
            _ForwardIterator1 __last,
            _ForwardIterator2 __result,
            const _Tp& __value) {
  return std::copy_if(
      std::forward<_ExecutionPolicy>(__exec),
      __first,
      __last,
      __result,
      __pstl::__internal::__not_equal_value<_Tp>(__value));
}

template <class _ExecutionPolicy, class _ForwardIterator, class _UnaryPredicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
remove_if(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last, _UnaryPredicate __pred) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  return __pstl::__internal::__pattern_remove_if(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __pred);
}

template <class _ExecutionPolicy, class _ForwardIterator, class _Tp>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
remove(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last, const _Tp& __value) {
  return std::remove_if(
      std::forward<_ExecutionPolicy>(__exec), __first, __last, __pstl::__internal::__equal_value<_Tp>(__value));
}

// [alg.unique]

template <class _ExecutionPolicy, class _ForwardIterator, class _BinaryPredicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
unique(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last, _BinaryPredicate __pred) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  return __pstl::__internal::__pattern_unique(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __pred);
}

template <class _ExecutionPolicy, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
unique(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last) {
  return std::unique(std::forward<_ExecutionPolicy>(__exec), __first, __last, std::equal_to<>());
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2>
unique_copy(_ExecutionPolicy&& __exec,
            _ForwardIterator1 __first,
            _ForwardIterator1 __last,
            _ForwardIterator2 __result,
            _BinaryPredicate __pred) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first, __result);

  return __pstl::__internal::__pattern_unique_copy(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __result, __pred);
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2> unique_copy(
    _ExecutionPolicy&& __exec, _ForwardIterator1 __first, _ForwardIterator1 __last, _ForwardIterator2 __result) {
  return std::unique_copy(__exec, __first, __last, __result, std::equal_to<>());
}

// [alg.reverse]

template <class _ExecutionPolicy, class _BidirectionalIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, void>
reverse(_ExecutionPolicy&& __exec, _BidirectionalIterator __first, _BidirectionalIterator __last) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  __pstl::__internal::__pattern_reverse(__dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last);
}

template <class _ExecutionPolicy, class _BidirectionalIterator, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
reverse_copy(_ExecutionPolicy&& __exec,
             _BidirectionalIterator __first,
             _BidirectionalIterator __last,
             _ForwardIterator __d_first) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first, __d_first);

  return __pstl::__internal::__pattern_reverse_copy(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __d_first);
}

// [alg.rotate]

template <class _ExecutionPolicy, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
rotate(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __middle, _ForwardIterator __last) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  return __pstl::__internal::__pattern_rotate(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __middle, __last);
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2>
rotate_copy(_ExecutionPolicy&& __exec,
            _ForwardIterator1 __first,
            _ForwardIterator1 __middle,
            _ForwardIterator1 __last,
            _ForwardIterator2 __result) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first, __result);

  return __pstl::__internal::__pattern_rotate_copy(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __middle, __last, __result);
}

// [alg.partitions]

template <class _ExecutionPolicy, class _ForwardIterator, class _UnaryPredicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, bool>
is_partitioned(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last, _UnaryPredicate __pred) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);
  return __pstl::__internal::__pattern_is_partitioned(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __pred);
}

template <class _ExecutionPolicy, class _ForwardIterator, class _UnaryPredicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
partition(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last, _UnaryPredicate __pred) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  return __pstl::__internal::__pattern_partition(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __pred);
}

template <class _ExecutionPolicy, class _BidirectionalIterator, class _UnaryPredicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _BidirectionalIterator> stable_partition(
    _ExecutionPolicy&& __exec, _BidirectionalIterator __first, _BidirectionalIterator __last, _UnaryPredicate __pred) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);
  return __pstl::__internal::__pattern_stable_partition(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __pred);
}

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _UnaryPredicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, std::pair<_ForwardIterator1, _ForwardIterator2>>
partition_copy(_ExecutionPolicy&& __exec,
               _ForwardIterator __first,
               _ForwardIterator __last,
               _ForwardIterator1 __out_true,
               _ForwardIterator2 __out_false,
               _UnaryPredicate __pred) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first, __out_true, __out_false);

  return __pstl::__internal::__pattern_partition_copy(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __out_true, __out_false, __pred);
}

// [alg.sort]

template <class _ExecutionPolicy, class _RandomAccessIterator, class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, void>
sort(_ExecutionPolicy&& __exec, _RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  typedef typename iterator_traits<_RandomAccessIterator>::value_type _InputType;
  return __pstl::__internal::__pattern_sort(
      __dispatch_tag,
      std::forward<_ExecutionPolicy>(__exec),
      __first,
      __last,
      __comp,
      typename std::is_move_constructible<_InputType>::type());
}

template <class _ExecutionPolicy, class _RandomAccessIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, void>
sort(_ExecutionPolicy&& __exec, _RandomAccessIterator __first, _RandomAccessIterator __last) {
  typedef typename std::iterator_traits<_RandomAccessIterator>::value_type _InputType;
  std::sort(std::forward<_ExecutionPolicy>(__exec), __first, __last, std::less<_InputType>());
}

// [stable.sort]

template <class _ExecutionPolicy, class _RandomAccessIterator, class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, void>
stable_sort(_ExecutionPolicy&& __exec, _RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  return __pstl::__internal::__pattern_stable_sort(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __comp);
}

template <class _ExecutionPolicy, class _RandomAccessIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, void>
stable_sort(_ExecutionPolicy&& __exec, _RandomAccessIterator __first, _RandomAccessIterator __last) {
  typedef typename std::iterator_traits<_RandomAccessIterator>::value_type _InputType;
  std::stable_sort(__exec, __first, __last, std::less<_InputType>());
}

// [mismatch]

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, std::pair<_ForwardIterator1, _ForwardIterator2>>
mismatch(_ExecutionPolicy&& __exec,
         _ForwardIterator1 __first1,
         _ForwardIterator1 __last1,
         _ForwardIterator2 __first2,
         _ForwardIterator2 __last2,
         _BinaryPredicate __pred) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first1, __first2);

  return __pstl::__internal::__pattern_mismatch(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __last2, __pred);
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, std::pair<_ForwardIterator1, _ForwardIterator2>>
mismatch(_ExecutionPolicy&& __exec,
         _ForwardIterator1 __first1,
         _ForwardIterator1 __last1,
         _ForwardIterator2 __first2,
         _BinaryPredicate __pred) {
  return std::mismatch(
      __exec, __first1, __last1, __first2, std::next(__first2, std::distance(__first1, __last1)), __pred);
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, std::pair<_ForwardIterator1, _ForwardIterator2>>
mismatch(_ExecutionPolicy&& __exec,
         _ForwardIterator1 __first1,
         _ForwardIterator1 __last1,
         _ForwardIterator2 __first2,
         _ForwardIterator2 __last2) {
  return std::mismatch(std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __last2, std::equal_to<>());
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, std::pair<_ForwardIterator1, _ForwardIterator2>>
mismatch(_ExecutionPolicy&& __exec, _ForwardIterator1 __first1, _ForwardIterator1 __last1, _ForwardIterator2 __first2) {
  // TODO: to get rid of "distance"
  return std::mismatch(
      std::forward<_ExecutionPolicy>(__exec),
      __first1,
      __last1,
      __first2,
      std::next(__first2, std::distance(__first1, __last1)));
}

// [alg.equal]

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, bool>
equal(_ExecutionPolicy&& __exec,
      _ForwardIterator1 __first1,
      _ForwardIterator1 __last1,
      _ForwardIterator2 __first2,
      _BinaryPredicate __p) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first1, __first2);

  return __pstl::__internal::__pattern_equal(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __p);
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, bool>
equal(_ExecutionPolicy&& __exec, _ForwardIterator1 __first1, _ForwardIterator1 __last1, _ForwardIterator2 __first2) {
  return std::equal(std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, std::equal_to<>());
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, bool>
equal(_ExecutionPolicy&& __exec,
      _ForwardIterator1 __first1,
      _ForwardIterator1 __last1,
      _ForwardIterator2 __first2,
      _ForwardIterator2 __last2,
      _BinaryPredicate __p) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first1, __first2);

  return __pstl::__internal::__pattern_equal(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __last2, __p);
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, bool>
equal(_ExecutionPolicy&& __exec,
      _ForwardIterator1 __first1,
      _ForwardIterator1 __last1,
      _ForwardIterator2 __first2,
      _ForwardIterator2 __last2) {
  return equal(std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __last2, std::equal_to<>());
}

// [alg.move]
template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2>
move(_ExecutionPolicy&& __exec, _ForwardIterator1 __first, _ForwardIterator1 __last, _ForwardIterator2 __d_first) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first, __d_first);

  using __is_vector = typename decltype(__dispatch_tag)::__is_vector;

  return __pstl::__internal::__pattern_walk2_brick(
      __dispatch_tag,
      std::forward<_ExecutionPolicy>(__exec),
      __first,
      __last,
      __d_first,
      [](_ForwardIterator1 __begin, _ForwardIterator1 __end, _ForwardIterator2 __res) {
        return __pstl::__internal::__brick_move(__begin, __end, __res, __is_vector{});
      });
}

// [partial.sort]

template <class _ExecutionPolicy, class _RandomAccessIterator, class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, void>
partial_sort(_ExecutionPolicy&& __exec,
             _RandomAccessIterator __first,
             _RandomAccessIterator __middle,
             _RandomAccessIterator __last,
             _Compare __comp) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  __pstl::__internal::__pattern_partial_sort(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __middle, __last, __comp);
}

template <class _ExecutionPolicy, class _RandomAccessIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, void>
partial_sort(_ExecutionPolicy&& __exec,
             _RandomAccessIterator __first,
             _RandomAccessIterator __middle,
             _RandomAccessIterator __last) {
  typedef typename iterator_traits<_RandomAccessIterator>::value_type _InputType;
  std::partial_sort(__exec, __first, __middle, __last, std::less<_InputType>());
}

// [partial.sort.copy]

template <class _ExecutionPolicy, class _ForwardIterator, class _RandomAccessIterator, class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _RandomAccessIterator> partial_sort_copy(
    _ExecutionPolicy&& __exec,
    _ForwardIterator __first,
    _ForwardIterator __last,
    _RandomAccessIterator __d_first,
    _RandomAccessIterator __d_last,
    _Compare __comp) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first, __d_first);

  return __pstl::__internal::__pattern_partial_sort_copy(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __d_first, __d_last, __comp);
}

template <class _ExecutionPolicy, class _ForwardIterator, class _RandomAccessIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _RandomAccessIterator> partial_sort_copy(
    _ExecutionPolicy&& __exec,
    _ForwardIterator __first,
    _ForwardIterator __last,
    _RandomAccessIterator __d_first,
    _RandomAccessIterator __d_last) {
  return std::partial_sort_copy(
      std::forward<_ExecutionPolicy>(__exec), __first, __last, __d_first, __d_last, std::less<>());
}

// [is.sorted]
template <class _ExecutionPolicy, class _ForwardIterator, class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
is_sorted_until(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last, _Compare __comp) {
  auto __dispatch_tag          = __pstl::__internal::__select_backend(__exec, __first);
  const _ForwardIterator __res = __pstl::__internal::__pattern_adjacent_find(
      __dispatch_tag,
      std::forward<_ExecutionPolicy>(__exec),
      __first,
      __last,
      __pstl::__internal::__reorder_pred<_Compare>(__comp),
      /*first_semantic*/ false);
  return __res == __last ? __last : std::next(__res);
}

template <class _ExecutionPolicy, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
is_sorted_until(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last) {
  typedef typename std::iterator_traits<_ForwardIterator>::value_type _InputType;
  return is_sorted_until(std::forward<_ExecutionPolicy>(__exec), __first, __last, std::less<_InputType>());
}

template <class _ExecutionPolicy, class _ForwardIterator, class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, bool>
is_sorted(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last, _Compare __comp) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);
  return __pstl::__internal::__pattern_adjacent_find(
             __dispatch_tag,
             std::forward<_ExecutionPolicy>(__exec),
             __first,
             __last,
             __pstl::__internal::__reorder_pred<_Compare>(__comp),
             /*or_semantic*/ true) == __last;
}

template <class _ExecutionPolicy, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, bool>
is_sorted(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last) {
  typedef typename std::iterator_traits<_ForwardIterator>::value_type _InputType;
  return std::is_sorted(std::forward<_ExecutionPolicy>(__exec), __first, __last, std::less<_InputType>());
}

// [alg.merge]
template <class _ExecutionPolicy, class _BidirectionalIterator, class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, void>
inplace_merge(_ExecutionPolicy&& __exec,
              _BidirectionalIterator __first,
              _BidirectionalIterator __middle,
              _BidirectionalIterator __last,
              _Compare __comp) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  __pstl::__internal::__pattern_inplace_merge(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __middle, __last, __comp);
}

template <class _ExecutionPolicy, class _BidirectionalIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, void>
inplace_merge(_ExecutionPolicy&& __exec,
              _BidirectionalIterator __first,
              _BidirectionalIterator __middle,
              _BidirectionalIterator __last) {
  typedef typename std::iterator_traits<_BidirectionalIterator>::value_type _InputType;
  std::inplace_merge(__exec, __first, __middle, __last, std::less<_InputType>());
}

// [includes]

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, bool>
includes(_ExecutionPolicy&& __exec,
         _ForwardIterator1 __first1,
         _ForwardIterator1 __last1,
         _ForwardIterator2 __first2,
         _ForwardIterator2 __last2,
         _Compare __comp) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first1, __first2);

  return __pstl::__internal::__pattern_includes(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __last2, __comp);
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, bool>
includes(_ExecutionPolicy&& __exec,
         _ForwardIterator1 __first1,
         _ForwardIterator1 __last1,
         _ForwardIterator2 __first2,
         _ForwardIterator2 __last2) {
  return std::includes(std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __last2, std::less<>());
}

// [set.union]

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _ForwardIterator,
          class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
set_union(_ExecutionPolicy&& __exec,
          _ForwardIterator1 __first1,
          _ForwardIterator1 __last1,
          _ForwardIterator2 __first2,
          _ForwardIterator2 __last2,
          _ForwardIterator __result,
          _Compare __comp) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first1, __first2, __result);

  return __pstl::__internal::__pattern_set_union(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __last2, __result, __comp);
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
set_union(_ExecutionPolicy&& __exec,
          _ForwardIterator1 __first1,
          _ForwardIterator1 __last1,
          _ForwardIterator2 __first2,
          _ForwardIterator2 __last2,
          _ForwardIterator __result) {
  return std::set_union(
      std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __last2, __result, std::less<>());
}

// [set.intersection]

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _ForwardIterator,
          class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator> set_intersection(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first1,
    _ForwardIterator1 __last1,
    _ForwardIterator2 __first2,
    _ForwardIterator2 __last2,
    _ForwardIterator __result,
    _Compare __comp) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first1, __first2, __result);

  return __pstl::__internal::__pattern_set_intersection(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __last2, __result, __comp);
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator> set_intersection(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first1,
    _ForwardIterator1 __last1,
    _ForwardIterator2 __first2,
    _ForwardIterator2 __last2,
    _ForwardIterator __result) {
  return std::set_intersection(
      std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __last2, __result, std::less<>());
}

// [set.difference]

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _ForwardIterator,
          class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator> set_difference(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first1,
    _ForwardIterator1 __last1,
    _ForwardIterator2 __first2,
    _ForwardIterator2 __last2,
    _ForwardIterator __result,
    _Compare __comp) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first1, __first2, __result);

  return __pstl::__internal::__pattern_set_difference(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __last2, __result, __comp);
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator> set_difference(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first1,
    _ForwardIterator1 __last1,
    _ForwardIterator2 __first2,
    _ForwardIterator2 __last2,
    _ForwardIterator __result) {
  return std::set_difference(
      std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __last2, __result, std::less<>());
}

// [set.symmetric.difference]

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _ForwardIterator,
          class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator> set_symmetric_difference(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first1,
    _ForwardIterator1 __last1,
    _ForwardIterator2 __first2,
    _ForwardIterator2 __last2,
    _ForwardIterator __result,
    _Compare __comp) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first1, __first2, __result);

  return __pstl::__internal::__pattern_set_symmetric_difference(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __last2, __result, __comp);
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator> set_symmetric_difference(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first1,
    _ForwardIterator1 __last1,
    _ForwardIterator2 __first2,
    _ForwardIterator2 __last2,
    _ForwardIterator __result) {
  return std::set_symmetric_difference(
      std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __last2, __result, std::less<>());
}

// [is.heap]
template <class _ExecutionPolicy, class _RandomAccessIterator, class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _RandomAccessIterator>
is_heap_until(_ExecutionPolicy&& __exec, _RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  return __pstl::__internal::__pattern_is_heap_until(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __comp);
}

template <class _ExecutionPolicy, class _RandomAccessIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _RandomAccessIterator>
is_heap_until(_ExecutionPolicy&& __exec, _RandomAccessIterator __first, _RandomAccessIterator __last) {
  typedef typename std::iterator_traits<_RandomAccessIterator>::value_type _InputType;
  return std::is_heap_until(std::forward<_ExecutionPolicy>(__exec), __first, __last, std::less<_InputType>());
}

template <class _ExecutionPolicy, class _RandomAccessIterator, class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, bool>
is_heap(_ExecutionPolicy&& __exec, _RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp) {
  return std::is_heap_until(std::forward<_ExecutionPolicy>(__exec), __first, __last, __comp) == __last;
}

template <class _ExecutionPolicy, class _RandomAccessIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, bool>
is_heap(_ExecutionPolicy&& __exec, _RandomAccessIterator __first, _RandomAccessIterator __last) {
  typedef typename std::iterator_traits<_RandomAccessIterator>::value_type _InputType;
  return std::is_heap(std::forward<_ExecutionPolicy>(__exec), __first, __last, std::less<_InputType>());
}

// [alg.min.max]

template <class _ExecutionPolicy, class _ForwardIterator, class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
min_element(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last, _Compare __comp) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);
  return __pstl::__internal::__pattern_min_element(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __comp);
}

template <class _ExecutionPolicy, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
min_element(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last) {
  typedef typename std::iterator_traits<_ForwardIterator>::value_type _InputType;
  return std::min_element(std::forward<_ExecutionPolicy>(__exec), __first, __last, std::less<_InputType>());
}

template <class _ExecutionPolicy, class _ForwardIterator, class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
max_element(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last, _Compare __comp) {
  return min_element(
      std::forward<_ExecutionPolicy>(__exec), __first, __last, __pstl::__internal::__reorder_pred<_Compare>(__comp));
}

template <class _ExecutionPolicy, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
max_element(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last) {
  typedef typename std::iterator_traits<_ForwardIterator>::value_type _InputType;
  return std::min_element(
      std::forward<_ExecutionPolicy>(__exec),
      __first,
      __last,
      __pstl::__internal::__reorder_pred<std::less<_InputType>>(std::less<_InputType>()));
}

template <class _ExecutionPolicy, class _ForwardIterator, class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, std::pair<_ForwardIterator, _ForwardIterator>>
minmax_element(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last, _Compare __comp) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);
  return __pstl::__internal::__pattern_minmax_element(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, __comp);
}

template <class _ExecutionPolicy, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, std::pair<_ForwardIterator, _ForwardIterator>>
minmax_element(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last) {
  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType;
  return std::minmax_element(std::forward<_ExecutionPolicy>(__exec), __first, __last, std::less<_ValueType>());
}

// [alg.nth.element]

template <class _ExecutionPolicy, class _RandomAccessIterator, class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, void>
nth_element(_ExecutionPolicy&& __exec,
            _RandomAccessIterator __first,
            _RandomAccessIterator __nth,
            _RandomAccessIterator __last,
            _Compare __comp) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  __pstl::__internal::__pattern_nth_element(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __nth, __last, __comp);
}

template <class _ExecutionPolicy, class _RandomAccessIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, void>
nth_element(_ExecutionPolicy&& __exec,
            _RandomAccessIterator __first,
            _RandomAccessIterator __nth,
            _RandomAccessIterator __last) {
  typedef typename iterator_traits<_RandomAccessIterator>::value_type _InputType;
  std::nth_element(std::forward<_ExecutionPolicy>(__exec), __first, __nth, __last, std::less<_InputType>());
}

// [alg.lex.comparison]

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _Compare>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, bool> lexicographical_compare(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first1,
    _ForwardIterator1 __last1,
    _ForwardIterator2 __first2,
    _ForwardIterator2 __last2,
    _Compare __comp) {
  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first1, __first2);

  return __pstl::__internal::__pattern_lexicographical_compare(
      __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __last2, __comp);
}

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, bool> lexicographical_compare(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first1,
    _ForwardIterator1 __last1,
    _ForwardIterator2 __first2,
    _ForwardIterator2 __last2) {
  return std::lexicographical_compare(
      std::forward<_ExecutionPolicy>(__exec), __first1, __last1, __first2, __last2, std::less<>());
}

} // namespace std

#endif /* _PSTL_GLUE_ALGORITHM_IMPL_H */
