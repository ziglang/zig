//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_REFERENCE_CONSTRUCTS_FROM_TEMPORARY_H
#define _LIBCPP___TYPE_TRAITS_REFERENCE_CONSTRUCTS_FROM_TEMPORARY_H

#include <__config>
#include <__type_traits/integral_constant.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER >= 23 && __has_builtin(__reference_constructs_from_temporary)

template <class _Tp, class _Up>
struct _LIBCPP_NO_SPECIALIZATIONS reference_constructs_from_temporary
    : public bool_constant<__reference_constructs_from_temporary(_Tp, _Up)> {};

template <class _Tp, class _Up>
_LIBCPP_NO_SPECIALIZATIONS inline constexpr bool reference_constructs_from_temporary_v =
    __reference_constructs_from_temporary(_Tp, _Up);

#endif

#if __has_builtin(__reference_constructs_from_temporary)
template <class _Tp, class _Up>
inline const bool __reference_constructs_from_temporary_v = __reference_constructs_from_temporary(_Tp, _Up);
#else
// TODO(LLVM 22): Remove this as all supported compilers should have __reference_constructs_from_temporary implemented.
template <class _Tp, class _Up>
inline const bool __reference_constructs_from_temporary_v = __reference_binds_to_temporary(_Tp, _Up);
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_REFERENCE_CONSTRUCTS_FROM_TEMPORARY_H
