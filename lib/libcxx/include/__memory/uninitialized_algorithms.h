// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___MEMORY_UNINITIALIZED_ALGORITHMS_H
#define _LIBCPP___MEMORY_UNINITIALIZED_ALGORITHMS_H

#include <__algorithm/copy.h>
#include <__algorithm/move.h>
#include <__config>
#include <__iterator/iterator_traits.h>
#include <__iterator/reverse_iterator.h>
#include <__memory/addressof.h>
#include <__memory/allocator_traits.h>
#include <__memory/construct_at.h>
#include <__memory/pointer_traits.h>
#include <__memory/voidify.h>
#include <__type_traits/is_constant_evaluated.h>
#include <__utility/move.h>
#include <__utility/pair.h>
#include <__utility/transaction.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

// This is a simplified version of C++20 `unreachable_sentinel` that doesn't use concepts and thus can be used in any
// language mode.
struct __unreachable_sentinel {
  template <class _Iter>
  _LIBCPP_HIDE_FROM_ABI friend _LIBCPP_CONSTEXPR bool operator!=(const _Iter&, __unreachable_sentinel) _NOEXCEPT {
    return true;
  }
};

// uninitialized_copy

template <class _ValueType, class _InputIterator, class _Sentinel1, class _ForwardIterator, class _Sentinel2>
inline _LIBCPP_HIDE_FROM_ABI pair<_InputIterator, _ForwardIterator>
__uninitialized_copy(_InputIterator __ifirst, _Sentinel1 __ilast,
                     _ForwardIterator __ofirst, _Sentinel2 __olast) {
  _ForwardIterator __idx = __ofirst;
#ifndef _LIBCPP_NO_EXCEPTIONS
  try {
#endif
    for (; __ifirst != __ilast && __idx != __olast; ++__ifirst, (void)++__idx)
      ::new (_VSTD::__voidify(*__idx)) _ValueType(*__ifirst);
#ifndef _LIBCPP_NO_EXCEPTIONS
  } catch (...) {
    _VSTD::__destroy(__ofirst, __idx);
    throw;
  }
#endif

  return pair<_InputIterator, _ForwardIterator>(_VSTD::move(__ifirst), _VSTD::move(__idx));
}

template <class _InputIterator, class _ForwardIterator>
_ForwardIterator uninitialized_copy(_InputIterator __ifirst, _InputIterator __ilast,
                                    _ForwardIterator __ofirst) {
  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType;
  auto __result = _VSTD::__uninitialized_copy<_ValueType>(_VSTD::move(__ifirst), _VSTD::move(__ilast),
                                                          _VSTD::move(__ofirst), __unreachable_sentinel());
  return _VSTD::move(__result.second);
}

// uninitialized_copy_n

template <class _ValueType, class _InputIterator, class _Size, class _ForwardIterator, class _Sentinel>
inline _LIBCPP_HIDE_FROM_ABI pair<_InputIterator, _ForwardIterator>
__uninitialized_copy_n(_InputIterator __ifirst, _Size __n,
                       _ForwardIterator __ofirst, _Sentinel __olast) {
  _ForwardIterator __idx = __ofirst;
#ifndef _LIBCPP_NO_EXCEPTIONS
  try {
#endif
    for (; __n > 0 && __idx != __olast; ++__ifirst, (void)++__idx, (void)--__n)
      ::new (_VSTD::__voidify(*__idx)) _ValueType(*__ifirst);
#ifndef _LIBCPP_NO_EXCEPTIONS
  } catch (...) {
    _VSTD::__destroy(__ofirst, __idx);
    throw;
  }
#endif

  return pair<_InputIterator, _ForwardIterator>(_VSTD::move(__ifirst), _VSTD::move(__idx));
}

