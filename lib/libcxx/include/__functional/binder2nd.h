// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FUNCTIONAL_BINDER2ND_H
#define _LIBCPP___FUNCTIONAL_BINDER2ND_H

#include <__config>
#include <__functional/unary_function.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER <= 14 || defined(_LIBCPP_ENABLE_CXX17_REMOVED_BINDERS)

template <class __Operation>
class _LIBCPP_TEMPLATE_VIS _LIBCPP_DEPRECATED_IN_CXX11 binder2nd
    : public __unary_function<typename __Operation::first_argument_type, typename __Operation::result_type>
{
protected:
    __Operation                                op;
    typename __Operation::second_argument_type value;
public:
    _LIBCPP_INLINE_VISIBILITY
    binder2nd(const __Operation& __x, const typename __Operation::second_argument_type __y)
        : op(__x), value(__y) {}
    _LIBCPP_INLINE_VISIBILITY typename __Operation::result_type operator()
        (      typename __Operation::first_argument_type& __x) const
            {return op(__x, value);}
    _LIBCPP_INLINE_VISIBILITY typename __Operation::result_type operator()
        (const typename __Operation::first_argument_type& __x) const
            {return op(__x, value);}
};

template <class __Operation, class _Tp>
_LIBCPP_DEPRECATED_IN_CXX11 inline _LIBCPP_INLINE_VISIBILITY
binder2nd<__Operation>
bind2nd(const __Operation& __op, const _Tp& __x)
    {return binder2nd<__Operation>(__op, __x);}

#endif // _LIBCPP_STD_VER <= 14 || defined(_LIBCPP_ENABLE_CXX17_REMOVED_BINDERS)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FUNCTIONAL_BINDER2ND_H
