// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___CHRONO_TIME_POINT_H
#define _LIBCPP___CHRONO_TIME_POINT_H

#include <__chrono/duration.h>
#include <__config>
#include <limits>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

namespace chrono
{

template <class _Clock, class _Duration = typename _Clock::duration>
class _LIBCPP_TEMPLATE_VIS time_point
{
    static_assert(__is_duration<_Duration>::value,
                  "Second template parameter of time_point must be a std::chrono::duration");
public:
    typedef _Clock                    clock;
    typedef _Duration                 duration;
    typedef typename duration::rep    rep;
    typedef typename duration::period period;
private:
    duration __d_;

public:
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11 time_point() : __d_(duration::zero()) {}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11 explicit time_point(const duration& __d) : __d_(__d) {}

    // conversions
    template <class _Duration2>
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    time_point(const time_point<clock, _Duration2>& __t,
        typename enable_if
        <
            is_convertible<_Duration2, duration>::value
        >::type* = nullptr)
            : __d_(__t.time_since_epoch()) {}

    // observer

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11 duration time_since_epoch() const {return __d_;}

    // arithmetic

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14 time_point& operator+=(const duration& __d) {__d_ += __d; return *this;}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14 time_point& operator-=(const duration& __d) {__d_ -= __d; return *this;}

    // special values

    _LIBCPP_INLINE_VISIBILITY static _LIBCPP_CONSTEXPR time_point min() _NOEXCEPT {return time_point(duration::min());}
    _LIBCPP_INLINE_VISIBILITY static _LIBCPP_CONSTEXPR time_point max() _NOEXCEPT {return time_point(duration::max());}
};

} // namespace chrono

template <class _Clock, class _Duration1, class _Duration2>
struct _LIBCPP_TEMPLATE_VIS common_type<chrono::time_point<_Clock, _Duration1>,
                                         chrono::time_point<_Clock, _Duration2> >
{
    typedef chrono::time_point<_Clock, typename common_type<_Duration1, _Duration2>::type> type;
};

namespace chrono {

template <class _ToDuration, class _Clock, class _Duration>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
time_point<_Clock, _ToDuration>
time_point_cast(const time_point<_Clock, _Duration>& __t)
{
    return time_point<_Clock, _ToDuration>(chrono::duration_cast<_ToDuration>(__t.time_since_epoch()));
}

#if _LIBCPP_STD_VER > 14
template <class _ToDuration, class _Clock, class _Duration>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR
typename enable_if
<
    __is_duration<_ToDuration>::value,
    time_point<_Clock, _ToDuration>
>::type
floor(const time_point<_Clock, _Duration>& __t)
{
    return time_point<_Clock, _ToDuration>{floor<_ToDuration>(__t.time_since_epoch())};
}

template <class _ToDuration, class _Clock, class _Duration>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR
typename enable_if
<
    __is_duration<_ToDuration>::value,
    time_point<_Clock, _ToDuration>
>::type
ceil(const time_point<_Clock, _Duration>& __t)
{
    return time_point<_Clock, _ToDuration>{ceil<_ToDuration>(__t.time_since_epoch())};
}

template <class _ToDuration, class _Clock, class _Duration>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR
typename enable_if
<
    __is_duration<_ToDuration>::value,
    time_point<_Clock, _ToDuration>
>::type
round(const time_point<_Clock, _Duration>& __t)
{
    return time_point<_Clock, _ToDuration>{round<_ToDuration>(__t.time_since_epoch())};
}

template <class _Rep, class _Period>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR
typename enable_if
<
    numeric_limits<_Rep>::is_signed,
    duration<_Rep, _Period>
>::type
abs(duration<_Rep, _Period> __d)
{
    return __d >= __d.zero() ? +__d : -__d;
}
#endif // _LIBCPP_STD_VER > 14

// time_point ==

template <class _Clock, class _Duration1, class _Duration2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
bool
operator==(const time_point<_Clock, _Duration1>& __lhs, const time_point<_Clock, _Duration2>& __rhs)
{
    return __lhs.time_since_epoch() == __rhs.time_since_epoch();
}

// time_point !=

template <class _Clock, class _Duration1, class _Duration2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
bool
operator!=(const time_point<_Clock, _Duration1>& __lhs, const time_point<_Clock, _Duration2>& __rhs)
{
    return !(__lhs == __rhs);
}

// time_point <

template <class _Clock, class _Duration1, class _Duration2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
bool
operator<(const time_point<_Clock, _Duration1>& __lhs, const time_point<_Clock, _Duration2>& __rhs)
{
    return __lhs.time_since_epoch() < __rhs.time_since_epoch();
}

// time_point >

template <class _Clock, class _Duration1, class _Duration2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
bool
operator>(const time_point<_Clock, _Duration1>& __lhs, const time_point<_Clock, _Duration2>& __rhs)
{
    return __rhs < __lhs;
}

// time_point <=

template <class _Clock, class _Duration1, class _Duration2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
bool
operator<=(const time_point<_Clock, _Duration1>& __lhs, const time_point<_Clock, _Duration2>& __rhs)
{
    return !(__rhs < __lhs);
}

// time_point >=

template <class _Clock, class _Duration1, class _Duration2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
bool
operator>=(const time_point<_Clock, _Duration1>& __lhs, const time_point<_Clock, _Duration2>& __rhs)
{
    return !(__lhs < __rhs);
}

// time_point operator+(time_point x, duration y);

template <class _Clock, class _Duration1, class _Rep2, class _Period2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
time_point<_Clock, typename common_type<_Duration1, duration<_Rep2, _Period2> >::type>
operator+(const time_point<_Clock, _Duration1>& __lhs, const duration<_Rep2, _Period2>& __rhs)
{
    typedef time_point<_Clock, typename common_type<_Duration1, duration<_Rep2, _Period2> >::type> _Tr;
    return _Tr (__lhs.time_since_epoch() + __rhs);
}

// time_point operator+(duration x, time_point y);

template <class _Rep1, class _Period1, class _Clock, class _Duration2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
time_point<_Clock, typename common_type<duration<_Rep1, _Period1>, _Duration2>::type>
operator+(const duration<_Rep1, _Period1>& __lhs, const time_point<_Clock, _Duration2>& __rhs)
{
    return __rhs + __lhs;
}

// time_point operator-(time_point x, duration y);

template <class _Clock, class _Duration1, class _Rep2, class _Period2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
time_point<_Clock, typename common_type<_Duration1, duration<_Rep2, _Period2> >::type>
operator-(const time_point<_Clock, _Duration1>& __lhs, const duration<_Rep2, _Period2>& __rhs)
{
    typedef time_point<_Clock, typename common_type<_Duration1, duration<_Rep2, _Period2> >::type> _Ret;
    return _Ret(__lhs.time_since_epoch() -__rhs);
}

// duration operator-(time_point x, time_point y);

template <class _Clock, class _Duration1, class _Duration2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
typename common_type<_Duration1, _Duration2>::type
operator-(const time_point<_Clock, _Duration1>& __lhs, const time_point<_Clock, _Duration2>& __rhs)
{
    return __lhs.time_since_epoch() - __rhs.time_since_epoch();
}

} // namespace chrono

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___CHRONO_TIME_POINT_H
