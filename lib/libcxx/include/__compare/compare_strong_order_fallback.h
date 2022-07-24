//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___COMPARE_COMPARE_STRONG_ORDER_FALLBACK
#define _LIBCPP___COMPARE_COMPARE_STRONG_ORDER_FALLBACK

#include <__compare/ordering.h>
#include <__compare/strong_order.h>
#include <__config>
#include <__utility/forward.h>
#include <__utility/priority_tag.h>
#include <type_traits>

#ifndef _LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_CONCEPTS)

// [cmp.alg]
namespace __compare_strong_order_fallback {
    struct __fn {
        template<class _Tp, class _Up>
            requires is_same_v<decay_t<_Tp>, decay_t<_Up>>
        _LIBCPP_HIDE_FROM_ABI static constexpr auto
        __go(_Tp&& __t, _Up&& __u, __priority_tag<1>)
            noexcept(noexcept(_VSTD::strong_order(_VSTD::forward<_Tp>(__t), _VSTD::forward<_Up>(__u))))
            -> decltype(      _VSTD::strong_order(_VSTD::forward<_Tp>(__t), _VSTD::forward<_Up>(__u)))
            { return          _VSTD::strong_order(_VSTD::forward<_Tp>(__t), _VSTD::forward<_Up>(__u)); }

        template<class _Tp, class _Up>
            requires is_same_v<decay_t<_Tp>, decay_t<_Up>>
        _LIBCPP_HIDE_FROM_ABI static constexpr auto
        __go(_Tp&& __t, _Up&& __u, __priority_tag<0>)
            noexcept(noexcept(_VSTD::forward<_Tp>(__t) == _VSTD::forward<_Up>(__u) ? strong_ordering::equal :
                              _VSTD::forward<_Tp>(__t) < _VSTD::forward<_Up>(__u) ? strong_ordering::less :
                              strong_ordering::greater))
            -> decltype(      _VSTD::forward<_Tp>(__t) == _VSTD::forward<_Up>(__u) ? strong_ordering::equal :
                              _VSTD::forward<_Tp>(__t) < _VSTD::forward<_Up>(__u) ? strong_ordering::less :
                              strong_ordering::greater)
        {
            return            _VSTD::forward<_Tp>(__t) == _VSTD::forward<_Up>(__u) ? strong_ordering::equal :
                              _VSTD::forward<_Tp>(__t) < _VSTD::forward<_Up>(__u) ? strong_ordering::less :
                              strong_ordering::greater;
        }

        template<class _Tp, class _Up>
        _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Tp&& __t, _Up&& __u) const
            noexcept(noexcept(__go(_VSTD::forward<_Tp>(__t), _VSTD::forward<_Up>(__u), __priority_tag<1>())))
            -> decltype(      __go(_VSTD::forward<_Tp>(__t), _VSTD::forward<_Up>(__u), __priority_tag<1>()))
            { return          __go(_VSTD::forward<_Tp>(__t), _VSTD::forward<_Up>(__u), __priority_tag<1>()); }
    };
} // namespace __compare_strong_order_fallback

inline namespace __cpo {
    inline constexpr auto compare_strong_order_fallback = __compare_strong_order_fallback::__fn{};
} // namespace __cpo

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___COMPARE_COMPARE_STRONG_ORDER_FALLBACK
