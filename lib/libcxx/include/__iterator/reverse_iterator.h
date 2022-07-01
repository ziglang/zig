// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ITERATOR_REVERSE_ITERATOR_H
#define _LIBCPP___ITERATOR_REVERSE_ITERATOR_H

#include <__compare/compare_three_way_result.h>
#include <__compare/three_way_comparable.h>
#include <__config>
#include <__iterator/iterator.h>
#include <__iterator/iterator_traits.h>
#include <__memory/addressof.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
template <class _Iter>
class _LIBCPP_TEMPLATE_VIS reverse_iterator
#if _LIBCPP_STD_VER <= 14 || !defined(_LIBCPP_ABI_NO_ITERATOR_BASES)
    : public iterator<typename iterator_traits<_Iter>::iterator_category,
                      typename iterator_traits<_Iter>::value_type,
                      typename iterator_traits<_Iter>::difference_type,
                      typename iterator_traits<_Iter>::pointer,
                      typename iterator_traits<_Iter>::reference>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
private:
#ifndef _LIBCPP_ABI_NO_ITERATOR_BASES
    _Iter __t; // no longer used as of LWG #2360, not removed due to ABI break
#endif

protected:
    _Iter current;
public:
    typedef _Iter                                            iterator_type;
    typedef typename iterator_traits<_Iter>::difference_type difference_type;
    typedef typename iterator_traits<_Iter>::reference       reference;
    typedef typename iterator_traits<_Iter>::pointer         pointer;
    typedef _If<__is_cpp17_random_access_iterator<_Iter>::value,
        random_access_iterator_tag,
        typename iterator_traits<_Iter>::iterator_category>  iterator_category;
    typedef typename iterator_traits<_Iter>::value_type      value_type;

#if _LIBCPP_STD_VER > 17
    typedef _If<__is_cpp17_random_access_iterator<_Iter>::value,
        random_access_iterator_tag,
        bidirectional_iterator_tag>                          iterator_concept;
#endif

#ifndef _LIBCPP_ABI_NO_ITERATOR_BASES
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    reverse_iterator() : __t(), current() {}

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    explicit reverse_iterator(_Iter __x) : __t(__x), current(__x) {}

    template <class _Up, class = __enable_if_t<
        !is_same<_Up, _Iter>::value && is_convertible<_Up const&, _Iter>::value
    > >
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    reverse_iterator(const reverse_iterator<_Up>& __u)
        : __t(__u.base()), current(__u.base())
    { }

    template <class _Up, class = __enable_if_t<
        !is_same<_Up, _Iter>::value &&
        is_convertible<_Up const&, _Iter>::value &&
        is_assignable<_Iter&, _Up const&>::value
    > >
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    reverse_iterator& operator=(const reverse_iterator<_Up>& __u) {
        __t = current = __u.base();
        return *this;
    }
#else
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    reverse_iterator() : current() {}

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    explicit reverse_iterator(_Iter __x) : current(__x) {}

    template <class _Up, class = __enable_if_t<
        !is_same<_Up, _Iter>::value && is_convertible<_Up const&, _Iter>::value
    > >
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    reverse_iterator(const reverse_iterator<_Up>& __u)
        : current(__u.base())
    { }

    template <class _Up, class = __enable_if_t<
        !is_same<_Up, _Iter>::value &&
        is_convertible<_Up const&, _Iter>::value &&
        is_assignable<_Iter&, _Up const&>::value
    > >
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    reverse_iterator& operator=(const reverse_iterator<_Up>& __u) {
        current = __u.base();
        return *this;
    }
#endif
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    _Iter base() const {return current;}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    reference operator*() const {_Iter __tmp = current; return *--__tmp;}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    pointer  operator->() const {return _VSTD::addressof(operator*());}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    reverse_iterator& operator++() {--current; return *this;}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    reverse_iterator  operator++(int) {reverse_iterator __tmp(*this); --current; return __tmp;}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    reverse_iterator& operator--() {++current; return *this;}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    reverse_iterator  operator--(int) {reverse_iterator __tmp(*this); ++current; return __tmp;}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    reverse_iterator  operator+ (difference_type __n) const {return reverse_iterator(current - __n);}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    reverse_iterator& operator+=(difference_type __n) {current -= __n; return *this;}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    reverse_iterator  operator- (difference_type __n) const {return reverse_iterator(current + __n);}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    reverse_iterator& operator-=(difference_type __n) {current += __n; return *this;}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
    reference         operator[](difference_type __n) const {return *(*this + __n);}
};

template <class _Iter1, class _Iter2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
bool
operator==(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y)
{
    return __x.base() == __y.base();
}

template <class _Iter1, class _Iter2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
bool
operator<(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y)
{
    return __x.base() > __y.base();
}

template <class _Iter1, class _Iter2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
bool
operator!=(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y)
{
    return __x.base() != __y.base();
}

template <class _Iter1, class _Iter2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
bool
operator>(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y)
{
    return __x.base() < __y.base();
}

template <class _Iter1, class _Iter2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
bool
operator>=(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y)
{
    return __x.base() <= __y.base();
}

template <class _Iter1, class _Iter2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
bool
operator<=(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y)
{
    return __x.base() >= __y.base();
}

#if !defined(_LIBCPP_HAS_NO_CONCEPTS)
template <class _Iter1, three_way_comparable_with<_Iter1> _Iter2>
_LIBCPP_HIDE_FROM_ABI constexpr
compare_three_way_result_t<_Iter1, _Iter2>
operator<=>(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y)
{
    return __y.base() <=> __x.base();
}
#endif

#ifndef _LIBCPP_CXX03_LANG
template <class _Iter1, class _Iter2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
auto
operator-(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y)
-> decltype(__y.base() - __x.base())
{
    return __y.base() - __x.base();
}
#else
template <class _Iter1, class _Iter2>
inline _LIBCPP_INLINE_VISIBILITY
typename reverse_iterator<_Iter1>::difference_type
operator-(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y)
{
    return __y.base() - __x.base();
}
#endif

template <class _Iter>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
reverse_iterator<_Iter>
operator+(typename reverse_iterator<_Iter>::difference_type __n, const reverse_iterator<_Iter>& __x)
{
    return reverse_iterator<_Iter>(__x.base() - __n);
}

#if _LIBCPP_STD_VER > 11
template <class _Iter>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
reverse_iterator<_Iter> make_reverse_iterator(_Iter __i)
{
    return reverse_iterator<_Iter>(__i);
}
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ITERATOR_REVERSE_ITERATOR_H
