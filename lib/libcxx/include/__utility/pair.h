//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___UTILITY_PAIR_H
#define _LIBCPP___UTILITY_PAIR_H

#include <__config>
#include <__functional/unwrap_ref.h>
#include <__tuple>
#include <__utility/forward.h>
#include <__utility/move.h>
#include <__utility/piecewise_construct.h>
#include <cstddef>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD


#if defined(_LIBCPP_DEPRECATED_ABI_DISABLE_PAIR_TRIVIAL_COPY_CTOR)
template <class, class>
struct __non_trivially_copyable_base {
  _LIBCPP_CONSTEXPR _LIBCPP_INLINE_VISIBILITY
  __non_trivially_copyable_base() _NOEXCEPT {}
  _LIBCPP_CONSTEXPR_AFTER_CXX11 _LIBCPP_INLINE_VISIBILITY
  __non_trivially_copyable_base(__non_trivially_copyable_base const&) _NOEXCEPT {}
};
#endif

template <class _T1, class _T2>
struct _LIBCPP_TEMPLATE_VIS pair
#if defined(_LIBCPP_DEPRECATED_ABI_DISABLE_PAIR_TRIVIAL_COPY_CTOR)
: private __non_trivially_copyable_base<_T1, _T2>
#endif
{
    typedef _T1 first_type;
    typedef _T2 second_type;

    _T1 first;
    _T2 second;

#if !defined(_LIBCPP_CXX03_LANG)
    pair(pair const&) = default;
    pair(pair&&) = default;
#else
  // Use the implicitly declared copy constructor in C++03
#endif

#ifdef _LIBCPP_CXX03_LANG
    _LIBCPP_INLINE_VISIBILITY
    pair() : first(), second() {}

    _LIBCPP_INLINE_VISIBILITY
    pair(_T1 const& __t1, _T2 const& __t2) : first(__t1), second(__t2) {}

    template <class _U1, class _U2>
    _LIBCPP_INLINE_VISIBILITY
    pair(const pair<_U1, _U2>& __p) : first(__p.first), second(__p.second) {}

    _LIBCPP_INLINE_VISIBILITY
    pair& operator=(pair const& __p) {
        first = __p.first;
        second = __p.second;
        return *this;
    }
#else
    template <bool _Val>
    using _EnableB _LIBCPP_NODEBUG_TYPE = typename enable_if<_Val, bool>::type;

    struct _CheckArgs {
      template <int&...>
      static constexpr bool __enable_explicit_default() {
          return is_default_constructible<_T1>::value
              && is_default_constructible<_T2>::value
              && !__enable_implicit_default<>();
      }

      template <int&...>
      static constexpr bool __enable_implicit_default() {
          return __is_implicitly_default_constructible<_T1>::value
              && __is_implicitly_default_constructible<_T2>::value;
      }

      template <class _U1, class _U2>
      static constexpr bool __enable_explicit() {
          return is_constructible<first_type, _U1>::value
              && is_constructible<second_type, _U2>::value
              && (!is_convertible<_U1, first_type>::value
                  || !is_convertible<_U2, second_type>::value);
      }

      template <class _U1, class _U2>
      static constexpr bool __enable_implicit() {
          return is_constructible<first_type, _U1>::value
              && is_constructible<second_type, _U2>::value
              && is_convertible<_U1, first_type>::value
              && is_convertible<_U2, second_type>::value;
      }
    };

    template <bool _MaybeEnable>
    using _CheckArgsDep _LIBCPP_NODEBUG_TYPE = typename conditional<
      _MaybeEnable, _CheckArgs, __check_tuple_constructor_fail>::type;

    struct _CheckTupleLikeConstructor {
        template <class _Tuple>
        static constexpr bool __enable_implicit() {
            return __tuple_convertible<_Tuple, pair>::value;
        }

        template <class _Tuple>
        static constexpr bool __enable_explicit() {
            return __tuple_constructible<_Tuple, pair>::value
               && !__tuple_convertible<_Tuple, pair>::value;
        }

        template <class _Tuple>
        static constexpr bool __enable_assign() {
            return __tuple_assignable<_Tuple, pair>::value;
        }
    };

    template <class _Tuple>
    using _CheckTLC _LIBCPP_NODEBUG_TYPE = typename conditional<
        __tuple_like_with_size<_Tuple, 2>::value
            && !is_same<typename decay<_Tuple>::type, pair>::value,
        _CheckTupleLikeConstructor,
        __check_tuple_constructor_fail
    >::type;

    template<bool _Dummy = true, _EnableB<
            _CheckArgsDep<_Dummy>::__enable_explicit_default()
    > = false>
    explicit _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR
    pair() _NOEXCEPT_(is_nothrow_default_constructible<first_type>::value &&
                      is_nothrow_default_constructible<second_type>::value)
        : first(), second() {}

    template<bool _Dummy = true, _EnableB<
            _CheckArgsDep<_Dummy>::__enable_implicit_default()
    > = false>
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR
    pair() _NOEXCEPT_(is_nothrow_default_constructible<first_type>::value &&
                      is_nothrow_default_constructible<second_type>::value)
        : first(), second() {}

    template <bool _Dummy = true, _EnableB<
             _CheckArgsDep<_Dummy>::template __enable_explicit<_T1 const&, _T2 const&>()
    > = false>
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    explicit pair(_T1 const& __t1, _T2 const& __t2)
        _NOEXCEPT_(is_nothrow_copy_constructible<first_type>::value &&
                   is_nothrow_copy_constructible<second_type>::value)
        : first(__t1), second(__t2) {}

    template<bool _Dummy = true, _EnableB<
            _CheckArgsDep<_Dummy>::template __enable_implicit<_T1 const&, _T2 const&>()
    > = false>
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    pair(_T1 const& __t1, _T2 const& __t2)
        _NOEXCEPT_(is_nothrow_copy_constructible<first_type>::value &&
                   is_nothrow_copy_constructible<second_type>::value)
        : first(__t1), second(__t2) {}

    template<class _U1, class _U2, _EnableB<
             _CheckArgs::template __enable_explicit<_U1, _U2>()
    > = false>
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    explicit pair(_U1&& __u1, _U2&& __u2)
        _NOEXCEPT_((is_nothrow_constructible<first_type, _U1>::value &&
                    is_nothrow_constructible<second_type, _U2>::value))
        : first(_VSTD::forward<_U1>(__u1)), second(_VSTD::forward<_U2>(__u2)) {}

    template<class _U1, class _U2, _EnableB<
            _CheckArgs::template __enable_implicit<_U1, _U2>()
    > = false>
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    pair(_U1&& __u1, _U2&& __u2)
        _NOEXCEPT_((is_nothrow_constructible<first_type, _U1>::value &&
                    is_nothrow_constructible<second_type, _U2>::value))
        : first(_VSTD::forward<_U1>(__u1)), second(_VSTD::forward<_U2>(__u2)) {}

    template<class _U1, class _U2, _EnableB<
            _CheckArgs::template __enable_explicit<_U1 const&, _U2 const&>()
    > = false>
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    explicit pair(pair<_U1, _U2> const& __p)
        _NOEXCEPT_((is_nothrow_constructible<first_type, _U1 const&>::value &&
                    is_nothrow_constructible<second_type, _U2 const&>::value))
        : first(__p.first), second(__p.second) {}

    template<class _U1, class _U2, _EnableB<
            _CheckArgs::template __enable_implicit<_U1 const&, _U2 const&>()
    > = false>
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    pair(pair<_U1, _U2> const& __p)
        _NOEXCEPT_((is_nothrow_constructible<first_type, _U1 const&>::value &&
                    is_nothrow_constructible<second_type, _U2 const&>::value))
        : first(__p.first), second(__p.second) {}

    template<class _U1, class _U2, _EnableB<
            _CheckArgs::template __enable_explicit<_U1, _U2>()
    > = false>
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    explicit pair(pair<_U1, _U2>&&__p)
        _NOEXCEPT_((is_nothrow_constructible<first_type, _U1&&>::value &&
                    is_nothrow_constructible<second_type, _U2&&>::value))
        : first(_VSTD::forward<_U1>(__p.first)), second(_VSTD::forward<_U2>(__p.second)) {}

    template<class _U1, class _U2, _EnableB<
            _CheckArgs::template __enable_implicit<_U1, _U2>()
    > = false>
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    pair(pair<_U1, _U2>&& __p)
        _NOEXCEPT_((is_nothrow_constructible<first_type, _U1&&>::value &&
                    is_nothrow_constructible<second_type, _U2&&>::value))
        : first(_VSTD::forward<_U1>(__p.first)), second(_VSTD::forward<_U2>(__p.second)) {}

    template<class _Tuple, _EnableB<
            _CheckTLC<_Tuple>::template __enable_explicit<_Tuple>()
    > = false>
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    explicit pair(_Tuple&& __p)
        : first(_VSTD::get<0>(_VSTD::forward<_Tuple>(__p))),
          second(_VSTD::get<1>(_VSTD::forward<_Tuple>(__p))) {}

    template<class _Tuple, _EnableB<
            _CheckTLC<_Tuple>::template __enable_implicit<_Tuple>()
    > = false>
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    pair(_Tuple&& __p)
        : first(_VSTD::get<0>(_VSTD::forward<_Tuple>(__p))),
          second(_VSTD::get<1>(_VSTD::forward<_Tuple>(__p))) {}

    template <class... _Args1, class... _Args2>
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    pair(piecewise_construct_t __pc,
         tuple<_Args1...> __first_args, tuple<_Args2...> __second_args)
        _NOEXCEPT_((is_nothrow_constructible<first_type, _Args1...>::value &&
                    is_nothrow_constructible<second_type, _Args2...>::value))
        : pair(__pc, __first_args, __second_args,
                typename __make_tuple_indices<sizeof...(_Args1)>::type(),
                typename __make_tuple_indices<sizeof...(_Args2) >::type()) {}

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    pair& operator=(typename conditional<
                        is_copy_assignable<first_type>::value &&
                        is_copy_assignable<second_type>::value,
                    pair, __nat>::type const& __p)
        _NOEXCEPT_(is_nothrow_copy_assignable<first_type>::value &&
                   is_nothrow_copy_assignable<second_type>::value)
    {
        first = __p.first;
        second = __p.second;
        return *this;
    }

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    pair& operator=(typename conditional<
                        is_move_assignable<first_type>::value &&
                        is_move_assignable<second_type>::value,
                    pair, __nat>::type&& __p)
        _NOEXCEPT_(is_nothrow_move_assignable<first_type>::value &&
                   is_nothrow_move_assignable<second_type>::value)
    {
        first = _VSTD::forward<first_type>(__p.first);
        second = _VSTD::forward<second_type>(__p.second);
        return *this;
    }

    template <class _Tuple, _EnableB<
            _CheckTLC<_Tuple>::template __enable_assign<_Tuple>()
     > = false>
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    pair& operator=(_Tuple&& __p) {
        first = _VSTD::get<0>(_VSTD::forward<_Tuple>(__p));
        second = _VSTD::get<1>(_VSTD::forward<_Tuple>(__p));
        return *this;
    }
#endif

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    void
    swap(pair& __p) _NOEXCEPT_(__is_nothrow_swappable<first_type>::value &&
                               __is_nothrow_swappable<second_type>::value)
    {
        using _VSTD::swap;
        swap(first,  __p.first);
        swap(second, __p.second);
    }
private:

#ifndef _LIBCPP_CXX03_LANG
    template <class... _Args1, class... _Args2, size_t... _I1, size_t... _I2>
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    pair(piecewise_construct_t,
         tuple<_Args1...>& __first_args, tuple<_Args2...>& __second_args,
         __tuple_indices<_I1...>, __tuple_indices<_I2...>);
#endif
};

