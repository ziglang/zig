// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMATTER_TUPLE_H
#define _LIBCPP___FORMAT_FORMATTER_TUPLE_H

#include <__algorithm/ranges_copy.h>
#include <__availability>
#include <__chrono/statically_widen.h>
#include <__config>
#include <__format/concepts.h>
#include <__format/format_args.h>
#include <__format/format_context.h>
#include <__format/format_error.h>
#include <__format/format_parse_context.h>
#include <__format/formatter.h>
#include <__format/formatter_output.h>
#include <__format/parser_std_format_spec.h>
#include <__iterator/back_insert_iterator.h>
#include <__type_traits/remove_cvref.h>
#include <__utility/integer_sequence.h>
#include <__utility/pair.h>
#include <string_view>
#include <tuple>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 20

template <__fmt_char_type _CharT, class _Tuple, formattable<_CharT>... _Args>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT __formatter_tuple {
  _LIBCPP_HIDE_FROM_ABI constexpr void set_separator(basic_string_view<_CharT> __separator) {
    __separator_ = __separator;
  }
  _LIBCPP_HIDE_FROM_ABI constexpr void
  set_brackets(basic_string_view<_CharT> __opening_bracket, basic_string_view<_CharT> __closing_bracket) {
    __opening_bracket_ = __opening_bracket;
    __closing_bracket_ = __closing_bracket;
  }

  template <class _ParseContext>
  _LIBCPP_HIDE_FROM_ABI constexpr typename _ParseContext::iterator parse(_ParseContext& __parse_ctx) {
    const _CharT* __begin = __parser_.__parse(__parse_ctx, __format_spec::__fields_tuple);

    // [format.tuple]/7
    //   ... For each element e in underlying_, if e.set_debug_format()
    //   is a valid expression, calls e.set_debug_format().
    // TODO FMT this can be removed when P2733 is accepted.
    std::__for_each_index_sequence(make_index_sequence<sizeof...(_Args)>(), [&]<size_t _Index> {
      std::__set_debug_format(std::get<_Index>(__underlying_));
    });

    const _CharT* __end = __parse_ctx.end();
    if (__begin == __end)
      return __begin;

    if (*__begin == _CharT('m')) {
      if constexpr (sizeof...(_Args) == 2) {
        set_separator(_LIBCPP_STATICALLY_WIDEN(_CharT, ": "));
        set_brackets({}, {});
        ++__begin;
      } else
        std::__throw_format_error("The format specifier m requires a pair or a two-element tuple");
    } else if (*__begin == _CharT('n')) {
      set_brackets({}, {});
      ++__begin;
    }

    if (__begin != __end && *__begin != _CharT('}'))
      std::__throw_format_error("The format-spec should consume the input or end with a '}'");

    return __begin;
  }

  template <class _FormatContext>
  typename _FormatContext::iterator _LIBCPP_HIDE_FROM_ABI
  format(conditional_t<(formattable<const _Args, _CharT> && ...), const _Tuple&, _Tuple&> __tuple,
         _FormatContext& __ctx) const {
    __format_spec::__parsed_specifications<_CharT> __specs = __parser_.__get_parsed_std_specifications(__ctx);

    if (!__specs.__has_width())
      return __format_tuple(__tuple, __ctx);

    basic_string<_CharT> __str;

    // Since the output is written to a different iterator a new context is
    // created. Since the underlying formatter uses the default formatting it
    // doesn't need a locale or the formatting arguments. So creating a new
    // context works.
    //
    // This solution works for this formatter, but it will not work for the
    // range_formatter. In that patch a generic solution is work in progress.
    // Once that is finished it can be used here. (The range_formatter will use
    // these features so it's easier to add it there and then port it.)
    //
    // TODO FMT Use formatting wrapping used in the range_formatter.
    basic_format_context __c = std::__format_context_create(
        back_insert_iterator{__str},
        basic_format_args<basic_format_context<back_insert_iterator<basic_string<_CharT>>, _CharT>>{});

    __format_tuple(__tuple, __c);

    return __formatter::__write_string_no_precision(basic_string_view{__str}, __ctx.out(), __specs);
  }

  template <class _FormatContext>
  _LIBCPP_HIDE_FROM_ABI typename _FormatContext::iterator __format_tuple(auto&& __tuple, _FormatContext& __ctx) const {
    __ctx.advance_to(std::ranges::copy(__opening_bracket_, __ctx.out()).out);

    std::__for_each_index_sequence(make_index_sequence<sizeof...(_Args)>(), [&]<size_t _Index> {
      if constexpr (_Index)
        __ctx.advance_to(std::ranges::copy(__separator_, __ctx.out()).out);

        // During review Victor suggested to make the exposition only
        // __underlying_ member a local variable. Currently the Standard
        // requires nested debug-enabled formatter specializations not to
        // output escaped output. P2733 fixes that bug, once accepted the
        // code below can be used.
        // (Note when a paper allows parsing a tuple-underlying-spec the
        // exposition only member needs to be a class member. Earlier
        // revisions of P2286 proposed that, but this was not pursued,
        // due to time constrains and complexity of the matter.)
        // TODO FMT This can be updated after P2733 is accepted.
#  if 0
      // P2286 uses an exposition only member in the formatter
      //   tuple<formatter<remove_cvref_t<_Args>, _CharT>...> __underlying_;
      // This was used in earlier versions of the paper since
      // __underlying_.parse(...) was called. This is no longer the case
      // so we can reduce the scope of the formatter.
      //
      // It does require the underlying's parse effect to be moved here too.
      using _Arg = tuple_element<_Index, decltype(__tuple)>;
      formatter<remove_cvref_t<_Args>, _CharT> __underlying;

      // [format.tuple]/7
      //   ... For each element e in underlying_, if e.set_debug_format()
      //   is a valid expression, calls e.set_debug_format().
      std::__set_debug_format(__underlying);
#  else
      __ctx.advance_to(std::get<_Index>(__underlying_).format(std::get<_Index>(__tuple), __ctx));
#  endif
    });

    return std::ranges::copy(__closing_bracket_, __ctx.out()).out;
  }

  __format_spec::__parser<_CharT> __parser_{.__alignment_ = __format_spec::__alignment::__left};

private:
  tuple<formatter<remove_cvref_t<_Args>, _CharT>...> __underlying_;
  basic_string_view<_CharT> __separator_       = _LIBCPP_STATICALLY_WIDEN(_CharT, ", ");
  basic_string_view<_CharT> __opening_bracket_ = _LIBCPP_STATICALLY_WIDEN(_CharT, "(");
  basic_string_view<_CharT> __closing_bracket_ = _LIBCPP_STATICALLY_WIDEN(_CharT, ")");
};

template <__fmt_char_type _CharT, formattable<_CharT>... _Args>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<pair<_Args...>, _CharT>
    : public __formatter_tuple<_CharT, pair<_Args...>, _Args...> {};

template <__fmt_char_type _CharT, formattable<_CharT>... _Args>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<tuple<_Args...>, _CharT>
    : public __formatter_tuple<_CharT, tuple<_Args...>, _Args...> {};

#endif //_LIBCPP_STD_VER > 20

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FORMAT_FORMATTER_TUPLE_H