template <class _InputIterator, class _Size, class _ForwardIterator>
inline _LIBCPP_HIDE_FROM_ABI _ForwardIterator uninitialized_copy_n(_InputIterator __ifirst, _Size __n,
                                                                   _ForwardIterator __ofirst) {
  typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType;
  auto __result = _VSTD::__uninitialized_copy_n<_ValueType>(_VSTD::move(__ifirst), __n, _VSTD::move(__ofirst),
                                                            __unreachable_sentinel());
  return _VSTD::move(__result.second);
}

// uninitialized_fill

template <class _ValueType, class _ForwardIterator, class _Sentinel, class _Tp>
inline _LIBCPP_HIDE_FROM_ABI
_ForwardIterator __uninitialized_fill(_ForwardIterator __first, _Sentinel __last, const _Tp& __x)
{
    _ForwardIterator __idx = __first;
#ifndef _LIBCPP_NO_EXCEPTIONS
    try
    {
#endif
        for (; __idx != __last; ++__idx)
            ::new (_VSTD::__voidify(*__idx)) _ValueType(__x);
#ifndef _LIBCPP_NO_EXCEPTIONS
    }
    catch (...)
    {
        _VSTD::__destroy(__first, __idx);
        throw;
    }
#endif

    return __idx;
}

template <class _ForwardIterator, class _Tp>
inline _LIBCPP_HIDE_FROM_ABI
void uninitialized_fill(_ForwardIterator __first, _ForwardIterator __last, const _Tp& __x)
{
    typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType;
    (void)_VSTD::__uninitialized_fill<_ValueType>(__first, __last, __x);
}

// uninitialized_fill_n

template <class _ValueType, class _ForwardIterator, class _Size, class _Tp>
inline _LIBCPP_HIDE_FROM_ABI
_ForwardIterator __uninitialized_fill_n(_ForwardIterator __first, _Size __n, const _Tp& __x)
{
    _ForwardIterator __idx = __first;
#ifndef _LIBCPP_NO_EXCEPTIONS
    try
    {
#endif
        for (; __n > 0; ++__idx, (void) --__n)
            ::new (_VSTD::__voidify(*__idx)) _ValueType(__x);
#ifndef _LIBCPP_NO_EXCEPTIONS
    }
    catch (...)
    {
        _VSTD::__destroy(__first, __idx);
        throw;
    }
#endif

    return __idx;
}

template <class _ForwardIterator, class _Size, class _Tp>
inline _LIBCPP_HIDE_FROM_ABI
_ForwardIterator uninitialized_fill_n(_ForwardIterator __first, _Size __n, const _Tp& __x)
{
    typedef typename iterator_traits<_ForwardIterator>::value_type _ValueType;
    return _VSTD::__uninitialized_fill_n<_ValueType>(__first, __n, __x);
}

#if _LIBCPP_STD_VER > 14

// uninitialized_default_construct

template <class _ValueType, class _ForwardIterator, class _Sentinel>
inline _LIBCPP_HIDE_FROM_ABI
_ForwardIterator __uninitialized_default_construct(_ForwardIterator __first, _Sentinel __last) {
    auto __idx = __first;
#ifndef _LIBCPP_NO_EXCEPTIONS
    try {
#endif
    for (; __idx != __last; ++__idx)
        ::new (_VSTD::__voidify(*__idx)) _ValueType;
#ifndef _LIBCPP_NO_EXCEPTIONS
    } catch (...) {
        _VSTD::__destroy(__first, __idx);
        throw;
    }
#endif

    return __idx;
}

template <class _ForwardIterator>
inline _LIBCPP_HIDE_FROM_ABI
void uninitialized_default_construct(_ForwardIterator __first, _ForwardIterator __last) {
    using _ValueType = typename iterator_traits<_ForwardIterator>::value_type;
    (void)_VSTD::__uninitialized_default_construct<_ValueType>(
        _VSTD::move(__first), _VSTD::move(__last));
}

// uninitialized_default_construct_n

