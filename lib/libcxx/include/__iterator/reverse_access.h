// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ITERATOR_REVERSE_ACCESS_H
#define _LIBCPP___ITERATOR_REVERSE_ACCESS_H

#include <__config>
#include <__iterator/reverse_iterator.h>
#include <cstddef>
#include <initializer_list>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_CXX03_LANG)

#if _LIBCPP_STD_VER > 11

template <class _Tp, size_t _Np>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
reverse_iterator<_Tp*> rbegin(_Tp (&__array)[_Np])
{
    return reverse_iterator<_Tp*>(__array + _Np);
}

template <class _Tp, size_t _Np>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
reverse_iterator<_Tp*> rend(_Tp (&__array)[_Np])
{
    return reverse_iterator<_Tp*>(__array);
}

template <class _Ep>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
reverse_iterator<const _Ep*> rbegin(initializer_list<_Ep> __il)
{
    return reverse_iterator<const _Ep*>(__il.end());
}

template <class _Ep>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
reverse_iterator<const _Ep*> rend(initializer_list<_Ep> __il)
{
    return reverse_iterator<const _Ep*>(__il.begin());
}

template <class _Cp>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
auto rbegin(_Cp& __c) -> decltype(__c.rbegin())
{
    return __c.rbegin();
}

template <class _Cp>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
auto rbegin(const _Cp& __c) -> decltype(__c.rbegin())
{
    return __c.rbegin();
}

template <class _Cp>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
auto rend(_Cp& __c) -> decltype(__c.rend())
{
    return __c.rend();
}

template <class _Cp>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
auto rend(const _Cp& __c) -> decltype(__c.rend())
{
    return __c.rend();
}

template <class _Cp>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
auto crbegin(const _Cp& __c) -> decltype(_VSTD::rbegin(__c))
{
    return _VSTD::rbegin(__c);
}

template <class _Cp>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
auto crend(const _Cp& __c) -> decltype(_VSTD::rend(__c))
{
    return _VSTD::rend(__c);
}

#endif

#endif // !defined(_LIBCPP_CXX03_LANG)

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ITERATOR_REVERSE_ACCESS_H
