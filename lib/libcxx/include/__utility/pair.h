//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___UTILITY_PAIR_H
#define _LIBCPP___UTILITY_PAIR_H

#include <__compare/common_comparison_category.h>
#include <__compare/synth_three_way.h>
#include <__concepts/different_from.h>
#include <__config>
#include <__fwd/array.h>
#include <__fwd/get.h>
#include <__fwd/pair.h>
#include <__fwd/subrange.h>
#include <__fwd/tuple.h>
#include <__tuple/pair_like.h>
#include <__tuple/sfinae_helpers.h>
#include <__tuple/tuple_element.h>
#include <__tuple/tuple_indices.h>
#include <__tuple/tuple_size.h>
#include <__type_traits/common_reference.h>
#include <__type_traits/common_type.h>
#include <__type_traits/conditional.h>
#include <__type_traits/decay.h>
#include <__type_traits/integral_constant.h>
#include <__type_traits/is_assignable.h>
#include <__type_traits/is_constructible.h>
#include <__type_traits/is_convertible.h>
#include <__type_traits/is_copy_assignable.h>
#include <__type_traits/is_default_constructible.h>
#include <__type_traits/is_implicitly_default_constructible.h>
#include <__type_traits/is_move_assignable.h>
#include <__type_traits/is_nothrow_assignable.h>
#include <__type_traits/is_nothrow_constructible.h>
#include <__type_traits/is_nothrow_copy_assignable.h>
#include <__type_traits/is_nothrow_copy_constructible.h>
#include <__type_traits/is_nothrow_default_constructible.h>
#include <__type_traits/is_nothrow_move_assignable.h>
#include <__type_traits/is_same.h>
#include <__type_traits/is_swappable.h>
#include <__type_traits/nat.h>
#include <__type_traits/remove_cvref.h>
#include <__type_traits/unwrap_ref.h>
#include <__utility/declval.h>
#include <__utility/forward.h>
#include <__utility/move.h>
#include <__utility/piecewise_construct.h>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class, class>
struct __non_trivially_copyable_base {
  _LIBCPP_CONSTEXPR _LIBCPP_HIDE_FROM_ABI __non_trivially_copyable_base() _NOEXCEPT {}
  _LIBCPP_CONSTEXPR_SINCE_CXX14 _LIBCPP_HIDE_FROM_ABI
  __non_trivially_copyable_base(__non_trivially_copyable_base const&) _NOEXCEPT {}
};

#if _LIBCPP_STD_VER >= 23
template <class _Tp>
struct __is_specialization_of_subrange : false_type {};

template <class _Iter, class _Sent, ranges::subrange_kind _Kind>
struct __is_specialization_of_subrange<ranges::subrange<_Iter, _Sent, _Kind>> : true_type {};
#endif

template <class _T1, class _T2>
struct _LIBCPP_TEMPLATE_VIS pair
#if defined(_LIBCPP_DEPRECATED_ABI_DISABLE_PAIR_TRIVIAL_COPY_CTOR)
    : private __non_trivially_copyable_base<_T1, _T2>
