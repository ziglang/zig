// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ITERATOR_WRAP_ITER_H
#define _LIBCPP___ITERATOR_WRAP_ITER_H

#include <__config>
#include <__debug>
#include <__iterator/iterator_traits.h>
#include <__memory/pointer_traits.h> // __to_address
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Iter>
class __wrap_iter
{
public:
    typedef _Iter                                                      iterator_type;
    typedef typename iterator_traits<iterator_type>::value_type        value_type;
    typedef typename iterator_traits<iterator_type>::difference_type   difference_type;
    typedef typename iterator_traits<iterator_type>::pointer           pointer;
    typedef typename iterator_traits<iterator_type>::reference         reference;
    typedef typename iterator_traits<iterator_type>::iterator_category iterator_category;
#if _LIBCPP_STD_VER > 17
    typedef contiguous_iterator_tag                                    iterator_concept;
#endif

private:
    iterator_type __i;
public:
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG __wrap_iter() _NOEXCEPT
#if _LIBCPP_STD_VER > 11
                : __i{}
#endif
    {
#if _LIBCPP_DEBUG_LEVEL == 2
        __get_db()->__insert_i(this);
#endif
    }
    template <class _Up> _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
        __wrap_iter(const __wrap_iter<_Up>& __u,
            typename enable_if<is_convertible<_Up, iterator_type>::value>::type* = nullptr) _NOEXCEPT
            : __i(__u.base())
    {
#if _LIBCPP_DEBUG_LEVEL == 2
        __get_db()->__iterator_copy(this, &__u);
#endif
    }
#if _LIBCPP_DEBUG_LEVEL == 2
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
    __wrap_iter(const __wrap_iter& __x)
        : __i(__x.base())
    {
        __get_db()->__iterator_copy(this, &__x);
    }
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
    __wrap_iter& operator=(const __wrap_iter& __x)
    {
        if (this != &__x)
        {
            __get_db()->__iterator_copy(this, &__x);
            __i = __x.__i;
        }
        return *this;
    }
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
    ~__wrap_iter()
    {
        __get_db()->__erase_i(this);
    }
#endif
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG reference operator*() const _NOEXCEPT
    {
#if _LIBCPP_DEBUG_LEVEL == 2
        _LIBCPP_ASSERT(__get_const_db()->__dereferenceable(this),
                       "Attempted to dereference a non-dereferenceable iterator");
#endif
        return *__i;
    }
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG pointer  operator->() const _NOEXCEPT
    {
#if _LIBCPP_DEBUG_LEVEL == 2
        _LIBCPP_ASSERT(__get_const_db()->__dereferenceable(this),
                       "Attempted to dereference a non-dereferenceable iterator");
#endif
        return _VSTD::__to_address(__i);
    }
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG __wrap_iter& operator++() _NOEXCEPT
    {
#if _LIBCPP_DEBUG_LEVEL == 2
        _LIBCPP_ASSERT(__get_const_db()->__dereferenceable(this),
                       "Attempted to increment a non-incrementable iterator");
#endif
        ++__i;
        return *this;
    }
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG __wrap_iter  operator++(int) _NOEXCEPT
        {__wrap_iter __tmp(*this); ++(*this); return __tmp;}

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG __wrap_iter& operator--() _NOEXCEPT
    {
#if _LIBCPP_DEBUG_LEVEL == 2
        _LIBCPP_ASSERT(__get_const_db()->__decrementable(this),
                       "Attempted to decrement a non-decrementable iterator");
#endif
        --__i;
        return *this;
    }
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG __wrap_iter  operator--(int) _NOEXCEPT
        {__wrap_iter __tmp(*this); --(*this); return __tmp;}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG __wrap_iter  operator+ (difference_type __n) const _NOEXCEPT
        {__wrap_iter __w(*this); __w += __n; return __w;}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG __wrap_iter& operator+=(difference_type __n) _NOEXCEPT
    {
#if _LIBCPP_DEBUG_LEVEL == 2
        _LIBCPP_ASSERT(__get_const_db()->__addable(this, __n),
                   "Attempted to add/subtract an iterator outside its valid range");
#endif
        __i += __n;
        return *this;
    }
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG __wrap_iter  operator- (difference_type __n) const _NOEXCEPT
        {return *this + (-__n);}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG __wrap_iter& operator-=(difference_type __n) _NOEXCEPT
        {*this += -__n; return *this;}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG reference    operator[](difference_type __n) const _NOEXCEPT
    {
#if _LIBCPP_DEBUG_LEVEL == 2
        _LIBCPP_ASSERT(__get_const_db()->__subscriptable(this, __n),
                   "Attempted to subscript an iterator outside its valid range");
#endif
        return __i[__n];
    }

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG iterator_type base() const _NOEXCEPT {return __i;}

private:
#if _LIBCPP_DEBUG_LEVEL == 2
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG __wrap_iter(const void* __p, iterator_type __x) : __i(__x)
    {
        __get_db()->__insert_ic(this, __p);
    }
#else
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG __wrap_iter(iterator_type __x) _NOEXCEPT : __i(__x) {}
#endif

