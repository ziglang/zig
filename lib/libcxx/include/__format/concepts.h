// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_CONCEPTS_H
#define _LIBCPP___FORMAT_CONCEPTS_H

#include <__concepts/same_as.h>
#include <__concepts/semiregular.h>
#include <__config>
#include <__format/format_fwd.h>
#include <__format/format_parse_context.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

// The output iterator isn't specified. A formatter should accept any
// output_iterator. This iterator is a minimal iterator to test the concept.
// (Note testing for (w)format_context would be a valid choice, but requires
// selecting the proper one depending on the type of _CharT.)
template <class _CharT>
using __fmt_iter_for = _CharT*;

// The concept is based on P2286R6
// It lacks the const of __cf as required by, the not yet accepted, LWG-3636.
// The current formatters can't be easily adapted, but that is WIP.
// TODO FMT properly implement this concepts once accepted.
template <class _Tp, class _CharT>
concept __formattable = (semiregular<formatter<remove_cvref_t<_Tp>, _CharT>>) &&
                        requires(formatter<remove_cvref_t<_Tp>, _CharT> __f,
                                 formatter<remove_cvref_t<_Tp>, _CharT> __cf, _Tp __t,
                                 basic_format_context<__fmt_iter_for<_CharT>, _CharT> __fc,
                                 basic_format_parse_context<_CharT> __pc) {
                          { __f.parse(__pc) } -> same_as<typename basic_format_parse_context<_CharT>::iterator>;
                          { __cf.format(__t, __fc) } -> same_as<__fmt_iter_for<_CharT>>;
                        };

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FORMAT_CONCEPTS_H
