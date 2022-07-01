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

#include <__config>
#include <__memory/addressof.h>
#include <__memory/construct_at.h>
#include <__memory/voidify.h>
#include <iterator>
#include <utility>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
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

#endif // _LIBCPP_STD_VER > 14

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___MEMORY_UNINITIALIZED_ALGORITHMS_H
