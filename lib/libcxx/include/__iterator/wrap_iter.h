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
#include <__memory/addressof.h>
#include <__memory/pointer_traits.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/is_convertible.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

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
    iterator_type __i_;
public:
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 __wrap_iter() _NOEXCEPT
                : __i_()
    {
        _VSTD::__debug_db_insert_i(this);
    }
    template <class _Up> _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14
        __wrap_iter(const __wrap_iter<_Up>& __u,
            typename enable_if<is_convertible<_Up, iterator_type>::value>::type* = nullptr) _NOEXCEPT
            : __i_(__u.base())
    {
#ifdef _LIBCPP_ENABLE_DEBUG_MODE
      if (!__libcpp_is_constant_evaluated())
        __get_db()->__iterator_copy(this, _VSTD::addressof(__u));
#endif
    }
#ifdef _LIBCPP_ENABLE_DEBUG_MODE
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14
    __wrap_iter(const __wrap_iter& __x)
        : __i_(__x.base())
    {
      if (!__libcpp_is_constant_evaluated())
        __get_db()->__iterator_copy(this, _VSTD::addressof(__x));
    }
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14
    __wrap_iter& operator=(const __wrap_iter& __x)
    {
        if (this != _VSTD::addressof(__x))
        {
            if (!__libcpp_is_constant_evaluated())
                __get_db()->__iterator_copy(this, _VSTD::addressof(__x));
            __i_ = __x.__i_;
        }
        return *this;
    }
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20
    ~__wrap_iter()
    {
      if (!__libcpp_is_constant_evaluated())
        __get_db()->__erase_i(this);
    }
#endif
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 reference operator*() const _NOEXCEPT
    {
        _LIBCPP_DEBUG_ASSERT(__get_const_db()->__dereferenceable(this),
                             "Attempted to dereference a non-dereferenceable iterator");
        return *__i_;
    }
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 pointer operator->() const _NOEXCEPT
    {
        _LIBCPP_DEBUG_ASSERT(__get_const_db()->__dereferenceable(this),
                             "Attempted to dereference a non-dereferenceable iterator");
        return _VSTD::__to_address(__i_);
    }
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 __wrap_iter& operator++() _NOEXCEPT
    {
        _LIBCPP_DEBUG_ASSERT(__get_const_db()->__dereferenceable(this),
                             "Attempted to increment a non-incrementable iterator");
        ++__i_;
        return *this;
    }
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 __wrap_iter  operator++(int) _NOEXCEPT
        {__wrap_iter __tmp(*this); ++(*this); return __tmp;}

    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 __wrap_iter& operator--() _NOEXCEPT
    {
        _LIBCPP_DEBUG_ASSERT(__get_const_db()->__decrementable(this),
                             "Attempted to decrement a non-decrementable iterator");
        --__i_;
        return *this;
    }
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 __wrap_iter  operator--(int) _NOEXCEPT
        {__wrap_iter __tmp(*this); --(*this); return __tmp;}
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 __wrap_iter  operator+ (difference_type __n) const _NOEXCEPT
        {__wrap_iter __w(*this); __w += __n; return __w;}
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 __wrap_iter& operator+=(difference_type __n) _NOEXCEPT
    {
        _LIBCPP_DEBUG_ASSERT(__get_const_db()->__addable(this, __n),
                             "Attempted to add/subtract an iterator outside its valid range");
        __i_ += __n;
        return *this;
    }
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 __wrap_iter  operator- (difference_type __n) const _NOEXCEPT
        {return *this + (-__n);}
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 __wrap_iter& operator-=(difference_type __n) _NOEXCEPT
        {*this += -__n; return *this;}
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 reference    operator[](difference_type __n) const _NOEXCEPT
    {
        _LIBCPP_DEBUG_ASSERT(__get_const_db()->__subscriptable(this, __n),
                             "Attempted to subscript an iterator outside its valid range");
        return __i_[__n];
    }

    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 iterator_type base() const _NOEXCEPT {return __i_;}

