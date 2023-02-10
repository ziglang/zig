//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___RANDOM_UNIFORM_INT_DISTRIBUTION_H
#define _LIBCPP___RANDOM_UNIFORM_INT_DISTRIBUTION_H

#include <__bits>
#include <__config>
#include <__random/is_valid.h>
#include <__random/log2.h>
#include <bit>
#include <cstddef>
#include <cstdint>
#include <iosfwd>
#include <limits>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template<class _Engine, class _UIntType>
class __independent_bits_engine
{
public:
    // types
    typedef _UIntType result_type;

private:
    typedef typename _Engine::result_type _Engine_result_type;
    typedef typename conditional
        <
            sizeof(_Engine_result_type) <= sizeof(result_type),
                result_type,
                _Engine_result_type
        >::type _Working_result_type;

    _Engine& __e_;
    size_t __w_;
    size_t __w0_;
    size_t __n_;
    size_t __n0_;
    _Working_result_type __y0_;
    _Working_result_type __y1_;
    _Engine_result_type __mask0_;
    _Engine_result_type __mask1_;

#ifdef _LIBCPP_CXX03_LANG
    static const _Working_result_type _Rp = _Engine::_Max - _Engine::_Min
                                          + _Working_result_type(1);
#else
    static _LIBCPP_CONSTEXPR const _Working_result_type _Rp = _Engine::max() - _Engine::min()
                                                      + _Working_result_type(1);
#endif
    static _LIBCPP_CONSTEXPR const size_t __m = __log2<_Working_result_type, _Rp>::value;
    static _LIBCPP_CONSTEXPR const size_t _WDt = numeric_limits<_Working_result_type>::digits;
    static _LIBCPP_CONSTEXPR const size_t _EDt = numeric_limits<_Engine_result_type>::digits;

public:
    // constructors and seeding functions
    __independent_bits_engine(_Engine& __e, size_t __w);

    // generating functions
    result_type operator()() {return __eval(integral_constant<bool, _Rp != 0>());}

private:
    result_type __eval(false_type);
    result_type __eval(true_type);
};

template<class _Engine, class _UIntType>
__independent_bits_engine<_Engine, _UIntType>
    ::__independent_bits_engine(_Engine& __e, size_t __w)
        : __e_(__e),
          __w_(__w)
{
    __n_ = __w_ / __m + (__w_ % __m != 0);
    __w0_ = __w_ / __n_;
    if (_Rp == 0)
        __y0_ = _Rp;
    else if (__w0_ < _WDt)
        __y0_ = (_Rp >> __w0_) << __w0_;
    else
        __y0_ = 0;
    if (_Rp - __y0_ > __y0_ / __n_)
    {
        ++__n_;
        __w0_ = __w_ / __n_;
        if (__w0_ < _WDt)
            __y0_ = (_Rp >> __w0_) << __w0_;
        else
            __y0_ = 0;
    }
    __n0_ = __n_ - __w_ % __n_;
    if (__w0_ < _WDt - 1)
        __y1_ = (_Rp >> (__w0_ + 1)) << (__w0_ + 1);
    else
        __y1_ = 0;
    __mask0_ = __w0_ > 0 ? _Engine_result_type(~0) >> (_EDt - __w0_) :
                          _Engine_result_type(0);
    __mask1_ = __w0_ < _EDt - 1 ?
                               _Engine_result_type(~0) >> (_EDt - (__w0_ + 1)) :
                               _Engine_result_type(~0);
}

template<class _Engine, class _UIntType>
inline
_UIntType
__independent_bits_engine<_Engine, _UIntType>::__eval(false_type)
{
    return static_cast<result_type>(__e_() & __mask0_);
}

template<class _Engine, class _UIntType>
_UIntType
__independent_bits_engine<_Engine, _UIntType>::__eval(true_type)
{
    const size_t _WRt = numeric_limits<result_type>::digits;
    result_type _Sp = 0;
    for (size_t __k = 0; __k < __n0_; ++__k)
    {
        _Engine_result_type __u;
        do
        {
            __u = __e_() - _Engine::min();
        } while (__u >= __y0_);
        if (__w0_ < _WRt)
            _Sp <<= __w0_;
        else
            _Sp = 0;
        _Sp += __u & __mask0_;
    }
    for (size_t __k = __n0_; __k < __n_; ++__k)
    {
        _Engine_result_type __u;
        do
        {
            __u = __e_() - _Engine::min();
        } while (__u >= __y1_);
        if (__w0_ < _WRt - 1)
            _Sp <<= __w0_ + 1;
        else
            _Sp = 0;
        _Sp += __u & __mask1_;
    }
    return _Sp;
}

template<class _IntType = int>
class uniform_int_distribution
{
    static_assert(__libcpp_random_is_valid_inttype<_IntType>::value, "IntType must be a supported integer type");
public:
    // types
    typedef _IntType result_type;

