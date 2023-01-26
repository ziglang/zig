// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___CHRONO_FORMATTER_H
#define _LIBCPP___CHRONO_FORMATTER_H

#include <__chrono/calendar.h>
#include <__chrono/convert_to_tm.h>
#include <__chrono/day.h>
#include <__chrono/duration.h>
#include <__chrono/hh_mm_ss.h>
#include <__chrono/month.h>
#include <__chrono/month_weekday.h>
#include <__chrono/monthday.h>
#include <__chrono/ostream.h>
#include <__chrono/parser_std_format_spec.h>
#include <__chrono/statically_widen.h>
#include <__chrono/time_point.h>
#include <__chrono/weekday.h>
#include <__chrono/year.h>
#include <__chrono/year_month.h>
#include <__chrono/year_month_day.h>
#include <__chrono/year_month_weekday.h>
#include <__concepts/arithmetic.h>
#include <__concepts/same_as.h>
#include <__config>
#include <__format/concepts.h>
#include <__format/format_error.h>
#include <__format/format_functions.h>
#include <__format/format_parse_context.h>
#include <__format/formatter.h>
#include <__format/formatter_output.h>
#include <__format/parser_std_format_spec.h>
#include <__memory/addressof.h>
#include <cmath>
#include <ctime>
#include <sstream>
#include <string>
#include <string_view>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17 && !defined(_LIBCPP_HAS_NO_INCOMPLETE_FORMAT)

