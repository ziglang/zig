// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _PSTL_GLUE_MEMORY_IMPL_H
#define _PSTL_GLUE_MEMORY_IMPL_H

#include <__config>

#include "algorithm_fwd.h"
#include "execution_defs.h"
#include "utils.h"

#include "execution_impl.h"

namespace std {

// [uninitialized.copy]

template <class _ExecutionPolicy, class _InputIterator, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator> uninitialized_copy(
    _ExecutionPolicy&& __exec, _InputIterator __first, _InputIterator __last, _ForwardIterator __result) {
  typedef typename iterator_traits<_InputIterator>::value_type _ValueType1;
  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType2;
  typedef typename iterator_traits<_InputIterator>::reference _ReferenceType1;
  typedef typename iterator_traits<_ForwardIterator>::reference _ReferenceType2;

  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first, __result);

  using __is_vector = typename decltype(__dispatch_tag)::__is_vector;

  return __pstl::__internal::__invoke_if_else(
      std::integral_constant < bool,
      std::is_trivial<_ValueType1>::value&& std::is_trivial<_ValueType2>::value > (),
      [&]() {
        return __pstl::__internal::__pattern_walk2_brick(
            __dispatch_tag,
            std::forward<_ExecutionPolicy>(__exec),
            __first,
            __last,
            __result,
            [](_InputIterator __begin, _InputIterator __end, _ForwardIterator __res) {
              return __pstl::__internal::__brick_copy(__begin, __end, __res, __is_vector{});
            });
      },
      [&]() {
        return __pstl::__internal::__pattern_walk2(
            __dispatch_tag,
            std::forward<_ExecutionPolicy>(__exec),
            __first,
            __last,
            __result,
            [](_ReferenceType1 __val1, _ReferenceType2 __val2) { ::new (std::addressof(__val2)) _ValueType2(__val1); });
      });
}

template <class _ExecutionPolicy, class _InputIterator, class _Size, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
uninitialized_copy_n(_ExecutionPolicy&& __exec, _InputIterator __first, _Size __n, _ForwardIterator __result) {
  typedef typename iterator_traits<_InputIterator>::value_type _ValueType1;
  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType2;
  typedef typename iterator_traits<_InputIterator>::reference _ReferenceType1;
  typedef typename iterator_traits<_ForwardIterator>::reference _ReferenceType2;

  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first, __result);

  using __is_vector = typename decltype(__dispatch_tag)::__is_vector;

  return __pstl::__internal::__invoke_if_else(
      std::integral_constant < bool,
      std::is_trivial<_ValueType1>::value&& std::is_trivial<_ValueType2>::value > (),
      [&]() {
        return __pstl::__internal::__pattern_walk2_brick_n(
            __dispatch_tag,
            std::forward<_ExecutionPolicy>(__exec),
            __first,
            __n,
            __result,
            [](_InputIterator __begin, _Size __sz, _ForwardIterator __res) {
              return __pstl::__internal::__brick_copy_n(__begin, __sz, __res, __is_vector{});
            });
      },
      [&]() {
        return __pstl::__internal::__pattern_walk2_n(
            __dispatch_tag,
            std::forward<_ExecutionPolicy>(__exec),
            __first,
            __n,
            __result,
            [](_ReferenceType1 __val1, _ReferenceType2 __val2) { ::new (std::addressof(__val2)) _ValueType2(__val1); });
      });
}

// [uninitialized.move]

template <class _ExecutionPolicy, class _InputIterator, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator> uninitialized_move(
    _ExecutionPolicy&& __exec, _InputIterator __first, _InputIterator __last, _ForwardIterator __result) {
  typedef typename iterator_traits<_InputIterator>::value_type _ValueType1;
  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType2;
  typedef typename iterator_traits<_InputIterator>::reference _ReferenceType1;
  typedef typename iterator_traits<_ForwardIterator>::reference _ReferenceType2;

  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first, __result);

  using __is_vector = typename decltype(__dispatch_tag)::__is_vector;

  return __pstl::__internal::__invoke_if_else(
      std::integral_constant < bool,
      std::is_trivial<_ValueType1>::value&& std::is_trivial<_ValueType2>::value > (),
      [&]() {
        return __pstl::__internal::__pattern_walk2_brick(
            __dispatch_tag,
            std::forward<_ExecutionPolicy>(__exec),
            __first,
            __last,
            __result,
            [](_InputIterator __begin, _InputIterator __end, _ForwardIterator __res) {
              return __pstl::__internal::__brick_copy(__begin, __end, __res, __is_vector{});
            });
      },
      [&]() {
        return __pstl::__internal::__pattern_walk2(
            __dispatch_tag,
            std::forward<_ExecutionPolicy>(__exec),
            __first,
            __last,
            __result,
            [](_ReferenceType1 __val1, _ReferenceType2 __val2) {
              ::new (std::addressof(__val2)) _ValueType2(std::move(__val1));
            });
      });
}

