// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMATTER_FLOATING_POINT_H
#define _LIBCPP___FORMAT_FORMATTER_FLOATING_POINT_H

#include <__algorithm/copy.h>
#include <__algorithm/copy_n.h>
#include <__algorithm/fill_n.h>
#include <__algorithm/find.h>
#include <__algorithm/min.h>
#include <__algorithm/rotate.h>
#include <__algorithm/transform.h>
#include <__concepts/arithmetic.h>
#include <__config>
#include <__debug>
#include <__format/format_error.h>
#include <__format/format_fwd.h>
#include <__format/format_string.h>
#include <__format/formatter.h>
#include <__format/formatter_integral.h>
#include <__format/parser_std_format_spec.h>
#include <__utility/move.h>
#include <charconv>
#include <cmath>

#ifndef _LIBCPP_HAS_NO_LOCALIZATION
#  include <locale>
#endif

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

// TODO FMT Remove this once we require compilers with proper C++20 support.
// If the compiler has no concepts support, the format header will be disabled.
// Without concepts support enable_if needs to be used and that too much effort
// to support compilers with partial C++20 support.
#  if !defined(_LIBCPP_HAS_NO_CONCEPTS)

namespace __format_spec {

template <floating_point _Tp>
_LIBCPP_HIDE_FROM_ABI char* __to_buffer(char* __first, char* __last, _Tp __value) {
  to_chars_result __r = _VSTD::to_chars(__first, __last, __value);
  _LIBCPP_ASSERT(__r.ec == errc(0), "Internal buffer too small");
  return __r.ptr;
}

template <floating_point _Tp>
_LIBCPP_HIDE_FROM_ABI char* __to_buffer(char* __first, char* __last, _Tp __value, chars_format __fmt) {
  to_chars_result __r = _VSTD::to_chars(__first, __last, __value, __fmt);
  _LIBCPP_ASSERT(__r.ec == errc(0), "Internal buffer too small");
  return __r.ptr;
}

template <floating_point _Tp>
_LIBCPP_HIDE_FROM_ABI char* __to_buffer(char* __first, char* __last, _Tp __value, chars_format __fmt, int __precision) {
  to_chars_result __r = _VSTD::to_chars(__first, __last, __value, __fmt, __precision);
  _LIBCPP_ASSERT(__r.ec == errc(0), "Internal buffer too small");
  return __r.ptr;
}

// https://en.cppreference.com/w/cpp/language/types#cite_note-1
// float             min subnormal: +/-0x1p-149   max: +/- 3.402,823,4 10^38
// double            min subnormal: +/-0x1p-1074  max  +/- 1.797,693,134,862,315,7 10^308
// long double (x86) min subnormal: +/-0x1p-16446 max: +/- 1.189,731,495,357,231,765,021 10^4932
//
// The maximum number of digits required for the integral part is based on the
// maximum's value power of 10. Every power of 10 requires one additional
// decimal digit.
// The maximum number of digits required for the fractional part is based on
// the minimal subnormal hexadecimal output's power of 10. Every division of a
// fraction's binary 1 by 2, requires one additional decimal digit.
//
// The maximum size of a formatted value depends on the selected output format.
// Ignoring the fact the format string can request a precision larger than the
// values maximum required, these values are:
//
// sign                    1 code unit
// __max_integral
// radix point             1 code unit
// __max_fractional
// exponent character      1 code unit
// sign                    1 code unit
// __max_fractional_value
// -----------------------------------
// total                   4 code units extra required.
//
// TODO FMT Optimize the storage to avoid storing digits that are known to be zero.
// https://www.exploringbinary.com/maximum-number-of-decimal-digits-in-binary-floating-point-numbers/

// TODO FMT Add long double specialization when to_chars has proper long double support.
template <class _Tp>
struct __traits;

template <floating_point _Fp>
static constexpr size_t __float_buffer_size(int __precision) {
  using _Traits = __traits<_Fp>;
  return 4 + _Traits::__max_integral + __precision + _Traits::__max_fractional_value;
}

template <>
struct __traits<float> {
  static constexpr int __max_integral = 38;
  static constexpr int __max_fractional = 149;
  static constexpr int __max_fractional_value = 3;
  static constexpr size_t __stack_buffer_size = 256;

