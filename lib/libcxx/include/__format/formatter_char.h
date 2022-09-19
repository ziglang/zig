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
#include <__concepts/same_as.h>
#include <__config>
#include <__format/format_fwd.h>
#include <__format/format_parse_context.h>
#include <__format/formatter.h>
#include <__format/formatter_integral.h>
#include <__format/formatter_output.h>
#include <__format/parser_std_format_spec.h>
#include <__type_traits/conditional.h>
#include <__type_traits/is_signed.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT __formatter_char {
public:
  _LIBCPP_HIDE_FROM_ABI constexpr auto
  parse(basic_format_parse_context<_CharT>& __parse_ctx) -> decltype(__parse_ctx.begin()) {
    auto __result = __parser_.__parse(__parse_ctx, __format_spec::__fields_integral);
    __format_spec::__process_parsed_char(__parser_);
    return __result;
  }

  _LIBCPP_HIDE_FROM_ABI auto format(_CharT __value, auto& __ctx) const -> decltype(__ctx.out()) {
    if (__parser_.__type_ == __format_spec::__type::__default || __parser_.__type_ == __format_spec::__type::__char)
      return __formatter::__format_char(__value, __ctx.out(), __parser_.__get_parsed_std_specifications(__ctx));

    if constexpr (sizeof(_CharT) <= sizeof(int))
      // Promotes _CharT to an integral type. This reduces the number of
      // instantiations of __format_integer reducing code size.
      return __formatter::__format_integer(
          static_cast<conditional_t<is_signed_v<_CharT>, int, unsigned>>(__value),
          __ctx,
          __parser_.__get_parsed_std_specifications(__ctx));
    else
      return __formatter::__format_integer(__value, __ctx, __parser_.__get_parsed_std_specifications(__ctx));
  }

  _LIBCPP_HIDE_FROM_ABI auto format(char __value, auto& __ctx) const -> decltype(__ctx.out())
    requires(same_as<_CharT, wchar_t>)
  {
    return format(static_cast<wchar_t>(__value), __ctx);
  }

  __format_spec::__parser<_CharT> __parser_;
};

template <>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<char, char> : public __formatter_char<char> {};

#  ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template <>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<char, wchar_t> : public __formatter_char<wchar_t> {};

template <>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<wchar_t, wchar_t> : public __formatter_char<wchar_t> {
};

#  endif // _LIBCPP_HAS_NO_WIDE_CHARACTERS

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FORMAT_FORMATTER_CHAR_H
