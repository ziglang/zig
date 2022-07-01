// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMATTER_INTEGRAL_H
#define _LIBCPP___FORMAT_FORMATTER_INTEGRAL_H

#include <__algorithm/copy.h>
#include <__algorithm/copy_n.h>
#include <__algorithm/fill_n.h>
#include <__algorithm/transform.h>
#include <__config>
#include <__format/format_error.h>
#include <__format/format_fwd.h>
#include <__format/formatter.h>
#include <__format/parser_std_format_spec.h>
#include <array>
#include <charconv>
#include <concepts>
#include <limits>
#include <string>

#ifndef _LIBCPP_HAS_NO_LOCALIZATION
#include <locale>
#endif

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

/**
 * Integral formatting classes.
 *
 * There are two types used here:
 * * C++-type, the type as used in C++.
 * * format-type, the output type specified in the std-format-spec.
 *
 * Design of the integral formatters consists of several layers.
 * * @ref __parser_integral The basic std-format-spec parser for all integral
 *   classes. This parser does the basic sanity checks. It also contains some
 *   helper functions that are nice to have available for all parsers.
 * * A C++-type specific parser. These parsers must derive from
 *   @ref __parser_integral. Their task is to validate whether the parsed
 *   std-format-spec is valid for the C++-type and selected format-type. After
 *   validation they need to make sure all members are properly set. For
 *   example, when the alignment hasn't changed it needs to set the proper
 *   default alignment for the format-type. The following parsers are available:
 *   - @ref __parser_integer
 *   - @ref __parser_char
 *   - @ref __parser_bool
 * * A general formatter for all integral types @ref __formatter_integral. This
 *   formatter can handle all formatting of integers and characters. The class
 *   derives from the proper formatter.
 *   Note the boolean string format-type isn't supported in this class.
 * * A typedef C++-type group combining the @ref __formatter_integral with a
 *   parser:
 *   * @ref __formatter_integer
 *   * @ref __formatter_char
 *   * @ref __formatter_bool
 * * Then every C++-type has its own formatter specializations. They inherit
 *   from the C++-type group typedef. Most specializations need nothing else.
 *   Others need some additional specializations in this class.
 */
namespace __format_spec {

/** Wrapper around @ref to_chars, returning the output pointer. */
template <integral _Tp>
_LIBCPP_HIDE_FROM_ABI char* __to_buffer(char* __first, char* __last,
                                        _Tp __value, int __base) {
  // TODO FMT Evaluate code overhead due to not calling the internal function
  // directly. (Should be zero overhead.)
  to_chars_result __r = _VSTD::to_chars(__first, __last, __value, __base);
  _LIBCPP_ASSERT(__r.ec == errc(0), "Internal buffer too small");
  return __r.ptr;
}

/**
 * Helper to determine the buffer size to output a integer in Base @em x.
 *
 * There are several overloads for the supported bases. The function uses the
 * base as template argument so it can be used in a constant expression.
 */
template <unsigned_integral _Tp, size_t _Base>
_LIBCPP_HIDE_FROM_ABI constexpr size_t __buffer_size() noexcept
    requires(_Base == 2) {
  return numeric_limits<_Tp>::digits // The number of binary digits.
         + 2                         // Reserve space for the '0[Bb]' prefix.
         + 1;                        // Reserve space for the sign.
}

template <unsigned_integral _Tp, size_t _Base>
_LIBCPP_HIDE_FROM_ABI constexpr size_t __buffer_size() noexcept
    requires(_Base == 8) {
  return numeric_limits<_Tp>::digits // The number of binary digits.
             / 3                     // Adjust to octal.
         + 1                         // Turn floor to ceil.
         + 1                         // Reserve space for the '0' prefix.
         + 1;                        // Reserve space for the sign.
}

template <unsigned_integral _Tp, size_t _Base>
_LIBCPP_HIDE_FROM_ABI constexpr size_t __buffer_size() noexcept
    requires(_Base == 10) {
  return numeric_limits<_Tp>::digits10 // The floored value.
         + 1                           // Turn floor to ceil.
         + 1;                          // Reserve space for the sign.
}

template <unsigned_integral _Tp, size_t _Base>
_LIBCPP_HIDE_FROM_ABI constexpr size_t __buffer_size() noexcept
    requires(_Base == 16) {
  return numeric_limits<_Tp>::digits // The number of binary digits.
             / 4                     // Adjust to hexadecimal.
         + 2                         // Reserve space for the '0[Xx]' prefix.
         + 1;                        // Reserve space for the sign.
}

/**
 * Determines the required grouping based on the size of the input.
 *
 * The grouping's last element will be repeated. For simplicity this repeating
 * is unwrapped based on the length of the input. (When the input is short some
 * groups are not processed.)
 *
 * @returns The size of the groups to write. This means the number of
 * separator characters written is size() - 1.
 *
 * @note Since zero-sized groups cause issues they are silently ignored.
 *
 * @note The grouping field of the locale is always a @c std::string,
 * regardless whether the @c std::numpunct's type is @c char or @c wchar_t.
 */
_LIBCPP_HIDE_FROM_ABI inline string
__determine_grouping(ptrdiff_t __size, const string& __grouping) {
  _LIBCPP_ASSERT(!__grouping.empty() && __size > __grouping[0],
                 "The slow grouping formatting is used while there will be no "
                 "separators written");
  string __r;
  auto __end = __grouping.end() - 1;
  auto __ptr = __grouping.begin();

  while (true) {
    __size -= *__ptr;
    if (__size > 0)
      __r.push_back(*__ptr);
    else {
      // __size <= 0 so the value pushed will be <= *__ptr.
      __r.push_back(*__ptr + __size);
      return __r;
    }

    // Proceed to the next group.
    if (__ptr != __end) {
      do {
        ++__ptr;
        // Skip grouping with a width of 0.
      } while (*__ptr == 0 && __ptr != __end);
    }
  }

  _LIBCPP_UNREACHABLE();
}

template <class _Parser>
requires __formatter::__char_type<typename _Parser::char_type>
class _LIBCPP_TEMPLATE_VIS __formatter_integral : public _Parser {
public:
  using _CharT = typename _Parser::char_type;

