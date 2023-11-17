//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_BACKEND_H
#define _LIBCPP___ALGORITHM_PSTL_BACKEND_H

#include <__algorithm/pstl_backends/cpu_backend.h>
#include <__config>
#include <execution>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

/*
TODO: Documentation of how backends work

A PSTL parallel backend is a tag type to which the following functions are associated, at minimum:

  template <class _ExecutionPolicy, class _Iterator, class _Func>
  void __pstl_for_each(_Backend, _ExecutionPolicy&&, _Iterator __first, _Iterator __last, _Func __f);

  template <class _ExecutionPolicy, class _Iterator, class _Predicate>
  _Iterator __pstl_find_if(_Backend, _Iterator __first, _Iterator __last, _Predicate __pred);

  template <class _ExecutionPolicy, class _RandomAccessIterator, class _Comp>
  void __pstl_stable_sort(_Backend, _RandomAccessIterator __first, _RandomAccessIterator __last, _Comp __comp);

  template <class _ExecutionPolicy, class _InIterator, class _OutIterator, class _UnaryOperation>
  _OutIterator __pstl_transform(_InIterator __first, _InIterator __last, _OutIterator __result, _UnaryOperation __op);

  template <class _ExecutionPolicy, class _InIterator1, class _InIterator2, class _OutIterator, class _BinaryOperation>
  _OutIterator __pstl_transform(_InIterator1 __first1,
                                _InIterator1 __last1,
                                _InIterator2 __first2,
                                _OutIterator __result,
                                _BinaryOperation __op);

  template <class _ExecutionPolicy,
            class _Iterator1,
            class _Iterator2,
            class _Tp,
            class _BinaryOperation1,
            class _BinaryOperation2>
  _Tp __pstl_transform_reduce(_Backend,
                              _Iterator1 __first1,
                              _Iterator1 __last1,
                              _Iterator2 __first2,
                              _Iterator2 __last2,
                              _Tp __init,
                              _BinaryOperation1 __reduce,
                              _BinaryOperation2 __transform);

  template <class _ExecutionPolicy, class _Iterator, class _Tp, class _BinaryOperation, class _UnaryOperation>
  _Tp __pstl_transform_reduce(_Backend,
                              _Iterator __first,
                              _Iterator __last,
                              _Tp __init,
                              _BinaryOperation __reduce,
                              _UnaryOperation __transform);

// TODO: Complete this list

The following functions are optional but can be provided. If provided, they are used by the corresponding
algorithms, otherwise they are implemented in terms of other algorithms. If none of the optional algorithms are
implemented, all the algorithms will eventually forward to the basis algorithms listed above:

  template <class _ExecutionPolicy, class _Iterator, class _Size, class _Func>
  void __pstl_for_each_n(_Backend, _Iterator __first, _Size __n, _Func __f);

  template <class _ExecutionPolicy, class _Iterator, class _Predicate>
  bool __pstl_any_of(_Backend, _Iterator __first, _iterator __last, _Predicate __pred);

  template <class _ExecutionPolicy, class _Iterator, class _Predicate>
  bool __pstl_all_of(_Backend, _Iterator __first, _iterator __last, _Predicate __pred);

  template <class _ExecutionPolicy, class _Iterator, class _Predicate>
  bool __pstl_none_of(_Backend, _Iterator __first, _iterator __last, _Predicate __pred);

  template <class _ExecutionPolicy, class _Iterator, class _Tp>
  _Iterator __pstl_find(_Backend, _Iterator __first, _Iterator __last, const _Tp& __value);

  template <class _ExecutionPolicy, class _Iterator, class _Predicate>
  _Iterator __pstl_find_if_not(_Backend, _Iterator __first, _Iterator __last, _Predicate __pred);

  template <class _ExecutionPolicy, class _Iterator, class _Tp>
  void __pstl_fill(_Backend, _Iterator __first, _Iterator __last, const _Tp& __value);

  template <class _ExecutionPolicy, class _Iterator, class _SizeT, class _Tp>
  void __pstl_fill_n(_Backend, _Iterator __first, _SizeT __n, const _Tp& __value);

  template <class _ExecutionPolicy, class _Iterator, class _Generator>
  void __pstl_generate(_Backend, _Iterator __first, _Iterator __last, _Generator __gen);

  template <class _ExecutionPolicy, class _Iterator, class _Predicate>
  void __pstl_is_partitioned(_Backend, _Iterator __first, _Iterator __last, _Predicate __pred);

  template <class _ExecutionPolicy, class _Iterator, class _Size, class _Generator>
  void __pstl_generator_n(_Backend, _Iterator __first, _Size __n, _Generator __gen);

  template <class _ExecutionPolicy, class _terator1, class _Iterator2, class _OutIterator, class _Comp>
  _OutIterator __pstl_merge(_Backend,
                            _Iterator1 __first1,
                            _Iterator1 __last1,
                            _Iterator2 __first2,
                            _Iterator2 __last2,
                            _OutIterator __result,
                            _Comp __comp);

  template <class _ExecutionPolicy, class _Iterator, class _Tp, class _BinaryOperation>
  _Tp __pstl_reduce(_Backend, _Iterator __first, _Iterator __last, _Tp __init, _BinaryOperation __op);

  temlate <class _ExecutionPolicy, class _Iterator>
  __iter_value_type<_Iterator> __pstl_reduce(_Backend, _Iterator __first, _Iterator __last);

  template <class _ExecuitonPolicy, class _Iterator, class _Tp>
  __iter_diff_t<_Iterator> __pstl_count(_Backend, _Iterator __first, _Iterator __last, const _Tp& __value);

  template <class _ExecutionPolicy, class _Iterator, class _Predicate>
  __iter_diff_t<_Iterator> __pstl_count_if(_Backend, _Iterator __first, _Iterator __last, _Predicate __pred);

  template <class _ExecutionPolicy, class _Iterator, class _Tp>
  void __pstl_replace(_Backend, _Iterator __first, _Iterator __last, const _Tp& __old_value, const _Tp& __new_value);

  template <class _ExecutionPolicy, class _Iterator, class _Pred, class _Tp>
  void __pstl_replace_if(_Backend, _Iterator __first, _Iterator __last, _Pred __pred, const _Tp& __new_value);

  template <class _ExecutionPolicy, class _Iterator, class _OutIterator, class _Tp>
  void __pstl_replace_copy(_Backend,
                           _Iterator __first,
                           _Iterator __last,
                           _OutIterator __result,
                           const _Tp& __old_value,
                           const _Tp& __new_value);

  template <class _ExecutionPolicy, class _Iterator, class _OutIterator, class _Pred, class _Tp>
  void __pstl_replace_copy_if(_Backend,
                              _Iterator __first,
                              _Iterator __last,
                              _OutIterator __result,
                              _Pred __pred,
                              const _Tp& __new_value);

  template <class _ExecutionPolicy, class _Iterator, class _Comp>
  void __pstl_sort(_Backend, _Iterator __first, _Iterator __last, _Comp __comp);

// TODO: Complete this list

*/

template <class _ExecutionPolicy>
struct __select_backend;

template <>
struct __select_backend<std::execution::sequenced_policy> {
  using type = __cpu_backend_tag;
};

#  if _LIBCPP_STD_VER >= 20
template <>
struct __select_backend<std::execution::unsequenced_policy> {
  using type = __cpu_backend_tag;
};
#  endif

#  if defined(_LIBCPP_PSTL_CPU_BACKEND_SERIAL) || defined(_LIBCPP_PSTL_CPU_BACKEND_THREAD) ||                          \
      defined(_LIBCPP_PSTL_CPU_BACKEND_LIBDISPATCH)
template <>
struct __select_backend<std::execution::parallel_policy> {
  using type = __cpu_backend_tag;
};

template <>
struct __select_backend<std::execution::parallel_unsequenced_policy> {
  using type = __cpu_backend_tag;
};

#  else

// ...New vendors can add parallel backends here...

#    error "Invalid choice of a PSTL parallel backend"
#  endif

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif // _LIBCPP___ALGORITHM_PSTL_BACKEND_H
