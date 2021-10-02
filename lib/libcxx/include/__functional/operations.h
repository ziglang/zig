// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FUNCTIONAL_OPERATIONS_H
#define _LIBCPP___FUNCTIONAL_OPERATIONS_H

#include <__config>
#include <__functional/binary_function.h>
#include <__functional/unary_function.h>
#include <__utility/forward.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

// Arithmetic operations

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS plus
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : binary_function<_Tp, _Tp, _Tp>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef _Tp __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp first_argument_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp second_argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    _Tp operator()(const _Tp& __x, const _Tp& __y) const
        {return __x + __y;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS plus<void>
{
    template <class _T1, class _T2>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_T1&& __t, _T2&& __u) const
    _NOEXCEPT_(noexcept(_VSTD::forward<_T1>(__t) + _VSTD::forward<_T2>(__u)))
    -> decltype        (_VSTD::forward<_T1>(__t) + _VSTD::forward<_T2>(__u))
        { return        _VSTD::forward<_T1>(__t) + _VSTD::forward<_T2>(__u); }
    typedef void is_transparent;
};
#endif

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS minus
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : binary_function<_Tp, _Tp, _Tp>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef _Tp __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp first_argument_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp second_argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    _Tp operator()(const _Tp& __x, const _Tp& __y) const
        {return __x - __y;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS minus<void>
{
    template <class _T1, class _T2>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_T1&& __t, _T2&& __u) const
    _NOEXCEPT_(noexcept(_VSTD::forward<_T1>(__t) - _VSTD::forward<_T2>(__u)))
    -> decltype        (_VSTD::forward<_T1>(__t) - _VSTD::forward<_T2>(__u))
        { return        _VSTD::forward<_T1>(__t) - _VSTD::forward<_T2>(__u); }
    typedef void is_transparent;
};
#endif

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS multiplies
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : binary_function<_Tp, _Tp, _Tp>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef _Tp __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp first_argument_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp second_argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    _Tp operator()(const _Tp& __x, const _Tp& __y) const
        {return __x * __y;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS multiplies<void>
{
    template <class _T1, class _T2>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_T1&& __t, _T2&& __u) const
    _NOEXCEPT_(noexcept(_VSTD::forward<_T1>(__t) * _VSTD::forward<_T2>(__u)))
    -> decltype        (_VSTD::forward<_T1>(__t) * _VSTD::forward<_T2>(__u))
        { return        _VSTD::forward<_T1>(__t) * _VSTD::forward<_T2>(__u); }
    typedef void is_transparent;
};
#endif

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS divides
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : binary_function<_Tp, _Tp, _Tp>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef _Tp __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp first_argument_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp second_argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    _Tp operator()(const _Tp& __x, const _Tp& __y) const
        {return __x / __y;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS divides<void>
{
    template <class _T1, class _T2>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_T1&& __t, _T2&& __u) const
    _NOEXCEPT_(noexcept(_VSTD::forward<_T1>(__t) / _VSTD::forward<_T2>(__u)))
    -> decltype        (_VSTD::forward<_T1>(__t) / _VSTD::forward<_T2>(__u))
        { return        _VSTD::forward<_T1>(__t) / _VSTD::forward<_T2>(__u); }
    typedef void is_transparent;
};
#endif

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS modulus
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : binary_function<_Tp, _Tp, _Tp>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef _Tp __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp first_argument_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp second_argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    _Tp operator()(const _Tp& __x, const _Tp& __y) const
        {return __x % __y;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS modulus<void>
{
    template <class _T1, class _T2>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_T1&& __t, _T2&& __u) const
    _NOEXCEPT_(noexcept(_VSTD::forward<_T1>(__t) % _VSTD::forward<_T2>(__u)))
    -> decltype        (_VSTD::forward<_T1>(__t) % _VSTD::forward<_T2>(__u))
        { return        _VSTD::forward<_T1>(__t) % _VSTD::forward<_T2>(__u); }
    typedef void is_transparent;
};
#endif

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS negate
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : unary_function<_Tp, _Tp>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef _Tp __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    _Tp operator()(const _Tp& __x) const
        {return -__x;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS negate<void>
{
    template <class _Tp>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_Tp&& __x) const
    _NOEXCEPT_(noexcept(- _VSTD::forward<_Tp>(__x)))
    -> decltype        (- _VSTD::forward<_Tp>(__x))
        { return        - _VSTD::forward<_Tp>(__x); }
    typedef void is_transparent;
};
#endif

// Bitwise operations

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS bit_and
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : binary_function<_Tp, _Tp, _Tp>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef _Tp __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp first_argument_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp second_argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    _Tp operator()(const _Tp& __x, const _Tp& __y) const
        {return __x & __y;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS bit_and<void>
{
    template <class _T1, class _T2>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_T1&& __t, _T2&& __u) const
    _NOEXCEPT_(noexcept(_VSTD::forward<_T1>(__t) & _VSTD::forward<_T2>(__u)))
    -> decltype        (_VSTD::forward<_T1>(__t) & _VSTD::forward<_T2>(__u))
        { return        _VSTD::forward<_T1>(__t) & _VSTD::forward<_T2>(__u); }
    typedef void is_transparent;
};
#endif

