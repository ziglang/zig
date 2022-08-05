//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_DECAY_H
#define _LIBCPP___TYPE_TRAITS_DECAY_H

#include <__config>
#include <__type_traits/add_pointer.h>
#include <__type_traits/conditional.h>
#include <__type_traits/integral_constant.h>
#include <__type_traits/is_array.h>
#include <__type_traits/is_function.h>
#include <__type_traits/is_referenceable.h>
#include <__type_traits/remove_cv.h>
#include <__type_traits/remove_extent.h>
#include <__type_traits/remove_reference.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Up, bool>
struct __decay {
    typedef _LIBCPP_NODEBUG typename remove_cv<_Up>::type type;
};

template <class _Up>
struct __decay<_Up, true> {
public:
    typedef _LIBCPP_NODEBUG typename conditional
                     <
                         is_array<_Up>::value,
                         typename remove_extent<_Up>::type*,
                         typename conditional
                         <
                              is_function<_Up>::value,
                              typename add_pointer<_Up>::type,
                              typename remove_cv<_Up>::type
                         >::type
                     >::type type;
};

template <class _Tp>
struct _LIBCPP_TEMPLATE_VIS decay
{
private:
    typedef _LIBCPP_NODEBUG typename remove_reference<_Tp>::type _Up;
public:
    typedef _LIBCPP_NODEBUG typename __decay<_Up, __is_referenceable<_Up>::value>::type type;
};

#if _LIBCPP_STD_VER > 11
template <class _Tp> using decay_t = typename decay<_Tp>::type;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_DECAY_H