    class param_type
    {
        result_type __a_;
        result_type __b_;
    public:
        typedef uniform_int_distribution distribution_type;

        explicit param_type(result_type __a = 0,
                            result_type __b = numeric_limits<result_type>::max())
            : __a_(__a), __b_(__b) {}

        result_type a() const {return __a_;}
        result_type b() const {return __b_;}

        friend bool operator==(const param_type& __x, const param_type& __y)
            {return __x.__a_ == __y.__a_ && __x.__b_ == __y.__b_;}
        friend bool operator!=(const param_type& __x, const param_type& __y)
            {return !(__x == __y);}
    };

private:
    param_type __p_;

public:
    // constructors and reset functions
#ifndef _LIBCPP_CXX03_LANG
    uniform_int_distribution() : uniform_int_distribution(0) {}
    explicit uniform_int_distribution(
        result_type __a, result_type __b = numeric_limits<result_type>::max())
        : __p_(param_type(__a, __b)) {}
#else
    explicit uniform_int_distribution(
        result_type __a = 0,
        result_type __b = numeric_limits<result_type>::max())
        : __p_(param_type(__a, __b)) {}
#endif
    explicit uniform_int_distribution(const param_type& __p) : __p_(__p) {}
    void reset() {}

    // generating functions
    template<class _URNG> result_type operator()(_URNG& __g)
        {return (*this)(__g, __p_);}
    template<class _URNG> result_type operator()(_URNG& __g, const param_type& __p);

    // property functions
    result_type a() const {return __p_.a();}
    result_type b() const {return __p_.b();}

    param_type param() const {return __p_;}
    void param(const param_type& __p) {__p_ = __p;}

    result_type min() const {return a();}
    result_type max() const {return b();}

    friend bool operator==(const uniform_int_distribution& __x,
                           const uniform_int_distribution& __y)
        {return __x.__p_ == __y.__p_;}
    friend bool operator!=(const uniform_int_distribution& __x,
                           const uniform_int_distribution& __y)
            {return !(__x == __y);}
};

template<class _IntType>
template<class _URNG>
typename uniform_int_distribution<_IntType>::result_type
uniform_int_distribution<_IntType>::operator()(_URNG& __g, const param_type& __p)
_LIBCPP_DISABLE_UBSAN_UNSIGNED_INTEGER_CHECK
{
    static_assert(__libcpp_random_is_valid_urng<_URNG>::value, "");
    typedef typename conditional<sizeof(result_type) <= sizeof(uint32_t), uint32_t,
                                 typename make_unsigned<result_type>::type>::type _UIntType;
    const _UIntType _Rp = _UIntType(__p.b()) - _UIntType(__p.a()) + _UIntType(1);
    if (_Rp == 1)
        return __p.a();
    const size_t _Dt = numeric_limits<_UIntType>::digits;
    typedef __independent_bits_engine<_URNG, _UIntType> _Eng;
    if (_Rp == 0)
        return static_cast<result_type>(_Eng(__g, _Dt)());
    size_t __w = _Dt - __countl_zero(_Rp) - 1;
    if ((_Rp & (numeric_limits<_UIntType>::max() >> (_Dt - __w))) != 0)
        ++__w;
    _Eng __e(__g, __w);
    _UIntType __u;
    do
    {
        __u = __e();
    } while (__u >= _Rp);
    return static_cast<result_type>(__u + __p.a());
}

template <class _CharT, class _Traits, class _IT>
basic_ostream<_CharT, _Traits>&
operator<<(basic_ostream<_CharT, _Traits>& __os,
           const uniform_int_distribution<_IT>& __x)
{
    __save_flags<_CharT, _Traits> __lx(__os);
    typedef basic_ostream<_CharT, _Traits> _Ostream;
    __os.flags(_Ostream::dec | _Ostream::left);
    _CharT __sp = __os.widen(' ');
    __os.fill(__sp);
    return __os << __x.a() << __sp << __x.b();
}

template <class _CharT, class _Traits, class _IT>
basic_istream<_CharT, _Traits>&
operator>>(basic_istream<_CharT, _Traits>& __is,
           uniform_int_distribution<_IT>& __x)
{
    typedef uniform_int_distribution<_IT> _Eng;
    typedef typename _Eng::result_type result_type;
    typedef typename _Eng::param_type param_type;
    __save_flags<_CharT, _Traits> __lx(__is);
    typedef basic_istream<_CharT, _Traits> _Istream;
    __is.flags(_Istream::dec | _Istream::skipws);
    result_type __a;
    result_type __b;
    __is >> __a >> __b;
    if (!__is.fail())
        __x.param(param_type(__a, __b));
    return __is;
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___RANDOM_UNIFORM_INT_DISTRIBUTION_H