#if _LIBCPP_STD_VER > 11
_LIBCPP_SUPPRESS_DEPRECATED_PUSH
template <class _Tp = void>
struct _LIBCPP_TEMPLATE_VIS bit_not
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : unary_function<_Tp, _Tp>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    _Tp operator()(const _Tp& __x) const
        {return ~__x;}
};

template <>
struct _LIBCPP_TEMPLATE_VIS bit_not<void>
{
    template <class _Tp>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_Tp&& __x) const
    _NOEXCEPT_(noexcept(~_VSTD::forward<_Tp>(__x)))
    -> decltype        (~_VSTD::forward<_Tp>(__x))
        { return        ~_VSTD::forward<_Tp>(__x); }
    typedef void is_transparent;
};
#endif

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS bit_or
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : binary_function<_Tp, _Tp, _Tp>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef _Tp __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp first_argument_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp second_argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    _Tp operator()(const _Tp& __x, const _Tp& __y) const
        {return __x | __y;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS bit_or<void>
{
    template <class _T1, class _T2>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_T1&& __t, _T2&& __u) const
    _NOEXCEPT_(noexcept(_VSTD::forward<_T1>(__t) | _VSTD::forward<_T2>(__u)))
    -> decltype        (_VSTD::forward<_T1>(__t) | _VSTD::forward<_T2>(__u))
        { return        _VSTD::forward<_T1>(__t) | _VSTD::forward<_T2>(__u); }
    typedef void is_transparent;
};
#endif

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS bit_xor
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : binary_function<_Tp, _Tp, _Tp>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef _Tp __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp first_argument_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp second_argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    _Tp operator()(const _Tp& __x, const _Tp& __y) const
        {return __x ^ __y;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS bit_xor<void>
{
    template <class _T1, class _T2>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_T1&& __t, _T2&& __u) const
    _NOEXCEPT_(noexcept(_VSTD::forward<_T1>(__t) ^ _VSTD::forward<_T2>(__u)))
    -> decltype        (_VSTD::forward<_T1>(__t) ^ _VSTD::forward<_T2>(__u))
        { return        _VSTD::forward<_T1>(__t) ^ _VSTD::forward<_T2>(__u); }
    typedef void is_transparent;
};
#endif

// Comparison operations

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS equal_to
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : binary_function<_Tp, _Tp, bool>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef bool __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef bool result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp first_argument_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp second_argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    bool operator()(const _Tp& __x, const _Tp& __y) const
        {return __x == __y;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS equal_to<void>
{
    template <class _T1, class _T2>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_T1&& __t, _T2&& __u) const
    _NOEXCEPT_(noexcept(_VSTD::forward<_T1>(__t) == _VSTD::forward<_T2>(__u)))
    -> decltype        (_VSTD::forward<_T1>(__t) == _VSTD::forward<_T2>(__u))
        { return        _VSTD::forward<_T1>(__t) == _VSTD::forward<_T2>(__u); }
    typedef void is_transparent;
};
#endif

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS not_equal_to
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : binary_function<_Tp, _Tp, bool>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef bool __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef bool result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp first_argument_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp second_argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    bool operator()(const _Tp& __x, const _Tp& __y) const
        {return __x != __y;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS not_equal_to<void>
{
    template <class _T1, class _T2>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_T1&& __t, _T2&& __u) const
    _NOEXCEPT_(noexcept(_VSTD::forward<_T1>(__t) != _VSTD::forward<_T2>(__u)))
    -> decltype        (_VSTD::forward<_T1>(__t) != _VSTD::forward<_T2>(__u))
        { return        _VSTD::forward<_T1>(__t) != _VSTD::forward<_T2>(__u); }
    typedef void is_transparent;
};
#endif

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS less
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : binary_function<_Tp, _Tp, bool>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef bool __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef bool result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp first_argument_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp second_argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    bool operator()(const _Tp& __x, const _Tp& __y) const
        {return __x < __y;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS less<void>
{
    template <class _T1, class _T2>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_T1&& __t, _T2&& __u) const
    _NOEXCEPT_(noexcept(_VSTD::forward<_T1>(__t) < _VSTD::forward<_T2>(__u)))
    -> decltype        (_VSTD::forward<_T1>(__t) < _VSTD::forward<_T2>(__u))
        { return        _VSTD::forward<_T1>(__t) < _VSTD::forward<_T2>(__u); }
    typedef void is_transparent;
};
#endif

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS less_equal
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : binary_function<_Tp, _Tp, bool>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef bool __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef bool result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp first_argument_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp second_argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    bool operator()(const _Tp& __x, const _Tp& __y) const
        {return __x <= __y;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS less_equal<void>
{
    template <class _T1, class _T2>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_T1&& __t, _T2&& __u) const
    _NOEXCEPT_(noexcept(_VSTD::forward<_T1>(__t) <= _VSTD::forward<_T2>(__u)))
    -> decltype        (_VSTD::forward<_T1>(__t) <= _VSTD::forward<_T2>(__u))
        { return        _VSTD::forward<_T1>(__t) <= _VSTD::forward<_T2>(__u); }
    typedef void is_transparent;
};
#endif

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS greater_equal
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : binary_function<_Tp, _Tp, bool>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef bool __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef bool result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp first_argument_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp second_argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    bool operator()(const _Tp& __x, const _Tp& __y) const
        {return __x >= __y;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS greater_equal<void>
{
    template <class _T1, class _T2>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_T1&& __t, _T2&& __u) const
    _NOEXCEPT_(noexcept(_VSTD::forward<_T1>(__t) >= _VSTD::forward<_T2>(__u)))
    -> decltype        (_VSTD::forward<_T1>(__t) >= _VSTD::forward<_T2>(__u))
        { return        _VSTD::forward<_T1>(__t) >= _VSTD::forward<_T2>(__u); }
    typedef void is_transparent;
};
#endif

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS greater
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : binary_function<_Tp, _Tp, bool>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef bool __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef bool result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp first_argument_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp second_argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    bool operator()(const _Tp& __x, const _Tp& __y) const
        {return __x > __y;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS greater<void>
{
    template <class _T1, class _T2>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_T1&& __t, _T2&& __u) const
    _NOEXCEPT_(noexcept(_VSTD::forward<_T1>(__t) > _VSTD::forward<_T2>(__u)))
    -> decltype        (_VSTD::forward<_T1>(__t) > _VSTD::forward<_T2>(__u))
        { return        _VSTD::forward<_T1>(__t) > _VSTD::forward<_T2>(__u); }
    typedef void is_transparent;
};
#endif