template <class _ValueType, class _ForwardIterator, class _Size>
inline _LIBCPP_HIDE_FROM_ABI
_ForwardIterator __uninitialized_default_construct_n(_ForwardIterator __first, _Size __n) {
    auto __idx = __first;
#ifndef _LIBCPP_NO_EXCEPTIONS
    try {
#endif
    for (; __n > 0; ++__idx, (void) --__n)
        ::new (_VSTD::__voidify(*__idx)) _ValueType;
#ifndef _LIBCPP_NO_EXCEPTIONS
    } catch (...) {
        _VSTD::__destroy(__first, __idx);
        throw;
    }
#endif

    return __idx;
}

template <class _ForwardIterator, class _Size>
inline _LIBCPP_HIDE_FROM_ABI
_ForwardIterator uninitialized_default_construct_n(_ForwardIterator __first, _Size __n) {
    using _ValueType = typename iterator_traits<_ForwardIterator>::value_type;
    return _VSTD::__uninitialized_default_construct_n<_ValueType>(_VSTD::move(__first), __n);
}

// uninitialized_value_construct

template <class _ValueType, class _ForwardIterator, class _Sentinel>
inline _LIBCPP_HIDE_FROM_ABI
_ForwardIterator __uninitialized_value_construct(_ForwardIterator __first, _Sentinel __last) {
    auto __idx = __first;
#ifndef _LIBCPP_NO_EXCEPTIONS
    try {
#endif
    for (; __idx != __last; ++__idx)
        ::new (_VSTD::__voidify(*__idx)) _ValueType();
#ifndef _LIBCPP_NO_EXCEPTIONS
    } catch (...) {
        _VSTD::__destroy(__first, __idx);
        throw;
    }
#endif

    return __idx;
}

template <class _ForwardIterator>
inline _LIBCPP_HIDE_FROM_ABI
void uninitialized_value_construct(_ForwardIterator __first, _ForwardIterator __last) {
    using _ValueType = typename iterator_traits<_ForwardIterator>::value_type;
    (void)_VSTD::__uninitialized_value_construct<_ValueType>(
        _VSTD::move(__first), _VSTD::move(__last));
}

// uninitialized_value_construct_n

template <class _ValueType, class _ForwardIterator, class _Size>
inline _LIBCPP_HIDE_FROM_ABI
_ForwardIterator __uninitialized_value_construct_n(_ForwardIterator __first, _Size __n) {
    auto __idx = __first;
#ifndef _LIBCPP_NO_EXCEPTIONS
    try {
#endif
    for (; __n > 0; ++__idx, (void) --__n)
        ::new (_VSTD::__voidify(*__idx)) _ValueType();
#ifndef _LIBCPP_NO_EXCEPTIONS
    } catch (...) {
        _VSTD::__destroy(__first, __idx);
        throw;
    }
#endif

    return __idx;
}

template <class _ForwardIterator, class _Size>
inline _LIBCPP_HIDE_FROM_ABI
_ForwardIterator uninitialized_value_construct_n(_ForwardIterator __first, _Size __n) {
    using _ValueType = typename iterator_traits<_ForwardIterator>::value_type;
    return __uninitialized_value_construct_n<_ValueType>(_VSTD::move(__first), __n);
}

// uninitialized_move

template <class _ValueType, class _InputIterator, class _Sentinel1, class _ForwardIterator, class _Sentinel2,
          class _IterMove>
inline _LIBCPP_HIDE_FROM_ABI pair<_InputIterator, _ForwardIterator>
__uninitialized_move(_InputIterator __ifirst, _Sentinel1 __ilast,
                     _ForwardIterator __ofirst, _Sentinel2 __olast, _IterMove __iter_move) {
  auto __idx = __ofirst;
#ifndef _LIBCPP_NO_EXCEPTIONS
  try {
#endif
    for (; __ifirst != __ilast && __idx != __olast; ++__idx, (void)++__ifirst) {
      ::new (_VSTD::__voidify(*__idx)) _ValueType(__iter_move(__ifirst));
    }
#ifndef _LIBCPP_NO_EXCEPTIONS
  } catch (...) {
    _VSTD::__destroy(__ofirst, __idx);
    throw;
  }
#endif

  return {_VSTD::move(__ifirst), _VSTD::move(__idx)};
}

