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
#include <iterator>
#include <utility>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _InputIterator, class _ForwardIterator>
_ForwardIterator
uninitialized_copy(_InputIterator __f, _InputIterator __l, _ForwardIterator __r)
{
    typedef typename iterator_traits<_ForwardIterator>::value_type value_type;
#ifndef _LIBCPP_NO_EXCEPTIONS
    _ForwardIterator __s = __r;
    try
    {
#endif
        for (; __f != __l; ++__f, (void) ++__r)
            ::new ((void*)_VSTD::addressof(*__r)) value_type(*__f);
#ifndef _LIBCPP_NO_EXCEPTIONS
    }
    catch (...)
    {
        for (; __s != __r; ++__s)
            __s->~value_type();
        throw;
    }
#endif
    return __r;
}

template <class _InputIterator, class _Size, class _ForwardIterator>
_ForwardIterator
uninitialized_copy_n(_InputIterator __f, _Size __n, _ForwardIterator __r)
{
    typedef typename iterator_traits<_ForwardIterator>::value_type value_type;
#ifndef _LIBCPP_NO_EXCEPTIONS
    _ForwardIterator __s = __r;
    try
    {
#endif
        for (; __n > 0; ++__f, (void) ++__r, (void) --__n)
            ::new ((void*)_VSTD::addressof(*__r)) value_type(*__f);
#ifndef _LIBCPP_NO_EXCEPTIONS
    }
    catch (...)
    {
        for (; __s != __r; ++__s)
            __s->~value_type();
        throw;
    }
#endif
    return __r;
}

template <class _ForwardIterator, class _Tp>
void
uninitialized_fill(_ForwardIterator __f, _ForwardIterator __l, const _Tp& __x)
{
    typedef typename iterator_traits<_ForwardIterator>::value_type value_type;
#ifndef _LIBCPP_NO_EXCEPTIONS
    _ForwardIterator __s = __f;
    try
    {
#endif
        for (; __f != __l; ++__f)
            ::new ((void*)_VSTD::addressof(*__f)) value_type(__x);
#ifndef _LIBCPP_NO_EXCEPTIONS
    }
    catch (...)
    {
        for (; __s != __f; ++__s)
            __s->~value_type();
        throw;
    }
#endif
}

template <class _ForwardIterator, class _Size, class _Tp>
_ForwardIterator
uninitialized_fill_n(_ForwardIterator __f, _Size __n, const _Tp& __x)
{
    typedef typename iterator_traits<_ForwardIterator>::value_type value_type;
#ifndef _LIBCPP_NO_EXCEPTIONS
    _ForwardIterator __s = __f;
    try
    {
#endif
        for (; __n > 0; ++__f, (void) --__n)
            ::new ((void*)_VSTD::addressof(*__f)) value_type(__x);
#ifndef _LIBCPP_NO_EXCEPTIONS
    }
    catch (...)
    {
        for (; __s != __f; ++__s)
            __s->~value_type();
        throw;
    }
#endif
    return __f;
}

#if _LIBCPP_STD_VER > 14

template <class _ForwardIterator>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
void destroy(_ForwardIterator __first, _ForwardIterator __last) {
    for (; __first != __last; ++__first)
        _VSTD::destroy_at(_VSTD::addressof(*__first));
}

template <class _ForwardIterator, class _Size>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
_ForwardIterator destroy_n(_ForwardIterator __first, _Size __n) {
    for (; __n > 0; (void)++__first, --__n)
        _VSTD::destroy_at(_VSTD::addressof(*__first));
    return __first;
}

template <class _ForwardIterator>
inline _LIBCPP_INLINE_VISIBILITY
void uninitialized_default_construct(_ForwardIterator __first, _ForwardIterator __last) {
    using _Vt = typename iterator_traits<_ForwardIterator>::value_type;
    auto __idx = __first;
#ifndef _LIBCPP_NO_EXCEPTIONS
    try {
#endif
    for (; __idx != __last; ++__idx)
        ::new ((void*)_VSTD::addressof(*__idx)) _Vt;
#ifndef _LIBCPP_NO_EXCEPTIONS
    } catch (...) {
        _VSTD::destroy(__first, __idx);
        throw;
    }
#endif
}