namespace __formatter {

/// Formats a time based on a tm struct.
///
/// This formatter passes the formatting to time_put which uses strftime. When
/// the value is outside the valid range it's unspecified what strftime will
/// output. For example weekday 8 can print 1 when the day is processed modulo
/// 7 since that handles the Sunday for 0-based weekday. It can also print 8 if
/// 7 is handled as a special case.
///
/// The Standard doesn't specify what to do in this case so the result depends
/// on the result of the underlying code.
///
/// \pre When the (abbreviated) weekday or month name are used, the caller
///      validates whether the value is valid. So the caller handles that
///      requirement of Table 97: Meaning of conversion specifiers
///      [tab:time.format.spec].
///
/// When no chrono-specs are provided it uses the stream formatter.

// For tiny ratios it's not possible to convert a duration to a hh_mm_ss. This
// fails compile-time due to the limited precision of the ratio (64-bit is too
// small). Therefore a duration uses its own conversion.
template <class _CharT, class _Tp>
  requires(chrono::__is_duration<_Tp>::value)
_LIBCPP_HIDE_FROM_ABI void __format_sub_seconds(const _Tp& __value, basic_stringstream<_CharT>& __sstr) {
  __sstr << std::use_facet<numpunct<_CharT>>(__sstr.getloc()).decimal_point();

  auto __fraction = __value - chrono::duration_cast<chrono::seconds>(__value);
  if constexpr (chrono::treat_as_floating_point_v<typename _Tp::rep>)
    // When the floating-point value has digits itself they are ignored based
    // on the wording in [tab:time.format.spec]
    //   If the precision of the input cannot be exactly represented with
    //   seconds, then the format is a decimal floating-point number with a
    //   fixed format and a precision matching that of the precision of the
    //   input (or to a microseconds precision if the conversion to
    //   floating-point decimal seconds cannot be made within 18 fractional
    //   digits).
    //
    // This matches the behaviour of MSVC STL, fmtlib interprets this
    // differently and uses 3 decimals.
    // https://godbolt.org/z/6dsbnW8ba
    std::format_to(std::ostreambuf_iterator<_CharT>{__sstr},
                   _LIBCPP_STATICALLY_WIDEN(_CharT, "{:0{}.0f}"),
                   __fraction.count(),
                   chrono::hh_mm_ss<_Tp>::fractional_width);
  else
    std::format_to(std::ostreambuf_iterator<_CharT>{__sstr},
                   _LIBCPP_STATICALLY_WIDEN(_CharT, "{:0{}}"),
                   __fraction.count(),
                   chrono::hh_mm_ss<_Tp>::fractional_width);
}

template <class _Tp>
consteval bool __use_fraction() {
  if constexpr (chrono::__is_duration<_Tp>::value)
    return chrono::hh_mm_ss<_Tp>::fractional_width;
  else
    return false;
}

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI void __format_year(int __year, basic_stringstream<_CharT>& __sstr) {
  if (__year < 0) {
    __sstr << _CharT('-');
    __year = -__year;
  }

  // TODO FMT Write an issue
  //   If the result has less than four digits it is zero-padded with 0 to two digits.
  // is less -> has less
  // left-padded -> zero-padded, otherwise the proper value would be 000-0.

  // Note according to the wording it should be left padded, which is odd.
  __sstr << std::format(_LIBCPP_STATICALLY_WIDEN(_CharT, "{:04}"), __year);
}

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI void __format_century(int __year, basic_stringstream<_CharT>& __sstr) {
  // TODO FMT Write an issue
  // [tab:time.format.spec]
  //   %C The year divided by 100 using floored division. If the result is a
  //   single decimal digit, it is prefixed with 0.

  bool __negative = __year < 0;
  int __century   = (__year - (99 * __negative)) / 100; // floored division
  __sstr << std::format(_LIBCPP_STATICALLY_WIDEN(_CharT, "{:02}"), __century);
}

template <class _CharT, class _Tp>
_LIBCPP_HIDE_FROM_ABI void __format_chrono_using_chrono_specs(
    const _Tp& __value, basic_stringstream<_CharT>& __sstr, basic_string_view<_CharT> __chrono_specs) {
  tm __t              = std::__convert_to_tm<tm>(__value);
  const auto& __facet = std::use_facet<time_put<_CharT>>(__sstr.getloc());
  for (auto __it = __chrono_specs.begin(); __it != __chrono_specs.end(); ++__it) {
    if (*__it == _CharT('%')) {
      auto __s = __it;
      ++__it;
      // We only handle the types that can't be directly handled by time_put.
      // (as an optimization n, t, and % are also handled directly.)
      switch (*__it) {
      case _CharT('n'):
        __sstr << _CharT('\n');
        break;
      case _CharT('t'):
        __sstr << _CharT('\t');
        break;
      case _CharT('%'):
        __sstr << *__it;
        break;

      case _CharT('C'): {
        // strftime's output is only defined in the range [00, 99].
        int __year = __t.tm_year + 1900;
        if (__year < 1000 || __year > 9999)
          __formatter::__format_century(__year, __sstr);
        else
          __facet.put({__sstr}, __sstr, _CharT(' '), std::addressof(__t), __s, __it + 1);
      } break;

      case _CharT('j'):
        if constexpr (chrono::__is_duration<_Tp>::value)
          // Converting a duration where the period has a small ratio to days
          // may fail to compile. This due to loss of precision in the
          // conversion. In order to avoid that issue convert to seconds as
          // an intemediate step.
          __sstr << chrono::duration_cast<chrono::days>(chrono::duration_cast<chrono::seconds>(__value)).count();
        else
          __facet.put({__sstr}, __sstr, _CharT(' '), std::addressof(__t), __s, __it + 1);
        break;

      case _CharT('q'):
        if constexpr (chrono::__is_duration<_Tp>::value) {
          __sstr << chrono::__units_suffix<_CharT, typename _Tp::period>();
          break;
        }
        __builtin_unreachable();

      case _CharT('Q'):
        // TODO FMT Determine the proper ideas
        // - Should it honour the precision?
        // - Shoult it honour the locale setting for the separators?
        // The wording for Q doesn't use the word locale and the effect of
        // precision is unspecified.
        //
        // MSVC STL ignores precision but uses separator
        // FMT honours precision and has a bug for separator
        // https://godbolt.org/z/78b7sMxns
        if constexpr (chrono::__is_duration<_Tp>::value) {
          __sstr << std::format(_LIBCPP_STATICALLY_WIDEN(_CharT, "{}"), __value.count());
          break;
        }
        __builtin_unreachable();

      case _CharT('S'):
      case _CharT('T'):
        __facet.put({__sstr}, __sstr, _CharT(' '), std::addressof(__t), __s, __it + 1);
        if constexpr (__use_fraction<_Tp>())
          __formatter::__format_sub_seconds(__value, __sstr);
        break;

        // Unlike time_put and strftime the formatting library requires %Y
        //
        // [tab:time.format.spec]
        //   The year as a decimal number. If the result is less than four digits
        //   it is left-padded with 0 to four digits.
        //
        // This means years in the range (-1000, 1000) need manual formatting.
        // It's unclear whether %EY needs the same treatment. For example the
        // Japanese EY contains the era name and year. This is zero-padded to 2
        // digits in time_put (note that older glibc versions didn't do
        // padding.) However most eras won't reach 100 years, let alone 1000.
        // So padding to 4 digits seems unwanted for Japanese.
        //
        // The same applies to %Ex since that too depends on the era.
        //
        // %x the locale's date representation is currently doesn't handle the
        // zero-padding too.
        //
        // The 4 digits can be implemented better at a later time. On POSIX
        // systems the required information can be extracted by nl_langinfo
        // https://man7.org/linux/man-pages/man3/nl_langinfo.3.html
        //
        // Note since year < -1000 is expected to be rare it uses the more
        // expensive year routine.
        //
        // TODO FMT evaluate the comment above.

#  if defined(__GLIBC__) || defined(_AIX)
      case _CharT('y'):
        // Glibc fails for negative values, AIX for positive values too.
        __sstr << std::format(_LIBCPP_STATICALLY_WIDEN(_CharT, "{:02}"), (std::abs(__t.tm_year + 1900)) % 100);
        break;
#  endif // defined(__GLIBC__) || defined(_AIX)

      case _CharT('Y'): {
        int __year = __t.tm_year + 1900;
        if (__year < 1000)
          __formatter::__format_year(__year, __sstr);
        else
          __facet.put({__sstr}, __sstr, _CharT(' '), std::addressof(__t), __s, __it + 1);
      } break;

      case _CharT('F'): {
        int __year = __t.tm_year + 1900;
        if (__year < 1000) {
          __formatter::__format_year(__year, __sstr);
          __sstr << std::format(_LIBCPP_STATICALLY_WIDEN(_CharT, "-{:02}-{:02}"), __t.tm_mon + 1, __t.tm_mday);
        } else
          __facet.put({__sstr}, __sstr, _CharT(' '), std::addressof(__t), __s, __it + 1);
      } break;

      case _CharT('O'):
        if constexpr (__use_fraction<_Tp>()) {
          // Handle OS using the normal representation for the non-fractional
          // part. There seems to be no locale information regarding how the
          // fractional part should be formatted.
          if (*(__it + 1) == 'S') {
            ++__it;
            __facet.put({__sstr}, __sstr, _CharT(' '), std::addressof(__t), __s, __it + 1);
            __formatter::__format_sub_seconds(__value, __sstr);
            break;
          }
        }
        [[fallthrough]];
      case _CharT('E'):
        ++__it;
        [[fallthrough]];
      default:
        __facet.put({__sstr}, __sstr, _CharT(' '), std::addressof(__t), __s, __it + 1);
        break;
      }
    } else {
      __sstr << *__it;
    }
  }
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI constexpr bool __weekday_ok(const _Tp& __value) {
  if constexpr (same_as<_Tp, chrono::day>)
    return true;
  else if constexpr (same_as<_Tp, chrono::month>)
    return __value.ok();
  else if constexpr (same_as<_Tp, chrono::year>)
    return true;
  else if constexpr (same_as<_Tp, chrono::weekday>)
    return true;
  else if constexpr (same_as<_Tp, chrono::weekday_indexed>)
    return true;
  else if constexpr (same_as<_Tp, chrono::weekday_last>)
    return true;
  else if constexpr (same_as<_Tp, chrono::month_day>)
    return true;
  else if constexpr (same_as<_Tp, chrono::month_day_last>)
    return true;
  else if constexpr (same_as<_Tp, chrono::month_weekday>)
    return true;
  else if constexpr (same_as<_Tp, chrono::month_weekday_last>)
    return true;
  else if constexpr (same_as<_Tp, chrono::year_month>)
    return true;
  else if constexpr (same_as<_Tp, chrono::year_month_day>)
    return __value.ok();
  else if constexpr (same_as<_Tp, chrono::year_month_day_last>)
    return __value.ok();
  else if constexpr (same_as<_Tp, chrono::year_month_weekday>)
    return __value.weekday().ok();
  else if constexpr (same_as<_Tp, chrono::year_month_weekday_last>)
    return __value.weekday().ok();
  else
    static_assert(sizeof(_Tp) == 0, "Add the missing type specialization");
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI constexpr bool __weekday_name_ok(const _Tp& __value) {
  if constexpr (same_as<_Tp, chrono::day>)
    return true;
  else if constexpr (same_as<_Tp, chrono::month>)
    return __value.ok();
  else if constexpr (same_as<_Tp, chrono::year>)
    return true;
  else if constexpr (same_as<_Tp, chrono::weekday>)
    return __value.ok();
  else if constexpr (same_as<_Tp, chrono::weekday_indexed>)
    return __value.weekday().ok();
  else if constexpr (same_as<_Tp, chrono::weekday_last>)
    return __value.weekday().ok();
  else if constexpr (same_as<_Tp, chrono::month_day>)
    return true;
  else if constexpr (same_as<_Tp, chrono::month_day_last>)
    return true;
  else if constexpr (same_as<_Tp, chrono::month_weekday>)
    return __value.weekday_indexed().ok();
  else if constexpr (same_as<_Tp, chrono::month_weekday_last>)
    return __value.weekday_indexed().ok();
  else if constexpr (same_as<_Tp, chrono::year_month>)
    return true;
  else if constexpr (same_as<_Tp, chrono::year_month_day>)
    return __value.ok();
  else if constexpr (same_as<_Tp, chrono::year_month_day_last>)
    return __value.ok();
  else if constexpr (same_as<_Tp, chrono::year_month_weekday>)
    return __value.weekday().ok();
  else if constexpr (same_as<_Tp, chrono::year_month_weekday_last>)
    return __value.weekday().ok();
  else
    static_assert(sizeof(_Tp) == 0, "Add the missing type specialization");
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI constexpr bool __date_ok(const _Tp& __value) {
  if constexpr (same_as<_Tp, chrono::day>)
    return true;
  else if constexpr (same_as<_Tp, chrono::month>)
    return __value.ok();
  else if constexpr (same_as<_Tp, chrono::year>)
    return true;
  else if constexpr (same_as<_Tp, chrono::weekday>)
    return true;
  else if constexpr (same_as<_Tp, chrono::weekday_indexed>)
    return true;
  else if constexpr (same_as<_Tp, chrono::weekday_last>)
    return true;
  else if constexpr (same_as<_Tp, chrono::month_day>)
    return true;
  else if constexpr (same_as<_Tp, chrono::month_day_last>)
    return true;
  else if constexpr (same_as<_Tp, chrono::month_weekday>)
    return true;
  else if constexpr (same_as<_Tp, chrono::month_weekday_last>)
    return true;
  else if constexpr (same_as<_Tp, chrono::year_month>)
    return true;
  else if constexpr (same_as<_Tp, chrono::year_month_day>)
    return __value.ok();
  else if constexpr (same_as<_Tp, chrono::year_month_day_last>)
    return __value.ok();
  else if constexpr (same_as<_Tp, chrono::year_month_weekday>)
    return __value.ok();
  else if constexpr (same_as<_Tp, chrono::year_month_weekday_last>)
    return __value.ok();
  else
    static_assert(sizeof(_Tp) == 0, "Add the missing type specialization");
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI constexpr bool __month_name_ok(const _Tp& __value) {
  if constexpr (same_as<_Tp, chrono::day>)
    return true;
  else if constexpr (same_as<_Tp, chrono::month>)
    return __value.ok();
  else if constexpr (same_as<_Tp, chrono::year>)
    return true;
  else if constexpr (same_as<_Tp, chrono::weekday>)
    return true;
  else if constexpr (same_as<_Tp, chrono::weekday_indexed>)
    return true;
  else if constexpr (same_as<_Tp, chrono::weekday_last>)
    return true;
  else if constexpr (same_as<_Tp, chrono::month_day>)
    return __value.month().ok();
  else if constexpr (same_as<_Tp, chrono::month_day_last>)
    return __value.month().ok();
  else if constexpr (same_as<_Tp, chrono::month_weekday>)
    return __value.month().ok();
  else if constexpr (same_as<_Tp, chrono::month_weekday_last>)
    return __value.month().ok();
  else if constexpr (same_as<_Tp, chrono::year_month>)
    return __value.month().ok();
  else if constexpr (same_as<_Tp, chrono::year_month_day>)
    return __value.month().ok();
  else if constexpr (same_as<_Tp, chrono::year_month_day_last>)
    return __value.month().ok();
  else if constexpr (same_as<_Tp, chrono::year_month_weekday>)
    return __value.month().ok();
  else if constexpr (same_as<_Tp, chrono::year_month_weekday_last>)
    return __value.month().ok();
  else
    static_assert(sizeof(_Tp) == 0, "Add the missing type specialization");
}

template <class _CharT, class _Tp>
_LIBCPP_HIDE_FROM_ABI auto
__format_chrono(const _Tp& __value,
                auto& __ctx,
                __format_spec::__parsed_specifications<_CharT> __specs,
                basic_string_view<_CharT> __chrono_specs) -> decltype(__ctx.out()) {
  basic_stringstream<_CharT> __sstr;
  // [time.format]/2
  // 2.1 - the "C" locale if the L option is not present in chrono-format-spec, otherwise
  // 2.2 - the locale passed to the formatting function if any, otherwise
  // 2.3 - the global locale.
  // Note that the __ctx's locale() call does 2.2 and 2.3.
  if (__specs.__chrono_.__locale_specific_form_)
    __sstr.imbue(__ctx.locale());
  else
    __sstr.imbue(locale::classic());

  if (__chrono_specs.empty())
    __sstr << __value;
  else {
    if constexpr (chrono::__is_duration<_Tp>::value) {
      if (__value < __value.zero())
        __sstr << _CharT('-');
      __formatter::__format_chrono_using_chrono_specs(chrono::abs(__value), __sstr, __chrono_specs);
      // TODO FMT When keeping the precision it will truncate the string.
      // Note that the behaviour what the precision does isn't specified.
      __specs.__precision_ = -1;
    } else {
      // Test __weekday_name_ before __weekday_ to give a better error.
      if (__specs.__chrono_.__weekday_name_ && !__formatter::__weekday_name_ok(__value))
        std::__throw_format_error("formatting a weekday name needs a valid weekday");

      if (__specs.__chrono_.__weekday_ && !__formatter::__weekday_ok(__value))
        std::__throw_format_error("formatting a weekday needs a valid weekday");

      if (__specs.__chrono_.__day_of_year_ && !__formatter::__date_ok(__value))
        std::__throw_format_error("formatting a day of year needs a valid date");

      if (__specs.__chrono_.__week_of_year_ && !__formatter::__date_ok(__value))
        std::__throw_format_error("formatting a week of year needs a valid date");

      if (__specs.__chrono_.__month_name_ && !__formatter::__month_name_ok(__value))
        std::__throw_format_error("formatting a month name from an invalid month number");

      __formatter::__format_chrono_using_chrono_specs(__value, __sstr, __chrono_specs);
    }
  }

  // TODO FMT Use the stringstream's view after P0408R7 has been implemented.
  basic_string<_CharT> __str = __sstr.str();
  return __formatter::__write_string(basic_string_view<_CharT>{__str}, __ctx.out(), __specs);
}

} // namespace __formatter

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT __formatter_chrono {
public:
  _LIBCPP_HIDE_FROM_ABI constexpr auto __parse(
      basic_format_parse_context<_CharT>& __parse_ctx, __format_spec::__fields __fields, __format_spec::__flags __flags)
      -> decltype(__parse_ctx.begin()) {
    return __parser_.__parse(__parse_ctx, __fields, __flags);
  }

  template <class _Tp>
  _LIBCPP_HIDE_FROM_ABI auto format(const _Tp& __value, auto& __ctx) const -> decltype(__ctx.out()) const {
    return __formatter::__format_chrono(
        __value, __ctx, __parser_.__parser_.__get_parsed_chrono_specifications(__ctx), __parser_.__chrono_specs_);
  }

  __format_spec::__parser_chrono<_CharT> __parser_;
};

template <class _Rep, class _Period, __fmt_char_type _CharT>
struct formatter<chrono::duration<_Rep, _Period>, _CharT> : public __formatter_chrono<_CharT> {
public:
  using _Base = __formatter_chrono<_CharT>;

  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    // [time.format]/1
    // Giving a precision specification in the chrono-format-spec is valid only
    // for std::chrono::duration types where the representation type Rep is a
    // floating-point type. For all other Rep types, an exception of type
    // format_error is thrown if the chrono-format-spec contains a precision
    // specification.
    //
    // Note this doesn't refer to chrono::treat_as_floating_point_v<_Rep>.
    if constexpr (std::floating_point<_Rep>)
      return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono_fractional, __format_spec::__flags::__duration);
    else
      return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono, __format_spec::__flags::__duration);
  }
};

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<chrono::day, _CharT>
    : public __formatter_chrono<_CharT> {
public:
  using _Base = __formatter_chrono<_CharT>;

  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono, __format_spec::__flags::__day);
  }
};

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<chrono::month, _CharT>
    : public __formatter_chrono<_CharT> {
public:
  using _Base = __formatter_chrono<_CharT>;

  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono, __format_spec::__flags::__month);
  }
};

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<chrono::year, _CharT>
    : public __formatter_chrono<_CharT> {
public:
  using _Base = __formatter_chrono<_CharT>;

  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono, __format_spec::__flags::__year);
  }
};

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<chrono::weekday, _CharT>
    : public __formatter_chrono<_CharT> {
public:
  using _Base = __formatter_chrono<_CharT>;

  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono, __format_spec::__flags::__weekday);
  }
};

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<chrono::weekday_indexed, _CharT>
    : public __formatter_chrono<_CharT> {
public:
  using _Base = __formatter_chrono<_CharT>;

  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono, __format_spec::__flags::__weekday);
  }
};

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<chrono::weekday_last, _CharT>
    : public __formatter_chrono<_CharT> {
public:
  using _Base = __formatter_chrono<_CharT>;

  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono, __format_spec::__flags::__weekday);
  }
};

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<chrono::month_day, _CharT>
    : public __formatter_chrono<_CharT> {
public:
  using _Base = __formatter_chrono<_CharT>;

  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono, __format_spec::__flags::__month_day);
  }
};

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<chrono::month_day_last, _CharT>
    : public __formatter_chrono<_CharT> {
public:
  using _Base = __formatter_chrono<_CharT>;

  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono, __format_spec::__flags::__month);
  }
};

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<chrono::month_weekday, _CharT>
    : public __formatter_chrono<_CharT> {
public:
  using _Base = __formatter_chrono<_CharT>;

  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono, __format_spec::__flags::__month_weekday);
  }
};

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<chrono::month_weekday_last, _CharT>
    : public __formatter_chrono<_CharT> {
public:
  using _Base = __formatter_chrono<_CharT>;

  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono, __format_spec::__flags::__month_weekday);
  }
};

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<chrono::year_month, _CharT>
    : public __formatter_chrono<_CharT> {
public:
  using _Base = __formatter_chrono<_CharT>;

  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono, __format_spec::__flags::__year_month);
  }
};

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<chrono::year_month_day, _CharT>
    : public __formatter_chrono<_CharT> {
public:
  using _Base = __formatter_chrono<_CharT>;

  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono, __format_spec::__flags::__date);
  }
};

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<chrono::year_month_day_last, _CharT>
    : public __formatter_chrono<_CharT> {
public:
  using _Base = __formatter_chrono<_CharT>;

  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono, __format_spec::__flags::__date);
  }
};

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<chrono::year_month_weekday, _CharT>
    : public __formatter_chrono<_CharT> {
public:
  using _Base = __formatter_chrono<_CharT>;

  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono, __format_spec::__flags::__date);
  }
};

template <__fmt_char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<chrono::year_month_weekday_last, _CharT>
    : public __formatter_chrono<_CharT> {
public:
  using _Base = __formatter_chrono<_CharT>;

  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(basic_format_parse_context<_CharT>& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    return _Base::__parse(__parse_ctx, __format_spec::__fields_chrono, __format_spec::__flags::__date);
  }
};

#endif // if _LIBCPP_STD_VER > 17 && !defined(_LIBCPP_HAS_NO_INCOMPLETE_FORMAT)

_LIBCPP_END_NAMESPACE_STD

#endif //  _LIBCPP___CHRONO_FORMATTER_H
