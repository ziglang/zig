// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FUNCTIONAL_IDENTITY_H
#define _LIBCPP___FUNCTIONAL_IDENTITY_H

#include <__config>
#include <__utility/forward.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

struct __identity {
  template <class _Tp>
  _LIBCPP_NODISCARD _LIBCPP_CONSTEXPR _Tp&& operator()(_Tp&& __t) const _NOEXCEPT {
    return std::forward<_Tp>(__t);
  }

  using is_transparent = void;
};

#if _LIBCPP_STD_VER > 17

struct identity {
    template<class _Tp>
    _LIBCPP_NODISCARD_EXT constexpr _Tp&& operator()(_Tp&& __t) const noexcept
    {
        return _VSTD::forward<_Tp>(__t);
    }

    using is_transparent = void;
};
#endif // _LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FUNCTIONAL_IDENTITY_H
