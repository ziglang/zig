//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_FRONTEND_DISPATCH
#define _LIBCPP___ALGORITHM_PSTL_FRONTEND_DISPATCH

#include <__config>
#include <__type_traits/is_callable.h>
#include <__utility/forward.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

#  define _LIBCPP_PSTL_CUSTOMIZATION_POINT(name, policy)                                                               \
    [](auto&&... __args) -> decltype(std::name<policy>(                                                                \
                             typename __select_backend<policy>::type{}, std::forward<decltype(__args)>(__args)...)) {  \
      return std::name<policy>(typename __select_backend<policy>::type{}, std::forward<decltype(__args)>(__args)...);  \
    }

template <class _SpecializedImpl, class _GenericImpl, class... _Args>
_LIBCPP_HIDE_FROM_ABI decltype(auto)
__pstl_frontend_dispatch(_SpecializedImpl __specialized_impl, _GenericImpl __generic_impl, _Args&&... __args) {
  if constexpr (__is_callable<_SpecializedImpl, _Args...>::value) {
    return __specialized_impl(std::forward<_Args>(__args)...);
  } else {
    return __generic_impl(std::forward<_Args>(__args)...);
  }
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP_STD_VER >= 17

#endif // _LIBCPP___ALGORITHM_PSTL_FRONTEND_DISPATCH
