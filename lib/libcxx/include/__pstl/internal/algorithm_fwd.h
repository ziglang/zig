// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _PSTL_ALGORITHM_FWD_H
#define _PSTL_ALGORITHM_FWD_H

#include <__config>
#include <iterator>
#include <type_traits>
#include <utility>

namespace __pstl {
namespace __internal {

//------------------------------------------------------------------------
// walk1 (pseudo)
//
// walk1 evaluates f(x) for each dereferenced value x drawn from [first,last)
//------------------------------------------------------------------------

template <class _ForwardIterator, class _Function>
void __brick_walk1(_ForwardIterator,
                   _ForwardIterator,
                   _Function,
                   /*vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _Function>
void __brick_walk1(_RandomAccessIterator,
                   _RandomAccessIterator,
                   _Function,
                   /*vector=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator, class _Function>
void __pattern_walk1(_Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, _Function) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _Function>
void __pattern_walk1(
    __parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _Function);

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator, class _Brick>
void __pattern_walk_brick(_Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, _Brick) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _Brick>
void __pattern_walk_brick(
    __parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _Brick);

//------------------------------------------------------------------------
// walk1_n
//------------------------------------------------------------------------

template <class _ForwardIterator, class _Size, class _Function>
_ForwardIterator __brick_walk1_n(
    _ForwardIterator,
    _Size,
    _Function,
    /*_IsVectorTag=*/std::false_type);

template <class _RandomAccessIterator, class _DifferenceType, class _Function>
_RandomAccessIterator __brick_walk1_n(
    _RandomAccessIterator,
    _DifferenceType,
    _Function,
    /*vectorTag=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator, class _Size, class _Function>
_ForwardIterator __pattern_walk1_n(_Tag, _ExecutionPolicy&&, _ForwardIterator, _Size, _Function) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _Size, class _Function>
_RandomAccessIterator
__pattern_walk1_n(__parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _Size, _Function);

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator, class _Size, class _Brick>
_ForwardIterator __pattern_walk_brick_n(_Tag, _ExecutionPolicy&&, _ForwardIterator, _Size, _Brick) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _Size, class _Brick>
_RandomAccessIterator
__pattern_walk_brick_n(__parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _Size, _Brick);

//------------------------------------------------------------------------
// walk2 (pseudo)
//
// walk2 evaluates f(x,y) for deferenced values (x,y) drawn from [first1,last1) and [first2,...)
//------------------------------------------------------------------------

template <class _ForwardIterator1, class _ForwardIterator2, class _Function>
_ForwardIterator2 __brick_walk2(
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _Function,
    /*vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator1, class _RandomAccessIterator2, class _Function>
_RandomAccessIterator2 __brick_walk2(
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _Function,
    /*vector=*/std::true_type) noexcept;

template <class _ForwardIterator1, class _Size, class _ForwardIterator2, class _Function>
_ForwardIterator2 __brick_walk2_n(
    _ForwardIterator1,
    _Size,
    _ForwardIterator2,
    _Function,
    /*vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator1, class _Size, class _RandomAccessIterator2, class _Function>
_RandomAccessIterator2 __brick_walk2_n(
    _RandomAccessIterator1,
    _Size,
    _RandomAccessIterator2,
    _Function,
    /*vector=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _Function>
_ForwardIterator2
__pattern_walk2(_Tag, _ExecutionPolicy&&, _ForwardIterator1, _ForwardIterator1, _ForwardIterator2, _Function) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _Function>
_RandomAccessIterator2 __pattern_walk2(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _Function);

template <class _Tag,
          class _ExecutionPolicy,
          class _ForwardIterator1,
          class _Size,
          class _ForwardIterator2,
          class _Function>
_ForwardIterator2
__pattern_walk2_n(_Tag, _ExecutionPolicy&&, _ForwardIterator1, _Size, _ForwardIterator2, _Function) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _Size,
          class _RandomAccessIterator2,
          class _Function>
_RandomAccessIterator2 __pattern_walk2_n(
    __parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator1, _Size, _RandomAccessIterator2, _Function);

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _Brick>
_ForwardIterator2 __pattern_walk2_brick(
    _Tag, _ExecutionPolicy&&, _ForwardIterator1, _ForwardIterator1, _ForwardIterator2, _Brick) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _Brick>
_RandomAccessIterator2 __pattern_walk2_brick(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _Brick);

template <class _Tag,
          class _ExecutionPolicy,
          class _ForwardIterator1,
          class _Size,
          class _ForwardIterator2,
          class _Brick>
_ForwardIterator2
__pattern_walk2_brick_n(_Tag, _ExecutionPolicy&&, _ForwardIterator1, _Size, _ForwardIterator2, _Brick) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _Size,
          class _RandomAccessIterator2,
          class _Brick>
_RandomAccessIterator2 __pattern_walk2_brick_n(
    __parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator1, _Size, _RandomAccessIterator2, _Brick);

//------------------------------------------------------------------------
// walk3 (pseudo)
//
// walk3 evaluates f(x,y,z) for (x,y,z) drawn from [first1,last1), [first2,...), [first3,...)
//------------------------------------------------------------------------

template <class _ForwardIterator1, class _ForwardIterator2, class _ForwardIterator3, class _Function>
_ForwardIterator3 __brick_walk3(
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator3,
    _Function,
    /*vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator1, class _RandomAccessIterator2, class _RandomAccessIterator3, class _Function>
_RandomAccessIterator3 __brick_walk3(
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator3,
    _Function,
    /*vector=*/std::true_type) noexcept;

template <class _Tag,
          class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _ForwardIterator3,
          class _Function>
_ForwardIterator3 __pattern_walk3(
    _Tag,
    _ExecutionPolicy&&,
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator3,
    _Function) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _RandomAccessIterator3,
          class _Function>
_RandomAccessIterator3 __pattern_walk3(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator3,
    _Function);

//------------------------------------------------------------------------
// equal
//------------------------------------------------------------------------

template <class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
bool __brick_equal(_ForwardIterator1,
                   _ForwardIterator1,
                   _ForwardIterator2,
                   _BinaryPredicate,
                   /* is_vector = */ std::false_type) noexcept;

template <class _RandomAccessIterator1, class _RandomAccessIterator2, class _BinaryPredicate>
bool __brick_equal(_RandomAccessIterator1,
                   _RandomAccessIterator1,
                   _RandomAccessIterator2,
                   _BinaryPredicate,
                   /* is_vector = */ std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
bool __pattern_equal(
    _Tag, _ExecutionPolicy&&, _ForwardIterator1, _ForwardIterator1, _ForwardIterator2, _BinaryPredicate) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _BinaryPredicate>
bool __pattern_equal(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _BinaryPredicate);

template <class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
bool __brick_equal(_ForwardIterator1,
                   _ForwardIterator1,
                   _ForwardIterator2,
                   _ForwardIterator2,
                   _BinaryPredicate,
                   /* is_vector = */ std::false_type) noexcept;

template <class _RandomAccessIterator1, class _RandomAccessIterator2, class _BinaryPredicate>
bool __brick_equal(_RandomAccessIterator1,
                   _RandomAccessIterator1,
                   _RandomAccessIterator2,
                   _RandomAccessIterator2,
                   _BinaryPredicate,
                   /* is_vector = */ std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
bool __pattern_equal(
    _Tag,
    _ExecutionPolicy&&,
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _BinaryPredicate) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _BinaryPredicate>
bool __pattern_equal(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _BinaryPredicate);

//------------------------------------------------------------------------
// find_end
//------------------------------------------------------------------------

template <class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
_ForwardIterator1 __brick_find_end(
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _BinaryPredicate,
    /*__is_vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator1, class _RandomAccessIterator2, class _BinaryPredicate>
_RandomAccessIterator1 __brick_find_end(
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _BinaryPredicate,
    /*__is_vector=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
_ForwardIterator1 __pattern_find_end(
    _Tag,
    _ExecutionPolicy&&,
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _BinaryPredicate) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _BinaryPredicate>
_RandomAccessIterator1 __pattern_find_end(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _BinaryPredicate) noexcept;

//------------------------------------------------------------------------
// find_first_of
//------------------------------------------------------------------------

template <class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
_ForwardIterator1 __brick_find_first_of(
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _BinaryPredicate,
    /*__is_vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator1, class _RandomAccessIterator2, class _BinaryPredicate>
_RandomAccessIterator1 __brick_find_first_of(
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _BinaryPredicate,
    /*__is_vector=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
_ForwardIterator1 __pattern_find_first_of(
    _Tag,
    _ExecutionPolicy&&,
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _BinaryPredicate) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _BinaryPredicate>
_RandomAccessIterator1 __pattern_find_first_of(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _BinaryPredicate) noexcept;

//------------------------------------------------------------------------
// search
//------------------------------------------------------------------------

template <class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
_ForwardIterator1 __brick_search(
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _BinaryPredicate,
    /*vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator1, class _RandomAccessIterator2, class _BinaryPredicate>
_RandomAccessIterator1 __brick_search(
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _BinaryPredicate,
    /*vector=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
_ForwardIterator1 __pattern_search(
    _Tag,
    _ExecutionPolicy&&,
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _BinaryPredicate) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _BinaryPredicate>
_RandomAccessIterator1 __pattern_search(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _BinaryPredicate) noexcept;

//------------------------------------------------------------------------
// search_n
//------------------------------------------------------------------------

template <class _ForwardIterator, class _Size, class _Tp, class _BinaryPredicate>
_ForwardIterator __brick_search_n(
    _ForwardIterator,
    _ForwardIterator,
    _Size,
    const _Tp&,
    _BinaryPredicate,
    /*vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _Size, class _Tp, class _BinaryPredicate>
_RandomAccessIterator __brick_search_n(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _Size,
    const _Tp&,
    _BinaryPredicate,
    /*vector=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator, class _Size, class _Tp, class _BinaryPredicate>
_ForwardIterator __pattern_search_n(
    _Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, _Size, const _Tp&, _BinaryPredicate) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator,
          class _Size,
          class _Tp,
          class _BinaryPredicate>
_RandomAccessIterator __pattern_search_n(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _Size,
    const _Tp&,
    _BinaryPredicate) noexcept;

//------------------------------------------------------------------------
// copy_n
//------------------------------------------------------------------------

template <class _ForwardIterator, class _Size, class _OutputIterator>
_OutputIterator __brick_copy_n(_ForwardIterator,
                               _Size,
                               _OutputIterator,
                               /*vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _Size, class _OutputIterator>
_OutputIterator __brick_copy_n(_RandomAccessIterator,
                               _Size,
                               _OutputIterator,
                               /*vector=*/std::true_type) noexcept;

//------------------------------------------------------------------------
// copy
//------------------------------------------------------------------------

template <class _ForwardIterator, class _OutputIterator>
_OutputIterator __brick_copy(_ForwardIterator,
                             _ForwardIterator,
                             _OutputIterator,
                             /*vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _OutputIterator>
_OutputIterator __brick_copy(_RandomAccessIterator,
                             _RandomAccessIterator,
                             _OutputIterator,
                             /*vector=*/std::true_type) noexcept;

//------------------------------------------------------------------------
// move
//------------------------------------------------------------------------

template <class _ForwardIterator, class _OutputIterator>
_OutputIterator __brick_move(_ForwardIterator,
                             _ForwardIterator,
                             _OutputIterator,
                             /*vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _OutputIterator>
_OutputIterator __brick_move(_RandomAccessIterator,
                             _RandomAccessIterator,
                             _OutputIterator,
                             /*vector=*/std::true_type) noexcept;

//------------------------------------------------------------------------
// swap_ranges
//------------------------------------------------------------------------
template <class _ForwardIterator, class _OutputIterator>
_OutputIterator __brick_swap_ranges(
    _ForwardIterator,
    _ForwardIterator,
    _OutputIterator,
    /*vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _OutputIterator>
_OutputIterator __brick_swap_ranges(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _OutputIterator,
    /*vector=*/std::true_type) noexcept;

//------------------------------------------------------------------------
// copy_if
//------------------------------------------------------------------------

template <class _ForwardIterator, class _OutputIterator, class _UnaryPredicate>
_OutputIterator __brick_copy_if(
    _ForwardIterator,
    _ForwardIterator,
    _OutputIterator,
    _UnaryPredicate,
    /*vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _OutputIterator, class _UnaryPredicate>
_OutputIterator __brick_copy_if(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _OutputIterator,
    _UnaryPredicate,
    /*vector=*/std::true_type) noexcept;

template <class _DifferenceType, class _ForwardIterator, class _UnaryPredicate>
std::pair<_DifferenceType, _DifferenceType> __brick_calc_mask_1(
    _ForwardIterator,
    _ForwardIterator,
    bool* __restrict,
    _UnaryPredicate,
    /*vector=*/std::false_type) noexcept;
template <class _DifferenceType, class _RandomAccessIterator, class _UnaryPredicate>
std::pair<_DifferenceType, _DifferenceType> __brick_calc_mask_1(
    _RandomAccessIterator,
    _RandomAccessIterator,
    bool* __restrict,
    _UnaryPredicate,
    /*vector=*/std::true_type) noexcept;

template <class _ForwardIterator, class _OutputIterator>
void __brick_copy_by_mask(
    _ForwardIterator,
    _ForwardIterator,
    _OutputIterator,
    bool*,
    /*vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _OutputIterator>
void __brick_copy_by_mask(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _OutputIterator,
    bool* __restrict,
    /*vector=*/std::true_type) noexcept;

template <class _ForwardIterator, class _OutputIterator1, class _OutputIterator2>
void __brick_partition_by_mask(
    _ForwardIterator,
    _ForwardIterator,
    _OutputIterator1,
    _OutputIterator2,
    bool*,
    /*vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _OutputIterator1, class _OutputIterator2>
void __brick_partition_by_mask(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _OutputIterator1,
    _OutputIterator2,
    bool*,
    /*vector=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator, class _OutputIterator, class _UnaryPredicate>
_OutputIterator __pattern_copy_if(
    _Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, _OutputIterator, _UnaryPredicate) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator,
          class _OutputIterator,
          class _UnaryPredicate>
_OutputIterator __pattern_copy_if(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _OutputIterator,
    _UnaryPredicate);

//------------------------------------------------------------------------
// count
//------------------------------------------------------------------------

template <class _RandomAccessIterator, class _Predicate>
typename std::iterator_traits<_RandomAccessIterator>::difference_type __brick_count(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _Predicate,
    /* is_vector = */ std::true_type) noexcept;

template <class _ForwardIterator, class _Predicate>
typename std::iterator_traits<_ForwardIterator>::difference_type __brick_count(
    _ForwardIterator,
    _ForwardIterator,
    _Predicate,
    /* is_vector = */ std::false_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator, class _Predicate>
typename std::iterator_traits<_ForwardIterator>::difference_type
__pattern_count(_Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, _Predicate) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _Predicate>
typename std::iterator_traits<_RandomAccessIterator>::difference_type __pattern_count(
    __parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _Predicate);

//------------------------------------------------------------------------
// unique
//------------------------------------------------------------------------

template <class _ForwardIterator, class _BinaryPredicate>
_ForwardIterator __brick_unique(
    _ForwardIterator,
    _ForwardIterator,
    _BinaryPredicate,
    /*is_vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _BinaryPredicate>
_RandomAccessIterator __brick_unique(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _BinaryPredicate,
    /*is_vector=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator, class _BinaryPredicate>
_ForwardIterator
__pattern_unique(_Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, _BinaryPredicate) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _BinaryPredicate>
_RandomAccessIterator __pattern_unique(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _BinaryPredicate) noexcept;

//------------------------------------------------------------------------
// unique_copy
//------------------------------------------------------------------------

template <class _ForwardIterator, class OutputIterator, class _BinaryPredicate>
OutputIterator __brick_unique_copy(
    _ForwardIterator,
    _ForwardIterator,
    OutputIterator,
    _BinaryPredicate,
    /*vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _OutputIterator, class _BinaryPredicate>
_OutputIterator __brick_unique_copy(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _OutputIterator,
    _BinaryPredicate,
    /*vector=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator, class _OutputIterator, class _BinaryPredicate>
_OutputIterator __pattern_unique_copy(
    _Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, _OutputIterator, _BinaryPredicate) noexcept;

template <class _ExecutionPolicy, class _DifferenceType, class _RandomAccessIterator, class _BinaryPredicate>
_DifferenceType __brick_calc_mask_2(
    _RandomAccessIterator,
    _RandomAccessIterator,
    bool* __restrict,
    _BinaryPredicate,
    /*vector=*/std::false_type) noexcept;

template <class _DifferenceType, class _RandomAccessIterator, class _BinaryPredicate>
_DifferenceType __brick_calc_mask_2(
    _RandomAccessIterator,
    _RandomAccessIterator,
    bool* __restrict,
    _BinaryPredicate,
    /*vector=*/std::true_type) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator,
          class _OutputIterator,
          class _BinaryPredicate>
_OutputIterator __pattern_unique_copy(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _OutputIterator,
    _BinaryPredicate);

//------------------------------------------------------------------------
// reverse
//------------------------------------------------------------------------

template <class _BidirectionalIterator>
void __brick_reverse(_BidirectionalIterator,
                     _BidirectionalIterator,
                     /*__is_vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator>
void __brick_reverse(_RandomAccessIterator,
                     _RandomAccessIterator,
                     /*__is_vector=*/std::true_type) noexcept;

template <class _BidirectionalIterator>
void __brick_reverse(_BidirectionalIterator,
                     _BidirectionalIterator,
                     _BidirectionalIterator,
                     /*is_vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator>
void __brick_reverse(_RandomAccessIterator,
                     _RandomAccessIterator,
                     _RandomAccessIterator,
                     /*is_vector=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _BidirectionalIterator>
void __pattern_reverse(_Tag, _ExecutionPolicy&&, _BidirectionalIterator, _BidirectionalIterator) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator>
void __pattern_reverse(__parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator);

//------------------------------------------------------------------------
// reverse_copy
//------------------------------------------------------------------------

template <class _BidirectionalIterator, class _OutputIterator>
_OutputIterator __brick_reverse_copy(
    _BidirectionalIterator,
    _BidirectionalIterator,
    _OutputIterator,
    /*is_vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _OutputIterator>
_OutputIterator __brick_reverse_copy(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _OutputIterator,
    /*is_vector=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _BidirectionalIterator, class _OutputIterator>
_OutputIterator __pattern_reverse_copy(
    _Tag, _ExecutionPolicy&&, _BidirectionalIterator, _BidirectionalIterator, _OutputIterator) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _OutputIterator>
_OutputIterator __pattern_reverse_copy(
    __parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _OutputIterator);

//------------------------------------------------------------------------
// rotate
//------------------------------------------------------------------------

template <class _ForwardIterator>
_ForwardIterator __brick_rotate(
    _ForwardIterator,
    _ForwardIterator,
    _ForwardIterator,
    /*is_vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator>
_RandomAccessIterator __brick_rotate(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _RandomAccessIterator,
    /*is_vector=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator>
_ForwardIterator
__pattern_rotate(_Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, _ForwardIterator) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator>
_RandomAccessIterator __pattern_rotate(
    __parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _RandomAccessIterator);

//------------------------------------------------------------------------
// rotate_copy
//------------------------------------------------------------------------

template <class _ForwardIterator, class _OutputIterator>
_OutputIterator __brick_rotate_copy(
    _ForwardIterator,
    _ForwardIterator,
    _ForwardIterator,
    _OutputIterator,
    /*__is_vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _OutputIterator>
_OutputIterator __brick_rotate_copy(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _OutputIterator,
    /*__is_vector=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator, class _OutputIterator>
_OutputIterator __pattern_rotate_copy(
    _Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, _ForwardIterator, _OutputIterator) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _OutputIterator>
_OutputIterator __pattern_rotate_copy(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _OutputIterator);

//------------------------------------------------------------------------
// is_partitioned
//------------------------------------------------------------------------

template <class _ForwardIterator, class _UnaryPredicate>
bool __brick_is_partitioned(_ForwardIterator,
                            _ForwardIterator,
                            _UnaryPredicate,
                            /*is_vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _UnaryPredicate>
bool __brick_is_partitioned(_RandomAccessIterator,
                            _RandomAccessIterator,
                            _UnaryPredicate,
                            /*is_vector=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator, class _UnaryPredicate>
bool __pattern_is_partitioned(_Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, _UnaryPredicate) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _UnaryPredicate>
bool __pattern_is_partitioned(
    __parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _UnaryPredicate);

//------------------------------------------------------------------------
// partition
//------------------------------------------------------------------------

template <class _ForwardIterator, class _UnaryPredicate>
_ForwardIterator __brick_partition(
    _ForwardIterator,
    _ForwardIterator,
    _UnaryPredicate,
    /*is_vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _UnaryPredicate>
_RandomAccessIterator __brick_partition(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _UnaryPredicate,
    /*is_vector=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator, class _UnaryPredicate>
_ForwardIterator
__pattern_partition(_Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, _UnaryPredicate) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _UnaryPredicate>
_RandomAccessIterator __pattern_partition(
    __parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _UnaryPredicate);

//------------------------------------------------------------------------
// stable_partition
//------------------------------------------------------------------------

template <class _BidirectionalIterator, class _UnaryPredicate>
_BidirectionalIterator __brick_stable_partition(
    _BidirectionalIterator,
    _BidirectionalIterator,
    _UnaryPredicate,
    /*__is_vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _UnaryPredicate>
_RandomAccessIterator __brick_stable_partition(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _UnaryPredicate,
    /*__is_vector=*/std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _BidirectionalIterator, class _UnaryPredicate>
_BidirectionalIterator __pattern_stable_partition(
    _Tag, _ExecutionPolicy&&, _BidirectionalIterator, _BidirectionalIterator, _UnaryPredicate) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _UnaryPredicate>
_RandomAccessIterator __pattern_stable_partition(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _UnaryPredicate) noexcept;

//------------------------------------------------------------------------
// partition_copy
//------------------------------------------------------------------------

template <class _ForwardIterator, class _OutputIterator1, class _OutputIterator2, class _UnaryPredicate>
std::pair<_OutputIterator1, _OutputIterator2> __brick_partition_copy(
    _ForwardIterator,
    _ForwardIterator,
    _OutputIterator1,
    _OutputIterator2,
    _UnaryPredicate,
    /*is_vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator, class _OutputIterator1, class _OutputIterator2, class _UnaryPredicate>
std::pair<_OutputIterator1, _OutputIterator2> __brick_partition_copy(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _OutputIterator1,
    _OutputIterator2,
    _UnaryPredicate,
    /*is_vector=*/std::true_type) noexcept;

template <class _Tag,
          class _ExecutionPolicy,
          class _ForwardIterator,
          class _OutputIterator1,
          class _OutputIterator2,
          class _UnaryPredicate>
std::pair<_OutputIterator1, _OutputIterator2> __pattern_partition_copy(
    _Tag,
    _ExecutionPolicy&&,
    _ForwardIterator,
    _ForwardIterator,
    _OutputIterator1,
    _OutputIterator2,
    _UnaryPredicate) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator,
          class _OutputIterator1,
          class _OutputIterator2,
          class _UnaryPredicate>
std::pair<_OutputIterator1, _OutputIterator2> __pattern_partition_copy(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _OutputIterator1,
    _OutputIterator2,
    _UnaryPredicate);

//------------------------------------------------------------------------
// sort
//------------------------------------------------------------------------

template <class _Tag, class _ExecutionPolicy, class _RandomAccessIterator, class _Compare, class _IsMoveConstructible>
void __pattern_sort(
    _Tag, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _Compare, _IsMoveConstructible) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _Compare>
void __pattern_sort(__parallel_tag<_IsVector>,
                    _ExecutionPolicy&&,
                    _RandomAccessIterator,
                    _RandomAccessIterator,
                    _Compare,
                    /*is_move_constructible=*/std::true_type);

//------------------------------------------------------------------------
// stable_sort
//------------------------------------------------------------------------

template <class _Tag, class _ExecutionPolicy, class _RandomAccessIterator, class _Compare>
void __pattern_stable_sort(_Tag, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _Compare) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _Compare>
void __pattern_stable_sort(
    __parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _Compare);

//------------------------------------------------------------------------
// partial_sort
//------------------------------------------------------------------------

template <class _Tag, class _ExecutionPolicy, class _RandomAccessIterator, class _Compare>
void __pattern_partial_sort(
    _Tag, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _RandomAccessIterator, _Compare) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _Compare>
void __pattern_partial_sort(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _Compare);

//------------------------------------------------------------------------
// partial_sort_copy
//------------------------------------------------------------------------

template <class _Tag,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _Compare>
_RandomAccessIterator2 __pattern_partial_sort_copy(
    _Tag,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _Compare) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _Compare>
_RandomAccessIterator2 __pattern_partial_sort_copy(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _Compare);

//------------------------------------------------------------------------
// adjacent_find
//------------------------------------------------------------------------

template <class _RandomAccessIterator, class _BinaryPredicate>
_RandomAccessIterator __brick_adjacent_find(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _BinaryPredicate,
    /* IsVector = */ std::true_type,
    bool) noexcept;

template <class _ForwardIterator, class _BinaryPredicate>
_ForwardIterator __brick_adjacent_find(
    _ForwardIterator,
    _ForwardIterator,
    _BinaryPredicate,
    /* IsVector = */ std::false_type,
    bool) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator, class _BinaryPredicate>
_ForwardIterator
__pattern_adjacent_find(_Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, _BinaryPredicate, bool) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _BinaryPredicate>
_RandomAccessIterator __pattern_adjacent_find(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _BinaryPredicate,
    bool);

//------------------------------------------------------------------------
// nth_element
//------------------------------------------------------------------------
template <class _Tag, class _ExecutionPolicy, class _RandomAccessIterator, class _Compare>
void __pattern_nth_element(
    _Tag, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _RandomAccessIterator, _Compare) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _Compare>
void __pattern_nth_element(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _Compare) noexcept;

//------------------------------------------------------------------------
// fill, fill_n
//------------------------------------------------------------------------
template <class _RandomAccessIterator, class _Tp>
void __brick_fill(_RandomAccessIterator,
                  _RandomAccessIterator,
                  const _Tp&,
                  /* __is_vector = */ std::true_type) noexcept;

template <class _ForwardIterator, class _Tp>
void __brick_fill(_ForwardIterator,
                  _ForwardIterator,
                  const _Tp&,
                  /* __is_vector = */ std::false_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator, class _Tp>
void __pattern_fill(_Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, const _Tp&) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _Tp>
_RandomAccessIterator
__pattern_fill(__parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, const _Tp&);

template <class _RandomAccessIterator, class _Size, class _Tp>
_RandomAccessIterator
__brick_fill_n(_RandomAccessIterator,
               _Size,
               const _Tp&,
               /* __is_vector = */ std::true_type) noexcept;

template <class _OutputIterator, class _Size, class _Tp>
_OutputIterator
__brick_fill_n(_OutputIterator,
               _Size,
               const _Tp&,
               /* __is_vector = */ std::false_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _OutputIterator, class _Size, class _Tp>
_OutputIterator __pattern_fill_n(_Tag, _ExecutionPolicy&&, _OutputIterator, _Size, const _Tp&) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _Size, class _Tp>
_RandomAccessIterator
__pattern_fill_n(__parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _Size, const _Tp&);

//------------------------------------------------------------------------
// generate, generate_n
//------------------------------------------------------------------------

template <class _RandomAccessIterator, class _Generator>
void __brick_generate(_RandomAccessIterator,
                      _RandomAccessIterator,
                      _Generator,
                      /* is_vector = */ std::true_type) noexcept;

template <class _ForwardIterator, class _Generator>
void __brick_generate(_ForwardIterator,
                      _ForwardIterator,
                      _Generator,
                      /* is_vector = */ std::false_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator, class _Generator>
void __pattern_generate(_Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, _Generator) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _Generator>
_RandomAccessIterator __pattern_generate(
    __parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _Generator);

template <class _RandomAccessIterator, class Size, class _Generator>
_RandomAccessIterator __brick_generate_n(
    _RandomAccessIterator,
    Size,
    _Generator,
    /* is_vector = */ std::true_type) noexcept;

template <class OutputIterator, class Size, class _Generator>
OutputIterator __brick_generate_n(
    OutputIterator,
    Size,
    _Generator,
    /* is_vector = */ std::false_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class OutputIterator, class Size, class _Generator>
OutputIterator __pattern_generate_n(_Tag, _ExecutionPolicy&&, OutputIterator, Size, _Generator) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class Size, class _Generator>
_RandomAccessIterator
__pattern_generate_n(__parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, Size, _Generator);

//------------------------------------------------------------------------
// remove
//------------------------------------------------------------------------
template <class _ForwardIterator, class _UnaryPredicate>
_ForwardIterator __brick_remove_if(
    _ForwardIterator,
    _ForwardIterator,
    _UnaryPredicate,
    /* __is_vector = */ std::false_type) noexcept;

template <class _RandomAccessIterator, class _UnaryPredicate>
_RandomAccessIterator __brick_remove_if(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _UnaryPredicate,
    /* __is_vector = */ std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator, class _UnaryPredicate>
_ForwardIterator
__pattern_remove_if(_Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, _UnaryPredicate) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _UnaryPredicate>
_RandomAccessIterator __pattern_remove_if(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _UnaryPredicate) noexcept;

//------------------------------------------------------------------------
// merge
//------------------------------------------------------------------------

template <class _ForwardIterator1, class _ForwardIterator2, class _OutputIterator, class _Compare>
_OutputIterator __brick_merge(
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _OutputIterator,
    _Compare,
    /* __is_vector = */ std::false_type) noexcept;

template <class _RandomAccessIterator1, class _RandomAccessIterator2, class _OutputIterator, class _Compare>
_OutputIterator __brick_merge(
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _OutputIterator,
    _Compare,
    /* __is_vector = */ std::true_type) noexcept;

template <class _Tag,
          class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _OutputIterator,
          class _Compare>
_OutputIterator __pattern_merge(
    _Tag,
    _ExecutionPolicy&&,
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _OutputIterator,
    _Compare) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _OutputIterator,
          class _Compare>
_OutputIterator __pattern_merge(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _OutputIterator,
    _Compare);

//------------------------------------------------------------------------
// inplace_merge
//------------------------------------------------------------------------

template <class _BidirectionalIterator, class _Compare>
void __brick_inplace_merge(
    _BidirectionalIterator,
    _BidirectionalIterator,
    _BidirectionalIterator,
    _Compare,
    /* __is_vector = */ std::false_type) noexcept;

template <class _RandomAccessIterator, class _Compare>
void __brick_inplace_merge(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _Compare,
    /* __is_vector = */ std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _BidirectionalIterator, class _Compare>
void __pattern_inplace_merge(
    _Tag,
    _ExecutionPolicy&&,
    _BidirectionalIterator,
    _BidirectionalIterator,
    _BidirectionalIterator,
    _Compare) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _Compare>
void __pattern_inplace_merge(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _RandomAccessIterator,
    _Compare);

//------------------------------------------------------------------------
// includes
//------------------------------------------------------------------------

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _Compare>
bool __pattern_includes(
    _Tag,
    _ExecutionPolicy&&,
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _Compare) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _Compare>
bool __pattern_includes(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _Compare);

//------------------------------------------------------------------------
// set_union
//------------------------------------------------------------------------

template <class _ForwardIterator1, class _ForwardIterator2, class _OutputIterator, class _Compare>
_OutputIterator __brick_set_union(
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _OutputIterator,
    _Compare,
    /*__is_vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator1, class _RandomAccessIterator2, class _OutputIterator, class _Compare>
_OutputIterator __brick_set_union(
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _OutputIterator,
    _Compare,
    /*__is_vector=*/std::true_type) noexcept;

template <class _Tag,
          class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _OutputIterator,
          class _Compare>
_OutputIterator __pattern_set_union(
    _Tag,
    _ExecutionPolicy&&,
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _OutputIterator,
    _Compare) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _OutputIterator,
          class _Compare>
_OutputIterator __pattern_set_union(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _OutputIterator,
    _Compare);

//------------------------------------------------------------------------
// set_intersection
//------------------------------------------------------------------------

template <class _ForwardIterator1, class _ForwardIterator2, class _OutputIterator, class _Compare>
_OutputIterator __brick_set_intersection(
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _OutputIterator,
    _Compare,
    /*__is_vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator1, class _RandomAccessIterator2, class _OutputIterator, class _Compare>
_OutputIterator __brick_set_intersection(
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _OutputIterator,
    _Compare,
    /*__is_vector=*/std::true_type) noexcept;

template <class _Tag,
          class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _OutputIterator,
          class _Compare>
_OutputIterator __pattern_set_intersection(
    _Tag,
    _ExecutionPolicy&&,
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _OutputIterator,
    _Compare) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _OutputIterator,
          class _Compare>
_OutputIterator __pattern_set_intersection(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _OutputIterator,
    _Compare);

//------------------------------------------------------------------------
// set_difference
//------------------------------------------------------------------------

template <class _ForwardIterator1, class _ForwardIterator2, class _OutputIterator, class _Compare>
_OutputIterator __brick_set_difference(
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _OutputIterator,
    _Compare,
    /*__is_vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator1, class _RandomAccessIterator2, class _OutputIterator, class _Compare>
_OutputIterator __brick_set_difference(
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _OutputIterator,
    _Compare,
    /*__is_vector=*/std::true_type) noexcept;

template <class _Tag,
          class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _OutputIterator,
          class _Compare>
_OutputIterator __pattern_set_difference(
    _Tag,
    _ExecutionPolicy&&,
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _OutputIterator,
    _Compare) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _OutputIterator,
          class _Compare>
_OutputIterator __pattern_set_difference(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _OutputIterator,
    _Compare);

//------------------------------------------------------------------------
// set_symmetric_difference
//------------------------------------------------------------------------

template <class _ForwardIterator1, class _ForwardIterator2, class _OutputIterator, class _Compare>
_OutputIterator __brick_set_symmetric_difference(
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _OutputIterator,
    _Compare,
    /*__is_vector=*/std::false_type) noexcept;

template <class _RandomAccessIterator1, class _RandomAccessIterator2, class _OutputIterator, class _Compare>
_OutputIterator __brick_set_symmetric_difference(
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _OutputIterator,
    _Compare,
    /*__is_vector=*/std::true_type) noexcept;

template <class _Tag,
          class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _OutputIterator,
          class _Compare>
_OutputIterator __pattern_set_symmetric_difference(
    _Tag,
    _ExecutionPolicy&&,
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _OutputIterator,
    _Compare) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _OutputIterator,
          class _Compare>
_OutputIterator __pattern_set_symmetric_difference(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _OutputIterator,
    _Compare);

//------------------------------------------------------------------------
// is_heap_until
//------------------------------------------------------------------------

template <class _RandomAccessIterator, class _Compare>
_RandomAccessIterator __brick_is_heap_until(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _Compare,
    /* __is_vector = */ std::false_type) noexcept;

template <class _RandomAccessIterator, class _Compare>
_RandomAccessIterator __brick_is_heap_until(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _Compare,
    /* __is_vector = */ std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _RandomAccessIterator, class _Compare>
_RandomAccessIterator
__pattern_is_heap_until(_Tag, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _Compare) noexcept;

template <class _IsVector, class _ExecutionPolicy, class _RandomAccessIterator, class _Compare>
_RandomAccessIterator __pattern_is_heap_until(
    __parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _Compare) noexcept;

//------------------------------------------------------------------------
// min_element
//------------------------------------------------------------------------

template <typename _ForwardIterator, typename _Compare>
_ForwardIterator __brick_min_element(
    _ForwardIterator,
    _ForwardIterator,
    _Compare,
    /* __is_vector = */ std::false_type) noexcept;

template <typename _RandomAccessIterator, typename _Compare>
_RandomAccessIterator __brick_min_element(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _Compare,
    /* __is_vector = */ std::true_type) noexcept;

template <typename _Tag, typename _ExecutionPolicy, typename _ForwardIterator, typename _Compare>
_ForwardIterator __pattern_min_element(_Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, _Compare) noexcept;

template <typename _IsVector, typename _ExecutionPolicy, typename _RandomAccessIterator, typename _Compare>
_RandomAccessIterator __pattern_min_element(
    __parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _Compare);

//------------------------------------------------------------------------
// minmax_element
//------------------------------------------------------------------------

template <typename _ForwardIterator, typename _Compare>
std::pair<_ForwardIterator, _ForwardIterator> __brick_minmax_element(
    _ForwardIterator,
    _ForwardIterator,
    _Compare,
    /* __is_vector = */ std::false_type) noexcept;

template <typename _RandomAccessIterator, typename _Compare>
std::pair<_RandomAccessIterator, _RandomAccessIterator> __brick_minmax_element(
    _RandomAccessIterator,
    _RandomAccessIterator,
    _Compare,
    /* __is_vector = */ std::true_type) noexcept;

template <typename _Tag, typename _ExecutionPolicy, typename _ForwardIterator, typename _Compare>
std::pair<_ForwardIterator, _ForwardIterator>
__pattern_minmax_element(_Tag, _ExecutionPolicy&&, _ForwardIterator, _ForwardIterator, _Compare) noexcept;

template <typename _IsVector, typename _ExecutionPolicy, typename _RandomAccessIterator, typename _Compare>
std::pair<_RandomAccessIterator, _RandomAccessIterator> __pattern_minmax_element(
    __parallel_tag<_IsVector>, _ExecutionPolicy&&, _RandomAccessIterator, _RandomAccessIterator, _Compare);

//------------------------------------------------------------------------
// mismatch
//------------------------------------------------------------------------

template <class _ForwardIterator1, class _ForwardIterator2, class _Predicate>
std::pair<_ForwardIterator1, _ForwardIterator2> __brick_mismatch(
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _Predicate,
    /* __is_vector = */ std::false_type) noexcept;

template <class _RandomAccessIterator1, class _RandomAccessIterator2, class _Predicate>
std::pair<_RandomAccessIterator1, _RandomAccessIterator2> __brick_mismatch(
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _Predicate,
    /* __is_vector = */ std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _Predicate>
std::pair<_ForwardIterator1, _ForwardIterator2> __pattern_mismatch(
    _Tag,
    _ExecutionPolicy&&,
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _Predicate) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _Predicate>
std::pair<_RandomAccessIterator1, _RandomAccessIterator2> __pattern_mismatch(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _Predicate) noexcept;

//------------------------------------------------------------------------
// lexicographical_compare
//------------------------------------------------------------------------

template <class _ForwardIterator1, class _ForwardIterator2, class _Compare>
bool __brick_lexicographical_compare(
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _Compare,
    /* __is_vector = */ std::false_type) noexcept;

template <class _RandomAccessIterator1, class _RandomAccessIterator2, class _Compare>
bool __brick_lexicographical_compare(
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _Compare,
    /* __is_vector = */ std::true_type) noexcept;

template <class _Tag, class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _Compare>
bool __pattern_lexicographical_compare(
    _Tag,
    _ExecutionPolicy&&,
    _ForwardIterator1,
    _ForwardIterator1,
    _ForwardIterator2,
    _ForwardIterator2,
    _Compare) noexcept;

template <class _IsVector,
          class _ExecutionPolicy,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _Compare>
bool __pattern_lexicographical_compare(
    __parallel_tag<_IsVector>,
    _ExecutionPolicy&&,
    _RandomAccessIterator1,
    _RandomAccessIterator1,
    _RandomAccessIterator2,
    _RandomAccessIterator2,
    _Compare) noexcept;

} // namespace __internal
} // namespace __pstl

#endif /* _PSTL_ALGORITHM_FWD_H */
