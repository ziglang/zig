// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMATTER_CHAR_H
#define _LIBCPP___FORMAT_FORMATTER_CHAR_H

#include <__availability>
#include <__config>
#include <__format/format_error.h>
#include <__format/format_fwd.h>
#include <__format/formatter.h>
#include <__format/formatter_integral.h>
#include <__format/parser_std_format_spec.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

// TODO FMT Remove this once we require compilers with proper C++20 support.
// If the compiler has no concepts support, the format header will be disabled.
// Without concepts support enable_if needs to be used and that too much effort
// to support compilers with partial C++20 support.
#if !defined(_LIBCPP_HAS_NO_CONCEPTS)

namespace __format_spec {

template <class _CharT>
class _LIBCPP_TEMPLATE_VIS __parser_char : public __parser_integral<_CharT> {
public:
  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(auto& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    auto __it = __parser_integral<_CharT>::__parse(__parse_ctx);

    switch (this->__type) {
    case _Flags::_Type::__default:
      this->__type = _Flags::_Type::__char;
      [[fallthrough]];
    case _Flags::_Type::__char:
      this->__handle_char();
      break;

    case _Flags::_Type::__binary_lower_case:
    case _Flags::_Type::__binary_upper_case:
    case _Flags::_Type::__octal:
    case _Flags::_Type::__decimal:
    case _Flags::_Type::__hexadecimal_lower_case:
    case _Flags::_Type::__hexadecimal_upper_case:
      this->__handle_integer();
      break;

    default:
      __throw_format_error(
          "The format-spec type has a type not supported for a char argument");
    }

    return __it;
  }
};

template <class _CharT>
using __formatter_char = __formatter_integral<__parser_char<_CharT>>;

} // namespace __format_spec

// [format.formatter.spec]/2.1 The specializations

template <>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<char, char>
    : public __format_spec::__formatter_char<char> {};

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template <>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<char, wchar_t>
    : public __format_spec::__formatter_char<wchar_t> {
  using _Base = __format_spec::__formatter_char<wchar_t>;

  _LIBCPP_HIDE_FROM_ABI auto format(char __value, auto& __ctx)
      -> decltype(__ctx.out()) {
    return _Base::format(static_cast<wchar_t>(__value), __ctx);
  }
};

template <>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT
    formatter<wchar_t, wchar_t>
    : public __format_spec::__formatter_char<wchar_t> {};
#endif // _LIBCPP_HAS_NO_WIDE_CHARACTERS
#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FORMAT_FORMATTER_CHAR_H
