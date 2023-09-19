//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FWD_GET_H
#define _LIBCPP___FWD_GET_H

#include <__concepts/copyable.h>
#include <__config>
#include <__fwd/array.h>
#include <__fwd/pair.h>
#include <__fwd/subrange.h>
#include <__fwd/tuple.h>
#include <__tuple/tuple_element.h>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#ifndef _LIBCPP_CXX03_LANG

template <size_t _Ip, class ..._Tp>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
typename tuple_element<_Ip, tuple<_Tp...> >::type&
get(tuple<_Tp...>&) _NOEXCEPT;

template <size_t _Ip, class ..._Tp>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
const typename tuple_element<_Ip, tuple<_Tp...> >::type&
get(const tuple<_Tp...>&) _NOEXCEPT;

template <size_t _Ip, class ..._Tp>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
typename tuple_element<_Ip, tuple<_Tp...> >::type&&
get(tuple<_Tp...>&&) _NOEXCEPT;

template <size_t _Ip, class ..._Tp>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
const typename tuple_element<_Ip, tuple<_Tp...> >::type&&
get(const tuple<_Tp...>&&) _NOEXCEPT;

#endif //_LIBCPP_CXX03_LANG

template <size_t _Ip, class _T1, class _T2>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
typename tuple_element<_Ip, pair<_T1, _T2> >::type&
get(pair<_T1, _T2>&) _NOEXCEPT;

template <size_t _Ip, class _T1, class _T2>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
const typename tuple_element<_Ip, pair<_T1, _T2> >::type&
get(const pair<_T1, _T2>&) _NOEXCEPT;

#ifndef _LIBCPP_CXX03_LANG
template <size_t _Ip, class _T1, class _T2>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
typename tuple_element<_Ip, pair<_T1, _T2> >::type&&
get(pair<_T1, _T2>&&) _NOEXCEPT;

template <size_t _Ip, class _T1, class _T2>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
const typename tuple_element<_Ip, pair<_T1, _T2> >::type&&
get(const pair<_T1, _T2>&&) _NOEXCEPT;
#endif

template <size_t _Ip, class _Tp, size_t _Size>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
_Tp&
get(array<_Tp, _Size>&) _NOEXCEPT;

template <size_t _Ip, class _Tp, size_t _Size>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
const _Tp&
get(const array<_Tp, _Size>&) _NOEXCEPT;

#ifndef _LIBCPP_CXX03_LANG
template <size_t _Ip, class _Tp, size_t _Size>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
_Tp&&
get(array<_Tp, _Size>&&) _NOEXCEPT;

template <size_t _Ip, class _Tp, size_t _Size>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
const _Tp&&
get(const array<_Tp, _Size>&&) _NOEXCEPT;
#endif

#if _LIBCPP_STD_VER >= 20

namespace ranges {

template <size_t _Index, class _Iter, class _Sent, subrange_kind _Kind>
  requires((_Index == 0 && copyable<_Iter>) || _Index == 1)
_LIBCPP_HIDE_FROM_ABI constexpr auto get(const subrange<_Iter, _Sent, _Kind>& __subrange);

template <size_t _Index, class _Iter, class _Sent, subrange_kind _Kind>
  requires(_Index < 2)
_LIBCPP_HIDE_FROM_ABI constexpr auto get(subrange<_Iter, _Sent, _Kind>&& __subrange);

} // namespace ranges

using ranges::get;

#endif // _LIBCPP_STD_VER >= 20

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FWD_GET_H
