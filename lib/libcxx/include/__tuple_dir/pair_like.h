//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TUPLE_PAIR_LIKE_H
#define _LIBCPP___TUPLE_PAIR_LIKE_H

#include <__config>
#include <__tuple_dir/tuple_like.h>
#include <__tuple_dir/tuple_size.h>
#include <__type_traits/remove_cvref.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER >= 20

template <class _Tp>
concept __pair_like = __tuple_like<_Tp> && tuple_size<remove_cvref_t<_Tp>>::value == 2;

#endif // _LIBCPP_STD_VER >= 20

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TUPLE_PAIR_LIKE_H
