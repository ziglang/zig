//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___RANDOM_SHUFFLE_ORDER_ENGINE_H
#define _LIBCPP___RANDOM_SHUFFLE_ORDER_ENGINE_H

#include <__algorithm/equal.h>
#include <__config>
#include <__random/is_seed_sequence.h>
#include <__utility/move.h>
#include <cstdint>
#include <iosfwd>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <uint64_t _Xp, uint64_t _Yp>
struct __ugcd
{
    static _LIBCPP_CONSTEXPR const uint64_t value = __ugcd<_Yp, _Xp % _Yp>::value;
};

template <uint64_t _Xp>
struct __ugcd<_Xp, 0>
{
    static _LIBCPP_CONSTEXPR const uint64_t value = _Xp;
};

template <uint64_t _Np, uint64_t _Dp>
class __uratio
{
    static_assert(_Dp != 0, "__uratio divide by 0");
    static _LIBCPP_CONSTEXPR const uint64_t __gcd = __ugcd<_Np, _Dp>::value;
public:
    static _LIBCPP_CONSTEXPR const uint64_t num = _Np / __gcd;
    static _LIBCPP_CONSTEXPR const uint64_t den = _Dp / __gcd;

    typedef __uratio<num, den> type;
};

template<class _Engine, size_t __k>
class _LIBCPP_TEMPLATE_VIS shuffle_order_engine
{
    static_assert(0 < __k, "shuffle_order_engine invalid parameters");
public:
    // types
    typedef typename _Engine::result_type result_type;

private:
    _Engine __e_;
    result_type _V_[__k];
    result_type _Y_;

public:
    // engine characteristics
    static _LIBCPP_CONSTEXPR const size_t table_size = __k;

#ifdef _LIBCPP_CXX03_LANG
    static const result_type _Min = _Engine::_Min;
    static const result_type _Max = _Engine::_Max;
#else
    static _LIBCPP_CONSTEXPR const result_type _Min = _Engine::min();
    static _LIBCPP_CONSTEXPR const result_type _Max = _Engine::max();
#endif
    static_assert(_Min < _Max, "shuffle_order_engine invalid parameters");
    _LIBCPP_INLINE_VISIBILITY
    static _LIBCPP_CONSTEXPR result_type min() { return _Min; }
    _LIBCPP_INLINE_VISIBILITY
    static _LIBCPP_CONSTEXPR result_type max() { return _Max; }

    static _LIBCPP_CONSTEXPR const unsigned long long _Rp = _Max - _Min + 1ull;

    // constructors and seeding functions
    _LIBCPP_INLINE_VISIBILITY
    shuffle_order_engine() {__init();}
    _LIBCPP_INLINE_VISIBILITY
    explicit shuffle_order_engine(const _Engine& __e)
        : __e_(__e) {__init();}
#ifndef _LIBCPP_CXX03_LANG
    _LIBCPP_INLINE_VISIBILITY
    explicit shuffle_order_engine(_Engine&& __e)
        : __e_(_VSTD::move(__e)) {__init();}
#endif // _LIBCPP_CXX03_LANG
    _LIBCPP_INLINE_VISIBILITY
    explicit shuffle_order_engine(result_type __sd) : __e_(__sd) {__init();}
    template<class _Sseq>
        _LIBCPP_INLINE_VISIBILITY
        explicit shuffle_order_engine(_Sseq& __q,
        typename enable_if<__is_seed_sequence<_Sseq, shuffle_order_engine>::value &&
                           !is_convertible<_Sseq, _Engine>::value>::type* = 0)
         : __e_(__q) {__init();}
    _LIBCPP_INLINE_VISIBILITY
    void seed() {__e_.seed(); __init();}
    _LIBCPP_INLINE_VISIBILITY
    void seed(result_type __sd) {__e_.seed(__sd); __init();}
    template<class _Sseq>
        _LIBCPP_INLINE_VISIBILITY
        typename enable_if
        <
            __is_seed_sequence<_Sseq, shuffle_order_engine>::value,
            void
        >::type
        seed(_Sseq& __q) {__e_.seed(__q); __init();}

    // generating functions
    _LIBCPP_INLINE_VISIBILITY
    result_type operator()() {return __eval(integral_constant<bool, _Rp != 0>());}
    _LIBCPP_INLINE_VISIBILITY
    void discard(unsigned long long __z) {for (; __z; --__z) operator()();}

    // property functions
    _LIBCPP_INLINE_VISIBILITY
    const _Engine& base() const _NOEXCEPT {return __e_;}

private:
    template<class _Eng, size_t _Kp>
    friend
    bool
    operator==(
        const shuffle_order_engine<_Eng, _Kp>& __x,
        const shuffle_order_engine<_Eng, _Kp>& __y);

    template<class _Eng, size_t _Kp>
    friend
    bool
    operator!=(
        const shuffle_order_engine<_Eng, _Kp>& __x,
        const shuffle_order_engine<_Eng, _Kp>& __y);

    template <class _CharT, class _Traits,
              class _Eng, size_t _Kp>
    friend
    basic_ostream<_CharT, _Traits>&
    operator<<(basic_ostream<_CharT, _Traits>& __os,
               const shuffle_order_engine<_Eng, _Kp>& __x);