#ifndef _LIBCPP_HAS_NO_DEDUCTION_GUIDES
template<class _T1, class _T2>
pair(_T1, _T2) -> pair<_T1, _T2>;
#endif // _LIBCPP_HAS_NO_DEDUCTION_GUIDES

template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
bool
operator==(const pair<_T1,_T2>& __x, const pair<_T1,_T2>& __y)
{
    return __x.first == __y.first && __x.second == __y.second;
}

template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
bool
operator!=(const pair<_T1,_T2>& __x, const pair<_T1,_T2>& __y)
{
    return !(__x == __y);
}

template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
bool
operator< (const pair<_T1,_T2>& __x, const pair<_T1,_T2>& __y)
{
    return __x.first < __y.first || (!(__y.first < __x.first) && __x.second < __y.second);
}

template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
bool
operator> (const pair<_T1,_T2>& __x, const pair<_T1,_T2>& __y)
{
    return __y < __x;
}

template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
bool
operator>=(const pair<_T1,_T2>& __x, const pair<_T1,_T2>& __y)
{
    return !(__x < __y);
}

template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
bool
operator<=(const pair<_T1,_T2>& __x, const pair<_T1,_T2>& __y)
{
    return !(__y < __x);
}

template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
typename enable_if
<
    __is_swappable<_T1>::value &&
    __is_swappable<_T2>::value,
    void
