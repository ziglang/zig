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
#include <__concepts/arithmetic.h>
#include <__config>
#include <__format/format_fwd.h>
#include <__format/format_parse_context.h>
#include <__format/formatter.h>
#include <__format/formatter_integral.h>
#include <__format/formatter_output.h>
#include <__format/parser_std_format_spec.h>
#include <__type_traits/make_32_64_or_128_bit.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

    _LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

    template <__formatter::__char_type _CharT>
    struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT __formatter_integer {

public:
  _LIBCPP_HIDE_FROM_ABI constexpr auto
  parse(basic_format_parse_context<_CharT>& __parse_ctx) -> decltype(__parse_ctx.begin()) {
    auto __result = __parser_.__parse(__parse_ctx, __format_spec::__fields_integral);
    __format_spec::__process_parsed_integer(__parser_);
    return __result;
  }

  template <integral _Tp>
  _LIBCPP_HIDE_FROM_ABI auto format(_Tp __value, auto& __ctx) const -> decltype(__ctx.out()) {
    __format_spec::__parsed_specifications<_CharT> __specs = __parser_.__get_parsed_std_specifications(__ctx);

    if (__specs.__std_.__type_ == __format_spec::__type::__char)
      return __formatter::__format_char(__value, __ctx.out(), __specs);

    using _Type = __make_32_64_or_128_bit_t<_Tp>;
    static_assert(!is_same<_Type, void>::value, "unsupported integral type used in __formatter_integer::__format");

    // Reduce the number of instantiation of the integer formatter
    return __formatter::__format_integer(static_cast<_Type>(__value), __ctx, __specs);
  }

  __format_spec::__parser<_CharT> __parser_;
};

// Signed integral types.
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<signed char, _CharT>
    : public __formatter_integer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<short, _CharT> : public __formatter_integer<_CharT> {
};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<int, _CharT> : public __formatter_integer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<long, _CharT> : public __formatter_integer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<long long, _CharT>
    : public __formatter_integer<_CharT> {};
#  ifndef _LIBCPP_HAS_NO_INT128
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<__int128_t, _CharT>
    : public __formatter_integer<_CharT> {};
#  endif

// Unsigned integral types.
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<unsigned char, _CharT>
    : public __formatter_integer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<unsigned short, _CharT>
    : public __formatter_integer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<unsigned, _CharT>
    : public __formatter_integer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<unsigned long, _CharT>
    : public __formatter_integer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<unsigned long long, _CharT>
    : public __formatter_integer<_CharT> {};
#  ifndef _LIBCPP_HAS_NO_INT128
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<__uint128_t, _CharT>
    : public __formatter_integer<_CharT> {};
#  endif

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FORMAT_FORMATTER_INTEGER_H
