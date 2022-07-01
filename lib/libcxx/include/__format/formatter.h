// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMATTER_H
#define _LIBCPP___FORMAT_FORMATTER_H

#include <__algorithm/copy.h>
#include <__algorithm/fill_n.h>
#include <__availability>
#include <__config>
#include <__format/format_error.h>
#include <__format/format_fwd.h>
#include <__format/format_string.h>
#include <__format/parser_std_format_spec.h>
#include <concepts>
#include <string_view>

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

/// The default formatter template.
///
/// [format.formatter.spec]/5
/// If F is a disabled specialization of formatter, these values are false:
/// - is_default_constructible_v<F>,
/// - is_copy_constructible_v<F>,
/// - is_move_constructible_v<F>,
/// - is_copy_assignable<F>, and
/// - is_move_assignable<F>.
template <class _Tp, class _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter {
  formatter() = delete;
  formatter(const formatter&) = delete;
  formatter& operator=(const formatter&) = delete;
};

namespace __format_spec {

_LIBCPP_HIDE_FROM_ABI inline char* __insert_sign(char* __buf, bool __negative,
                                                 _Flags::_Sign __sign) {
  if (__negative)
    *__buf++ = '-';
  else
    switch (__sign) {
    case _Flags::_Sign::__default:
    case _Flags::_Sign::__minus:
      // No sign added.
      break;
    case _Flags::_Sign::__plus:
      *__buf++ = '+';
      break;
    case _Flags::_Sign::__space:
      *__buf++ = ' ';
      break;
    }

  return __buf;
}

_LIBCPP_HIDE_FROM_ABI constexpr char __hex_to_upper(char c) {
  switch (c) {
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
  return c;
}

} // namespace __format_spec

namespace __formatter {

/** The character types that formatters are specialized for. */
template <class _CharT>
concept __char_type = same_as<_CharT, char> || same_as<_CharT, wchar_t>;

struct _LIBCPP_TEMPLATE_VIS __padding_size_result {
  size_t __before;
  size_t __after;
};

_LIBCPP_HIDE_FROM_ABI constexpr __padding_size_result
__padding_size(size_t __size, size_t __width,
               __format_spec::_Flags::_Alignment __align) {
  _LIBCPP_ASSERT(__width > __size,
                 "Don't call this function when no padding is required");
  _LIBCPP_ASSERT(
      __align != __format_spec::_Flags::_Alignment::__default,
      "Caller should adjust the default to the value required by the type");

  size_t __fill = __width - __size;
  switch (__align) {
  case __format_spec::_Flags::_Alignment::__default:
    _LIBCPP_UNREACHABLE();

  case __format_spec::_Flags::_Alignment::__left:
    return {0, __fill};

  case __format_spec::_Flags::_Alignment::__center: {
    // The extra padding is divided per [format.string.std]/3
    // __before = floor(__fill, 2);
    // __after = ceil(__fill, 2);
    size_t __before = __fill / 2;
    size_t __after = __fill - __before;
    return {__before, __after};
  }
  case __format_spec::_Flags::_Alignment::__right:
    return {__fill, 0};
  }
  _LIBCPP_UNREACHABLE();
}

/**
 * Writes the input to the output with the required padding.
 *
 * Since the output column width is specified the function can be used for
 * ASCII and Unicode input.
 *
 * @pre [@a __first, @a __last) is a valid range.
 * @pre @a __size <= @a __width. Using this function when this pre-condition
 *      doesn't hold incurs an unwanted overhead.
 *
 * @param __out_it    The output iterator to write to.
 * @param __first     Pointer to the first element to write.
 * @param __last      Pointer beyond the last element to write.
 * @param __size      The (estimated) output column width. When the elements
 *                    to be written are ASCII the following condition holds
 *                    @a __size == @a __last - @a __first.
 * @param __width     The number of output columns to write.
 * @param __fill      The character used for the alignment of the output.
 *                    TODO FMT Will probably change to support Unicode grapheme
 *                    cluster.
 * @param __alignment The requested alignment.
 *
 * @returns           An iterator pointing beyond the last element written.
 *
 * @note The type of the elements in range [@a __first, @a __last) can differ
 * from the type of @a __fill. Integer output uses @c std::to_chars for its
 * conversion, which means the [@a __first, @a __last) always contains elements
 * of the type @c char.
 */
template <class _CharT, class _Fill>
_LIBCPP_HIDE_FROM_ABI auto
__write(output_iterator<const _CharT&> auto __out_it, const _CharT* __first,
        const _CharT* __last, size_t __size, size_t __width, _Fill __fill,
        __format_spec::_Flags::_Alignment __alignment) -> decltype(__out_it) {

  _LIBCPP_ASSERT(__first <= __last, "Not a valid range");
  _LIBCPP_ASSERT(__size < __width, "Precondition failure");

  __padding_size_result __padding =
      __padding_size(__size, __width, __alignment);
  __out_it = _VSTD::fill_n(_VSTD::move(__out_it), __padding.__before, __fill);
  __out_it = _VSTD::copy(__first, __last, _VSTD::move(__out_it));
  return _VSTD::fill_n(_VSTD::move(__out_it), __padding.__after, __fill);
}

/**
 * @overload
 *
 * Writes additional zero's for the precision before the exponent.
 * This is used when the precision requested in the format string is larger
 * than the maximum precision of the floating-point type. These precision
 * digits are always 0.
 *
 * @param __exponent           The location of the exponent character.
 * @param __num_trailing_zeros The number of 0's to write before the exponent
 *                             character.
 */
template <class _CharT, class _Fill>
_LIBCPP_HIDE_FROM_ABI auto __write(output_iterator<const _CharT&> auto __out_it, const _CharT* __first,
                                   const _CharT* __last, size_t __size, size_t __width, _Fill __fill,
                                   __format_spec::_Flags::_Alignment __alignment, const _CharT* __exponent,
                                   size_t __num_trailing_zeros) -> decltype(__out_it) {
  _LIBCPP_ASSERT(__first <= __last, "Not a valid range");
  _LIBCPP_ASSERT(__num_trailing_zeros > 0, "The overload not writing trailing zeros should have been used");

  __padding_size_result __padding = __padding_size(__size + __num_trailing_zeros, __width, __alignment);
  __out_it = _VSTD::fill_n(_VSTD::move(__out_it), __padding.__before, __fill);
  __out_it = _VSTD::copy(__first, __exponent, _VSTD::move(__out_it));
  __out_it = _VSTD::fill_n(_VSTD::move(__out_it), __num_trailing_zeros, _CharT('0'));
  __out_it = _VSTD::copy(__exponent, __last, _VSTD::move(__out_it));
  return _VSTD::fill_n(_VSTD::move(__out_it), __padding.__after, __fill);
}

/**
 * @overload
 *
 * Uses a transformation operation before writing an element.
 *
 * TODO FMT Fill will probably change to support Unicode grapheme cluster.
 */
template <class _CharT, class _UnaryOperation, class _Fill>
_LIBCPP_HIDE_FROM_ABI auto
__write(output_iterator<const _CharT&> auto __out_it, const _CharT* __first,
        const _CharT* __last, size_t __size, _UnaryOperation __op,
        size_t __width, _Fill __fill,
        __format_spec::_Flags::_Alignment __alignment) -> decltype(__out_it) {

  _LIBCPP_ASSERT(__first <= __last, "Not a valid range");
  _LIBCPP_ASSERT(__size < __width, "Precondition failure");

  __padding_size_result __padding =
      __padding_size(__size, __width, __alignment);
  __out_it = _VSTD::fill_n(_VSTD::move(__out_it), __padding.__before, __fill);
  __out_it = _VSTD::transform(__first, __last, _VSTD::move(__out_it), __op);
  return _VSTD::fill_n(_VSTD::move(__out_it), __padding.__after, __fill);
}

/**
 * Writes Unicode input to the output with the required padding.
 *
 * This function does almost the same as the @ref __write function, but handles
 * the width estimation of the Unicode input.
 *
 * @param __str       The range [@a __first, @a __last).
 * @param __precision The width to truncate the input string to, use @c -1 for
 *                     no limit.
 */
template <class _CharT, class _Fill>
_LIBCPP_HIDE_FROM_ABI auto
__write_unicode(output_iterator<const _CharT&> auto __out_it,
                basic_string_view<_CharT> __str, ptrdiff_t __width,
                ptrdiff_t __precision, _Fill __fill,
                __format_spec::_Flags::_Alignment __alignment)
    -> decltype(__out_it) {

  // This value changes when there Unicode column width limits the output
  // size.
  auto __last = __str.end();
  if (__width != 0 || __precision != -1) {
    __format_spec::__string_alignment<_CharT> __format_traits =
        __format_spec::__get_string_alignment(__str.begin(), __str.end(),
                                              __width, __precision);

    if (__format_traits.__align)
      return __write(_VSTD::move(__out_it), __str.begin(),
                     __format_traits.__last, __format_traits.__size, __width,
                     __fill, __alignment);

    // No alignment required update the output based on the precision.
    // This might be the same as __str.end().
    __last = __format_traits.__last;
  }

  // Copy the input to the output. The output size might be limited by the
  // precision.
  return _VSTD::copy(__str.begin(), __last, _VSTD::move(__out_it));
}

} // namespace __formatter

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___FORMAT_FORMATTER_H