  template <integral _Tp>
  _LIBCPP_HIDE_FROM_ABI auto format(_Tp __value, auto& __ctx)
      -> decltype(__ctx.out()) {
    if (this->__width_needs_substitution())
      this->__substitute_width_arg_id(__ctx.arg(this->__width));

    if (this->__type == _Flags::_Type::__char)
      return __format_as_char(__value, __ctx);

    if constexpr (unsigned_integral<_Tp>)
      return __format_unsigned_integral(__value, false, __ctx);
    else {
      // Depending on the std-format-spec string the sign and the value
      // might not be outputted together:
      // - alternate form may insert a prefix string.
      // - zero-padding may insert additional '0' characters.
      // Therefore the value is processed as a positive unsigned value.
      // The function @ref __insert_sign will a '-' when the value was negative.
      auto __r = __to_unsigned_like(__value);
      bool __negative = __value < 0;
      if (__negative)
        __r = __complement(__r);

      return __format_unsigned_integral(__r, __negative, __ctx);
    }
  }

private:
  /** Generic formatting for format-type c. */
  _LIBCPP_HIDE_FROM_ABI auto __format_as_char(integral auto __value,
                                              auto& __ctx)
      -> decltype(__ctx.out()) {
    if (this->__alignment == _Flags::_Alignment::__default)
      this->__alignment = _Flags::_Alignment::__right;

    using _Tp = decltype(__value);
    if constexpr (!same_as<_CharT, _Tp>) {
      // cmp_less and cmp_greater can't be used for character types.
      if constexpr (signed_integral<_CharT> == signed_integral<_Tp>) {
        if (__value < numeric_limits<_CharT>::min() ||
            __value > numeric_limits<_CharT>::max())
          __throw_format_error(
              "Integral value outside the range of the char type");
      } else if constexpr (signed_integral<_CharT>) {
        // _CharT is signed _Tp is unsigned
        if (__value >
            static_cast<make_unsigned_t<_CharT>>(numeric_limits<_CharT>::max()))
          __throw_format_error(
              "Integral value outside the range of the char type");
      } else {
        // _CharT is unsigned _Tp is signed
        if (__value < 0 || static_cast<make_unsigned_t<_Tp>>(__value) >
                               numeric_limits<_CharT>::max())
          __throw_format_error(
              "Integral value outside the range of the char type");
      }
    }

    const auto __c = static_cast<_CharT>(__value);
    return __write(_VSTD::addressof(__c), _VSTD::addressof(__c) + 1,
                   __ctx.out());
  }

