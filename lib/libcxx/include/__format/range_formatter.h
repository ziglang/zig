// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_RANGE_FORMATTER_H
#define _LIBCPP___FORMAT_RANGE_FORMATTER_H

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#include <__algorithm/ranges_copy.h>
#include <__availability>
#include <__chrono/statically_widen.h>
#include <__concepts/same_as.h>
#include <__config>
#include <__format/buffer.h>
#include <__format/concepts.h>
#include <__format/format_args.h>
#include <__format/format_context.h>
#include <__format/format_error.h>
#include <__format/formatter.h>
#include <__format/formatter_output.h>
#include <__format/parser_std_format_spec.h>
#include <__iterator/back_insert_iterator.h>
#include <__ranges/concepts.h>
#include <__ranges/data.h>
#include <__ranges/size.h>
#include <__type_traits/remove_cvref.h>
#include <string_view>

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 20

template <class _Tp, class _CharT = char>
  requires same_as<remove_cvref_t<_Tp>, _Tp> && formattable<_Tp, _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT range_formatter {
  _LIBCPP_HIDE_FROM_ABI constexpr void set_separator(basic_string_view<_CharT> __separator) {
    __separator_ = __separator;
  }
  _LIBCPP_HIDE_FROM_ABI constexpr void
  set_brackets(basic_string_view<_CharT> __opening_bracket, basic_string_view<_CharT> __closing_bracket) {
    __opening_bracket_ = __opening_bracket;
    __closing_bracket_ = __closing_bracket;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr formatter<_Tp, _CharT>& underlying() { return __underlying_; }
  _LIBCPP_HIDE_FROM_ABI constexpr const formatter<_Tp, _CharT>& underlying() const { return __underlying_; }

  template <class _ParseContext>
  _LIBCPP_HIDE_FROM_ABI constexpr typename _ParseContext::iterator parse(_ParseContext& __parse_ctx) {
    const _CharT* __begin = __parser_.__parse(__parse_ctx, __format_spec::__fields_range);
    const _CharT* __end   = __parse_ctx.end();
    if (__begin == __end)
      return __begin;

    // The n field overrides a possible m type, therefore delay applying the
    // effect of n until the type has been procesed.
    bool __clear_brackets = (*__begin == _CharT('n'));
    if (__clear_brackets) {
      ++__begin;
      if (__begin == __end) {
        // Since there is no more data, clear the brackets before returning.
        set_brackets({}, {});
        return __begin;
      }
    }

    __parse_type(__begin, __end);
    if (__clear_brackets)
      set_brackets({}, {});
    if (__begin == __end)
      return __begin;

    bool __has_range_underlying_spec = *__begin == _CharT(':');
    if (__parser_.__type_ != __format_spec::__type::__default) {
      // [format.range.formatter]/6
      //   If the range-type is s or ?s, then there shall be no n option and no
      //   range-underlying-spec.
      if (__clear_brackets) {
        if (__parser_.__type_ == __format_spec::__type::__string)
          std::__throw_format_error("The n option and type s can't be used together");
        std::__throw_format_error("The n option and type ?s can't be used together");
      }
      if (__has_range_underlying_spec) {
        if (__parser_.__type_ == __format_spec::__type::__string)
          std::__throw_format_error("Type s and an underlying format specification can't be used together");
        std::__throw_format_error("Type ?s and an underlying format specification can't be used together");
      }
    } else if (!__has_range_underlying_spec)
      std::__set_debug_format(__underlying_);

    if (__has_range_underlying_spec) {
      // range-underlying-spec:
      //   :  format-spec
      ++__begin;
      if (__begin == __end)
        return __begin;

      __parse_ctx.advance_to(__begin);
      __begin = __underlying_.parse(__parse_ctx);
    }

    if (__begin != __end && *__begin != _CharT('}'))
      std::__throw_format_error("The format-spec should consume the input or end with a '}'");

    return __begin;
  }

  template <ranges::input_range _Rp, class _FormatContext>
    requires formattable<ranges::range_reference_t<_Rp>, _CharT> &&
             same_as<remove_cvref_t<ranges::range_reference_t<_Rp>>, _Tp>
  _LIBCPP_HIDE_FROM_ABI typename _FormatContext::iterator format(_Rp&& __range, _FormatContext& __ctx) const {
    __format_spec::__parsed_specifications<_CharT> __specs = __parser_.__get_parsed_std_specifications(__ctx);

    if (!__specs.__has_width())
      return __format_range(__range, __ctx, __specs);

    // The size of the buffer needed is:
    // - open bracket characters
    // - close bracket character
    // - n elements where every element may have a different size
    // - (n -1) separators
    // The size of the element is hard to predict, knowing the type helps but
    // it depends on the format-spec. As an initial estimate we guess 6
    // characters.
    // Typically both brackets are 1 character and the separator is 2
    // characters. Which means there will be
    //   (n - 1) * 2 + 1 + 1 = n * 2 character
    // So estimate 8 times the range size as buffer.
    std::size_t __capacity_hint = 0;
    if constexpr (std::ranges::sized_range<_Rp>)
      __capacity_hint = 8 * ranges::size(__range);
    __format::__retarget_buffer<_CharT> __buffer{__capacity_hint};
    basic_format_context<typename __format::__retarget_buffer<_CharT>::__iterator, _CharT> __c{
        __buffer.__make_output_iterator(), __ctx};

    __format_range(__range, __c, __specs);

    return __formatter::__write_string_no_precision(__buffer.__view(), __ctx.out(), __specs);
  }

  template <ranges::input_range _Rp, class _FormatContext>
  typename _FormatContext::iterator _LIBCPP_HIDE_FROM_ABI
  __format_range(_Rp&& __range, _FormatContext& __ctx, __format_spec::__parsed_specifications<_CharT> __specs) const {
    if constexpr (same_as<_Tp, _CharT>) {
      switch (__specs.__std_.__type_) {
      case __format_spec::__type::__string:
      case __format_spec::__type::__debug:
        return __format_as_string(__range, __ctx, __specs.__std_.__type_ == __format_spec::__type::__debug);
      default:
        return __format_as_sequence(__range, __ctx);
      }
    } else
      return __format_as_sequence(__range, __ctx);
  }

  template <ranges::input_range _Rp, class _FormatContext>
  _LIBCPP_HIDE_FROM_ABI typename _FormatContext::iterator
  __format_as_string(_Rp&& __range, _FormatContext& __ctx, bool __debug_format) const {
    // When the range is contiguous use a basic_string_view instead to avoid a
    // copy of the underlying data. The basic_string_view formatter
    // specialization is the "basic" string formatter in libc++.
    if constexpr (ranges::contiguous_range<_Rp> && std::ranges::sized_range<_Rp>) {
      std::formatter<basic_string_view<_CharT>, _CharT> __formatter;
      if (__debug_format)
        __formatter.set_debug_format();
      return __formatter.format(
          basic_string_view<_CharT>{
              ranges::data(__range),
              ranges::size(__range),
          },
          __ctx);
    } else {
      std::formatter<basic_string<_CharT>, _CharT> __formatter;
      if (__debug_format)
        __formatter.set_debug_format();
      // P2106's from_range has not been implemented yet. Instead use a simple
      // copy operation.
      // TODO FMT use basic_string's "from_range" constructor.
      // return std::formatter<basic_string<_CharT>, _CharT>{}.format(basic_string<_CharT>{from_range, __range}, __ctx);
      basic_string<_CharT> __str;
      ranges::copy(__range, back_insert_iterator{__str});
      return __formatter.format(__str, __ctx);
    }
  }

  template <ranges::input_range _Rp, class _FormatContext>
  _LIBCPP_HIDE_FROM_ABI typename _FormatContext::iterator
  __format_as_sequence(_Rp&& __range, _FormatContext& __ctx) const {
    __ctx.advance_to(ranges::copy(__opening_bracket_, __ctx.out()).out);
    bool __use_separator = false;
    for (auto&& __e : __range) {
      if (__use_separator)
        __ctx.advance_to(ranges::copy(__separator_, __ctx.out()).out);
      else
        __use_separator = true;

      __ctx.advance_to(__underlying_.format(__e, __ctx));
    }

    return ranges::copy(__closing_bracket_, __ctx.out()).out;
  }

  __format_spec::__parser<_CharT> __parser_{.__alignment_ = __format_spec::__alignment::__left};

private:
  _LIBCPP_HIDE_FROM_ABI constexpr void __parse_type(const _CharT*& __begin, const _CharT* __end) {
    switch (*__begin) {
    case _CharT('m'):
      if constexpr (__fmt_pair_like<_Tp>) {
        set_brackets(_LIBCPP_STATICALLY_WIDEN(_CharT, "{"), _LIBCPP_STATICALLY_WIDEN(_CharT, "}"));
        set_separator(_LIBCPP_STATICALLY_WIDEN(_CharT, ", "));
        ++__begin;
      } else
        std::__throw_format_error("The range-format-spec type m requires two elements for a pair or tuple");
      break;

    case _CharT('s'):
      if constexpr (same_as<_Tp, _CharT>) {
        __parser_.__type_ = __format_spec::__type::__string;
        ++__begin;
      } else
        std::__throw_format_error("The range-format-spec type s requires formatting a character type");
      break;

    case _CharT('?'):
      ++__begin;
      if (__begin == __end || *__begin != _CharT('s'))
        std::__throw_format_error("The format-spec should consume the input or end with a '}'");
      if constexpr (same_as<_Tp, _CharT>) {
        __parser_.__type_ = __format_spec::__type::__debug;
        ++__begin;
      } else
        std::__throw_format_error("The range-format-spec type ?s requires formatting a character type");
    }
  }

  formatter<_Tp, _CharT> __underlying_;
  basic_string_view<_CharT> __separator_       = _LIBCPP_STATICALLY_WIDEN(_CharT, ", ");
  basic_string_view<_CharT> __opening_bracket_ = _LIBCPP_STATICALLY_WIDEN(_CharT, "[");
  basic_string_view<_CharT> __closing_bracket_ = _LIBCPP_STATICALLY_WIDEN(_CharT, "]");
};

#endif //_LIBCPP_STD_VER > 20

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FORMAT_RANGE_FORMATTER_H