#endif
{
  using first_type  = _T1;
  using second_type = _T2;

  _T1 first;
  _T2 second;

  _LIBCPP_HIDE_FROM_ABI pair(pair const&) = default;
  _LIBCPP_HIDE_FROM_ABI pair(pair&&)      = default;

#ifdef _LIBCPP_CXX03_LANG
  _LIBCPP_HIDE_FROM_ABI pair() : first(), second() {}

  _LIBCPP_HIDE_FROM_ABI pair(_T1 const& __t1, _T2 const& __t2) : first(__t1), second(__t2) {}

  template <class _U1, class _U2>
  _LIBCPP_HIDE_FROM_ABI pair(const pair<_U1, _U2>& __p) : first(__p.first), second(__p.second) {}

  _LIBCPP_HIDE_FROM_ABI pair& operator=(pair const& __p) {
    first  = __p.first;
    second = __p.second;
    return *this;
  }

  // Extension: This is provided in C++03 because it allows properly handling the
  //            assignment to a pair containing references, which would be a hard
  //            error otherwise.
  template <class _U1,
            class _U2,
            class = __enable_if_t< is_assignable<first_type&, _U1 const&>::value &&
                                   is_assignable<second_type&, _U2 const&>::value > >
  _LIBCPP_HIDE_FROM_ABI pair& operator=(pair<_U1, _U2> const& __p) {
    first  = __p.first;
    second = __p.second;
    return *this;
  }
#else
  struct _CheckArgs {
    template <int&...>
    static _LIBCPP_HIDE_FROM_ABI constexpr bool __enable_explicit_default() {
      return is_default_constructible<_T1>::value && is_default_constructible<_T2>::value &&
             !__enable_implicit_default<>();
    }

    template <int&...>
    static _LIBCPP_HIDE_FROM_ABI constexpr bool __enable_implicit_default() {
      return __is_implicitly_default_constructible<_T1>::value && __is_implicitly_default_constructible<_T2>::value;
    }

    template <class _U1, class _U2>
    static _LIBCPP_HIDE_FROM_ABI constexpr bool __is_pair_constructible() {
      return is_constructible<first_type, _U1>::value && is_constructible<second_type, _U2>::value;
    }

    template <class _U1, class _U2>
    static _LIBCPP_HIDE_FROM_ABI constexpr bool __is_implicit() {
      return is_convertible<_U1, first_type>::value && is_convertible<_U2, second_type>::value;
    }

    template <class _U1, class _U2>
    static _LIBCPP_HIDE_FROM_ABI constexpr bool __enable_explicit() {
      return __is_pair_constructible<_U1, _U2>() && !__is_implicit<_U1, _U2>();
    }

    template <class _U1, class _U2>
    static _LIBCPP_HIDE_FROM_ABI constexpr bool __enable_implicit() {
      return __is_pair_constructible<_U1, _U2>() && __is_implicit<_U1, _U2>();
    }
  };

  template <bool _MaybeEnable>
  using _CheckArgsDep _LIBCPP_NODEBUG =
      typename conditional< _MaybeEnable, _CheckArgs, __check_tuple_constructor_fail>::type;

  template <bool _Dummy = true, __enable_if_t<_CheckArgsDep<_Dummy>::__enable_explicit_default(), int> = 0>
  explicit _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR pair() _NOEXCEPT_(
      is_nothrow_default_constructible<first_type>::value&& is_nothrow_default_constructible<second_type>::value)
      : first(), second() {}

  template <bool _Dummy = true, __enable_if_t<_CheckArgsDep<_Dummy>::__enable_implicit_default(), int> = 0>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR pair() _NOEXCEPT_(
      is_nothrow_default_constructible<first_type>::value&& is_nothrow_default_constructible<second_type>::value)
      : first(), second() {}

  template <bool _Dummy                                                                                     = true,
            __enable_if_t<_CheckArgsDep<_Dummy>::template __enable_explicit<_T1 const&, _T2 const&>(), int> = 0>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 explicit pair(_T1 const& __t1, _T2 const& __t2)
      _NOEXCEPT_(is_nothrow_copy_constructible<first_type>::value&& is_nothrow_copy_constructible<second_type>::value)
      : first(__t1), second(__t2) {}

  template <bool _Dummy                                                                                     = true,
            __enable_if_t<_CheckArgsDep<_Dummy>::template __enable_implicit<_T1 const&, _T2 const&>(), int> = 0>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 pair(_T1 const& __t1, _T2 const& __t2)
      _NOEXCEPT_(is_nothrow_copy_constructible<first_type>::value&& is_nothrow_copy_constructible<second_type>::value)
      : first(__t1), second(__t2) {}

  template <
#  if _LIBCPP_STD_VER >= 23 // http://wg21.link/P1951
      class _U1 = _T1,
      class _U2 = _T2,
#  else
      class _U1,
      class _U2,
#  endif
      __enable_if_t<_CheckArgs::template __enable_explicit<_U1, _U2>(), int> = 0 >
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 explicit pair(_U1&& __u1, _U2&& __u2)
      _NOEXCEPT_((is_nothrow_constructible<first_type, _U1>::value &&
                  is_nothrow_constructible<second_type, _U2>::value))
      : first(std::forward<_U1>(__u1)), second(std::forward<_U2>(__u2)) {
  }

  template <
#  if _LIBCPP_STD_VER >= 23 // http://wg21.link/P1951
      class _U1 = _T1,
      class _U2 = _T2,
#  else
      class _U1,
      class _U2,
#  endif
      __enable_if_t<_CheckArgs::template __enable_implicit<_U1, _U2>(), int> = 0 >
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 pair(_U1&& __u1, _U2&& __u2)
      _NOEXCEPT_((is_nothrow_constructible<first_type, _U1>::value &&
                  is_nothrow_constructible<second_type, _U2>::value))
      : first(std::forward<_U1>(__u1)), second(std::forward<_U2>(__u2)) {
  }

#  if _LIBCPP_STD_VER >= 23
  template <class _U1,
            class _U2,
            __enable_if_t< _CheckArgs::template __is_pair_constructible<_U1&, _U2&>() >* = nullptr>
  _LIBCPP_HIDE_FROM_ABI constexpr explicit(!_CheckArgs::template __is_implicit<_U1&, _U2&>())
      pair(pair<_U1, _U2>& __p) noexcept((is_nothrow_constructible<first_type, _U1&>::value &&
                                          is_nothrow_constructible<second_type, _U2&>::value))
      : first(__p.first), second(__p.second) {}
#  endif

  template <class _U1,
            class _U2,
            __enable_if_t<_CheckArgs::template __enable_explicit<_U1 const&, _U2 const&>(), int> = 0>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 explicit pair(pair<_U1, _U2> const& __p)
      _NOEXCEPT_((is_nothrow_constructible<first_type, _U1 const&>::value &&
                  is_nothrow_constructible<second_type, _U2 const&>::value))
      : first(__p.first), second(__p.second) {}

  template <class _U1,
            class _U2,
            __enable_if_t<_CheckArgs::template __enable_implicit<_U1 const&, _U2 const&>(), int> = 0>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 pair(pair<_U1, _U2> const& __p)
      _NOEXCEPT_((is_nothrow_constructible<first_type, _U1 const&>::value &&
                  is_nothrow_constructible<second_type, _U2 const&>::value))
      : first(__p.first), second(__p.second) {}

  template <class _U1, class _U2, __enable_if_t<_CheckArgs::template __enable_explicit<_U1, _U2>(), int> = 0>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 explicit pair(pair<_U1, _U2>&& __p)
      _NOEXCEPT_((is_nothrow_constructible<first_type, _U1&&>::value &&
                  is_nothrow_constructible<second_type, _U2&&>::value))
      : first(std::forward<_U1>(__p.first)), second(std::forward<_U2>(__p.second)) {}

  template <class _U1, class _U2, __enable_if_t<_CheckArgs::template __enable_implicit<_U1, _U2>(), int> = 0>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 pair(pair<_U1, _U2>&& __p)
      _NOEXCEPT_((is_nothrow_constructible<first_type, _U1&&>::value &&
                  is_nothrow_constructible<second_type, _U2&&>::value))
      : first(std::forward<_U1>(__p.first)), second(std::forward<_U2>(__p.second)) {}

#  if _LIBCPP_STD_VER >= 23
  template <class _U1,
            class _U2,
            __enable_if_t< _CheckArgs::template __is_pair_constructible<const _U1&&, const _U2&&>() >* = nullptr>
  _LIBCPP_HIDE_FROM_ABI constexpr explicit(!_CheckArgs::template __is_implicit<const _U1&&, const _U2&&>())
      pair(const pair<_U1, _U2>&& __p) noexcept(is_nothrow_constructible<first_type, const _U1&&>::value &&
                                                is_nothrow_constructible<second_type, const _U2&&>::value)
      : first(std::move(__p.first)), second(std::move(__p.second)) {}
#  endif

#  if _LIBCPP_STD_VER >= 23
  // This is a workaround for http://llvm.org/PR60710. We should be able to remove it once Clang is fixed.
  template <class _PairLike>
  _LIBCPP_HIDE_FROM_ABI static constexpr bool __pair_like_explicit_wknd() {
    if constexpr (__pair_like<_PairLike>) {
      return !is_convertible_v<decltype(std::get<0>(std::declval<_PairLike&&>())), first_type> ||
             !is_convertible_v<decltype(std::get<1>(std::declval<_PairLike&&>())), second_type>;
    }
    return false;
  }

  template <__pair_like _PairLike>
    requires(!__is_specialization_of_subrange<remove_cvref_t<_PairLike>>::value &&
             is_constructible_v<first_type, decltype(std::get<0>(std::declval<_PairLike &&>()))> &&
             is_constructible_v<second_type, decltype(std::get<1>(std::declval<_PairLike &&>()))>)
  _LIBCPP_HIDE_FROM_ABI constexpr explicit(__pair_like_explicit_wknd<_PairLike>()) pair(_PairLike&& __p)
      : first(std::get<0>(std::forward<_PairLike>(__p))), second(std::get<1>(std::forward<_PairLike>(__p))) {}
#  endif

  template <class... _Args1, class... _Args2>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20
  pair(piecewise_construct_t __pc, tuple<_Args1...> __first_args, tuple<_Args2...> __second_args)
      _NOEXCEPT_((is_nothrow_constructible<first_type, _Args1...>::value &&
                  is_nothrow_constructible<second_type, _Args2...>::value))
      : pair(__pc,
             __first_args,
             __second_args,
             typename __make_tuple_indices<sizeof...(_Args1)>::type(),
             typename __make_tuple_indices<sizeof...(_Args2) >::type()) {}

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 pair&
  operator=(__conditional_t< is_copy_assignable<first_type>::value && is_copy_assignable<second_type>::value,
                             pair,
                             __nat> const& __p)
      _NOEXCEPT_(is_nothrow_copy_assignable<first_type>::value&& is_nothrow_copy_assignable<second_type>::value) {
    first  = __p.first;
    second = __p.second;
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 pair& operator=(
      __conditional_t< is_move_assignable<first_type>::value && is_move_assignable<second_type>::value, pair, __nat>&&
          __p)
      _NOEXCEPT_(is_nothrow_move_assignable<first_type>::value&& is_nothrow_move_assignable<second_type>::value) {
    first  = std::forward<first_type>(__p.first);
    second = std::forward<second_type>(__p.second);
    return *this;
  }

  template <class _U1,
            class _U2,
            __enable_if_t< is_assignable<first_type&, _U1 const&>::value &&
                           is_assignable<second_type&, _U2 const&>::value >* = nullptr>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 pair& operator=(pair<_U1, _U2> const& __p) {
    first  = __p.first;
    second = __p.second;
    return *this;
  }

  template <
      class _U1,
      class _U2,
      __enable_if_t< is_assignable<first_type&, _U1>::value && is_assignable<second_type&, _U2>::value >* = nullptr>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 pair& operator=(pair<_U1, _U2>&& __p) {
    first  = std::forward<_U1>(__p.first);
    second = std::forward<_U2>(__p.second);
    return *this;
  }

#  if _LIBCPP_STD_VER >= 23
  _LIBCPP_HIDE_FROM_ABI constexpr const pair& operator=(pair const& __p) const
      noexcept(is_nothrow_copy_assignable_v<const first_type> && is_nothrow_copy_assignable_v<const second_type>)
    requires(is_copy_assignable_v<const first_type> && is_copy_assignable_v<const second_type>)
  {
    first  = __p.first;
    second = __p.second;
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr const pair& operator=(pair&& __p) const
      noexcept(is_nothrow_assignable_v<const first_type&, first_type> &&
               is_nothrow_assignable_v<const second_type&, second_type>)
    requires(is_assignable_v<const first_type&, first_type> && is_assignable_v<const second_type&, second_type>)
  {
    first  = std::forward<first_type>(__p.first);
    second = std::forward<second_type>(__p.second);
    return *this;
  }

  template <class _U1, class _U2>
  _LIBCPP_HIDE_FROM_ABI constexpr const pair& operator=(const pair<_U1, _U2>& __p) const
    requires(is_assignable_v<const first_type&, const _U1&> && is_assignable_v<const second_type&, const _U2&>)
  {
    first  = __p.first;
    second = __p.second;
    return *this;
  }

  template <class _U1, class _U2>
  _LIBCPP_HIDE_FROM_ABI constexpr const pair& operator=(pair<_U1, _U2>&& __p) const
    requires(is_assignable_v<const first_type&, _U1> && is_assignable_v<const second_type&, _U2>)
  {
    first  = std::forward<_U1>(__p.first);
    second = std::forward<_U2>(__p.second);
    return *this;
  }

  template <__pair_like _PairLike>
    requires(__different_from<_PairLike, pair> && !__is_specialization_of_subrange<remove_cvref_t<_PairLike>>::value &&
             is_assignable_v<first_type&, decltype(std::get<0>(std::declval<_PairLike>()))> &&
             is_assignable_v<second_type&, decltype(std::get<1>(std::declval<_PairLike>()))>)
  _LIBCPP_HIDE_FROM_ABI constexpr pair& operator=(_PairLike&& __p) {
    first  = std::get<0>(std::forward<_PairLike>(__p));
    second = std::get<1>(std::forward<_PairLike>(__p));
    return *this;
  }

  template <__pair_like _PairLike>
    requires(__different_from<_PairLike, pair> && !__is_specialization_of_subrange<remove_cvref_t<_PairLike>>::value &&
             is_assignable_v<first_type const&, decltype(std::get<0>(std::declval<_PairLike>()))> &&
             is_assignable_v<second_type const&, decltype(std::get<1>(std::declval<_PairLike>()))>)
  _LIBCPP_HIDE_FROM_ABI constexpr pair const& operator=(_PairLike&& __p) const {
    first  = std::get<0>(std::forward<_PairLike>(__p));
    second = std::get<1>(std::forward<_PairLike>(__p));
    return *this;
  }
#  endif // _LIBCPP_STD_VER >= 23

  // Prior to C++23, we provide an approximation of constructors and assignment operators from
  // pair-like types. This was historically provided as an extension.
#  if _LIBCPP_STD_VER < 23
  // from std::tuple
  template <
      class _U1,
      class _U2,
      __enable_if_t< is_convertible<_U1 const&, _T1>::value && is_convertible<_U2 const&, _T2>::value >* = nullptr>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 pair(tuple<_U1, _U2> const& __p)
      : first(std::get<0>(__p)), second(std::get<1>(__p)) {}

  template <
      class _U1,
      class _U2,
      __enable_if_t< is_constructible<_T1, _U1 const&>::value && is_constructible<_T2, _U2 const&>::value &&
                     !(is_convertible<_U1 const&, _T1>::value && is_convertible<_U2 const&, _T2>::value) >* = nullptr>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 explicit pair(tuple<_U1, _U2> const& __p)
      : first(std::get<0>(__p)), second(std::get<1>(__p)) {}

  template <class _U1,
            class _U2,
            __enable_if_t< is_convertible<_U1, _T1>::value && is_convertible<_U2, _T2>::value >* = nullptr>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 pair(tuple<_U1, _U2>&& __p)
      : first(std::get<0>(std::move(__p))), second(std::get<1>(std::move(__p))) {}

  template <class _U1,
            class _U2,
            __enable_if_t< is_constructible<_T1, _U1>::value && is_constructible<_T2, _U2>::value &&
                           !(is_convertible<_U1, _T1>::value && is_convertible<_U2, _T2>::value) >* = nullptr>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 explicit pair(tuple<_U1, _U2>&& __p)
      : first(std::get<0>(std::move(__p))), second(std::get<1>(std::move(__p))) {}

  template <
      class _U1,
      class _U2,
      __enable_if_t< is_assignable<_T1&, _U1 const&>::value && is_assignable<_T2&, _U2 const&>::value >* = nullptr>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 pair& operator=(tuple<_U1, _U2> const& __p) {
    first  = std::get<0>(__p);
    second = std::get<1>(__p);
    return *this;
  }

  template <class _U1,
            class _U2,
            __enable_if_t< is_assignable<_T1&, _U1&&>::value && is_assignable<_T2&, _U2&&>::value >* = nullptr>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 pair& operator=(tuple<_U1, _U2>&& __p) {
    first  = std::get<0>(std::move(__p));
    second = std::get<1>(std::move(__p));
    return *this;
  }

  // from std::array
  template <
      class _Up,
      __enable_if_t< is_convertible<_Up const&, _T1>::value && is_convertible<_Up const&, _T2>::value >* = nullptr>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 pair(array<_Up, 2> const& __p) : first(__p[0]), second(__p[1]) {}

  template <
      class _Up,
      __enable_if_t< is_constructible<_T1, _Up const&>::value && is_constructible<_T2, _Up const&>::value &&
                     !(is_convertible<_Up const&, _T1>::value && is_convertible<_Up const&, _T2>::value) >* = nullptr>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 explicit pair(array<_Up, 2> const& __p)
      : first(__p[0]), second(__p[1]) {}

  template <class _Up, __enable_if_t< is_convertible<_Up, _T1>::value && is_convertible<_Up, _T2>::value >* = nullptr>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 pair(array<_Up, 2>&& __p)
      : first(std::move(__p)[0]), second(std::move(__p)[1]) {}

  template <class _Up,
            __enable_if_t< is_constructible<_T1, _Up>::value && is_constructible<_T2, _Up>::value &&
                           !(is_convertible<_Up, _T1>::value && is_convertible<_Up, _T2>::value) >* = nullptr>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 explicit pair(array<_Up, 2>&& __p)
      : first(std::move(__p)[0]), second(std::move(__p)[1]) {}

  template <
      class _Up,
      __enable_if_t< is_assignable<_T1&, _Up const&>::value && is_assignable<_T2&, _Up const&>::value >* = nullptr>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 pair& operator=(array<_Up, 2> const& __p) {
    first  = std::get<0>(__p);
    second = std::get<1>(__p);
    return *this;
  }

  template <class _Up, __enable_if_t< is_assignable<_T1&, _Up>::value && is_assignable<_T2&, _Up>::value >* = nullptr>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 pair& operator=(array<_Up, 2>&& __p) {
    first  = std::get<0>(std::move(__p));
    second = std::get<1>(std::move(__p));
    return *this;
  }
#  endif // _LIBCPP_STD_VER < 23
#endif   // _LIBCPP_CXX03_LANG

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 void swap(pair& __p)
      _NOEXCEPT_(__is_nothrow_swappable<first_type>::value&& __is_nothrow_swappable<second_type>::value) {
    using std::swap;
    swap(first, __p.first);
    swap(second, __p.second);
  }

#if _LIBCPP_STD_VER >= 23
  _LIBCPP_HIDE_FROM_ABI constexpr void swap(const pair& __p) const
      noexcept(__is_nothrow_swappable<const first_type>::value && __is_nothrow_swappable<const second_type>::value) {
    using std::swap;
    swap(first, __p.first);
    swap(second, __p.second);
  }
#endif

private:
#ifndef _LIBCPP_CXX03_LANG
  template <class... _Args1, class... _Args2, size_t... _I1, size_t... _I2>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20
  pair(piecewise_construct_t,
       tuple<_Args1...>& __first_args,
       tuple<_Args2...>& __second_args,
       __tuple_indices<_I1...>,
       __tuple_indices<_I2...>);
#endif
};

#if _LIBCPP_STD_VER >= 17
template <class _T1, class _T2>
pair(_T1, _T2) -> pair<_T1, _T2>;
#endif

// [pairs.spec], specialized algorithms

template <class _T1, class _T2, class _U1, class _U2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 bool
operator==(const pair<_T1, _T2>& __x, const pair<_U1, _U2>& __y) {
  return __x.first == __y.first && __x.second == __y.second;
}

#if _LIBCPP_STD_VER >= 20

template <class _T1, class _T2, class _U1, class _U2>
_LIBCPP_HIDE_FROM_ABI constexpr common_comparison_category_t< __synth_three_way_result<_T1, _U1>,
                                                              __synth_three_way_result<_T2, _U2> >
operator<=>(const pair<_T1, _T2>& __x, const pair<_U1, _U2>& __y) {
  if (auto __c = std::__synth_three_way(__x.first, __y.first); __c != 0) {
    return __c;
  }
  return std::__synth_three_way(__x.second, __y.second);
}

#else // _LIBCPP_STD_VER >= 20

template <class _T1, class _T2, class _U1, class _U2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 bool
operator!=(const pair<_T1, _T2>& __x, const pair<_U1, _U2>& __y) {
  return !(__x == __y);
}

template <class _T1, class _T2, class _U1, class _U2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 bool
operator<(const pair<_T1, _T2>& __x, const pair<_U1, _U2>& __y) {
  return __x.first < __y.first || (!(__y.first < __x.first) && __x.second < __y.second);
}

template <class _T1, class _T2, class _U1, class _U2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 bool
operator>(const pair<_T1, _T2>& __x, const pair<_U1, _U2>& __y) {
  return __y < __x;
}

template <class _T1, class _T2, class _U1, class _U2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 bool
operator>=(const pair<_T1, _T2>& __x, const pair<_U1, _U2>& __y) {
  return !(__x < __y);
}

template <class _T1, class _T2, class _U1, class _U2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 bool
operator<=(const pair<_T1, _T2>& __x, const pair<_U1, _U2>& __y) {
  return !(__y < __x);
}

#endif // _LIBCPP_STD_VER >= 20

#if _LIBCPP_STD_VER >= 23
template <class _T1, class _T2, class _U1, class _U2, template <class> class _TQual, template <class> class _UQual>
  requires requires {
    typename pair<common_reference_t<_TQual<_T1>, _UQual<_U1>>, common_reference_t<_TQual<_T2>, _UQual<_U2>>>;
  }
struct basic_common_reference<pair<_T1, _T2>, pair<_U1, _U2>, _TQual, _UQual> {
  using type = pair<common_reference_t<_TQual<_T1>, _UQual<_U1>>, common_reference_t<_TQual<_T2>, _UQual<_U2>>>;
};

template <class _T1, class _T2, class _U1, class _U2>
  requires requires { typename pair<common_type_t<_T1, _U1>, common_type_t<_T2, _U2>>; }
struct common_type<pair<_T1, _T2>, pair<_U1, _U2>> {
  using type = pair<common_type_t<_T1, _U1>, common_type_t<_T2, _U2>>;
};
#endif // _LIBCPP_STD_VER >= 23

template <class _T1, class _T2, __enable_if_t<__is_swappable<_T1>::value && __is_swappable<_T2>::value, int> = 0>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 void swap(pair<_T1, _T2>& __x, pair<_T1, _T2>& __y)
    _NOEXCEPT_((__is_nothrow_swappable<_T1>::value && __is_nothrow_swappable<_T2>::value)) {
  __x.swap(__y);
}

#if _LIBCPP_STD_VER >= 23
template <class _T1, class _T2>
  requires(__is_swappable<const _T1>::value && __is_swappable<const _T2>::value)
_LIBCPP_HIDE_FROM_ABI constexpr void
swap(const pair<_T1, _T2>& __x, const pair<_T1, _T2>& __y) noexcept(noexcept(__x.swap(__y))) {
  __x.swap(__y);
}
#endif

template <class _T1, class _T2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14
    pair<typename __unwrap_ref_decay<_T1>::type, typename __unwrap_ref_decay<_T2>::type>
    make_pair(_T1&& __t1, _T2&& __t2) {
  return pair<typename __unwrap_ref_decay<_T1>::type, typename __unwrap_ref_decay<_T2>::type>(
      std::forward<_T1>(__t1), std::forward<_T2>(__t2));
}

template <class _T1, class _T2>
struct _LIBCPP_TEMPLATE_VIS tuple_size<pair<_T1, _T2> > : public integral_constant<size_t, 2> {};

template <size_t _Ip, class _T1, class _T2>
struct _LIBCPP_TEMPLATE_VIS tuple_element<_Ip, pair<_T1, _T2> > {
  static_assert(_Ip < 2, "Index out of bounds in std::tuple_element<std::pair<T1, T2>>");
};

template <class _T1, class _T2>
struct _LIBCPP_TEMPLATE_VIS tuple_element<0, pair<_T1, _T2> > {
  using type _LIBCPP_NODEBUG = _T1;
};

template <class _T1, class _T2>
struct _LIBCPP_TEMPLATE_VIS tuple_element<1, pair<_T1, _T2> > {
  using type _LIBCPP_NODEBUG = _T2;
};

template <size_t _Ip>
struct __get_pair;

template <>
struct __get_pair<0> {
  template <class _T1, class _T2>
  static _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 _T1& get(pair<_T1, _T2>& __p) _NOEXCEPT {
    return __p.first;
  }

  template <class _T1, class _T2>
  static _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 const _T1& get(const pair<_T1, _T2>& __p) _NOEXCEPT {
    return __p.first;
  }

  template <class _T1, class _T2>
  static _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 _T1&& get(pair<_T1, _T2>&& __p) _NOEXCEPT {
    return std::forward<_T1>(__p.first);
  }

  template <class _T1, class _T2>
  static _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 const _T1&& get(const pair<_T1, _T2>&& __p) _NOEXCEPT {
    return std::forward<const _T1>(__p.first);
  }
};

template <>
struct __get_pair<1> {
  template <class _T1, class _T2>
  static _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 _T2& get(pair<_T1, _T2>& __p) _NOEXCEPT {
    return __p.second;
  }

  template <class _T1, class _T2>
  static _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 const _T2& get(const pair<_T1, _T2>& __p) _NOEXCEPT {
    return __p.second;
  }

  template <class _T1, class _T2>
  static _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 _T2&& get(pair<_T1, _T2>&& __p) _NOEXCEPT {
    return std::forward<_T2>(__p.second);
  }

  template <class _T1, class _T2>
  static _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 const _T2&& get(const pair<_T1, _T2>&& __p) _NOEXCEPT {
    return std::forward<const _T2>(__p.second);
  }
};

template <size_t _Ip, class _T1, class _T2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 typename tuple_element<_Ip, pair<_T1, _T2> >::type&
get(pair<_T1, _T2>& __p) _NOEXCEPT {
  return __get_pair<_Ip>::get(__p);
}

template <size_t _Ip, class _T1, class _T2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 const typename tuple_element<_Ip, pair<_T1, _T2> >::type&
get(const pair<_T1, _T2>& __p) _NOEXCEPT {
  return __get_pair<_Ip>::get(__p);
}

template <size_t _Ip, class _T1, class _T2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 typename tuple_element<_Ip, pair<_T1, _T2> >::type&&
get(pair<_T1, _T2>&& __p) _NOEXCEPT {
  return __get_pair<_Ip>::get(std::move(__p));
}

template <size_t _Ip, class _T1, class _T2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 const typename tuple_element<_Ip, pair<_T1, _T2> >::type&&
get(const pair<_T1, _T2>&& __p) _NOEXCEPT {
  return __get_pair<_Ip>::get(std::move(__p));
}

#if _LIBCPP_STD_VER >= 14
template <class _T1, class _T2>
inline _LIBCPP_HIDE_FROM_ABI constexpr _T1& get(pair<_T1, _T2>& __p) _NOEXCEPT {
  return __get_pair<0>::get(__p);
}

template <class _T1, class _T2>
inline _LIBCPP_HIDE_FROM_ABI constexpr _T1 const& get(pair<_T1, _T2> const& __p) _NOEXCEPT {
  return __get_pair<0>::get(__p);
}

template <class _T1, class _T2>
inline _LIBCPP_HIDE_FROM_ABI constexpr _T1&& get(pair<_T1, _T2>&& __p) _NOEXCEPT {
  return __get_pair<0>::get(std::move(__p));
}

template <class _T1, class _T2>
inline _LIBCPP_HIDE_FROM_ABI constexpr _T1 const&& get(pair<_T1, _T2> const&& __p) _NOEXCEPT {
  return __get_pair<0>::get(std::move(__p));
}

template <class _T1, class _T2>
inline _LIBCPP_HIDE_FROM_ABI constexpr _T1& get(pair<_T2, _T1>& __p) _NOEXCEPT {
  return __get_pair<1>::get(__p);
}

template <class _T1, class _T2>
inline _LIBCPP_HIDE_FROM_ABI constexpr _T1 const& get(pair<_T2, _T1> const& __p) _NOEXCEPT {
  return __get_pair<1>::get(__p);
}

template <class _T1, class _T2>
inline _LIBCPP_HIDE_FROM_ABI constexpr _T1&& get(pair<_T2, _T1>&& __p) _NOEXCEPT {
  return __get_pair<1>::get(std::move(__p));
}

template <class _T1, class _T2>
inline _LIBCPP_HIDE_FROM_ABI constexpr _T1 const&& get(pair<_T2, _T1> const&& __p) _NOEXCEPT {
  return __get_pair<1>::get(std::move(__p));
}

#endif // _LIBCPP_STD_VER >= 14

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___UTILITY_PAIR_H