  /**
   * Generic formatting for format-type bBdoxX.
   *
   * This small wrapper allocates a buffer with the required size. Then calls
   * the real formatter with the buffer and the prefix for the base.
   */
  _LIBCPP_HIDE_FROM_ABI auto
  __format_unsigned_integral(unsigned_integral auto __value, bool __negative,
                             auto& __ctx) -> decltype(__ctx.out()) {
    switch (this->__type) {
    case _Flags::_Type::__binary_lower_case: {
      array<char, __buffer_size<decltype(__value), 2>()> __array;
      return __format_unsigned_integral(__array.begin(), __array.end(), __value,
                                        __negative, 2, __ctx, "0b");
    }
    case _Flags::_Type::__binary_upper_case: {
      array<char, __buffer_size<decltype(__value), 2>()> __array;
      return __format_unsigned_integral(__array.begin(), __array.end(), __value,
                                        __negative, 2, __ctx, "0B");
    }
    case _Flags::_Type::__octal: {
      // Octal is special; if __value == 0 there's no prefix.
      array<char, __buffer_size<decltype(__value), 8>()> __array;
      return __format_unsigned_integral(__array.begin(), __array.end(), __value,
                                        __negative, 8, __ctx,
                                        __value != 0 ? "0" : nullptr);
    }
    case _Flags::_Type::__decimal: {
      array<char, __buffer_size<decltype(__value), 10>()> __array;
      return __format_unsigned_integral(__array.begin(), __array.end(), __value,
                                        __negative, 10, __ctx, nullptr);
    }
    case _Flags::_Type::__hexadecimal_lower_case: {
      array<char, __buffer_size<decltype(__value), 16>()> __array;
      return __format_unsigned_integral(__array.begin(), __array.end(), __value,
                                        __negative, 16, __ctx, "0x");
    }
    case _Flags::_Type::__hexadecimal_upper_case: {
      array<char, __buffer_size<decltype(__value), 16>()> __array;
      return __format_unsigned_integral(__array.begin(), __array.end(), __value,
                                        __negative, 16, __ctx, "0X");
    }
    default:
      _LIBCPP_ASSERT(false, "The parser should have validated the type");
      _LIBCPP_UNREACHABLE();
    }
  }

  template <class _Tp>
  requires(same_as<char, _Tp> || same_as<wchar_t, _Tp>) _LIBCPP_HIDE_FROM_ABI
      auto __write(const _Tp* __first, const _Tp* __last, auto __out_it)
          -> decltype(__out_it) {

    unsigned __size = __last - __first;
    if (this->__type != _Flags::_Type::__hexadecimal_upper_case) [[likely]] {
      if (__size >= this->__width)
        return _VSTD::copy(__first, __last, _VSTD::move(__out_it));

      return __formatter::__write(_VSTD::move(__out_it), __first, __last,
                                  __size, this->__width, this->__fill,
                                  this->__alignment);
    }

    // this->__type == _Flags::_Type::__hexadecimal_upper_case
    // This means all characters in the range [a-f] need to be changed to their
    // uppercase representation. The transformation is done as transformation
    // in the output routine instead of before. This avoids another pass over
    // the data.
    // TODO FMT See whether it's possible to do this transformation during the
    // conversion. (This probably requires changing std::to_chars' alphabet.)
    if (__size >= this->__width)
      return _VSTD::transform(__first, __last, _VSTD::move(__out_it),
                              __hex_to_upper);

    return __formatter::__write(_VSTD::move(__out_it), __first, __last, __size,
                                __hex_to_upper, this->__width, this->__fill,
                                this->__alignment);
  }

