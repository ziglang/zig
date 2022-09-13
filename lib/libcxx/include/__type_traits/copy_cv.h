//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_COPY_CV_H
#define _LIBCPP___TYPE_TRAITS_COPY_CV_H

#include <__config>
#include <__type_traits/add_const.h>
#include <__type_traits/add_cv.h>
#include <__type_traits/add_volatile.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

// Let COPYCV(FROM, TO) be an alias for type TO with the addition of FROM's
// top-level cv-qualifiers.
template <class _From, class _To>
struct __copy_cv
{
    using type = _To;
};

template <class _From, class _To>
struct __copy_cv<const _From, _To>
{
    using type = typename add_const<_To>::type;
};

template <class _From, class _To>
struct __copy_cv<volatile _From, _To>
{
    using type = typename add_volatile<_To>::type;
};

template <class _From, class _To>
struct __copy_cv<const volatile _From, _To>
{
    using type = typename add_cv<_To>::type;
};

template <class _From, class _To>
using __copy_cv_t = typename __copy_cv<_From, _To>::type;

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_COPY_CV_H
