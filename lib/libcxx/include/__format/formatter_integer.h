// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMATTER_INTEGER_H
#define _LIBCPP___FORMAT_FORMATTER_INTEGER_H

#include <__availability>
#include <__config>
#include <__format/format_error.h>
#include <__format/format_fwd.h>
#include <__format/formatter.h>
#include <__format/formatter_integral.h>
#include <__format/parser_std_format_spec.h>
#include <limits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

// TODO FMT Remove this once we require compilers with proper C++20 support.
// If the compiler has no concepts support, the format header will be disabled.
// Without concepts support enable_if needs to be used and that too much effort
// to support compilers with partial C++20 support.
#if !defined(_LIBCPP_HAS_NO_CONCEPTS)

namespace __format_spec {

template <class _CharT>
class _LIBCPP_TEMPLATE_VIS __parser_integer : public __parser_integral<_CharT> {
public:
  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(auto& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    auto __it = __parser_integral<_CharT>::__parse(__parse_ctx);

    switch (this->__type) {
    case _Flags::_Type::__default:
      this->__type = _Flags::_Type::__decimal;
      [[fallthrough]];

    case _Flags::_Type::__binary_lower_case:
    case _Flags::_Type::__binary_upper_case:
    case _Flags::_Type::__octal:
    case _Flags::_Type::__decimal:
    case _Flags::_Type::__hexadecimal_lower_case:
    case _Flags::_Type::__hexadecimal_upper_case:
      this->__handle_integer();
      break;

    case _Flags::_Type::__char:
      this->__handle_char();
      break;

    default:
      __throw_format_error("The format-spec type has a type not supported for "
                           "an integer argument");
    }
    return __it;
  }
};

template <class _CharT>
using __formatter_integer = __formatter_integral<__parser_integer<_CharT>>;

} // namespace __format_spec

// [format.formatter.spec]/2.3
// For each charT, for each cv-unqualified arithmetic type ArithmeticT other
// than char, wchar_t, char8_t, char16_t, or char32_t, a specialization

// Signed integral types.
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT
    formatter<signed char, _CharT>
    : public __format_spec::__formatter_integer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<short, _CharT>
    : public __format_spec::__formatter_integer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<int, _CharT>
    : public __format_spec::__formatter_integer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<long, _CharT>
    : public __format_spec::__formatter_integer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT
    formatter<long long, _CharT>
    : public __format_spec::__formatter_integer<_CharT> {};
#ifndef _LIBCPP_HAS_NO_INT128
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT
    formatter<__int128_t, _CharT>
    : public __format_spec::__formatter_integer<_CharT> {
  using _Base = __format_spec::__formatter_integer<_CharT>;

  _LIBCPP_HIDE_FROM_ABI auto format(__int128_t __value, auto& __ctx)
      -> decltype(__ctx.out()) {
    // TODO FMT Implement full 128 bit support.
    using _To = long long;
    if (__value < numeric_limits<_To>::min() ||
        __value > numeric_limits<_To>::max())
      __throw_format_error("128-bit value is outside of implemented range");

    return _Base::format(static_cast<_To>(__value), __ctx);
  }
};
#endif

// Unsigned integral types.
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT
    formatter<unsigned char, _CharT>
    : public __format_spec::__formatter_integer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT
    formatter<unsigned short, _CharT>
    : public __format_spec::__formatter_integer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT
    formatter<unsigned, _CharT>
    : public __format_spec::__formatter_integer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT
    formatter<unsigned long, _CharT>
    : public __format_spec::__formatter_integer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT
    formatter<unsigned long long, _CharT>
    : public __format_spec::__formatter_integer<_CharT> {};
#ifndef _LIBCPP_HAS_NO_INT128
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT
    formatter<__uint128_t, _CharT>
    : public __format_spec::__formatter_integer<_CharT> {
  using _Base = __format_spec::__formatter_integer<_CharT>;

  _LIBCPP_HIDE_FROM_ABI auto format(__uint128_t __value, auto& __ctx)
      -> decltype(__ctx.out()) {
    // TODO FMT Implement full 128 bit support.
    using _To = unsigned long long;
    if (__value < numeric_limits<_To>::min() ||
        __value > numeric_limits<_To>::max())
      __throw_format_error("128-bit value is outside of implemented range");

    return _Base::format(static_cast<_To>(__value), __ctx);
  }
};
#endif

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___FORMAT_FORMATTER_INTEGER_H
