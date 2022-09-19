// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMATTER_POINTER_H
#define _LIBCPP___FORMAT_FORMATTER_POINTER_H

#include <__availability>
#include <__config>
#include <__format/format_fwd.h>
#include <__format/format_parse_context.h>
#include <__format/formatter.h>
#include <__format/formatter_integral.h>
#include <__format/formatter_output.h>
#include <__format/parser_std_format_spec.h>
#include <cstddef>
#include <cstdint>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS __formatter_pointer {
public:
  constexpr __formatter_pointer() { __parser_.__alignment_ = __format_spec::__alignment::__right; }

  _LIBCPP_HIDE_FROM_ABI constexpr auto
  parse(basic_format_parse_context<_CharT>& __parse_ctx) -> decltype(__parse_ctx.begin()) {
    auto __result = __parser_.__parse(__parse_ctx, __format_spec::__fields_pointer);
    __format_spec::__process_display_type_pointer(__parser_.__type_);
    return __result;
  }

  _LIBCPP_HIDE_FROM_ABI auto format(const void* __ptr, auto& __ctx) const -> decltype(__ctx.out()) {
    __format_spec::__parsed_specifications<_CharT> __specs = __parser_.__get_parsed_std_specifications(__ctx);
    __specs.__std_.__alternate_form_                       = true;
    __specs.__std_.__type_                                 = __format_spec::__type::__hexadecimal_lower_case;
    return __formatter::__format_integer(reinterpret_cast<uintptr_t>(__ptr), __ctx, __specs);
  }

  __format_spec::__parser<_CharT> __parser_;
};

// [format.formatter.spec]/2.4
// For each charT, the pointer type specializations template<>
// - struct formatter<nullptr_t, charT>;
// - template<> struct formatter<void*, charT>;
// - template<> struct formatter<const void*, charT>;
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<nullptr_t, _CharT>
    : public __formatter_pointer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<void*, _CharT> : public __formatter_pointer<_CharT> {
};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<const void*, _CharT>
    : public __formatter_pointer<_CharT> {};

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FORMAT_FORMATTER_POINTER_H