  static constexpr int __hex_precision_digits = 3;
};

template <>
struct __traits<double> {
  static constexpr int __max_integral = 308;
  static constexpr int __max_fractional = 1074;
  static constexpr int __max_fractional_value = 4;
  static constexpr size_t __stack_buffer_size = 1024;

  static constexpr int __hex_precision_digits = 4;
};

/// Helper class to store the conversion buffer.
///
/// Depending on the maxium size required for a value, the buffer is allocated
/// on the stack or the heap.
template <floating_point _Fp>
class _LIBCPP_TEMPLATE_VIS __float_buffer {
  using _Traits = __traits<_Fp>;

public:
  // TODO FMT Improve this constructor to do a better estimate.
  // When using a scientific formatting with a precision of 6 a stack buffer
  // will always suffice. At the moment that isn't important since floats and
  // doubles use a stack buffer, unless the precision used in the format string
  // is large.
  // When supporting long doubles the __max_integral part becomes 4932 which
  // may be too much for some platforms. For these cases a better estimate is
  // required.
  explicit _LIBCPP_HIDE_FROM_ABI __float_buffer(int __precision)
      : __precision_(__precision != -1 ? __precision : _Traits::__max_fractional) {

    // When the precision is larger than _Traits::__max_fractional the digits in
    // the range (_Traits::__max_fractional, precision] will contain the value
    // zero. There's no need to request to_chars to write these zeros:
    // - When the value is large a temporary heap buffer needs to be allocated.
    // - When to_chars writes the values they need to be "copied" to the output:
    //   - char: std::fill on the output iterator is faster than std::copy.
    //   - wchar_t: same argument as char, but additional std::copy won't work.
    //     The input is always a char buffer, so every char in the buffer needs
    //     to be converted from a char to a wchar_t.
    if (__precision_ > _Traits::__max_fractional) {
      __num_trailing_zeros_ = __precision_ - _Traits::__max_fractional;
      __precision_ = _Traits::__max_fractional;
    }

    __size_ = __format_spec::__float_buffer_size<_Fp>(__precision_);
    if (__size_ > _Traits::__stack_buffer_size)
      // The allocated buffer's contents don't need initialization.
      __begin_ = allocator<char>{}.allocate(__size_);
    else
      __begin_ = __buffer_;
  }

  _LIBCPP_HIDE_FROM_ABI ~__float_buffer() {
    if (__size_ > _Traits::__stack_buffer_size)
      allocator<char>{}.deallocate(__begin_, __size_);
  }
  _LIBCPP_HIDE_FROM_ABI __float_buffer(const __float_buffer&) = delete;
  _LIBCPP_HIDE_FROM_ABI __float_buffer& operator=(const __float_buffer&) = delete;

  _LIBCPP_HIDE_FROM_ABI char* begin() const { return __begin_; }
  _LIBCPP_HIDE_FROM_ABI char* end() const { return __begin_ + __size_; }

  _LIBCPP_HIDE_FROM_ABI int __precision() const { return __precision_; }
  _LIBCPP_HIDE_FROM_ABI int __num_trailing_zeros() const { return __num_trailing_zeros_; }
  _LIBCPP_HIDE_FROM_ABI void __remove_trailing_zeros() { __num_trailing_zeros_ = 0; }

private:
  int __precision_;
  int __num_trailing_zeros_{0};
  size_t __size_;
  char* __begin_;
  char __buffer_[_Traits::__stack_buffer_size];
};

struct __float_result {
  /// Points at the beginning of the integral part in the buffer.
  ///
  /// When there's no sign character this points at the start of the buffer.
  char* __integral;

  /// Points at the radix point, when not present it's the same as \ref __last.
  char* __radix_point;

  /// Points at the exponent character, when not present it's the same as \ref __last.
  char* __exponent;

