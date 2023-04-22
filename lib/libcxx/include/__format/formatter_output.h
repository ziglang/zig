// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMATTER_OUTPUT_H
#define _LIBCPP___FORMAT_FORMATTER_OUTPUT_H

#include <__algorithm/ranges_copy.h>
#include <__algorithm/ranges_fill_n.h>
#include <__algorithm/ranges_transform.h>
#include <__chrono/statically_widen.h>
#include <__concepts/same_as.h>
#include <__config>
#include <__format/buffer.h>
#include <__format/concepts.h>
#include <__format/escaped_output_table.h>
#include <__format/formatter.h>
#include <__format/parser_std_format_spec.h>
#include <__format/unicode.h>
#include <__iterator/back_insert_iterator.h>
#include <__type_traits/make_unsigned.h>
#include <__utility/move.h>
#include <__utility/unreachable.h>
#include <charconv>
#include <cstddef>
#include <string>
#include <string_view>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

namespace __formatter {

_LIBCPP_HIDE_FROM_ABI constexpr char __hex_to_upper(char __c) {
  switch (__c) {
  case 'a':
    return 'A';
  case 'b':
    return 'B';
  case 'c':
    return 'C';
  case 'd':
    return 'D';
  case 'e':
    return 'E';
  case 'f':
    return 'F';
  }
  return __c;
}

struct _LIBCPP_TYPE_VIS __padding_size_result {
  size_t __before_;
  size_t __after_;
};

_LIBCPP_HIDE_FROM_ABI constexpr __padding_size_result
__padding_size(size_t __size, size_t __width, __format_spec::__alignment __align) {
  _LIBCPP_ASSERT(__width > __size, "don't call this function when no padding is required");
  _LIBCPP_ASSERT(
      __align != __format_spec::__alignment::__zero_padding, "the caller should have handled the zero-padding");

  size_t __fill = __width - __size;
  switch (__align) {
  case __format_spec::__alignment::__zero_padding:
    __libcpp_unreachable();

  case __format_spec::__alignment::__left:
    return {0, __fill};

  case __format_spec::__alignment::__center: {
    // The extra padding is divided per [format.string.std]/3
    // __before = floor(__fill, 2);
    // __after = ceil(__fill, 2);
    size_t __before = __fill / 2;
    size_t __after  = __fill - __before;
    return {__before, __after};
  }
  case __format_spec::__alignment::__default:
  case __format_spec::__alignment::__right:
    return {__fill, 0};
  }
  __libcpp_unreachable();
}

/// Copy wrapper.
///
/// This uses a "mass output function" of __format::__output_buffer when possible.
template <__fmt_char_type _CharT, __fmt_char_type _OutCharT = _CharT>
_LIBCPP_HIDE_FROM_ABI auto __copy(basic_string_view<_CharT> __str, output_iterator<const _OutCharT&> auto __out_it)
    -> decltype(__out_it) {
  if constexpr (_VSTD::same_as<decltype(__out_it), _VSTD::back_insert_iterator<__format::__output_buffer<_OutCharT>>>) {
    __out_it.__get_container()->__copy(__str);
    return __out_it;
  } else if constexpr (_VSTD::same_as<decltype(__out_it),
                                      typename __format::__retarget_buffer<_OutCharT>::__iterator>) {
    __out_it.__buffer_->__copy(__str);
    return __out_it;
  } else {
    return std::ranges::copy(__str, _VSTD::move(__out_it)).out;
  }
}

template <__fmt_char_type _CharT, __fmt_char_type _OutCharT = _CharT>
_LIBCPP_HIDE_FROM_ABI auto
__copy(const _CharT* __first, const _CharT* __last, output_iterator<const _OutCharT&> auto __out_it)
    -> decltype(__out_it) {
  return __formatter::__copy(basic_string_view{__first, __last}, _VSTD::move(__out_it));
}

template <__fmt_char_type _CharT, __fmt_char_type _OutCharT = _CharT>
_LIBCPP_HIDE_FROM_ABI auto __copy(const _CharT* __first, size_t __n, output_iterator<const _OutCharT&> auto __out_it)
    -> decltype(__out_it) {
  return __formatter::__copy(basic_string_view{__first, __n}, _VSTD::move(__out_it));
}

/// Transform wrapper.
///
/// This uses a "mass output function" of __format::__output_buffer when possible.
template <__fmt_char_type _CharT, __fmt_char_type _OutCharT = _CharT, class _UnaryOperation>
_LIBCPP_HIDE_FROM_ABI auto
__transform(const _CharT* __first,
            const _CharT* __last,
            output_iterator<const _OutCharT&> auto __out_it,
            _UnaryOperation __operation) -> decltype(__out_it) {
  if constexpr (_VSTD::same_as<decltype(__out_it), _VSTD::back_insert_iterator<__format::__output_buffer<_OutCharT>>>) {
    __out_it.__get_container()->__transform(__first, __last, _VSTD::move(__operation));
    return __out_it;
  } else if constexpr (_VSTD::same_as<decltype(__out_it),
                                      typename __format::__retarget_buffer<_OutCharT>::__iterator>) {
    __out_it.__buffer_->__transform(__first, __last, _VSTD::move(__operation));
    return __out_it;
  } else {
    return std::ranges::transform(__first, __last, _VSTD::move(__out_it), __operation).out;
  }
}

/// Fill wrapper.
///
/// This uses a "mass output function" of __format::__output_buffer when possible.
template <__fmt_char_type _CharT, output_iterator<const _CharT&> _OutIt>
_LIBCPP_HIDE_FROM_ABI _OutIt __fill(_OutIt __out_it, size_t __n, _CharT __value) {
  if constexpr (_VSTD::same_as<decltype(__out_it), _VSTD::back_insert_iterator<__format::__output_buffer<_CharT>>>) {
    __out_it.__get_container()->__fill(__n, __value);
    return __out_it;
  } else if constexpr (_VSTD::same_as<decltype(__out_it), typename __format::__retarget_buffer<_CharT>::__iterator>) {
    __out_it.__buffer_->__fill(__n, __value);
    return __out_it;
  } else {
    return std::ranges::fill_n(_VSTD::move(__out_it), __n, __value);
  }
}

template <class _OutIt, class _CharT>
_LIBCPP_HIDE_FROM_ABI _OutIt __write_using_decimal_separators(_OutIt __out_it, const char* __begin, const char* __first,
                                                              const char* __last, string&& __grouping, _CharT __sep,
                                                              __format_spec::__parsed_specifications<_CharT> __specs) {
  int __size = (__first - __begin) +    // [sign][prefix]
               (__last - __first) +     // data
               (__grouping.size() - 1); // number of separator characters

  __padding_size_result __padding = {0, 0};
  if (__specs.__alignment_ == __format_spec::__alignment::__zero_padding) {
    // Write [sign][prefix].
    __out_it = __formatter::__copy(__begin, __first, _VSTD::move(__out_it));

    if (__specs.__width_ > __size) {
      // Write zero padding.
      __padding.__before_ = __specs.__width_ - __size;
      __out_it            = __formatter::__fill(_VSTD::move(__out_it), __specs.__width_ - __size, _CharT('0'));
    }
  } else {
    if (__specs.__width_ > __size) {
      // Determine padding and write padding.
      __padding = __formatter::__padding_size(__size, __specs.__width_, __specs.__alignment_);

      __out_it = __formatter::__fill(_VSTD::move(__out_it), __padding.__before_, __specs.__fill_);
    }
    // Write [sign][prefix].
    __out_it = __formatter::__copy(__begin, __first, _VSTD::move(__out_it));
  }

  auto __r = __grouping.rbegin();
  auto __e = __grouping.rend() - 1;
  _LIBCPP_ASSERT(__r != __e, "The slow grouping formatting is used while "
                             "there will be no separators written.");
  // The output is divided in small groups of numbers to write:
  // - A group before the first separator.
  // - A separator and a group, repeated for the number of separators.
  // - A group after the last separator.
  // This loop achieves that process by testing the termination condition
  // midway in the loop.
  //
  // TODO FMT This loop evaluates the loop invariant `__parser.__type !=
  // _Flags::_Type::__hexadecimal_upper_case` for every iteration. (This test
  // happens in the __write call.) Benchmark whether making two loops and
  // hoisting the invariant is worth the effort.
  while (true) {
    if (__specs.__std_.__type_ == __format_spec::__type::__hexadecimal_upper_case) {
      __last = __first + *__r;
      __out_it = __formatter::__transform(__first, __last, _VSTD::move(__out_it), __hex_to_upper);
      __first = __last;
    } else {
      __out_it = __formatter::__copy(__first, *__r, _VSTD::move(__out_it));
      __first += *__r;
    }

    if (__r == __e)
      break;

    ++__r;
    *__out_it++ = __sep;
  }

  return __formatter::__fill(_VSTD::move(__out_it), __padding.__after_, __specs.__fill_);
}

/// Writes the input to the output with the required padding.
///
/// Since the output column width is specified the function can be used for
/// ASCII and Unicode output.
///
/// \pre \a __size <= \a __width. Using this function when this pre-condition
///      doesn't hold incurs an unwanted overhead.
///
/// \param __str       The string to write.
/// \param __out_it    The output iterator to write to.
/// \param __specs     The parsed formatting specifications.
/// \param __size      The (estimated) output column width. When the elements
///                    to be written are ASCII the following condition holds
///                    \a __size == \a __last - \a __first.
///
/// \returns           An iterator pointing beyond the last element written.
///
/// \note The type of the elements in range [\a __first, \a __last) can differ
/// from the type of \a __specs. Integer output uses \c std::to_chars for its
/// conversion, which means the [\a __first, \a __last) always contains elements
/// of the type \c char.
template <class _CharT, class _ParserCharT>
_LIBCPP_HIDE_FROM_ABI auto
__write(basic_string_view<_CharT> __str,
        output_iterator<const _CharT&> auto __out_it,
        __format_spec::__parsed_specifications<_ParserCharT> __specs,
        ptrdiff_t __size) -> decltype(__out_it) {
  if (__size >= __specs.__width_)
    return __formatter::__copy(__str, _VSTD::move(__out_it));

  __padding_size_result __padding = __formatter::__padding_size(__size, __specs.__width_, __specs.__std_.__alignment_);
  __out_it                        = __formatter::__fill(_VSTD::move(__out_it), __padding.__before_, __specs.__fill_);
  __out_it                        = __formatter::__copy(__str, _VSTD::move(__out_it));
  return __formatter::__fill(_VSTD::move(__out_it), __padding.__after_, __specs.__fill_);
}

template <class _CharT, class _ParserCharT>
_LIBCPP_HIDE_FROM_ABI auto
__write(const _CharT* __first,
        const _CharT* __last,
        output_iterator<const _CharT&> auto __out_it,
        __format_spec::__parsed_specifications<_ParserCharT> __specs,
        ptrdiff_t __size) -> decltype(__out_it) {
  _LIBCPP_ASSERT(__first <= __last, "Not a valid range");
  return __formatter::__write(basic_string_view{__first, __last}, _VSTD::move(__out_it), __specs, __size);
}

/// \overload
///
/// Calls the function above where \a __size = \a __last - \a __first.
template <class _CharT, class _ParserCharT>
_LIBCPP_HIDE_FROM_ABI auto
__write(const _CharT* __first,
        const _CharT* __last,
        output_iterator<const _CharT&> auto __out_it,
        __format_spec::__parsed_specifications<_ParserCharT> __specs) -> decltype(__out_it) {
  _LIBCPP_ASSERT(__first <= __last, "Not a valid range");
  return __formatter::__write(__first, __last, _VSTD::move(__out_it), __specs, __last - __first);
}

template <class _CharT, class _ParserCharT, class _UnaryOperation>
_LIBCPP_HIDE_FROM_ABI auto __write_transformed(const _CharT* __first, const _CharT* __last,
                                               output_iterator<const _CharT&> auto __out_it,
                                               __format_spec::__parsed_specifications<_ParserCharT> __specs,
                                               _UnaryOperation __op) -> decltype(__out_it) {
  _LIBCPP_ASSERT(__first <= __last, "Not a valid range");

  ptrdiff_t __size = __last - __first;
  if (__size >= __specs.__width_)
    return __formatter::__transform(__first, __last, _VSTD::move(__out_it), __op);

  __padding_size_result __padding = __formatter::__padding_size(__size, __specs.__width_, __specs.__alignment_);
  __out_it                        = __formatter::__fill(_VSTD::move(__out_it), __padding.__before_, __specs.__fill_);
  __out_it                        = __formatter::__transform(__first, __last, _VSTD::move(__out_it), __op);
  return __formatter::__fill(_VSTD::move(__out_it), __padding.__after_, __specs.__fill_);
}

/// Writes additional zero's for the precision before the exponent.
/// This is used when the precision requested in the format string is larger
/// than the maximum precision of the floating-point type. These precision
/// digits are always 0.
///
/// \param __exponent           The location of the exponent character.
/// \param __num_trailing_zeros The number of 0's to write before the exponent
///                             character.
template <class _CharT, class _ParserCharT>
_LIBCPP_HIDE_FROM_ABI auto __write_using_trailing_zeros(
    const _CharT* __first,
    const _CharT* __last,
    output_iterator<const _CharT&> auto __out_it,
    __format_spec::__parsed_specifications<_ParserCharT> __specs,
    size_t __size,
    const _CharT* __exponent,
    size_t __num_trailing_zeros) -> decltype(__out_it) {
  _LIBCPP_ASSERT(__first <= __last, "Not a valid range");
  _LIBCPP_ASSERT(__num_trailing_zeros > 0, "The overload not writing trailing zeros should have been used");

  __padding_size_result __padding =
      __formatter::__padding_size(__size + __num_trailing_zeros, __specs.__width_, __specs.__alignment_);
  __out_it = __formatter::__fill(_VSTD::move(__out_it), __padding.__before_, __specs.__fill_);
  __out_it = __formatter::__copy(__first, __exponent, _VSTD::move(__out_it));
  __out_it = __formatter::__fill(_VSTD::move(__out_it), __num_trailing_zeros, _CharT('0'));
  __out_it = __formatter::__copy(__exponent, __last, _VSTD::move(__out_it));
  return __formatter::__fill(_VSTD::move(__out_it), __padding.__after_, __specs.__fill_);
}

/// Writes a string using format's width estimation algorithm.
///
/// \pre !__specs.__has_precision()
///
/// \note When \c _LIBCPP_HAS_NO_UNICODE is defined the function assumes the
/// input is ASCII.
template <class _CharT>
_LIBCPP_HIDE_FROM_ABI auto __write_string_no_precision(
    basic_string_view<_CharT> __str,
    output_iterator<const _CharT&> auto __out_it,
    __format_spec::__parsed_specifications<_CharT> __specs) -> decltype(__out_it) {
  _LIBCPP_ASSERT(!__specs.__has_precision(), "use __write_string");

  // No padding -> copy the string
  if (!__specs.__has_width())
    return __formatter::__copy(__str, _VSTD::move(__out_it));

  // Note when the estimated width is larger than size there's no padding. So
  // there's no reason to get the real size when the estimate is larger than or
  // equal to the minimum field width.
  size_t __size =
      __format_spec::__estimate_column_width(__str, __specs.__width_, __format_spec::__column_width_rounding::__up)
          .__width_;
  return __formatter::__write(__str, _VSTD::move(__out_it), __specs, __size);
}

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI int __truncate(basic_string_view<_CharT>& __str, int __precision) {
  __format_spec::__column_width_result<_CharT> __result =
      __format_spec::__estimate_column_width(__str, __precision, __format_spec::__column_width_rounding::__down);
  __str = basic_string_view<_CharT>{__str.begin(), __result.__last_};
  return __result.__width_;
}

/// Writes a string using format's width estimation algorithm.
///
/// \note When \c _LIBCPP_HAS_NO_UNICODE is defined the function assumes the
/// input is ASCII.
template <class _CharT>
_LIBCPP_HIDE_FROM_ABI auto __write_string(
    basic_string_view<_CharT> __str,
    output_iterator<const _CharT&> auto __out_it,
    __format_spec::__parsed_specifications<_CharT> __specs) -> decltype(__out_it) {
  if (!__specs.__has_precision())
    return __formatter::__write_string_no_precision(__str, _VSTD::move(__out_it), __specs);

  int __size = __formatter::__truncate(__str, __specs.__precision_);

  return __formatter::__write(__str.begin(), __str.end(), _VSTD::move(__out_it), __specs, __size);
}

#  if _LIBCPP_STD_VER > 20

struct __nul_terminator {};

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI bool operator==(const _CharT* __cstr, __nul_terminator) {
  return *__cstr == _CharT('\0');
}

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI void
__write_escaped_code_unit(basic_string<_CharT>& __str, char32_t __value, const _CharT* __prefix) {
  back_insert_iterator __out_it{__str};
  std::ranges::copy(__prefix, __nul_terminator{}, __out_it);

  char __buffer[8];
  to_chars_result __r = std::to_chars(std::begin(__buffer), std::end(__buffer), __value, 16);
  _LIBCPP_ASSERT(__r.ec == errc(0), "Internal buffer too small");
  std::ranges::copy(std::begin(__buffer), __r.ptr, __out_it);

  __str += _CharT('}');
}

// [format.string.escaped]/2.2.1.2
// ...
// then the sequence \u{hex-digit-sequence} is appended to E, where
// hex-digit-sequence is the shortest hexadecimal representation of C using
// lower-case hexadecimal digits.
template <class _CharT>
_LIBCPP_HIDE_FROM_ABI void __write_well_formed_escaped_code_unit(basic_string<_CharT>& __str, char32_t __value) {
  __formatter::__write_escaped_code_unit(__str, __value, _LIBCPP_STATICALLY_WIDEN(_CharT, "\\u{"));
}

// [format.string.escaped]/2.2.3
// Otherwise (X is a sequence of ill-formed code units), each code unit U is
// appended to E in order as the sequence \x{hex-digit-sequence}, where
// hex-digit-sequence is the shortest hexadecimal representation of U using
// lower-case hexadecimal digits.
template <class _CharT>
_LIBCPP_HIDE_FROM_ABI void __write_escape_ill_formed_code_unit(basic_string<_CharT>& __str, char32_t __value) {
  __formatter::__write_escaped_code_unit(__str, __value, _LIBCPP_STATICALLY_WIDEN(_CharT, "\\x{"));
}

template <class _CharT>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI bool __is_escaped_sequence_written(basic_string<_CharT>& __str, char32_t __value) {
#    ifdef _LIBCPP_HAS_NO_UNICODE
  // For ASCII assume everything above 127 is printable.
  if (__value > 127)
    return false;
#    endif

  if (!__escaped_output_table::__needs_escape(__value))
    return false;

  __formatter::__write_well_formed_escaped_code_unit(__str, __value);
  return true;
}

template <class _CharT>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr char32_t __to_char32(_CharT __value) {
  return static_cast<make_unsigned_t<_CharT>>(__value);
}

enum class _LIBCPP_ENUM_VIS __escape_quotation_mark { __apostrophe, __double_quote };

// [format.string.escaped]/2
template <class _CharT>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI bool
__is_escaped_sequence_written(basic_string<_CharT>& __str, char32_t __value, __escape_quotation_mark __mark) {
  // 2.2.1.1 - Mapped character in [tab:format.escape.sequences]
  switch (__value) {
  case _CharT('\t'):
    __str += _LIBCPP_STATICALLY_WIDEN(_CharT, "\\t");
    return true;
  case _CharT('\n'):
    __str += _LIBCPP_STATICALLY_WIDEN(_CharT, "\\n");
    return true;
  case _CharT('\r'):
    __str += _LIBCPP_STATICALLY_WIDEN(_CharT, "\\r");
    return true;
  case _CharT('\''):
    if (__mark == __escape_quotation_mark::__apostrophe)
      __str += _LIBCPP_STATICALLY_WIDEN(_CharT, R"(\')");
    else
      __str += __value;
    return true;
  case _CharT('"'):
    if (__mark == __escape_quotation_mark::__double_quote)
      __str += _LIBCPP_STATICALLY_WIDEN(_CharT, R"(\")");
    else
      __str += __value;
    return true;
  case _CharT('\\'):
    __str += _LIBCPP_STATICALLY_WIDEN(_CharT, R"(\\)");
    return true;

  // 2.2.1.2 - Space
  case _CharT(' '):
    __str += __value;
    return true;
  }

  // 2.2.2
  //   Otherwise, if X is a shift sequence, the effect on E and further
  //   decoding of S is unspecified.
  // For now shift sequences are ignored and treated as Unicode. Other parts
  // of the format library do the same. It's unknown how ostream treats them.
  // TODO FMT determine what to do with shift sequences.

  // 2.2.1.2.1 and 2.2.1.2.2 - Escape
  return __formatter::__is_escaped_sequence_written(__str, __formatter::__to_char32(__value));
}

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI void
__escape(basic_string<_CharT>& __str, basic_string_view<_CharT> __values, __escape_quotation_mark __mark) {
  __unicode::__code_point_view<_CharT> __view{__values.begin(), __values.end()};

  while (!__view.__at_end()) {
    const _CharT* __first                               = __view.__position();
    typename __unicode::__consume_p2286_result __result = __view.__consume_p2286();
    if (__result.__ill_formed_size == 0) {
      if (!__formatter::__is_escaped_sequence_written(__str, __result.__value, __mark))
        // 2.2.1.3 - Add the character
        ranges::copy(__first, __view.__position(), std::back_insert_iterator(__str));

    } else {
      // 2.2.3 sequence of ill-formed code units
      // The number of code-units in __result.__value depends on the character type being used.
      if constexpr (sizeof(_CharT) == 1) {
        _LIBCPP_ASSERT(__result.__ill_formed_size == 1 || __result.__ill_formed_size == 4,
                       "illegal number of invalid code units.");
        if (__result.__ill_formed_size == 1) // ill-formed, one code unit
          __formatter::__write_escape_ill_formed_code_unit(__str, __result.__value & 0xff);
        else { // out of valid range, four code units
               // The code point was properly encoded, decode the value.
          __formatter::__write_escape_ill_formed_code_unit(__str, __result.__value >> 18 | 0xf0);
          __formatter::__write_escape_ill_formed_code_unit(__str, (__result.__value >> 12 & 0x3f) | 0x80);
          __formatter::__write_escape_ill_formed_code_unit(__str, (__result.__value >> 6 & 0x3f) | 0x80);
          __formatter::__write_escape_ill_formed_code_unit(__str, (__result.__value & 0x3f) | 0x80);
        }
      } else if constexpr (sizeof(_CharT) == 2) {
        _LIBCPP_ASSERT(__result.__ill_formed_size == 1, "for UTF-16 at most one invalid code unit");
        __formatter::__write_escape_ill_formed_code_unit(__str, __result.__value & 0xffff);
      } else {
        static_assert(sizeof(_CharT) == 4, "unsupported character width");
        _LIBCPP_ASSERT(__result.__ill_formed_size == 1, "for UTF-32 one code unit is one code point");
        __formatter::__write_escape_ill_formed_code_unit(__str, __result.__value);
      }
    }
  }
}

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI auto
__format_escaped_char(_CharT __value,
                      output_iterator<const _CharT&> auto __out_it,
                      __format_spec::__parsed_specifications<_CharT> __specs) -> decltype(__out_it) {
  basic_string<_CharT> __str;
  __str += _CharT('\'');
  __formatter::__escape(__str, basic_string_view{std::addressof(__value), 1}, __escape_quotation_mark::__apostrophe);
  __str += _CharT('\'');
  return __formatter::__write(__str.data(), __str.data() + __str.size(), _VSTD::move(__out_it), __specs, __str.size());
}

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI auto
__format_escaped_string(basic_string_view<_CharT> __values,
                        output_iterator<const _CharT&> auto __out_it,
                        __format_spec::__parsed_specifications<_CharT> __specs) -> decltype(__out_it) {
  basic_string<_CharT> __str;
  __str += _CharT('"');
  __formatter::__escape(__str, __values, __escape_quotation_mark::__double_quote);
  __str += _CharT('"');
  return __formatter::__write_string(basic_string_view{__str}, _VSTD::move(__out_it), __specs);
}

#  endif // _LIBCPP_STD_VER > 20

} // namespace __formatter

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FORMAT_FORMATTER_OUTPUT_H
