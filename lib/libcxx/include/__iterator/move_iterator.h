// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ITERATOR_MOVE_ITERATOR_H
#define _LIBCPP___ITERATOR_MOVE_ITERATOR_H

#include <__config>
#include <__iterator/iterator_traits.h>
#include <__utility/move.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Iter>
class _LIBCPP_TEMPLATE_VIS move_iterator
{
public:
#if _LIBCPP_STD_VER > 17
    typedef input_iterator_tag iterator_concept;
#endif

    typedef _Iter iterator_type;
    typedef _If<
        __is_cpp17_random_access_iterator<_Iter>::value,
        random_access_iterator_tag,
        typename iterator_traits<_Iter>::iterator_category
    >  iterator_category;
    typedef typename iterator_traits<iterator_type>::value_type value_type;
    typedef typename iterator_traits<iterator_type>::difference_type difference_type;
    typedef iterator_type pointer;

#ifndef _LIBCPP_CXX03_LANG
    typedef typename iterator_traits<iterator_type>::reference __reference;
    typedef typename conditional<
            is_reference<__reference>::value,
            typename remove_reference<__reference>::type&&,
            __reference
        >::type reference;
#else
    typedef typename iterator_traits<iterator_type>::reference reference;
#endif

    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
    move_iterator() : __current_() {}

    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
    explicit move_iterator(_Iter __i) : __current_(_VSTD::move(__i)) {}

    template <class _Up, class = __enable_if_t<
        !is_same<_Up, _Iter>::value && is_convertible<const _Up&, _Iter>::value
    > >
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
    move_iterator(const move_iterator<_Up>& __u) : __current_(__u.base()) {}

    template <class _Up, class = __enable_if_t<
        !is_same<_Up, _Iter>::value &&
        is_convertible<const _Up&, _Iter>::value &&
        is_assignable<_Iter&, const _Up&>::value
    > >
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
    move_iterator& operator=(const move_iterator<_Up>& __u) {
        __current_ = __u.base();
        return *this;
    }

    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
    _Iter base() const { return __current_; }

    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
    reference operator*() const { return static_cast<reference>(*__current_); }
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
    pointer operator->() const { return __current_; }
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
    reference operator[](difference_type __n) const { return static_cast<reference>(__current_[__n]); }

    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
    move_iterator& operator++() { ++__current_; return *this; }
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
    move_iterator operator++(int) { move_iterator __tmp(*this); ++__current_; return __tmp; }
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
    move_iterator& operator--() { --__current_; return *this; }
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
    move_iterator operator--(int) { move_iterator __tmp(*this); --__current_; return __tmp; }
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
    move_iterator operator+(difference_type __n) const { return move_iterator(__current_ + __n); }
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
    move_iterator& operator+=(difference_type __n) { __current_ += __n; return *this; }
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
    move_iterator operator-(difference_type __n) const { return move_iterator(__current_ - __n); }
    _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
    move_iterator& operator-=(difference_type __n) { __current_ -= __n; return *this; }

private:
    _Iter __current_;
};

template <class _Iter1, class _Iter2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
bool operator==(const move_iterator<_Iter1>& __x, const move_iterator<_Iter2>& __y)
{
    return __x.base() == __y.base();
}

template <class _Iter1, class _Iter2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
bool operator!=(const move_iterator<_Iter1>& __x, const move_iterator<_Iter2>& __y)
{
    return __x.base() != __y.base();
}

template <class _Iter1, class _Iter2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
bool operator<(const move_iterator<_Iter1>& __x, const move_iterator<_Iter2>& __y)
{
    return __x.base() < __y.base();
}

template <class _Iter1, class _Iter2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
bool operator>(const move_iterator<_Iter1>& __x, const move_iterator<_Iter2>& __y)
{
    return __x.base() > __y.base();
}

template <class _Iter1, class _Iter2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
bool operator<=(const move_iterator<_Iter1>& __x, const move_iterator<_Iter2>& __y)
{
    return __x.base() <= __y.base();
}

template <class _Iter1, class _Iter2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
bool operator>=(const move_iterator<_Iter1>& __x, const move_iterator<_Iter2>& __y)
{
    return __x.base() >= __y.base();
}

#ifndef _LIBCPP_CXX03_LANG
template <class _Iter1, class _Iter2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
auto operator-(const move_iterator<_Iter1>& __x, const move_iterator<_Iter2>& __y)
    -> decltype(__x.base() - __y.base())
{
    return __x.base() - __y.base();
}
#else
template <class _Iter1, class _Iter2>
inline _LIBCPP_HIDE_FROM_ABI
typename move_iterator<_Iter1>::difference_type
operator-(const move_iterator<_Iter1>& __x, const move_iterator<_Iter2>& __y)
{
    return __x.base() - __y.base();
}
#endif

template <class _Iter>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
move_iterator<_Iter>
operator+(typename move_iterator<_Iter>::difference_type __n, const move_iterator<_Iter>& __x)
{
    return move_iterator<_Iter>(__x.base() + __n);
}

template <class _Iter>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
move_iterator<_Iter>
make_move_iterator(_Iter __i)
{
    return move_iterator<_Iter>(_VSTD::move(__i));
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ITERATOR_MOVE_ITERATOR_H
