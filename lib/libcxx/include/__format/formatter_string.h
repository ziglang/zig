// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMATTER_STRING_H
#define _LIBCPP___FORMAT_FORMATTER_STRING_H

#include <__availability>
#include <__config>
#include <__format/concepts.h>
#include <__format/format_parse_context.h>
#include <__format/formatter.h>
#include <__format/formatter_output.h>
#include <__format/parser_std_format_spec.h>
#include <__utility/move.h>
#include <string>
#include <string_view>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS __formatter_string {
public:
  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    auto __result = __parser_.__parse(__parse_ctx, __format_spec::__fields_string);
    __format_spec::__process_display_type_string(__parser_.__type_);
    return __result;
  }

  _LIBCPP_HIDE_FROM_ABI auto format(basic_string_view<_CharT> __str, auto& __ctx) const -> decltype(__ctx.out()) {
#  if _LIBCPP_STD_VER > 20
    if (__parser_.__type_ == __format_spec::__type::__debug)
      return __formatter::__format_escaped_string(__str, __ctx.out(), __parser_.__get_parsed_std_specifications(__ctx));
#  endif

    return __formatter::__write_string(__str, __ctx.out(), __parser_.__get_parsed_std_specifications(__ctx));
  }

#  if _LIBCPP_STD_VER > 20
  _LIBCPP_HIDE_FROM_ABI constexpr void set_debug_format() { __parser_.__type_ = __format_spec::__type::__debug; }
#  endif

  __format_spec::__parser<_CharT> __parser_{.__alignment_ = __format_spec::__alignment::__left};
};

// Formatter const char*.
template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<const _CharT*, _CharT>
    : public __formatter_string<_CharT> {
  using _Base = __formatter_string<_CharT>;

  _LIBCPP_HIDE_FROM_ABI auto format(const _CharT* __str, auto& __ctx) const -> decltype(__ctx.out()) {
    _LIBCPP_ASSERT(__str, "The basic_format_arg constructor should have "
                          "prevented an invalid pointer.");

    __format_spec::__parsed_specifications<_CharT> __specs = _Base::__parser_.__get_parsed_std_specifications(__ctx);
#  if _LIBCPP_STD_VER > 20
    if (_Base::__parser_.__type_ == __format_spec::__type::__debug)
      return __formatter::__format_escaped_string(basic_string_view<_CharT>{__str}, __ctx.out(), __specs);
#  endif

    // When using a center or right alignment and the width option the length
    // of __str must be known to add the padding upfront. This case is handled
    // by the base class by converting the argument to a basic_string_view.
    //
    // When using left alignment and the width option the padding is added
    // after outputting __str so the length can be determined while outputting
    // __str. The same holds true for the precision, during outputting __str it
    // can be validated whether the precision threshold has been reached. For
    // now these optimizations aren't implemented. Instead the base class
    // handles these options.
    // TODO FMT Implement these improvements.
    if (__specs.__has_width() || __specs.__has_precision())
      return __formatter::__write_string(basic_string_view<_CharT>{__str}, __ctx.out(), __specs);

    // No formatting required, copy the string to the output.
    auto __out_it = __ctx.out();
    while (*__str)
      *__out_it++ = *__str++;
    return __out_it;
  }
};

// Formatter char*.
template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<_CharT*, _CharT>
    : public formatter<const _CharT*, _CharT> {
  using _Base = formatter<const _CharT*, _CharT>;

  _LIBCPP_HIDE_FROM_ABI auto format(_CharT* __str, auto& __ctx) const -> decltype(__ctx.out()) {
    return _Base::format(__str, __ctx);
  }
};

// Formatter char[].
template <__fmt_char_type _CharT, size_t _Size>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<_CharT[_Size], _CharT>
    : public __formatter_string<_CharT> {
  using _Base = __formatter_string<_CharT>;

  _LIBCPP_HIDE_FROM_ABI auto format(_CharT __str[_Size], auto& __ctx) const -> decltype(__ctx.out()) {
    return _Base::format(basic_string_view<_CharT>(__str, _Size), __ctx);
  }
};

// Formatter const char[].
template <__fmt_char_type _CharT, size_t _Size>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<const _CharT[_Size], _CharT>
    : public __formatter_string<_CharT> {
  using _Base = __formatter_string<_CharT>;

  _LIBCPP_HIDE_FROM_ABI auto format(const _CharT __str[_Size], auto& __ctx) const -> decltype(__ctx.out()) {
    return _Base::format(basic_string_view<_CharT>(__str, _Size), __ctx);
  }
};

// Formatter std::string.
template <__fmt_char_type _CharT, class _Traits, class _Allocator>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<basic_string<_CharT, _Traits, _Allocator>, _CharT>
    : public __formatter_string<_CharT> {
  using _Base = __formatter_string<_CharT>;

  _LIBCPP_HIDE_FROM_ABI auto format(const basic_string<_CharT, _Traits, _Allocator>& __str, auto& __ctx) const
      -> decltype(__ctx.out()) {
    // Drop _Traits and _Allocator to have one std::basic_string formatter.
    return _Base::format(basic_string_view<_CharT>(__str.data(), __str.size()), __ctx);
  }
};

// Formatter std::string_view.
template <__fmt_char_type _CharT, class _Traits>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<basic_string_view<_CharT, _Traits>, _CharT>
    : public __formatter_string<_CharT> {
  using _Base = __formatter_string<_CharT>;

  _LIBCPP_HIDE_FROM_ABI auto format(basic_string_view<_CharT, _Traits> __str, auto& __ctx) const
      -> decltype(__ctx.out()) {
    // Drop _Traits to have one std::basic_string_view formatter.
    return _Base::format(basic_string_view<_CharT>(__str.data(), __str.size()), __ctx);
  }
};

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FORMAT_FORMATTER_STRING_H