template <class _ForwardIterator, class _Size>
inline _LIBCPP_INLINE_VISIBILITY
_ForwardIterator uninitialized_default_construct_n(_ForwardIterator __first, _Size __n) {
    using _Vt = typename iterator_traits<_ForwardIterator>::value_type;
    auto __idx = __first;
#ifndef _LIBCPP_NO_EXCEPTIONS
    try {
#endif
    for (; __n > 0; (void)++__idx, --__n)
        ::new ((void*)_VSTD::addressof(*__idx)) _Vt;
    return __idx;
#ifndef _LIBCPP_NO_EXCEPTIONS
    } catch (...) {
        _VSTD::destroy(__first, __idx);
        throw;
    }
#endif
}


template <class _ForwardIterator>
inline _LIBCPP_INLINE_VISIBILITY
void uninitialized_value_construct(_ForwardIterator __first, _ForwardIterator __last) {
    using _Vt = typename iterator_traits<_ForwardIterator>::value_type;
    auto __idx = __first;
#ifndef _LIBCPP_NO_EXCEPTIONS
    try {
#endif
    for (; __idx != __last; ++__idx)
        ::new ((void*)_VSTD::addressof(*__idx)) _Vt();
#ifndef _LIBCPP_NO_EXCEPTIONS
    } catch (...) {
        _VSTD::destroy(__first, __idx);
        throw;
    }
#endif
}

template <class _ForwardIterator, class _Size>
inline _LIBCPP_INLINE_VISIBILITY
_ForwardIterator uninitialized_value_construct_n(_ForwardIterator __first, _Size __n) {
    using _Vt = typename iterator_traits<_ForwardIterator>::value_type;
    auto __idx = __first;
#ifndef _LIBCPP_NO_EXCEPTIONS
    try {
#endif
    for (; __n > 0; (void)++__idx, --__n)
        ::new ((void*)_VSTD::addressof(*__idx)) _Vt();
    return __idx;
#ifndef _LIBCPP_NO_EXCEPTIONS
    } catch (...) {
        _VSTD::destroy(__first, __idx);
        throw;
    }
#endif
}


template <class _InputIt, class _ForwardIt>
inline _LIBCPP_INLINE_VISIBILITY
_ForwardIt uninitialized_move(_InputIt __first, _InputIt __last, _ForwardIt __first_res) {
    using _Vt = typename iterator_traits<_ForwardIt>::value_type;
    auto __idx = __first_res;
#ifndef _LIBCPP_NO_EXCEPTIONS
    try {
#endif
    for (; __first != __last; (void)++__idx, ++__first)
        ::new ((void*)_VSTD::addressof(*__idx)) _Vt(_VSTD::move(*__first));
    return __idx;
#ifndef _LIBCPP_NO_EXCEPTIONS
    } catch (...) {
        _VSTD::destroy(__first_res, __idx);
        throw;
    }
#endif
}

template <class _InputIt, class _Size, class _ForwardIt>
inline _LIBCPP_INLINE_VISIBILITY
pair<_InputIt, _ForwardIt>
uninitialized_move_n(_InputIt __first, _Size __n, _ForwardIt __first_res) {
    using _Vt = typename iterator_traits<_ForwardIt>::value_type;
    auto __idx = __first_res;
#ifndef _LIBCPP_NO_EXCEPTIONS
    try {
#endif
    for (; __n > 0; ++__idx, (void)++__first, --__n)
        ::new ((void*)_VSTD::addressof(*__idx)) _Vt(_VSTD::move(*__first));
    return {__first, __idx};
#ifndef _LIBCPP_NO_EXCEPTIONS
    } catch (...) {
        _VSTD::destroy(__first_res, __idx);
        throw;
    }
#endif
}

#endif // _LIBCPP_STD_VER > 14

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___MEMORY_UNINITIALIZED_ALGORITHMS_H