    template <class _CharT, class _Traits,
              class _Eng, size_t _Kp>
    friend
    basic_istream<_CharT, _Traits>&
    operator>>(basic_istream<_CharT, _Traits>& __is,
               shuffle_order_engine<_Eng, _Kp>& __x);

    _LIBCPP_INLINE_VISIBILITY
    void __init()
    {
        for (size_t __i = 0; __i < __k; ++__i)
            _V_[__i] = __e_();
        _Y_ = __e_();
    }

    _LIBCPP_INLINE_VISIBILITY
    result_type __eval(false_type) {return __eval2(integral_constant<bool, __k & 1>());}
    _LIBCPP_INLINE_VISIBILITY
    result_type __eval(true_type) {return __eval(__uratio<__k, _Rp>());}

    _LIBCPP_INLINE_VISIBILITY
    result_type __eval2(false_type) {return __eval(__uratio<__k/2, 0x8000000000000000ull>());}
    _LIBCPP_INLINE_VISIBILITY
    result_type __eval2(true_type) {return __evalf<__k, 0>();}

    template <uint64_t _Np, uint64_t _Dp>
        _LIBCPP_INLINE_VISIBILITY
        typename enable_if
        <
            (__uratio<_Np, _Dp>::num > 0xFFFFFFFFFFFFFFFFull / (_Max - _Min)),
            result_type
        >::type
        __eval(__uratio<_Np, _Dp>)
            {return __evalf<__uratio<_Np, _Dp>::num, __uratio<_Np, _Dp>::den>();}

    template <uint64_t _Np, uint64_t _Dp>
        _LIBCPP_INLINE_VISIBILITY
        typename enable_if
        <
            __uratio<_Np, _Dp>::num <= 0xFFFFFFFFFFFFFFFFull / (_Max - _Min),
            result_type
        >::type
        __eval(__uratio<_Np, _Dp>)
        {
            const size_t __j = static_cast<size_t>(__uratio<_Np, _Dp>::num * (_Y_ - _Min)
                                                   / __uratio<_Np, _Dp>::den);
            _Y_ = _V_[__j];
            _V_[__j] = __e_();
            return _Y_;
        }

    template <uint64_t __n, uint64_t __d>
        _LIBCPP_INLINE_VISIBILITY
        result_type __evalf()
        {
            const double _Fp = __d == 0 ?
                __n / (2. * 0x8000000000000000ull) :
                __n / (double)__d;
            const size_t __j = static_cast<size_t>(_Fp * (_Y_ - _Min));
            _Y_ = _V_[__j];
            _V_[__j] = __e_();
            return _Y_;
        }
};

template<class _Engine, size_t __k>
    _LIBCPP_CONSTEXPR const size_t shuffle_order_engine<_Engine, __k>::table_size;

template<class _Eng, size_t _Kp>
bool
operator==(
    const shuffle_order_engine<_Eng, _Kp>& __x,
    const shuffle_order_engine<_Eng, _Kp>& __y)
{
    return __x._Y_ == __y._Y_ && _VSTD::equal(__x._V_, __x._V_ + _Kp, __y._V_) &&
           __x.__e_ == __y.__e_;
}

template<class _Eng, size_t _Kp>
inline _LIBCPP_INLINE_VISIBILITY
bool
operator!=(
    const shuffle_order_engine<_Eng, _Kp>& __x,
    const shuffle_order_engine<_Eng, _Kp>& __y)
{
    return !(__x == __y);
}

template <class _CharT, class _Traits,
          class _Eng, size_t _Kp>
basic_ostream<_CharT, _Traits>&
operator<<(basic_ostream<_CharT, _Traits>& __os,
           const shuffle_order_engine<_Eng, _Kp>& __x)
{
    __save_flags<_CharT, _Traits> __lx(__os);
    typedef basic_ostream<_CharT, _Traits> _Ostream;
    __os.flags(_Ostream::dec | _Ostream::left);
    _CharT __sp = __os.widen(' ');
    __os.fill(__sp);
    __os << __x.__e_ << __sp << __x._V_[0];
    for (size_t __i = 1; __i < _Kp; ++__i)
        __os << __sp << __x._V_[__i];
    return __os << __sp << __x._Y_;
}

template <class _CharT, class _Traits,
          class _Eng, size_t _Kp>
basic_istream<_CharT, _Traits>&
operator>>(basic_istream<_CharT, _Traits>& __is,
           shuffle_order_engine<_Eng, _Kp>& __x)
{
    typedef typename shuffle_order_engine<_Eng, _Kp>::result_type result_type;
    __save_flags<_CharT, _Traits> __lx(__is);
    typedef basic_istream<_CharT, _Traits> _Istream;
    __is.flags(_Istream::dec | _Istream::skipws);
    _Eng __e;
    result_type _Vp[_Kp+1];
    __is >> __e;
    for (size_t __i = 0; __i < _Kp+1; ++__i)
        __is >> _Vp[__i];
    if (!__is.fail())
    {
        __x.__e_ = __e;
        for (size_t __i = 0; __i < _Kp; ++__i)
            __x._V_[__i] = _Vp[__i];
        __x._Y_ = _Vp[_Kp];
    }
    return __is;
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___RANDOM_SHUFFLE_ORDER_ENGINE_H