template <class _InputIterator, class _ForwardIterator>
inline _LIBCPP_HIDE_FROM_ABI _ForwardIterator uninitialized_move(_InputIterator __ifirst, _InputIterator __ilast,
                                                                 _ForwardIterator __ofirst) {
  using _ValueType = typename iterator_traits<_ForwardIterator>::value_type;
  auto __iter_move = [](auto&& __iter) -> decltype(auto) { return _VSTD::move(*__iter); };

  auto __result = _VSTD::__uninitialized_move<_ValueType>(_VSTD::move(__ifirst), _VSTD::move(__ilast),
                                                          _VSTD::move(__ofirst), __unreachable_sentinel(), __iter_move);
  return _VSTD::move(__result.second);
}

// uninitialized_move_n

template <class _ValueType, class _InputIterator, class _Size, class _ForwardIterator, class _Sentinel, class _IterMove>
inline _LIBCPP_HIDE_FROM_ABI pair<_InputIterator, _ForwardIterator>
__uninitialized_move_n(_InputIterator __ifirst, _Size __n,
                       _ForwardIterator __ofirst, _Sentinel __olast, _IterMove __iter_move) {
  auto __idx = __ofirst;
#ifndef _LIBCPP_NO_EXCEPTIONS
  try {
#endif
    for (; __n > 0 && __idx != __olast; ++__idx, (void)++__ifirst, --__n)
      ::new (_VSTD::__voidify(*__idx)) _ValueType(__iter_move(__ifirst));
#ifndef _LIBCPP_NO_EXCEPTIONS
  } catch (...) {
    _VSTD::__destroy(__ofirst, __idx);
    throw;
  }
#endif

  return {_VSTD::move(__ifirst), _VSTD::move(__idx)};
}

template <class _InputIterator, class _Size, class _ForwardIterator>
inline _LIBCPP_HIDE_FROM_ABI pair<_InputIterator, _ForwardIterator>
uninitialized_move_n(_InputIterator __ifirst, _Size __n, _ForwardIterator __ofirst) {
  using _ValueType = typename iterator_traits<_ForwardIterator>::value_type;
  auto __iter_move = [](auto&& __iter) -> decltype(auto) { return _VSTD::move(*__iter); };

  return _VSTD::__uninitialized_move_n<_ValueType>(_VSTD::move(__ifirst), __n, _VSTD::move(__ofirst),
                                                   __unreachable_sentinel(), __iter_move);
}

// TODO: Rewrite this to iterate left to right and use reverse_iterators when calling
// Destroys every element in the range [first, last) FROM RIGHT TO LEFT using allocator
// destruction. If elements are themselves C-style arrays, they are recursively destroyed
// in the same manner.
//
// This function assumes that destructors do not throw, and that the allocator is bound to
// the correct type.
template<class _Alloc, class _BidirIter, class = __enable_if_t<
    __is_cpp17_bidirectional_iterator<_BidirIter>::value
>>
_LIBCPP_HIDE_FROM_ABI
constexpr void __allocator_destroy_multidimensional(_Alloc& __alloc, _BidirIter __first, _BidirIter __last) noexcept {
    using _ValueType = typename iterator_traits<_BidirIter>::value_type;
    static_assert(is_same_v<typename allocator_traits<_Alloc>::value_type, _ValueType>,
        "The allocator should already be rebound to the correct type");

    if (__first == __last)
        return;

    if constexpr (is_array_v<_ValueType>) {
        static_assert(!__libcpp_is_unbounded_array<_ValueType>::value,
            "arrays of unbounded arrays don't exist, but if they did we would mess up here");

        using _Element = remove_extent_t<_ValueType>;
        __allocator_traits_rebind_t<_Alloc, _Element> __elem_alloc(__alloc);
        do {
            --__last;
            decltype(auto) __array = *__last;
            std::__allocator_destroy_multidimensional(__elem_alloc, __array, __array + extent_v<_ValueType>);
        } while (__last != __first);
    } else {
        do {
            --__last;
            allocator_traits<_Alloc>::destroy(__alloc, std::addressof(*__last));
        } while (__last != __first);
    }
}