    template <class _Up> friend class __wrap_iter;
    template <class _CharT, class _Traits, class _Alloc> friend class basic_string;
    template <class _Tp, class _Alloc> friend class _LIBCPP_TEMPLATE_VIS vector;
    template <class _Tp, size_t> friend class _LIBCPP_TEMPLATE_VIS span;
};

template <class _Iter1>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
bool operator==(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter1>& __y) _NOEXCEPT
{
    return __x.base() == __y.base();
}

template <class _Iter1, class _Iter2>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
bool operator==(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter2>& __y) _NOEXCEPT
{
    return __x.base() == __y.base();
}

template <class _Iter1>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
bool operator<(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter1>& __y) _NOEXCEPT
{
#if _LIBCPP_DEBUG_LEVEL == 2
    _LIBCPP_ASSERT(__get_const_db()->__less_than_comparable(&__x, &__y),
                   "Attempted to compare incomparable iterators");
#endif
    return __x.base() < __y.base();
}

template <class _Iter1, class _Iter2>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
bool operator<(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter2>& __y) _NOEXCEPT
{
#if _LIBCPP_DEBUG_LEVEL == 2
    _LIBCPP_ASSERT(__get_const_db()->__less_than_comparable(&__x, &__y),
                   "Attempted to compare incomparable iterators");
#endif
    return __x.base() < __y.base();
}

template <class _Iter1>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
bool operator!=(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter1>& __y) _NOEXCEPT
{
    return !(__x == __y);
}

template <class _Iter1, class _Iter2>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
bool operator!=(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter2>& __y) _NOEXCEPT
{
    return !(__x == __y);
}

template <class _Iter1>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
bool operator>(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter1>& __y) _NOEXCEPT
{
    return __y < __x;
}

template <class _Iter1, class _Iter2>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
bool operator>(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter2>& __y) _NOEXCEPT
{
    return __y < __x;
}

template <class _Iter1>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
bool operator>=(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter1>& __y) _NOEXCEPT
{
    return !(__x < __y);
}

template <class _Iter1, class _Iter2>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
bool operator>=(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter2>& __y) _NOEXCEPT
{
    return !(__x < __y);
}

template <class _Iter1>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
bool operator<=(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter1>& __y) _NOEXCEPT
{
    return !(__y < __x);
}

template <class _Iter1, class _Iter2>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
bool operator<=(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter2>& __y) _NOEXCEPT
{
    return !(__y < __x);
}

template <class _Iter1, class _Iter2>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
#ifndef _LIBCPP_CXX03_LANG
auto operator-(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter2>& __y) _NOEXCEPT
    -> decltype(__x.base() - __y.base())
#else
typename __wrap_iter<_Iter1>::difference_type
operator-(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter2>& __y) _NOEXCEPT
#endif // C++03
{
#if _LIBCPP_DEBUG_LEVEL == 2
    _LIBCPP_ASSERT(__get_const_db()->__less_than_comparable(&__x, &__y),
                   "Attempted to subtract incompatible iterators");
#endif
    return __x.base() - __y.base();
}

template <class _Iter1>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_IF_NODEBUG
__wrap_iter<_Iter1> operator+(typename __wrap_iter<_Iter1>::difference_type __n, __wrap_iter<_Iter1> __x) _NOEXCEPT
{
    __x += __n;
    return __x;
}

#if _LIBCPP_STD_VER <= 17
template <class _It>
struct __is_cpp17_contiguous_iterator<__wrap_iter<_It> > : true_type {};
#endif

template <class _Iter>
_LIBCPP_CONSTEXPR
decltype(_VSTD::__to_address(declval<_Iter>()))
__to_address(__wrap_iter<_Iter> __w) _NOEXCEPT {
    return _VSTD::__to_address(__w.base());
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ITERATOR_WRAP_ITER_H