  /// Points beyond the last written element in the buffer.
  char* __last;
};

/// Finds the position of the exponent character 'e' at the end of the buffer.
///
/// Assuming there is an exponent the input will terminate with
/// eSdd and eSdddd (S = sign, d = digit)
///
/// \returns a pointer to the exponent or __last when not found.
constexpr inline _LIBCPP_HIDE_FROM_ABI char* __find_exponent(char* __first, char* __last) {
  ptrdiff_t __size = __last - __first;
  if (__size > 4) {
    __first = __last - _VSTD::min(__size, ptrdiff_t(6));
    for (; __first != __last - 3; ++__first) {
      if (*__first == 'e')
        return __first;
    }
  }
  return __last;
}

template <class _Fp, class _Tp>
_LIBCPP_HIDE_FROM_ABI __float_result __format_buffer_default(const __float_buffer<_Fp>& __buffer, _Tp __value,
                                                             char* __integral) {
  __float_result __result;
  __result.__integral = __integral;
  __result.__last = __format_spec::__to_buffer(__integral, __buffer.end(), __value);

  __result.__exponent = __format_spec::__find_exponent(__result.__integral, __result.__last);

  // Constrains:
  // - There's at least one decimal digit before the radix point.
  // - The radix point, when present, is placed before the exponent.
  __result.__radix_point = _VSTD::find(__result.__integral + 1, __result.__exponent, '.');

  // When the radix point isn't found its position is the exponent instead of
  // __result.__last.
  if (__result.__radix_point == __result.__exponent)
    __result.__radix_point = __result.__last;

  // clang-format off
  _LIBCPP_ASSERT((__result.__integral != __result.__last) &&
                 (__result.__radix_point == __result.__last || *__result.__radix_point == '.') &&
                 (__result.__exponent == __result.__last || *__result.__exponent == 'e'),
                 "Post-condition failure.");
  // clang-format on

  return __result;
}

template <class _Fp, class _Tp>
_LIBCPP_HIDE_FROM_ABI __float_result __format_buffer_hexadecimal_lower_case(const __float_buffer<_Fp>& __buffer,
                                                                            _Tp __value, int __precision,
                                                                            char* __integral) {
  __float_result __result;
  __result.__integral = __integral;
  if (__precision == -1)
    __result.__last = __format_spec::__to_buffer(__integral, __buffer.end(), __value, chars_format::hex);
  else
    __result.__last = __format_spec::__to_buffer(__integral, __buffer.end(), __value, chars_format::hex, __precision);

  // H = one or more hex-digits
  // S = sign
  // D = one or more decimal-digits
  // When the fractional part is zero and no precision the output is 0p+0
  // else the output is                                              0.HpSD
  // So testing the second position can differentiate between these two cases.
  char* __first = __integral + 1;
  if (*__first == '.') {
    __result.__radix_point = __first;
    // One digit is the minimum
    // 0.hpSd
    //       ^-- last
    //     ^---- integral = end of search
    // ^-------- start of search
    // 0123456
    //
    // Four digits is the maximum
    // 0.hpSdddd
    //          ^-- last
    //        ^---- integral = end of search
    //    ^-------- start of search
    // 0123456789
    static_assert(__traits<_Fp>::__hex_precision_digits <= 4, "Guard against possible underflow.");

    char* __last = __result.__last - 2;
    __first = __last - __traits<_Fp>::__hex_precision_digits;
    __result.__exponent = _VSTD::find(__first, __last, 'p');
  } else {
    __result.__radix_point = __result.__last;
    __result.__exponent = __first;
  }

  // clang-format off
  _LIBCPP_ASSERT((__result.__integral != __result.__last) &&
                 (__result.__radix_point == __result.__last || *__result.__radix_point == '.') &&
                 (__result.__exponent != __result.__last && *__result.__exponent == 'p'),
                 "Post-condition failure.");
  // clang-format on

  return __result;
}

template <class _Fp, class _Tp>
_LIBCPP_HIDE_FROM_ABI __float_result __format_buffer_hexadecimal_upper_case(const __float_buffer<_Fp>& __buffer,
                                                                            _Tp __value, int __precision,
                                                                            char* __integral) {
  __float_result __result =
      __format_spec::__format_buffer_hexadecimal_lower_case(__buffer, __value, __precision, __integral);
  _VSTD::transform(__result.__integral, __result.__exponent, __result.__integral, __hex_to_upper);
  *__result.__exponent = 'P';
  return __result;
}

template <class _Fp, class _Tp>
_LIBCPP_HIDE_FROM_ABI __float_result __format_buffer_scientific_lower_case(const __float_buffer<_Fp>& __buffer,
                                                                           _Tp __value, int __precision,
                                                                           char* __integral) {
  __float_result __result;
  __result.__integral = __integral;
  __result.__last =
      __format_spec::__to_buffer(__integral, __buffer.end(), __value, chars_format::scientific, __precision);

  char* __first = __integral + 1;
  _LIBCPP_ASSERT(__first != __result.__last, "No exponent present");
  if (*__first == '.') {
    __result.__radix_point = __first;
    __result.__exponent = __format_spec::__find_exponent(__first + 1, __result.__last);
  } else {
    __result.__radix_point = __result.__last;
    __result.__exponent = __first;
  }

  // clang-format off
  _LIBCPP_ASSERT((__result.__integral != __result.__last) &&
                 (__result.__radix_point == __result.__last || *__result.__radix_point == '.') &&
                 (__result.__exponent != __result.__last && *__result.__exponent == 'e'),
                 "Post-condition failure.");
  // clang-format on
  return __result;
}

template <class _Fp, class _Tp>
_LIBCPP_HIDE_FROM_ABI __float_result __format_buffer_scientific_upper_case(const __float_buffer<_Fp>& __buffer,
                                                                           _Tp __value, int __precision,
                                                                           char* __integral) {
  __float_result __result =
      __format_spec::__format_buffer_scientific_lower_case(__buffer, __value, __precision, __integral);
  *__result.__exponent = 'E';
  return __result;
}

template <class _Fp, class _Tp>
_LIBCPP_HIDE_FROM_ABI __float_result __format_buffer_fixed(const __float_buffer<_Fp>& __buffer, _Tp __value,
                                                           int __precision, char* __integral) {
  __float_result __result;
  __result.__integral = __integral;
  __result.__last = __format_spec::__to_buffer(__integral, __buffer.end(), __value, chars_format::fixed, __precision);

  // When there's no precision there's no radix point.
  // Else the radix point is placed at __precision + 1 from the end.
  // By converting __precision to a bool the subtraction can be done
  // unconditionally.
  __result.__radix_point = __result.__last - (__precision + bool(__precision));
  __result.__exponent = __result.__last;

  // clang-format off
  _LIBCPP_ASSERT((__result.__integral != __result.__last) &&
                 (__result.__radix_point == __result.__last || *__result.__radix_point == '.') &&
                 (__result.__exponent == __result.__last),
                 "Post-condition failure.");
  // clang-format on
  return __result;
}

template <class _Fp, class _Tp>
_LIBCPP_HIDE_FROM_ABI __float_result __format_buffer_general_lower_case(__float_buffer<_Fp>& __buffer, _Tp __value,
                                                                        int __precision, char* __integral) {

  __buffer.__remove_trailing_zeros();

  __float_result __result;
  __result.__integral = __integral;
  __result.__last = __format_spec::__to_buffer(__integral, __buffer.end(), __value, chars_format::general, __precision);

  char* __first = __integral + 1;
  if (__first == __result.__last) {
    __result.__radix_point = __result.__last;
    __result.__exponent = __result.__last;
  } else {
    __result.__exponent = __format_spec::__find_exponent(__first, __result.__last);
    if (__result.__exponent != __result.__last)
      // In scientific mode if there's a radix point it will always be after
      // the first digit. (This is the position __first points at).
      __result.__radix_point = *__first == '.' ? __first : __result.__last;
    else {
      // In fixed mode the algorithm truncates trailing spaces and possibly the
      // radix point. There's no good guess for the position of the radix point
      // therefore scan the output after the first digit.
      __result.__radix_point = _VSTD::find(__first, __result.__last, '.');
    }
  }

  // clang-format off
  _LIBCPP_ASSERT((__result.__integral != __result.__last) &&
                 (__result.__radix_point == __result.__last || *__result.__radix_point == '.') &&
                 (__result.__exponent == __result.__last || *__result.__exponent == 'e'),
                 "Post-condition failure.");
  // clang-format on

  return __result;
}

template <class _Fp, class _Tp>
_LIBCPP_HIDE_FROM_ABI __float_result __format_buffer_general_upper_case(__float_buffer<_Fp>& __buffer, _Tp __value,
                                                                        int __precision, char* __integral) {
  __float_result __result =
      __format_spec::__format_buffer_general_lower_case(__buffer, __value, __precision, __integral);
  if (__result.__exponent != __result.__last)
    *__result.__exponent = 'E';
  return __result;
}

#    ifndef _LIBCPP_HAS_NO_LOCALIZATION
template <class _OutIt, class _Fp, class _CharT>
_LIBCPP_HIDE_FROM_ABI _OutIt __format_locale_specific_form(_OutIt __out_it, const __float_buffer<_Fp>& __buffer,
                                                           const __float_result& __result, _VSTD::locale __loc,
                                                           size_t __width, _Flags::_Alignment __alignment,
                                                           _CharT __fill) {
  const auto& __np = use_facet<numpunct<_CharT>>(__loc);
  string __grouping = __np.grouping();
  char* __first = __result.__integral;
  // When no radix point or exponent are present __last will be __result.__last.
  char* __last = _VSTD::min(__result.__radix_point, __result.__exponent);

  ptrdiff_t __digits = __last - __first;
  if (!__grouping.empty()) {
    if (__digits <= __grouping[0])
      __grouping.clear();
    else
      __grouping = __determine_grouping(__digits, __grouping);
  }

  size_t __size = __result.__last - __buffer.begin() + // Formatted string
                  __buffer.__num_trailing_zeros() +    // Not yet rendered zeros
                  __grouping.size() -                  // Grouping contains one
                  !__grouping.empty();                 // additional character

  __formatter::__padding_size_result __padding = {0, 0};
  bool __zero_padding = __alignment == _Flags::_Alignment::__default;
  if (__size < __width) {
    if (__zero_padding) {
      __alignment = _Flags::_Alignment::__right;
      __fill = _CharT('0');
    }

    __padding = __formatter::__padding_size(__size, __width, __alignment);
  }

  // sign and (zero padding or alignment)
  if (__zero_padding && __first != __buffer.begin())
    *__out_it++ = *__buffer.begin();
  __out_it = _VSTD::fill_n(_VSTD::move(__out_it), __padding.__before, __fill);
  if (!__zero_padding && __first != __buffer.begin())
    *__out_it++ = *__buffer.begin();

  // integral part
  if (__grouping.empty()) {
    __out_it = _VSTD::copy_n(__first, __digits, _VSTD::move(__out_it));
  } else {
    auto __r = __grouping.rbegin();
    auto __e = __grouping.rend() - 1;
    _CharT __sep = __np.thousands_sep();
    // The output is divided in small groups of numbers to write:
    // - A group before the first separator.
    // - A separator and a group, repeated for the number of separators.
    // - A group after the last separator.
    // This loop achieves that process by testing the termination condition
    // midway in the loop.
    while (true) {
      __out_it = _VSTD::copy_n(__first, *__r, _VSTD::move(__out_it));
      __first += *__r;

      if (__r == __e)
        break;

      ++__r;
      *__out_it++ = __sep;
    }
  }

  // fractional part
  if (__result.__radix_point != __result.__last) {
    *__out_it++ = __np.decimal_point();
    __out_it = _VSTD::copy(__result.__radix_point + 1, __result.__exponent, _VSTD::move(__out_it));
    __out_it = _VSTD::fill_n(_VSTD::move(__out_it), __buffer.__num_trailing_zeros(), _CharT('0'));
  }

  // exponent
  if (__result.__exponent != __result.__last)
    __out_it = _VSTD::copy(__result.__exponent, __result.__last, _VSTD::move(__out_it));

  // alignment
  return _VSTD::fill_n(_VSTD::move(__out_it), __padding.__after, __fill);
}

#    endif // _LIBCPP_HAS_NO_LOCALIZATION

template <__formatter::__char_type _CharT>
class _LIBCPP_TEMPLATE_VIS __formatter_floating_point : public __parser_floating_point<_CharT> {
public:
  template <floating_point _Tp>
  _LIBCPP_HIDE_FROM_ABI auto format(_Tp __value, auto& __ctx) -> decltype(__ctx.out()) {
    if (this->__width_needs_substitution())
      this->__substitute_width_arg_id(__ctx.arg(this->__width));

    bool __negative = _VSTD::signbit(__value);

    if (!_VSTD::isfinite(__value)) [[unlikely]]
      return __format_non_finite(__ctx.out(), __negative, _VSTD::isnan(__value));

    bool __has_precision = this->__has_precision_field();
    if (this->__precision_needs_substitution())
      this->__substitute_precision_arg_id(__ctx.arg(this->__precision));

    // Depending on the std-format-spec string the sign and the value
    // might not be outputted together:
    // - zero-padding may insert additional '0' characters.
    // Therefore the value is processed as a non negative value.
    // The function @ref __insert_sign will insert a '-' when the value was
    // negative.

    if (__negative)
      __value = _VSTD::copysign(__value, +1.0);

    // TODO FMT _Fp should just be _Tp when to_chars has proper long double support.
    using _Fp = conditional_t<same_as<_Tp, long double>, double, _Tp>;
    // Force the type of the precision to avoid -1 to become an unsigned value.
    __float_buffer<_Fp> __buffer(__has_precision ? int(this->__precision) : -1);
    __float_result __result = __format_buffer(__buffer, __value, __negative, __has_precision);

    if (this->__alternate_form && __result.__radix_point == __result.__last) {
      *__result.__last++ = '.';

      // When there is an exponent the point needs to be moved before the
      // exponent. When there's no exponent the rotate does nothing. Since
      // rotate tests whether the operation is a nop, call it unconditionally.
      _VSTD::rotate(__result.__exponent, __result.__last - 1, __result.__last);
      __result.__radix_point = __result.__exponent;

      // The radix point is always placed before the exponent.
      // - No exponent needs to point to the new last.
      // - An exponent needs to move one position to the right.
      // So it's safe to increment the value unconditionally.
      ++__result.__exponent;
    }

#    ifndef _LIBCPP_HAS_NO_LOCALIZATION
    if (this->__locale_specific_form)
      return __format_spec::__format_locale_specific_form(__ctx.out(), __buffer, __result, __ctx.locale(),
                                                          this->__width, this->__alignment, this->__fill);
#    endif

    ptrdiff_t __size = __result.__last - __buffer.begin();
    int __num_trailing_zeros = __buffer.__num_trailing_zeros();
    if (__size + __num_trailing_zeros >= this->__width) {
      if (__num_trailing_zeros && __result.__exponent != __result.__last)
        // Insert trailing zeros before exponent character.
        return _VSTD::copy(__result.__exponent, __result.__last,
                           _VSTD::fill_n(_VSTD::copy(__buffer.begin(), __result.__exponent, __ctx.out()),
                                         __num_trailing_zeros, _CharT('0')));

      return _VSTD::fill_n(_VSTD::copy(__buffer.begin(), __result.__last, __ctx.out()), __num_trailing_zeros,
                           _CharT('0'));
    }

    auto __out_it = __ctx.out();
    char* __first = __buffer.begin();
    if (this->__alignment == _Flags::_Alignment::__default) {
      // When there is a sign output it before the padding. Note the __size
      // doesn't need any adjustment, regardless whether the sign is written
      // here or in __formatter::__write.
      if (__first != __result.__integral)
        *__out_it++ = *__first++;
      // After the sign is written, zero padding is the same a right alignment
      // with '0'.
      this->__alignment = _Flags::_Alignment::__right;
      this->__fill = _CharT('0');
    }

    if (__num_trailing_zeros)
      return __formatter::__write(_VSTD::move(__out_it), __first, __result.__last, __size, this->__width, this->__fill,
                                  this->__alignment, __result.__exponent, __num_trailing_zeros);

    return __formatter::__write(_VSTD::move(__out_it), __first, __result.__last, __size, this->__width, this->__fill,
                                this->__alignment);
  }

private:
  template <class _OutIt>
  _LIBCPP_HIDE_FROM_ABI _OutIt __format_non_finite(_OutIt __out_it, bool __negative, bool __isnan) {
    char __buffer[4];
    char* __last = __insert_sign(__buffer, __negative, this->__sign);

    // to_char can return inf, infinity, nan, and nan(n-char-sequence).
    // The format library requires inf and nan.
    // All in one expression to avoid dangling references.
    __last = _VSTD::copy_n(&("infnanINFNAN"[6 * (this->__type == _Flags::_Type::__float_hexadecimal_upper_case ||
                                                 this->__type == _Flags::_Type::__scientific_upper_case ||
                                                 this->__type == _Flags::_Type::__fixed_upper_case ||
                                                 this->__type == _Flags::_Type::__general_upper_case) +
                                            3 * __isnan]),
                           3, __last);

    // [format.string.std]/13
    // A zero (0) character preceding the width field pads the field with
    // leading zeros (following any indication of sign or base) to the field
    // width, except when applied to an infinity or NaN.
    if (this->__alignment == _Flags::_Alignment::__default)
      this->__alignment = _Flags::_Alignment::__right;

    ptrdiff_t __size = __last - __buffer;
    if (__size >= this->__width)
      return _VSTD::copy_n(__buffer, __size, _VSTD::move(__out_it));

    return __formatter::__write(_VSTD::move(__out_it), __buffer, __last, __size, this->__width, this->__fill,
                                this->__alignment);
  }