// Constructs the object at the given location using the allocator's construct method.
//
// If the object being constructed is an array, each element of the array is allocator-constructed,
// recursively. If an exception is thrown during the construction of an array, the initialized
// elements are destroyed in reverse order of initialization using allocator destruction.
//
// This function assumes that the allocator is bound to the correct type.
template<class _Alloc, class _Tp>
_LIBCPP_HIDE_FROM_ABI
constexpr void __allocator_construct_at(_Alloc& __alloc, _Tp* __loc) {
    static_assert(is_same_v<typename allocator_traits<_Alloc>::value_type, _Tp>,
        "The allocator should already be rebound to the correct type");

    if constexpr (is_array_v<_Tp>) {
        using _Element = remove_extent_t<_Tp>;
        __allocator_traits_rebind_t<_Alloc, _Element> __elem_alloc(__alloc);
        size_t __i = 0;
        _Tp& __array = *__loc;

        // If an exception is thrown, destroy what we have constructed so far in reverse order.
        __transaction __guard([&]() { std::__allocator_destroy_multidimensional(__elem_alloc, __array, __array + __i); });
        for (; __i != extent_v<_Tp>; ++__i) {
            std::__allocator_construct_at(__elem_alloc, std::addressof(__array[__i]));
        }
        __guard.__complete();
    } else {
        allocator_traits<_Alloc>::construct(__alloc, __loc);
    }
}

// Constructs the object at the given location using the allocator's construct method, passing along
// the provided argument.
//
// If the object being constructed is an array, the argument is also assumed to be an array. Each
// each element of the array being constructed is allocator-constructed from the corresponding
// element of the argument array. If an exception is thrown during the construction of an array,
// the initialized elements are destroyed in reverse order of initialization using allocator
// destruction.
//
// This function assumes that the allocator is bound to the correct type.
template<class _Alloc, class _Tp, class _Arg>
_LIBCPP_HIDE_FROM_ABI
constexpr void __allocator_construct_at(_Alloc& __alloc, _Tp* __loc, _Arg const& __arg) {
    static_assert(is_same_v<typename allocator_traits<_Alloc>::value_type, _Tp>,
        "The allocator should already be rebound to the correct type");

    if constexpr (is_array_v<_Tp>) {
        static_assert(is_array_v<_Arg>,
            "Provided non-array initialization argument to __allocator_construct_at when "
            "trying to construct an array.");

        using _Element = remove_extent_t<_Tp>;
        __allocator_traits_rebind_t<_Alloc, _Element> __elem_alloc(__alloc);
        size_t __i = 0;
        _Tp& __array = *__loc;

        // If an exception is thrown, destroy what we have constructed so far in reverse order.
        __transaction __guard([&]() { std::__allocator_destroy_multidimensional(__elem_alloc, __array, __array + __i); });
        for (; __i != extent_v<_Tp>; ++__i) {
            std::__allocator_construct_at(__elem_alloc, std::addressof(__array[__i]), __arg[__i]);
        }
        __guard.__complete();
    } else {
        allocator_traits<_Alloc>::construct(__alloc, __loc, __arg);
    }
}