template <class _ExecutionPolicy, class _InputIterator, class _Size, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
uninitialized_move_n(_ExecutionPolicy&& __exec, _InputIterator __first, _Size __n, _ForwardIterator __result) {
  typedef typename iterator_traits<_InputIterator>::value_type _ValueType1;
  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType2;
  typedef typename iterator_traits<_InputIterator>::reference _ReferenceType1;
  typedef typename iterator_traits<_ForwardIterator>::reference _ReferenceType2;

  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first, __result);

  using __is_vector = typename decltype(__dispatch_tag)::__is_vector;

  return __pstl::__internal::__invoke_if_else(
      std::integral_constant < bool,
      std::is_trivial<_ValueType1>::value&& std::is_trivial<_ValueType2>::value > (),
      [&]() {
        return __pstl::__internal::__pattern_walk2_brick_n(
            __dispatch_tag,
            std::forward<_ExecutionPolicy>(__exec),
            __first,
            __n,
            __result,
            [](_InputIterator __begin, _Size __sz, _ForwardIterator __res) {
              return __pstl::__internal::__brick_copy_n(__begin, __sz, __res, __is_vector{});
            });
      },
      [&]() {
        return __pstl::__internal::__pattern_walk2_n(
            __dispatch_tag,
            std::forward<_ExecutionPolicy>(__exec),
            __first,
            __n,
            __result,
            [](_ReferenceType1 __val1, _ReferenceType2 __val2) {
              ::new (std::addressof(__val2)) _ValueType2(std::move(__val1));
            });
      });
}

// [uninitialized.fill]

template <class _ExecutionPolicy, class _ForwardIterator, class _Tp>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, void>
uninitialized_fill(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last, const _Tp& __value) {
  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType;
  typedef typename iterator_traits<_ForwardIterator>::reference _ReferenceType;

  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  using __is_vector = typename decltype(__dispatch_tag)::__is_vector;

  __pstl::__internal::__invoke_if_else(
      std::is_arithmetic<_ValueType>(),
      [&]() {
        __pstl::__internal::__pattern_walk_brick(
            __dispatch_tag,
            std::forward<_ExecutionPolicy>(__exec),
            __first,
            __last,
            [&__value](_ForwardIterator __begin, _ForwardIterator __end) {
              __pstl::__internal::__brick_fill(__begin, __end, _ValueType(__value), __is_vector{});
            });
      },
      [&]() {
        __pstl::__internal::__pattern_walk1(
            __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, [&__value](_ReferenceType __val) {
              ::new (std::addressof(__val)) _ValueType(__value);
            });
      });
}

template <class _ExecutionPolicy, class _ForwardIterator, class _Size, class _Tp>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
uninitialized_fill_n(_ExecutionPolicy&& __exec, _ForwardIterator __first, _Size __n, const _Tp& __value) {
  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType;
  typedef typename iterator_traits<_ForwardIterator>::reference _ReferenceType;

  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  using __is_vector = typename decltype(__dispatch_tag)::__is_vector;

  return __pstl::__internal::__invoke_if_else(
      std::is_arithmetic<_ValueType>(),
      [&]() {
        return __pstl::__internal::__pattern_walk_brick_n(
            __dispatch_tag,
            std::forward<_ExecutionPolicy>(__exec),
            __first,
            __n,
            [&__value](_ForwardIterator __begin, _Size __count) {
              return __pstl::__internal::__brick_fill_n(__begin, __count, _ValueType(__value), __is_vector{});
            });
      },
      [&]() {
        return __pstl::__internal::__pattern_walk1_n(
            __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __n, [&__value](_ReferenceType __val) {
              ::new (std::addressof(__val)) _ValueType(__value);
            });
      });
}

// [specialized.destroy]