  /// Fills the buffer with the data based on the requested formatting.
  ///
  /// This function, when needed, turns the characters to upper case and
  /// determines the "interesting" locations which are returned to the caller.
  ///
  /// This means the caller never has to convert the contents of the buffer to
  /// upper case or search for radix points and the location of the exponent.
  /// This gives a bit of overhead. The original code didn't do that, but due
  /// to the number of possible additional work needed to turn this number to
  /// the proper output the code was littered with tests for upper cases and
  /// searches for radix points and exponents.
  /// - When a precision larger than the type's precision is selected
  ///   additional zero characters need to be written before the exponent.
  /// - alternate form needs to add a radix point when not present.
  /// - localization needs to do grouping in the integral part.
  template <class _Fp, class _Tp>
  // TODO FMT _Fp should just be _Tp when to_chars has proper long double support.
  _LIBCPP_HIDE_FROM_ABI __float_result __format_buffer(__float_buffer<_Fp>& __buffer, _Tp __value, bool __negative,
                                                       bool __has_precision) {
    char* __first = __insert_sign(__buffer.begin(), __negative, this->__sign);
    switch (this->__type) {
    case _Flags::_Type::__default:
      return __format_spec::__format_buffer_default(__buffer, __value, __first);

    case _Flags::_Type::__float_hexadecimal_lower_case:
      return __format_spec::__format_buffer_hexadecimal_lower_case(
          __buffer, __value, __has_precision ? __buffer.__precision() : -1, __first);

    case _Flags::_Type::__float_hexadecimal_upper_case:
      return __format_spec::__format_buffer_hexadecimal_upper_case(
          __buffer, __value, __has_precision ? __buffer.__precision() : -1, __first);

    case _Flags::_Type::__scientific_lower_case:
      return __format_spec::__format_buffer_scientific_lower_case(__buffer, __value, __buffer.__precision(), __first);

    case _Flags::_Type::__scientific_upper_case:
      return __format_spec::__format_buffer_scientific_upper_case(__buffer, __value, __buffer.__precision(), __first);

    case _Flags::_Type::__fixed_lower_case:
    case _Flags::_Type::__fixed_upper_case:
      return __format_spec::__format_buffer_fixed(__buffer, __value, __buffer.__precision(), __first);

    case _Flags::_Type::__general_lower_case:
      return __format_spec::__format_buffer_general_lower_case(__buffer, __value, __buffer.__precision(), __first);

    case _Flags::_Type::__general_upper_case:
      return __format_spec::__format_buffer_general_upper_case(__buffer, __value, __buffer.__precision(), __first);

    default:
      _LIBCPP_ASSERT(false, "The parser should have validated the type");
      _LIBCPP_UNREACHABLE();
    }
  }
};

} //namespace __format_spec

template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<float, _CharT>
    : public __format_spec::__formatter_floating_point<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<double, _CharT>
    : public __format_spec::__formatter_floating_point<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<long double, _CharT>
    : public __format_spec::__formatter_floating_point<_CharT> {};

#  endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___FORMAT_FORMATTER_FLOATING_POINT_H