private:
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14
    explicit __wrap_iter(const void* __p, iterator_type __x) _NOEXCEPT : __i_(__x)
    {
        (void)__p;
#ifdef _LIBCPP_ENABLE_DEBUG_MODE
      if (!__libcpp_is_constant_evaluated())
        __get_db()->__insert_ic(this, __p);
#endif
    }

    template <class _Up> friend class __wrap_iter;
    template <class _CharT, class _Traits, class _Alloc> friend class basic_string;
    template <class _Tp, class _Alloc> friend class _LIBCPP_TEMPLATE_VIS vector;
    template <class _Tp, size_t> friend class _LIBCPP_TEMPLATE_VIS span;
};

template <class _Iter1>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR
bool operator==(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter1>& __y) _NOEXCEPT
{
    return __x.base() == __y.base();
}

template <class _Iter1, class _Iter2>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR
bool operator==(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter2>& __y) _NOEXCEPT
{
    return __x.base() == __y.base();
}

template <class _Iter1>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14
bool operator<(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter1>& __y) _NOEXCEPT
{
    _LIBCPP_DEBUG_ASSERT(__get_const_db()->__less_than_comparable(_VSTD::addressof(__x), _VSTD::addressof(__y)),
                         "Attempted to compare incomparable iterators");
    return __x.base() < __y.base();
}

template <class _Iter1, class _Iter2>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14
bool operator<(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter2>& __y) _NOEXCEPT
{
    _LIBCPP_DEBUG_ASSERT(__get_const_db()->__less_than_comparable(&__x, &__y),
                         "Attempted to compare incomparable iterators");
    return __x.base() < __y.base();
}

template <class _Iter1>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR
bool operator!=(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter1>& __y) _NOEXCEPT
{
    return !(__x == __y);
}

template <class _Iter1, class _Iter2>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR
bool operator!=(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter2>& __y) _NOEXCEPT
{
    return !(__x == __y);
}

template <class _Iter1>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR
bool operator>(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter1>& __y) _NOEXCEPT
{
    return __y < __x;
}

template <class _Iter1, class _Iter2>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR
bool operator>(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter2>& __y) _NOEXCEPT
{
    return __y < __x;
}

template <class _Iter1>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR
bool operator>=(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter1>& __y) _NOEXCEPT
{
    return !(__x < __y);
}

template <class _Iter1, class _Iter2>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR
bool operator>=(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter2>& __y) _NOEXCEPT
{
    return !(__x < __y);
}

template <class _Iter1>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR
bool operator<=(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter1>& __y) _NOEXCEPT
{
    return !(__y < __x);
}

template <class _Iter1, class _Iter2>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR
bool operator<=(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter2>& __y) _NOEXCEPT
{
    return !(__y < __x);
}

template <class _Iter1, class _Iter2>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14
#ifndef _LIBCPP_CXX03_LANG
auto operator-(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter2>& __y) _NOEXCEPT
    -> decltype(__x.base() - __y.base())
#else
typename __wrap_iter<_Iter1>::difference_type
operator-(const __wrap_iter<_Iter1>& __x, const __wrap_iter<_Iter2>& __y) _NOEXCEPT
#endif // C++03
{
    _LIBCPP_DEBUG_ASSERT(__get_const_db()->__less_than_comparable(_VSTD::addressof(__x), _VSTD::addressof(__y)),
                         "Attempted to subtract incompatible iterators");
    return __x.base() - __y.base();
}

template <class _Iter1>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14
__wrap_iter<_Iter1> operator+(typename __wrap_iter<_Iter1>::difference_type __n, __wrap_iter<_Iter1> __x) _NOEXCEPT
{
    __x += __n;
    return __x;
}

#if _LIBCPP_STD_VER <= 17
template <class _It>
struct __is_cpp17_contiguous_iterator<__wrap_iter<_It> > : true_type {};
#endif

template <class _It>
struct _LIBCPP_TEMPLATE_VIS pointer_traits<__wrap_iter<_It> >
{
    typedef __wrap_iter<_It> pointer;
    typedef typename pointer_traits<_It>::element_type element_type;
    typedef typename pointer_traits<_It>::difference_type difference_type;

    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR
    static element_type *to_address(pointer __w) _NOEXCEPT {
        return _VSTD::__to_address(__w.base());
    }
};

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ITERATOR_WRAP_ITER_H
