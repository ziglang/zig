// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMATTER_H
#define _LIBCPP___FORMAT_FORMATTER_H

#include <__availability>
#include <__concepts/same_as.h>
#include <__config>
#include <__format/format_fwd.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

/// The default formatter template.
///
/// [format.formatter.spec]/5
/// If F is a disabled specialization of formatter, these values are false:
/// - is_default_constructible_v<F>,
/// - is_copy_constructible_v<F>,
/// - is_move_constructible_v<F>,
/// - is_copy_assignable<F>, and
/// - is_move_assignable<F>.
template <class _Tp, class _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter {
  formatter() = delete;
  formatter(const formatter&) = delete;
  formatter& operator=(const formatter&) = delete;
};

namespace __formatter {

/** The character types that formatters are specialized for. */
template <class _CharT>
concept __char_type = same_as<_CharT, char> || same_as<_CharT, wchar_t>;

} // namespace __formatter

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FORMAT_FORMATTER_H