>::type
swap(pair<_T1, _T2>& __x, pair<_T1, _T2>& __y)
                     _NOEXCEPT_((__is_nothrow_swappable<_T1>::value &&
                                 __is_nothrow_swappable<_T2>::value))
{
    __x.swap(__y);
}

#ifndef _LIBCPP_CXX03_LANG

template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
pair<typename __unwrap_ref_decay<_T1>::type, typename __unwrap_ref_decay<_T2>::type>
make_pair(_T1&& __t1, _T2&& __t2)
{
    return pair<typename __unwrap_ref_decay<_T1>::type, typename __unwrap_ref_decay<_T2>::type>
               (_VSTD::forward<_T1>(__t1), _VSTD::forward<_T2>(__t2));
}

#else  // _LIBCPP_CXX03_LANG

template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY
pair<_T1,_T2>
make_pair(_T1 __x, _T2 __y)
{
    return pair<_T1, _T2>(__x, __y);
}

#endif // _LIBCPP_CXX03_LANG

template <class _T1, class _T2>
  struct _LIBCPP_TEMPLATE_VIS tuple_size<pair<_T1, _T2> >
    : public integral_constant<size_t, 2> {};

template <size_t _Ip, class _T1, class _T2>
struct _LIBCPP_TEMPLATE_VIS tuple_element<_Ip, pair<_T1, _T2> >
{
    static_assert(_Ip < 2, "Index out of bounds in std::tuple_element<std::pair<T1, T2>>");
};