template <class _ExecutionPolicy, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, void>
destroy(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last) {
  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType;
  typedef typename iterator_traits<_ForwardIterator>::reference _ReferenceType;

  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  __pstl::__internal::__invoke_if_not(std::is_trivially_destructible<_ValueType>(), [&]() {
    __pstl::__internal::__pattern_walk1(
        __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, [](_ReferenceType __val) {
          __val.~_ValueType();
        });
  });
}

template <class _ExecutionPolicy, class _ForwardIterator, class _Size>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
destroy_n(_ExecutionPolicy&& __exec, _ForwardIterator __first, _Size __n) {
  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType;
  typedef typename iterator_traits<_ForwardIterator>::reference _ReferenceType;

  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  return __pstl::__internal::__invoke_if_else(
      std::is_trivially_destructible<_ValueType>(),
      [&]() { return std::next(__first, __n); },
      [&]() {
        return __pstl::__internal::__pattern_walk1_n(
            __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __n, [](_ReferenceType __val) {
              __val.~_ValueType();
            });
      });
}

// [uninitialized.construct.default]

template <class _ExecutionPolicy, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, void>
uninitialized_default_construct(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last) {
  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType;
  typedef typename iterator_traits<_ForwardIterator>::reference _ReferenceType;

  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  __pstl::__internal::__invoke_if_not(std::is_trivial<_ValueType>(), [&]() {
    __pstl::__internal::__pattern_walk1(
        __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, [](_ReferenceType __val) {
          ::new (std::addressof(__val)) _ValueType;
        });
  });
}

template <class _ExecutionPolicy, class _ForwardIterator, class _Size>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
uninitialized_default_construct_n(_ExecutionPolicy&& __exec, _ForwardIterator __first, _Size __n) {
  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType;
  typedef typename iterator_traits<_ForwardIterator>::reference _ReferenceType;

  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  return __pstl::__internal::__invoke_if_else(
      std::is_trivial<_ValueType>(),
      [&]() { return std::next(__first, __n); },
      [&]() {
        return __pstl::__internal::__pattern_walk1_n(
            __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __n, [](_ReferenceType __val) {
              ::new (std::addressof(__val)) _ValueType;
            });
      });
}

// [uninitialized.construct.value]

template <class _ExecutionPolicy, class _ForwardIterator>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, void>
uninitialized_value_construct(_ExecutionPolicy&& __exec, _ForwardIterator __first, _ForwardIterator __last) {
  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType;
  typedef typename iterator_traits<_ForwardIterator>::reference _ReferenceType;

  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  using __is_vector = typename decltype(__dispatch_tag)::__is_vector;

  __pstl::__internal::__invoke_if_else(
      std::is_trivial<_ValueType>(),
      [&]() {
        __pstl::__internal::__pattern_walk_brick(
            __dispatch_tag,
            std::forward<_ExecutionPolicy>(__exec),
            __first,
            __last,
            [](_ForwardIterator __begin, _ForwardIterator __end) {
              __pstl::__internal::__brick_fill(__begin, __end, _ValueType(), __is_vector{});
            });
      },
      [&]() {
        __pstl::__internal::__pattern_walk1(
            __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __last, [](_ReferenceType __val) {
              ::new (std::addressof(__val)) _ValueType();
            });
      });
}

template <class _ExecutionPolicy, class _ForwardIterator, class _Size>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator>
uninitialized_value_construct_n(_ExecutionPolicy&& __exec, _ForwardIterator __first, _Size __n) {
  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType;
  typedef typename iterator_traits<_ForwardIterator>::reference _ReferenceType;

  auto __dispatch_tag = __pstl::__internal::__select_backend(__exec, __first);

  using __is_vector = typename decltype(__dispatch_tag)::__is_vector;

  return __pstl::__internal::__invoke_if_else(
      std::is_trivial<_ValueType>(),
      [&]() {
        return __pstl::__internal::__pattern_walk_brick_n(
            __dispatch_tag,
            std::forward<_ExecutionPolicy>(__exec),
            __first,
            __n,
            [](_ForwardIterator __begin, _Size __count) {
              return __pstl::__internal::__brick_fill_n(__begin, __count, _ValueType(), __is_vector{});
            });
      },
      [&]() {
        return __pstl::__internal::__pattern_walk1_n(
            __dispatch_tag, std::forward<_ExecutionPolicy>(__exec), __first, __n, [](_ReferenceType __val) {
              ::new (std::addressof(__val)) _ValueType();
            });
      });
}

} // namespace std

#endif /* _PSTL_GLUE_MEMORY_IMPL_H */