  _LIBCPP_HIDE_FROM_ABI auto
  __format_unsigned_integral(char* __begin, char* __end,
                             unsigned_integral auto __value, bool __negative,
                             int __base, auto& __ctx, const char* __prefix)
      -> decltype(__ctx.out()) {
    char* __first = __insert_sign(__begin, __negative, this->__sign);
    if (this->__alternate_form && __prefix)
      while (*__prefix)
        *__first++ = *__prefix++;

    char* __last = __to_buffer(__first, __end, __value, __base);
#ifndef _LIBCPP_HAS_NO_LOCALIZATION
    if (this->__locale_specific_form) {
      const auto& __np = use_facet<numpunct<_CharT>>(__ctx.locale());
      string __grouping = __np.grouping();
      ptrdiff_t __size = __last - __first;
      // Writing the grouped form has more overhead than the normal output
      // routines. If there will be no separators written the locale-specific
      // form is identical to the normal routine. Test whether to grouped form
      // is required.
      if (!__grouping.empty() && __size > __grouping[0])
        return __format_grouping(__ctx.out(), __begin, __first, __last,
                                 __determine_grouping(__size, __grouping),
                                 __np.thousands_sep());
    }
#endif
    auto __out_it = __ctx.out();
    if (this->__alignment != _Flags::_Alignment::__default)
      __first = __begin;
    else {
      // __buf contains [sign][prefix]data
      //                              ^ location of __first
      // The zero padding is done like:
      // - Write [sign][prefix]
      // - Write data right aligned with '0' as fill character.
      __out_it = _VSTD::copy(__begin, __first, _VSTD::move(__out_it));
      this->__alignment = _Flags::_Alignment::__right;
      this->__fill = _CharT('0');
      uint32_t __size = __first - __begin;
      this->__width -= _VSTD::min(__size, this->__width);
    }

    return __write(__first, __last, _VSTD::move(__out_it));
  }

#ifndef _LIBCPP_HAS_NO_LOCALIZATION
  /** Format's the locale-specific form's groupings. */
  template <class _OutIt, class _CharT>
  _LIBCPP_HIDE_FROM_ABI _OutIt
  __format_grouping(_OutIt __out_it, const char* __begin, const char* __first,
                    const char* __last, string&& __grouping, _CharT __sep) {

    // TODO FMT This function duplicates some functionality of the normal
    // output routines. Evaluate whether these parts can be efficiently
    // combined with the existing routines.

    unsigned __size = (__first - __begin) +    // [sign][prefix]
                      (__last - __first) +     // data
                      (__grouping.size() - 1); // number of separator characters

    __formatter::__padding_size_result __padding = {0, 0};
    if (this->__alignment == _Flags::_Alignment::__default) {
      // Write [sign][prefix].
      __out_it = _VSTD::copy(__begin, __first, _VSTD::move(__out_it));

      if (this->__width > __size) {
        // Write zero padding.
        __padding.__before = this->__width - __size;
        __out_it = _VSTD::fill_n(_VSTD::move(__out_it), this->__width - __size,
                                 _CharT('0'));
      }
    } else {
      if (this->__width > __size) {
        // Determine padding and write padding.
        __padding = __formatter::__padding_size(__size, this->__width,
                                                this->__alignment);

        __out_it = _VSTD::fill_n(_VSTD::move(__out_it), __padding.__before,
                                 this->__fill);
      }
      // Write [sign][prefix].
      __out_it = _VSTD::copy(__begin, __first, _VSTD::move(__out_it));
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
    // TODO FMT This loop evaluates the loop invariant `this->__type !=
    // _Flags::_Type::__hexadecimal_upper_case` for every iteration. (This test
    // happens in the __write call.) Benchmark whether making two loops and
    // hoisting the invariant is worth the effort.
    while (true) {
      if (this->__type == _Flags::_Type::__hexadecimal_upper_case) {
        __last = __first + *__r;
        __out_it = _VSTD::transform(__first, __last, _VSTD::move(__out_it),
                                    __hex_to_upper);
        __first = __last;
      } else {
        __out_it = _VSTD::copy_n(__first, *__r, _VSTD::move(__out_it));
        __first += *__r;
      }

      if (__r == __e)
        break;

      ++__r;
      *__out_it++ = __sep;
    }

    return _VSTD::fill_n(_VSTD::move(__out_it), __padding.__after,
                         this->__fill);
  }
#endif // _LIBCPP_HAS_NO_LOCALIZATION
};

} // namespace __format_spec

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___FORMAT_FORMATTER_INTEGRAL_H