template <class _T1, class _T2>
struct _LIBCPP_TEMPLATE_VIS tuple_element<0, pair<_T1, _T2> >
{
    typedef _LIBCPP_NODEBUG_TYPE _T1 type;
};

template <class _T1, class _T2>
struct _LIBCPP_TEMPLATE_VIS tuple_element<1, pair<_T1, _T2> >
{
    typedef _LIBCPP_NODEBUG_TYPE _T2 type;
};

template <size_t _Ip> struct __get_pair;

template <>
struct __get_pair<0>
{
    template <class _T1, class _T2>
    static
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    _T1&
    get(pair<_T1, _T2>& __p) _NOEXCEPT {return __p.first;}

    template <class _T1, class _T2>
    static
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    const _T1&
    get(const pair<_T1, _T2>& __p) _NOEXCEPT {return __p.first;}

#ifndef _LIBCPP_CXX03_LANG
    template <class _T1, class _T2>
    static
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    _T1&&
    get(pair<_T1, _T2>&& __p) _NOEXCEPT {return _VSTD::forward<_T1>(__p.first);}

    template <class _T1, class _T2>
    static
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    const _T1&&
    get(const pair<_T1, _T2>&& __p) _NOEXCEPT {return _VSTD::forward<const _T1>(__p.first);}
#endif // _LIBCPP_CXX03_LANG
};

