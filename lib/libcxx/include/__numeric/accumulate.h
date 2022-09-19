// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___NUMERIC_ACCUMULATE_H
#define _LIBCPP___NUMERIC_ACCUMULATE_H

#include <__config>
#include <__utility/move.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _InputIterator, class _Tp>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
_Tp
accumulate(_InputIterator __first, _InputIterator __last, _Tp __init)
{
    for (; __first != __last; ++__first)
#if _LIBCPP_STD_VER > 17
        __init = _VSTD::move(__init) + *__first;
#else
        __init = __init + *__first;
#endif
    return __init;
}

template <class _InputIterator, class _Tp, class _BinaryOperation>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
_Tp
accumulate(_InputIterator __first, _InputIterator __last, _Tp __init, _BinaryOperation __binary_op)
{
    for (; __first != __last; ++__first)
#if _LIBCPP_STD_VER > 17
        __init = __binary_op(_VSTD::move(__init), *__first);
#else
        __init = __binary_op(__init, *__first);
#endif
    return __init;
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___NUMERIC_ACCUMULATE_H