// Given a range starting at it and containing n elements, initializes each element in the
// range from left to right using the construct method of the allocator (rebound to the
// correct type).
//
// If an exception is thrown, the initialized elements are destroyed in reverse order of
// initialization using allocator_traits destruction. If the elements in the range are C-style
// arrays, they are initialized element-wise using allocator construction, and recursively so.
template<class _Alloc, class _BidirIter, class _Tp, class _Size = typename iterator_traits<_BidirIter>::difference_type>
_LIBCPP_HIDE_FROM_ABI
constexpr void __uninitialized_allocator_fill_n(_Alloc& __alloc, _BidirIter __it, _Size __n, _Tp const& __value) {
    using _ValueType = typename iterator_traits<_BidirIter>::value_type;
    __allocator_traits_rebind_t<_Alloc, _ValueType> __value_alloc(__alloc);
    _BidirIter __begin = __it;

    // If an exception is thrown, destroy what we have constructed so far in reverse order.
    __transaction __guard([&]() { std::__allocator_destroy_multidimensional(__value_alloc, __begin, __it); });
    for (; __n != 0; --__n, ++__it) {
        std::__allocator_construct_at(__value_alloc, std::addressof(*__it), __value);
    }
    __guard.__complete();
}

// Same as __uninitialized_allocator_fill_n, but doesn't pass any initialization argument
// to the allocator's construct method, which results in value initialization.
template<class _Alloc, class _BidirIter, class _Size = typename iterator_traits<_BidirIter>::difference_type>
_LIBCPP_HIDE_FROM_ABI
constexpr void __uninitialized_allocator_value_construct_n(_Alloc& __alloc, _BidirIter __it, _Size __n) {
    using _ValueType = typename iterator_traits<_BidirIter>::value_type;
    __allocator_traits_rebind_t<_Alloc, _ValueType> __value_alloc(__alloc);
    _BidirIter __begin = __it;

    // If an exception is thrown, destroy what we have constructed so far in reverse order.
    __transaction __guard([&]() { std::__allocator_destroy_multidimensional(__value_alloc, __begin, __it); });
    for (; __n != 0; --__n, ++__it) {
        std::__allocator_construct_at(__value_alloc, std::addressof(*__it));
    }
    __guard.__complete();
}

#endif // _LIBCPP_STD_VER > 14

// Destroy all elements in [__first, __last) from left to right using allocator destruction.
template <class _Alloc, class _Iter, class _Sent>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17 void
__allocator_destroy(_Alloc& __alloc, _Iter __first, _Sent __last) {
  for (; __first != __last; ++__first)
     allocator_traits<_Alloc>::destroy(__alloc, std::__to_address(__first));
}

template <class _Alloc, class _Iter>
class _AllocatorDestroyRangeReverse {
public:
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11
  _AllocatorDestroyRangeReverse(_Alloc& __alloc, _Iter& __first, _Iter& __last)
      : __alloc_(__alloc), __first_(__first), __last_(__last) {}

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 void operator()() const {
    std::__allocator_destroy(__alloc_, std::reverse_iterator<_Iter>(__last_), std::reverse_iterator<_Iter>(__first_));
  }

private:
  _Alloc& __alloc_;
  _Iter& __first_;
  _Iter& __last_;
};

// Copy-construct [__first1, __last1) in [__first2, __first2 + N), where N is distance(__first1, __last1).
//
// The caller has to ensure that __first2 can hold at least N uninitialized elements. If an exception is thrown the
// already copied elements are destroyed in reverse order of their construction.
template <class _Alloc, class _Iter1, class _Sent1, class _Iter2>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17 _Iter2
__uninitialized_allocator_copy(_Alloc& __alloc, _Iter1 __first1, _Sent1 __last1, _Iter2 __first2) {
#ifndef _LIBCPP_NO_EXCEPTIONS
  auto __destruct_first = __first2;
  try {
#endif
  while (__first1 != __last1) {
    allocator_traits<_Alloc>::construct(__alloc, std::__to_address(__first2), *__first1);
    ++__first1;
    ++__first2;
  }
#ifndef _LIBCPP_NO_EXCEPTIONS
  } catch (...) {
    _AllocatorDestroyRangeReverse<_Alloc, _Iter2>(__alloc, __destruct_first, __first2)();
    throw;
  }
#endif
  return __first2;
}

