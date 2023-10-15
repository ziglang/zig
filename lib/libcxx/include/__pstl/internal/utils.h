// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _PSTL_UTILS_H
#define _PSTL_UTILS_H

#include <__config>
#include <__exception/terminate.h>
#include <__utility/forward.h>
#include <new>

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

namespace __pstl {
namespace __internal {

template <typename _Fp>
_LIBCPP_HIDE_FROM_ABI auto __except_handler(_Fp __f) -> decltype(__f()) {
#ifndef _LIBCPP_HAS_NO_EXCEPTIONS
  try {
#endif // _LIBCPP_HAS_NO_EXCEPTIONS
    return __f();
#ifndef _LIBCPP_HAS_NO_EXCEPTIONS
  } catch (const std::bad_alloc&) {
    throw;            // re-throw bad_alloc according to the standard [algorithms.parallel.exceptions]
  } catch (...) {
    std::terminate(); // Good bye according to the standard [algorithms.parallel.exceptions]
  }
#endif // _LIBCPP_HAS_NO_EXCEPTIONS
}

template <typename _Fp>
_LIBCPP_HIDE_FROM_ABI void __invoke_if(std::true_type, _Fp __f) {
  __f();
}

template <typename _Fp>
_LIBCPP_HIDE_FROM_ABI void __invoke_if(std::false_type, _Fp) {}

template <typename _Fp>
_LIBCPP_HIDE_FROM_ABI void __invoke_if_not(std::false_type, _Fp __f) {
  __f();
}

template <typename _Fp>
_LIBCPP_HIDE_FROM_ABI void __invoke_if_not(std::true_type, _Fp) {}

template <typename _F1, typename _F2>
_LIBCPP_HIDE_FROM_ABI auto __invoke_if_else(std::true_type, _F1 __f1, _F2) -> decltype(__f1()) {
  return __f1();
}

template <typename _F1, typename _F2>
_LIBCPP_HIDE_FROM_ABI auto __invoke_if_else(std::false_type, _F1, _F2 __f2) -> decltype(__f2()) {
  return __f2();
}

//! Unary operator that returns reference to its argument.
struct __no_op {
  template <typename _Tp>
  _LIBCPP_HIDE_FROM_ABI _Tp&& operator()(_Tp&& __a) const {
    return std::forward<_Tp>(__a);
  }
};

template <typename _Pred>
class __reorder_pred {
  _Pred __pred_;

public:
  _LIBCPP_HIDE_FROM_ABI explicit __reorder_pred(_Pred __pred) : __pred_(__pred) {}

  template <typename _FTp, typename _STp>
  _LIBCPP_HIDE_FROM_ABI bool operator()(_FTp&& __a, _STp&& __b) {
    return __pred_(std::forward<_STp>(__b), std::forward<_FTp>(__a));
  }
};

//! Like a polymorphic lambda for pred(...,value)
template <typename _Tp, typename _Predicate>
class __equal_value_by_pred {
  const _Tp& __value_;
  _Predicate __pred_;

public:
  _LIBCPP_HIDE_FROM_ABI __equal_value_by_pred(const _Tp& __value, _Predicate __pred)
      : __value_(__value), __pred_(__pred) {}

  template <typename _Arg>
  _LIBCPP_HIDE_FROM_ABI bool operator()(_Arg&& __arg) {
    return __pred_(std::forward<_Arg>(__arg), __value_);
  }
};

//! Like a polymorphic lambda for ==value
template <typename _Tp>
class __equal_value {
  const _Tp& __value_;

public:
  _LIBCPP_HIDE_FROM_ABI explicit __equal_value(const _Tp& __value) : __value_(__value) {}

  template <typename _Arg>
  _LIBCPP_HIDE_FROM_ABI bool operator()(_Arg&& __arg) const {
    return std::forward<_Arg>(__arg) == __value_;
  }
};

//! Logical negation of ==value
template <typename _Tp>
class __not_equal_value {
  const _Tp& __value_;

public:
  _LIBCPP_HIDE_FROM_ABI explicit __not_equal_value(const _Tp& __value) : __value_(__value) {}

  template <typename _Arg>
  _LIBCPP_HIDE_FROM_ABI bool operator()(_Arg&& __arg) const {
    return !(std::forward<_Arg>(__arg) == __value_);
  }
};

template <typename _ForwardIterator, typename _Compare>
_LIBCPP_HIDE_FROM_ABI _ForwardIterator
__cmp_iterators_by_values(_ForwardIterator __a, _ForwardIterator __b, _Compare __comp) {
  if (__a < __b) { // we should return closer iterator
    return __comp(*__b, *__a) ? __b : __a;
  } else {
    return __comp(*__a, *__b) ? __a : __b;
  }
}

} // namespace __internal
} // namespace __pstl

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif /* _PSTL_UTILS_H */
