// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMAT_STRING_H
#define _LIBCPP___FORMAT_FORMAT_STRING_H

#include <__config>
#include <__debug>
#include <__format/format_error.h>
#include <cstddef>
#include <cstdint>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

// TODO FMT Remove this once we require compilers with proper C++20 support.
// If the compiler has no concepts support, the format header will be disabled.
// Without concepts support enable_if needs to be used and that too much effort
// to support compilers with partial C++20 support.
#if !defined(_LIBCPP_HAS_NO_CONCEPTS)

namespace __format {

template <class _CharT>
struct _LIBCPP_TEMPLATE_VIS __parse_number_result {
  const _CharT* __ptr;
  uint32_t __value;
};

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr __parse_number_result<_CharT>
__parse_number(const _CharT* __begin, const _CharT* __end);

/**
 * The maximum value of a numeric argument.
 *
 * This is used for:
 * * arg-id
 * * width as value or arg-id.
 * * precision as value or arg-id.
 *
 * The value is compatible with the maximum formatting width and precision
 * using the `%*` syntax on a 32-bit system.
 */
inline constexpr uint32_t __number_max = INT32_MAX;

namespace __detail {
template <class _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr __parse_number_result<_CharT>
__parse_zero(const _CharT* __begin, const _CharT*, auto& __parse_ctx) {
  __parse_ctx.check_arg_id(0);
  return {++__begin, 0}; // can never be larger than the maximum.
}

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr __parse_number_result<_CharT>
__parse_automatic(const _CharT* __begin, const _CharT*, auto& __parse_ctx) {
  size_t __value = __parse_ctx.next_arg_id();
  _LIBCPP_ASSERT(__value <= __number_max,
                 "Compilers don't support this number of arguments");

  return {__begin, uint32_t(__value)};
}

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr __parse_number_result<_CharT>
__parse_manual(const _CharT* __begin, const _CharT* __end, auto& __parse_ctx) {
  __parse_number_result<_CharT> __r = __parse_number(__begin, __end);
  __parse_ctx.check_arg_id(__r.__value);
  return __r;
}

} // namespace __detail

/**
 * Parses a number.
 *
 * The number is used for the 31-bit values @em width and @em precision. This
 * allows a maximum value of 2147483647.
 */
template <class _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr __parse_number_result<_CharT>
__parse_number(const _CharT* __begin, const _CharT* __end_input) {
  static_assert(__format::__number_max == INT32_MAX,
                "The algorithm is implemented based on this value.");
  /*
   * Limit the input to 9 digits, otherwise we need two checks during every
   * iteration:
   * - Are we at the end of the input?
   * - Does the value exceed width of an uint32_t? (Switching to uint64_t would
   *   have the same issue, but with a higher maximum.)
   */
  const _CharT* __end = __end_input - __begin > 9 ? __begin + 9 : __end_input;
  uint32_t __value = *__begin - _CharT('0');
  while (++__begin != __end) {
    if (*__begin < _CharT('0') || *__begin > _CharT('9'))
      return {__begin, __value};

    __value = __value * 10 + *__begin - _CharT('0');
  }

  if (__begin != __end_input && *__begin >= _CharT('0') &&
      *__begin <= _CharT('9')) {

    /*
     * There are more than 9 digits, do additional validations:
     * - Does the 10th digit exceed the maximum allowed value?
     * - Are there more than 10 digits?
     * (More than 10 digits always overflows the maximum.)
     */
    uint64_t __v = uint64_t(__value) * 10 + *__begin++ - _CharT('0');
    if (__v > __number_max ||
        (__begin != __end_input && *__begin >= _CharT('0') &&
         *__begin <= _CharT('9')))
      __throw_format_error("The numeric value of the format-spec is too large");

    __value = __v;
  }

  return {__begin, __value};
}

/**
 * Multiplexer for all parse functions.
 *
 * The parser will return a pointer beyond the last consumed character. This
 * should be the closing '}' of the arg-id.
 */
template <class _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr __parse_number_result<_CharT>
__parse_arg_id(const _CharT* __begin, const _CharT* __end, auto& __parse_ctx) {
  switch (*__begin) {
  case _CharT('0'):
    return __detail::__parse_zero(__begin, __end, __parse_ctx);

  case _CharT(':'):
    // This case is conditionally valid. It's allowed in an arg-id in the
    // replacement-field, but not in the std-format-spec. The caller can
    // provide a better diagnostic, so accept it here unconditionally.
  case _CharT('}'):
    return __detail::__parse_automatic(__begin, __end, __parse_ctx);
  }
  if (*__begin < _CharT('0') || *__begin > _CharT('9'))
    __throw_format_error(
        "The arg-id of the format-spec starts with an invalid character");

  return __detail::__parse_manual(__begin, __end, __parse_ctx);
}

} // namespace __format

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FORMAT_FORMAT_STRING_H