template <>
struct __get_pair<1>
{
    template <class _T1, class _T2>
    static
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    _T2&
    get(pair<_T1, _T2>& __p) _NOEXCEPT {return __p.second;}

    template <class _T1, class _T2>
    static
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    const _T2&
    get(const pair<_T1, _T2>& __p) _NOEXCEPT {return __p.second;}

#ifndef _LIBCPP_CXX03_LANG
    template <class _T1, class _T2>
    static
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    _T2&&
    get(pair<_T1, _T2>&& __p) _NOEXCEPT {return _VSTD::forward<_T2>(__p.second);}

    template <class _T1, class _T2>
    static
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
    const _T2&&
    get(const pair<_T1, _T2>&& __p) _NOEXCEPT {return _VSTD::forward<const _T2>(__p.second);}
#endif // _LIBCPP_CXX03_LANG
};

template <size_t _Ip, class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
typename tuple_element<_Ip, pair<_T1, _T2> >::type&
get(pair<_T1, _T2>& __p) _NOEXCEPT
{
    return __get_pair<_Ip>::get(__p);
}

template <size_t _Ip, class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
const typename tuple_element<_Ip, pair<_T1, _T2> >::type&
get(const pair<_T1, _T2>& __p) _NOEXCEPT
{
    return __get_pair<_Ip>::get(__p);
}

#ifndef _LIBCPP_CXX03_LANG
template <size_t _Ip, class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
typename tuple_element<_Ip, pair<_T1, _T2> >::type&&
get(pair<_T1, _T2>&& __p) _NOEXCEPT
{
    return __get_pair<_Ip>::get(_VSTD::move(__p));
}

template <size_t _Ip, class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX11
const typename tuple_element<_Ip, pair<_T1, _T2> >::type&&
get(const pair<_T1, _T2>&& __p) _NOEXCEPT
{
    return __get_pair<_Ip>::get(_VSTD::move(__p));
}
#endif // _LIBCPP_CXX03_LANG

#if _LIBCPP_STD_VER > 11
template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY
constexpr _T1 & get(pair<_T1, _T2>& __p) _NOEXCEPT
{
    return __get_pair<0>::get(__p);
}

template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY
constexpr _T1 const & get(pair<_T1, _T2> const& __p) _NOEXCEPT
{
    return __get_pair<0>::get(__p);
}

template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY
constexpr _T1 && get(pair<_T1, _T2>&& __p) _NOEXCEPT
{
    return __get_pair<0>::get(_VSTD::move(__p));
}

template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY
constexpr _T1 const && get(pair<_T1, _T2> const&& __p) _NOEXCEPT
{
    return __get_pair<0>::get(_VSTD::move(__p));
}

template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY
constexpr _T1 & get(pair<_T2, _T1>& __p) _NOEXCEPT
{
    return __get_pair<1>::get(__p);
}

template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY
constexpr _T1 const & get(pair<_T2, _T1> const& __p) _NOEXCEPT
{
    return __get_pair<1>::get(__p);
}

template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY
constexpr _T1 && get(pair<_T2, _T1>&& __p) _NOEXCEPT
{
    return __get_pair<1>::get(_VSTD::move(__p));
}

template <class _T1, class _T2>
inline _LIBCPP_INLINE_VISIBILITY
constexpr _T1 const && get(pair<_T2, _T1> const&& __p) _NOEXCEPT
{
    return __get_pair<1>::get(_VSTD::move(__p));
}

#endif

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___UTILITY_PAIR_H