// Logical operations

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS logical_and
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : binary_function<_Tp, _Tp, bool>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef bool __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef bool result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp first_argument_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp second_argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    bool operator()(const _Tp& __x, const _Tp& __y) const
        {return __x && __y;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS logical_and<void>
{
    template <class _T1, class _T2>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_T1&& __t, _T2&& __u) const
    _NOEXCEPT_(noexcept(_VSTD::forward<_T1>(__t) && _VSTD::forward<_T2>(__u)))
    -> decltype        (_VSTD::forward<_T1>(__t) && _VSTD::forward<_T2>(__u))
        { return        _VSTD::forward<_T1>(__t) && _VSTD::forward<_T2>(__u); }
    typedef void is_transparent;
};
#endif

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS logical_not
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : unary_function<_Tp, bool>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef bool __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef bool result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    bool operator()(const _Tp& __x) const
        {return !__x;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS logical_not<void>
{
    template <class _Tp>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_Tp&& __x) const
    _NOEXCEPT_(noexcept(!_VSTD::forward<_Tp>(__x)))
    -> decltype        (!_VSTD::forward<_Tp>(__x))
        { return        !_VSTD::forward<_Tp>(__x); }
    typedef void is_transparent;
};
#endif

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
#if _LIBCPP_STD_VER > 11
template <class _Tp = void>
#else
template <class _Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS logical_or
#if !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : binary_function<_Tp, _Tp, bool>
#endif
{
_LIBCPP_SUPPRESS_DEPRECATED_POP
    typedef bool __result_type;  // used by valarray
#if _LIBCPP_STD_VER <= 17 || defined(_LIBCPP_ENABLE_CXX20_REMOVED_BINDER_TYPEDEFS)
    _LIBCPP_DEPRECATED_IN_CXX17 typedef bool result_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp first_argument_type;
    _LIBCPP_DEPRECATED_IN_CXX17 typedef _Tp second_argument_type;
#endif
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    bool operator()(const _Tp& __x, const _Tp& __y) const
        {return __x || __y;}
};

#if _LIBCPP_STD_VER > 11
template <>
struct _LIBCPP_TEMPLATE_VIS logical_or<void>
{
    template <class _T1, class _T2>
    _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
    auto operator()(_T1&& __t, _T2&& __u) const
    _NOEXCEPT_(noexcept(_VSTD::forward<_T1>(__t) || _VSTD::forward<_T2>(__u)))
    -> decltype        (_VSTD::forward<_T1>(__t) || _VSTD::forward<_T2>(__u))
        { return        _VSTD::forward<_T1>(__t) || _VSTD::forward<_T2>(__u); }
    typedef void is_transparent;
};
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FUNCTIONAL_OPERATIONS_H