template <class _Alloc, class _Type>
struct __allocator_has_trivial_copy_construct : _Not<__has_construct<_Alloc, _Type*, const _Type&> > {};

template <class _Type>
struct __allocator_has_trivial_copy_construct<allocator<_Type>, _Type> : true_type {};

template <class _Alloc,
          class _Type,
          class _RawType = typename remove_const<_Type>::type,
          __enable_if_t<
              // using _RawType because of the allocator<T const> extension
              is_trivially_copy_constructible<_RawType>::value && is_trivially_copy_assignable<_RawType>::value &&
              __allocator_has_trivial_copy_construct<_Alloc, _RawType>::value>* = nullptr>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17 _Type*
__uninitialized_allocator_copy(_Alloc&, const _Type* __first1, const _Type* __last1, _Type* __first2) {
  // TODO: Remove the const_cast once we drop support for std::allocator<T const>
  if (__libcpp_is_constant_evaluated()) {
    while (__first1 != __last1) {
      std::__construct_at(std::__to_address(__first2), *__first1);
      ++__first1;
      ++__first2;
    }
    return __first2;
  } else {
    return std::copy(__first1, __last1, const_cast<_RawType*>(__first2));
  }
}

// Move-construct the elements [__first1, __last1) into [__first2, __first2 + N)
// if the move constructor is noexcept, where N is distance(__first1, __last1).
//
// Otherwise try to copy all elements. If an exception is thrown the already copied
// elements are destroyed in reverse order of their construction.
template <class _Alloc, class _Iter1, class _Sent1, class _Iter2>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17 _Iter2 __uninitialized_allocator_move_if_noexcept(
    _Alloc& __alloc, _Iter1 __first1, _Sent1 __last1, _Iter2 __first2) {
  static_assert(__is_cpp17_move_insertable<_Alloc>::value,
                "The specified type does not meet the requirements of Cpp17MoveInsertable");
#ifndef _LIBCPP_NO_EXCEPTIONS
  auto __destruct_first = __first2;
  try {
#endif
  while (__first1 != __last1) {
#ifndef _LIBCPP_NO_EXCEPTIONS
    allocator_traits<_Alloc>::construct(__alloc, std::__to_address(__first2), std::move_if_noexcept(*__first1));
#else
    allocator_traits<_Alloc>::construct(__alloc, std::__to_address(__first2), std::move(*__first1));
#endif
    ++__first1;
    ++__first2;
  }
#ifndef _LIBCPP_NO_EXCEPTIONS
  } catch (...) {
    _AllocatorDestroyRangeReverse<_Alloc, _Iter2>(__alloc, __destruct_first, __first2)();
    throw;
  }
#endif
  return __first2;
}

template <class _Alloc, class _Type>
struct __allocator_has_trivial_move_construct : _Not<__has_construct<_Alloc, _Type*, _Type&&> > {};

template <class _Type>
struct __allocator_has_trivial_move_construct<allocator<_Type>, _Type> : true_type {};

#ifndef _LIBCPP_COMPILER_GCC
template <
    class _Alloc,
    class _Iter1,
    class _Iter2,
    class _Type = typename iterator_traits<_Iter1>::value_type,
    class = __enable_if_t<is_trivially_move_constructible<_Type>::value && is_trivially_move_assignable<_Type>::value &&
                          __allocator_has_trivial_move_construct<_Alloc, _Type>::value> >
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17 _Iter2
__uninitialized_allocator_move_if_noexcept(_Alloc&, _Iter1 __first1, _Iter1 __last1, _Iter2 __first2) {
  if (__libcpp_is_constant_evaluated()) {
    while (__first1 != __last1) {
      std::__construct_at(std::__to_address(__first2), std::move(*__first1));
      ++__first1;
      ++__first2;
    }
    return __first2;
  } else {
    return std::move(__first1, __last1, __first2);
  }
}
#endif // _LIBCPP_COMPILER_GCC

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___MEMORY_UNINITIALIZED_ALGORITHMS_H
