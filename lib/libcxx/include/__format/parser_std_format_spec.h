// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_PARSER_STD_FORMAT_SPEC_H
#define _LIBCPP___FORMAT_PARSER_STD_FORMAT_SPEC_H

#include <__algorithm/find_if.h>
#include <__algorithm/min.h>
#include <__config>
#include <__debug>
#include <__format/format_arg.h>
#include <__format/format_error.h>
#include <__format/format_string.h>
#include <__variant/monostate.h>
#include <bit>
#include <concepts>
#include <cstdint>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
# pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

// TODO FMT Remove this once we require compilers with proper C++20 support.
// If the compiler has no concepts support, the format header will be disabled.
// Without concepts support enable_if needs to be used and that too much effort
// to support compilers with partial C++20 support.
# if !defined(_LIBCPP_HAS_NO_CONCEPTS)

namespace __format_spec {

/**
 * Contains the flags for the std-format-spec.
 *
 * Some format-options can only be used for specific C++types and may depend on
 * the selected format-type.
 * * The C++type filtering can be done using the proper policies for
 *   @ref __parser_std.
 * * The format-type filtering needs to be done post parsing in the parser
 *   derived from @ref __parser_std.
 */
class _LIBCPP_TYPE_VIS _Flags {
public:
  enum class _LIBCPP_ENUM_VIS _Alignment : uint8_t {
    /**
     * No alignment is set in the format string.
     *
     * Zero-padding is ignored when an alignment is selected.
     * The default alignment depends on the selected format-type.
     */
    __default,
    __left,
    __center,
    __right
  };
  enum class _LIBCPP_ENUM_VIS _Sign : uint8_t {
    /**
     * No sign is set in the format string.
     *
     * The sign isn't allowed for certain format-types. By using this value
     * it's possible to detect whether or not the user explicitly set the sign
     * flag. For formatting purposes it behaves the same as @ref __minus.
     */
    __default,
    __minus,
    __plus,
    __space
  };

  _Alignment __alignment : 2 {_Alignment::__default};
  _Sign __sign : 2 {_Sign::__default};
  uint8_t __alternate_form : 1 {false};
  uint8_t __zero_padding : 1 {false};
  uint8_t __locale_specific_form : 1 {false};

  enum class _LIBCPP_ENUM_VIS _Type : uint8_t {
    __default,
    __string,
    __binary_lower_case,
    __binary_upper_case,
    __octal,
    __decimal,
    __hexadecimal_lower_case,
    __hexadecimal_upper_case,
    __pointer,
    __char,
    __float_hexadecimal_lower_case,
    __float_hexadecimal_upper_case,
    __scientific_lower_case,
    __scientific_upper_case,
    __fixed_lower_case,
    __fixed_upper_case,
    __general_lower_case,
    __general_upper_case
  };

  _Type __type{_Type::__default};
};

namespace __detail {
template <class _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr bool
__parse_alignment(_CharT __c, _Flags& __flags) noexcept {
  switch (__c) {
  case _CharT('<'):
    __flags.__alignment = _Flags::_Alignment::__left;
    return true;

  case _CharT('^'):
    __flags.__alignment = _Flags::_Alignment::__center;
    return true;

  case _CharT('>'):
    __flags.__alignment = _Flags::_Alignment::__right;
    return true;
  }
  return false;
}
} // namespace __detail

template <class _CharT>
class _LIBCPP_TEMPLATE_VIS __parser_fill_align {
public:
  // TODO FMT The standard doesn't specify this character is a Unicode
  // character. Validate what fmt and MSVC have implemented.
  _CharT __fill{_CharT(' ')};

protected:
  _LIBCPP_HIDE_FROM_ABI constexpr const _CharT*
  __parse(const _CharT* __begin, const _CharT* __end, _Flags& __flags) {
    _LIBCPP_ASSERT(__begin != __end,
                   "When called with an empty input the function will cause "
                   "undefined behavior by evaluating data not in the input");
    if (__begin + 1 != __end) {
      if (__detail::__parse_alignment(*(__begin + 1), __flags)) {
        if (*__begin == _CharT('{') || *__begin == _CharT('}'))
          __throw_format_error(
              "The format-spec fill field contains an invalid character");
        __fill = *__begin;
        return __begin + 2;
      }
    }

    if (__detail::__parse_alignment(*__begin, __flags))
      return __begin + 1;

    return __begin;
  }
};

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr const _CharT*
__parse_sign(const _CharT* __begin, _Flags& __flags) noexcept {
  switch (*__begin) {
  case _CharT('-'):
    __flags.__sign = _Flags::_Sign::__minus;
    break;
  case _CharT('+'):
    __flags.__sign = _Flags::_Sign::__plus;
    break;
  case _CharT(' '):
    __flags.__sign = _Flags::_Sign::__space;
    break;
  default:
    return __begin;
  }
  return __begin + 1;
}

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr const _CharT*
__parse_alternate_form(const _CharT* __begin, _Flags& __flags) noexcept {
  if (*__begin == _CharT('#')) {
    __flags.__alternate_form = true;
    ++__begin;
  }

  return __begin;
}

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr const _CharT*
__parse_zero_padding(const _CharT* __begin, _Flags& __flags) noexcept {
  if (*__begin == _CharT('0')) {
    __flags.__zero_padding = true;
    ++__begin;
  }

  return __begin;
}

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr __format::__parse_number_result< _CharT>
__parse_arg_id(const _CharT* __begin, const _CharT* __end, auto& __parse_ctx) {
  // This function is a wrapper to call the real parser. But it does the
  // validation for the pre-conditions and post-conditions.
  if (__begin == __end)
    __throw_format_error("End of input while parsing format-spec arg-id");

  __format::__parse_number_result __r =
      __format::__parse_arg_id(__begin, __end, __parse_ctx);

  if (__r.__ptr == __end || *__r.__ptr != _CharT('}'))
    __throw_format_error("Invalid arg-id");

  ++__r.__ptr;
  return __r;
}

template <class _Context>
_LIBCPP_HIDE_FROM_ABI constexpr uint32_t
__substitute_arg_id(basic_format_arg<_Context> __arg) {
  return visit_format_arg(
      [](auto __arg) -> uint32_t {
        using _Type = decltype(__arg);
        if constexpr (integral<_Type>) {
          if constexpr (signed_integral<_Type>) {
            if (__arg < 0)
              __throw_format_error("A format-spec arg-id replacement shouldn't "
                                   "have a negative value");
          }

          using _CT = common_type_t<_Type, decltype(__format::__number_max)>;
          if (static_cast<_CT>(__arg) >
              static_cast<_CT>(__format::__number_max))
            __throw_format_error("A format-spec arg-id replacement exceeds "
                                 "the maximum supported value");

          return __arg;
        } else if constexpr (same_as<_Type, monostate>)
          __throw_format_error("Argument index out of bounds");
        else
          __throw_format_error("A format-spec arg-id replacement argument "
                               "isn't an integral type");
      },
      __arg);
}

class _LIBCPP_TYPE_VIS __parser_width {
public:
  /** Contains a width or an arg-id. */
  uint32_t __width : 31 {0};
  /** Determines whether the value stored is a width or an arg-id. */
  uint32_t __width_as_arg : 1 {0};

protected:
  /**
   * Does the supplied std-format-spec contain a width field?
   *
   * When the field isn't present there's no padding required. This can be used
   * to optimize the formatting.
   */
  constexpr bool __has_width_field() const noexcept {
    return __width_as_arg || __width;
  }

  /**
   * Does the supplied width field contain an arg-id?
   *
   * If @c true the formatter needs to call @ref __substitute_width_arg_id.
   */
  constexpr bool __width_needs_substitution() const noexcept {
    return __width_as_arg;
  }

  template <class _CharT>
  _LIBCPP_HIDE_FROM_ABI constexpr const _CharT*
  __parse(const _CharT* __begin, const _CharT* __end, auto& __parse_ctx) {
    if (*__begin == _CharT('0'))
      __throw_format_error(
          "A format-spec width field shouldn't have a leading zero");

    if (*__begin == _CharT('{')) {
      __format::__parse_number_result __r =
          __parse_arg_id(++__begin, __end, __parse_ctx);
      __width = __r.__value;
      __width_as_arg = 1;
      return __r.__ptr;
    }

    if (*__begin < _CharT('0') || *__begin > _CharT('9'))
      return __begin;

    __format::__parse_number_result __r =
        __format::__parse_number(__begin, __end);
    __width = __r.__value;
    _LIBCPP_ASSERT(__width != 0,
                   "A zero value isn't allowed and should be impossible, "
                   "due to validations in this function");
    return __r.__ptr;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr void __substitute_width_arg_id(auto __arg) {
    _LIBCPP_ASSERT(__width_as_arg == 1,
                   "Substitute width called when no substitution is required");

    // The clearing of the flag isn't required but looks better when debugging
    // the code.
    __width_as_arg = 0;
    __width = __substitute_arg_id(__arg);
    if (__width == 0)
      __throw_format_error(
          "A format-spec width field replacement should have a positive value");
  }
};

class _LIBCPP_TYPE_VIS __parser_precision {
public:
  /** Contains a precision or an arg-id. */
  uint32_t __precision : 31 {__format::__number_max};
  /**
   * Determines whether the value stored is a precision or an arg-id.
   *
   * @note Since @ref __precision == @ref __format::__number_max is a valid
   * value, the default value contains an arg-id of INT32_MAX. (This number of
   * arguments isn't supported by compilers.)  This is used to detect whether
   * the std-format-spec contains a precision field.
   */
  uint32_t __precision_as_arg : 1 {1};

protected:
  /**
   * Does the supplied std-format-spec contain a precision field?
   *
   * When the field isn't present there's no truncating required. This can be
   * used to optimize the formatting.
   */
  constexpr bool __has_precision_field() const noexcept {

    return __precision_as_arg == 0 ||             // Contains a value?
           __precision != __format::__number_max; // The arg-id is valid?
  }

  /**
   * Does the supplied precision field contain an arg-id?
   *
   * If @c true the formatter needs to call @ref __substitute_precision_arg_id.
   */
  constexpr bool __precision_needs_substitution() const noexcept {
    return __precision_as_arg && __precision != __format::__number_max;
  }

  template <class _CharT>
  _LIBCPP_HIDE_FROM_ABI constexpr const _CharT*
  __parse(const _CharT* __begin, const _CharT* __end, auto& __parse_ctx) {
    if (*__begin != _CharT('.'))
      return __begin;

    ++__begin;
    if (__begin == __end)
      __throw_format_error("End of input while parsing format-spec precision");

    if (*__begin == _CharT('{')) {
      __format::__parse_number_result __arg_id =
          __parse_arg_id(++__begin, __end, __parse_ctx);
      _LIBCPP_ASSERT(__arg_id.__value != __format::__number_max,
                     "Unsupported number of arguments, since this number of "
                     "arguments is used a special value");
      __precision = __arg_id.__value;
      return __arg_id.__ptr;
    }

    if (*__begin < _CharT('0') || *__begin > _CharT('9'))
      __throw_format_error(
          "The format-spec precision field doesn't contain a value or arg-id");

    __format::__parse_number_result __r =
        __format::__parse_number(__begin, __end);
    __precision = __r.__value;
    __precision_as_arg = 0;
    return __r.__ptr;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr void __substitute_precision_arg_id(
      auto __arg) {
    _LIBCPP_ASSERT(
        __precision_as_arg == 1 && __precision != __format::__number_max,
        "Substitute precision called when no substitution is required");

    // The clearing of the flag isn't required but looks better when debugging
    // the code.
    __precision_as_arg = 0;
    __precision = __substitute_arg_id(__arg);
  }
};

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr const _CharT*
__parse_locale_specific_form(const _CharT* __begin, _Flags& __flags) noexcept {
  if (*__begin == _CharT('L')) {
    __flags.__locale_specific_form = true;
    ++__begin;
  }

  return __begin;
}

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr const _CharT*
__parse_type(const _CharT* __begin, _Flags& __flags) {

  // Determines the type. It does not validate whether the selected type is
  // valid. Most formatters have optional fields that are only allowed for
  // certain types. These parsers need to do validation after the type has
  // been parsed. So its easier to implement the validation for all types in
  // the specific parse function.
  switch (*__begin) {
  case 'A':
    __flags.__type = _Flags::_Type::__float_hexadecimal_upper_case;
    break;
  case 'B':
    __flags.__type = _Flags::_Type::__binary_upper_case;
    break;
  case 'E':
    __flags.__type = _Flags::_Type::__scientific_upper_case;
    break;
  case 'F':
    __flags.__type = _Flags::_Type::__fixed_upper_case;
    break;
  case 'G':
    __flags.__type = _Flags::_Type::__general_upper_case;
    break;
  case 'X':
    __flags.__type = _Flags::_Type::__hexadecimal_upper_case;
    break;
  case 'a':
    __flags.__type = _Flags::_Type::__float_hexadecimal_lower_case;
    break;
  case 'b':
    __flags.__type = _Flags::_Type::__binary_lower_case;
    break;
  case 'c':
    __flags.__type = _Flags::_Type::__char;
    break;
  case 'd':
    __flags.__type = _Flags::_Type::__decimal;
    break;
  case 'e':
    __flags.__type = _Flags::_Type::__scientific_lower_case;
    break;
  case 'f':
    __flags.__type = _Flags::_Type::__fixed_lower_case;
    break;
  case 'g':
    __flags.__type = _Flags::_Type::__general_lower_case;
    break;
  case 'o':
    __flags.__type = _Flags::_Type::__octal;
    break;
  case 'p':
    __flags.__type = _Flags::_Type::__pointer;
    break;
  case 's':
    __flags.__type = _Flags::_Type::__string;
    break;
  case 'x':
    __flags.__type = _Flags::_Type::__hexadecimal_lower_case;
    break;
  default:
    return __begin;
  }
  return ++__begin;
}

/**
 * Process the parsed alignment and zero-padding state of arithmetic types.
 *
 * [format.string.std]/13
 *   If the 0 character and an align option both appear, the 0 character is
 *   ignored.
 *
 * For the formatter a @ref __default alignment means zero-padding.
 */
_LIBCPP_HIDE_FROM_ABI constexpr void __process_arithmetic_alignment(_Flags& __flags) {
  __flags.__zero_padding &= __flags.__alignment == _Flags::_Alignment::__default;
  if (!__flags.__zero_padding && __flags.__alignment == _Flags::_Alignment::__default)
    __flags.__alignment = _Flags::_Alignment::__right;
}

/**
 * The parser for the std-format-spec.
 *
 * [format.string.std]/1 specifies the std-format-spec:
 *   fill-and-align sign # 0 width precision L type
 *
 * All these fields are optional. Whether these fields can be used depend on:
 * - The type supplied to the format string.
 *   E.g. A string never uses the sign field so the field may not be set.
 *   This constrain is validated by the parsers in this file.
 * - The supplied value for the optional type field.
 *   E.g. A int formatted as decimal uses the sign field.
 *   When formatted as a char the sign field may no longer be set.
 *   This constrain isn't validated by the parsers in this file.
 *
 * The base classes are ordered to minimize the amount of padding.
 *
 * This implements the parser for the string types.
 */
template <class _CharT>
class _LIBCPP_TEMPLATE_VIS __parser_string
    : public __parser_width,              // provides __width(|as_arg)
      public __parser_precision,          // provides __precision(|as_arg)
      public __parser_fill_align<_CharT>, // provides __fill and uses __flags
      public _Flags                       // provides __flags
{
public:
  using char_type = _CharT;

  _LIBCPP_HIDE_FROM_ABI constexpr __parser_string() {
    this->__alignment = _Flags::_Alignment::__left;
  }

  /**
   * The low-level std-format-spec parse function.
   *
   * @pre __begin points at the beginning of the std-format-spec. This means
   * directly after the ':'.
   * @pre The std-format-spec parses the entire input, or the first unmatched
   * character is a '}'.
   *
   * @returns The iterator pointing at the last parsed character.
   */
  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(auto& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    auto __it = __parse(__parse_ctx);
    __process_display_type();
    return __it;
  }

private:
  /**
   * Parses the std-format-spec.
   *
   * @throws __throw_format_error When @a __parse_ctx contains an ill-formed
   *                               std-format-spec.
   *
   * @returns An iterator to the end of input or point at the closing '}'.
   */
  _LIBCPP_HIDE_FROM_ABI constexpr auto __parse(auto& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {

    auto __begin = __parse_ctx.begin();
    auto __end = __parse_ctx.end();
    if (__begin == __end)
      return __begin;

    __begin = __parser_fill_align<_CharT>::__parse(__begin, __end,
                                                   static_cast<_Flags&>(*this));
    if (__begin == __end)
      return __begin;

    __begin = __parser_width::__parse(__begin, __end, __parse_ctx);
    if (__begin == __end)
      return __begin;

    __begin = __parser_precision::__parse(__begin, __end, __parse_ctx);
    if (__begin == __end)
      return __begin;

    __begin = __parse_type(__begin, static_cast<_Flags&>(*this));

    if (__begin != __end && *__begin != _CharT('}'))
      __throw_format_error(
          "The format-spec should consume the input or end with a '}'");

    return __begin;
  }

  /** Processes the parsed std-format-spec based on the parsed display type. */
  _LIBCPP_HIDE_FROM_ABI constexpr void __process_display_type() {
    switch (this->__type) {
    case _Flags::_Type::__default:
    case _Flags::_Type::__string:
      break;

    default:
      __throw_format_error("The format-spec type has a type not supported for "
                           "a string argument");
    }
  }
};

/**
 * The parser for the std-format-spec.
 *
 * This implements the parser for the integral types. This includes the
 * character type and boolean type.
 *
 * See @ref __parser_string.
 */
template <class _CharT>
class _LIBCPP_TEMPLATE_VIS __parser_integral
    : public __parser_width,              // provides __width(|as_arg)
      public __parser_fill_align<_CharT>, // provides __fill and uses __flags
      public _Flags                       // provides __flags
{
public:
  using char_type = _CharT;

protected:
  /**
   * The low-level std-format-spec parse function.
   *
   * @pre __begin points at the beginning of the std-format-spec. This means
   * directly after the ':'.
   * @pre The std-format-spec parses the entire input, or the first unmatched
   * character is a '}'.
   *
   * @returns The iterator pointing at the last parsed character.
   */
  _LIBCPP_HIDE_FROM_ABI constexpr auto __parse(auto& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    auto __begin = __parse_ctx.begin();
    auto __end = __parse_ctx.end();
    if (__begin == __end)
      return __begin;

    __begin = __parser_fill_align<_CharT>::__parse(__begin, __end,
                                                   static_cast<_Flags&>(*this));
    if (__begin == __end)
      return __begin;

    __begin = __parse_sign(__begin, static_cast<_Flags&>(*this));
    if (__begin == __end)
      return __begin;

    __begin = __parse_alternate_form(__begin, static_cast<_Flags&>(*this));
    if (__begin == __end)
      return __begin;

    __begin = __parse_zero_padding(__begin, static_cast<_Flags&>(*this));
    if (__begin == __end)
      return __begin;

    __begin = __parser_width::__parse(__begin, __end, __parse_ctx);
    if (__begin == __end)
      return __begin;

    __begin =
        __parse_locale_specific_form(__begin, static_cast<_Flags&>(*this));
    if (__begin == __end)
      return __begin;

    __begin = __parse_type(__begin, static_cast<_Flags&>(*this));

    if (__begin != __end && *__begin != _CharT('}'))
      __throw_format_error(
          "The format-spec should consume the input or end with a '}'");

    return __begin;
  }

  /** Handles the post-parsing updates for the integer types. */
  _LIBCPP_HIDE_FROM_ABI constexpr void __handle_integer() noexcept {
    __process_arithmetic_alignment(static_cast<_Flags&>(*this));
  }

  /**
   * Handles the post-parsing updates for the character types.
   *
   * Sets the alignment and validates the format flags set for a character type.
   *
   * At the moment the validation for a character and a Boolean behave the
   * same, but this may change in the future.
   * Specifically at the moment the locale-specific form is allowed for the
   * char output type, but it has no effect on the output.
   */
  _LIBCPP_HIDE_FROM_ABI constexpr void __handle_char() { __handle_bool(); }

  /**
   * Handles the post-parsing updates for the Boolean types.
   *
   * Sets the alignment and validates the format flags set for a Boolean type.
   */
  _LIBCPP_HIDE_FROM_ABI constexpr void __handle_bool() {
    if (this->__sign != _Flags::_Sign::__default)
      __throw_format_error("A sign field isn't allowed in this format-spec");

    if (this->__alternate_form)
      __throw_format_error(
          "An alternate form field isn't allowed in this format-spec");

    if (this->__zero_padding)
      __throw_format_error(
          "A zero-padding field isn't allowed in this format-spec");

    if (this->__alignment == _Flags::_Alignment::__default)
      this->__alignment = _Flags::_Alignment::__left;
  }
};

/**
 * The parser for the std-format-spec.
 *
 * This implements the parser for the floating-point types.
 *
 * See @ref __parser_string.
 */
template <class _CharT>
class _LIBCPP_TEMPLATE_VIS __parser_floating_point
    : public __parser_width,              // provides __width(|as_arg)
      public __parser_precision,          // provides __precision(|as_arg)
      public __parser_fill_align<_CharT>, // provides __fill and uses __flags
      public _Flags                       // provides __flags
{
public:
  using char_type = _CharT;

  /**
   * The low-level std-format-spec parse function.
   *
   * @pre __begin points at the beginning of the std-format-spec. This means
   * directly after the ':'.
   * @pre The std-format-spec parses the entire input, or the first unmatched
   * character is a '}'.
   *
   * @returns The iterator pointing at the last parsed character.
   */
  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(auto& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    auto __it = __parse(__parse_ctx);
    __process_arithmetic_alignment(static_cast<_Flags&>(*this));
    __process_display_type();
    return __it;
  }
protected:
  /**
   * The low-level std-format-spec parse function.
   *
   * @pre __begin points at the beginning of the std-format-spec. This means
   * directly after the ':'.
   * @pre The std-format-spec parses the entire input, or the first unmatched
   * character is a '}'.
   *
   * @returns The iterator pointing at the last parsed character.
   */
  _LIBCPP_HIDE_FROM_ABI constexpr auto __parse(auto& __parse_ctx)
      -> decltype(__parse_ctx.begin()) {
    auto __begin = __parse_ctx.begin();
    auto __end = __parse_ctx.end();
    if (__begin == __end)
      return __begin;

    __begin = __parser_fill_align<_CharT>::__parse(__begin, __end,
                                                   static_cast<_Flags&>(*this));
    if (__begin == __end)
      return __begin;

    __begin = __parse_sign(__begin, static_cast<_Flags&>(*this));
    if (__begin == __end)
      return __begin;

    __begin = __parse_alternate_form(__begin, static_cast<_Flags&>(*this));
    if (__begin == __end)
      return __begin;

    __begin = __parse_zero_padding(__begin, static_cast<_Flags&>(*this));
    if (__begin == __end)
      return __begin;

    __begin = __parser_width::__parse(__begin, __end, __parse_ctx);
    if (__begin == __end)
      return __begin;

    __begin = __parser_precision::__parse(__begin, __end, __parse_ctx);
    if (__begin == __end)
      return __begin;

    __begin =
        __parse_locale_specific_form(__begin, static_cast<_Flags&>(*this));
    if (__begin == __end)
      return __begin;

    __begin = __parse_type(__begin, static_cast<_Flags&>(*this));

    if (__begin != __end && *__begin != _CharT('}'))
      __throw_format_error(
          "The format-spec should consume the input or end with a '}'");

    return __begin;
  }

  /** Processes the parsed std-format-spec based on the parsed display type. */
  _LIBCPP_HIDE_FROM_ABI constexpr void __process_display_type() {
    switch (this->__type) {
    case _Flags::_Type::__default:
      // When no precision specified then it keeps default since that
      // formatting differs from the other types.
      if (this->__has_precision_field())
        this->__type = _Flags::_Type::__general_lower_case;
      break;
    case _Flags::_Type::__float_hexadecimal_lower_case:
    case _Flags::_Type::__float_hexadecimal_upper_case:
      // Precision specific behavior will be handled later.
      break;
    case _Flags::_Type::__scientific_lower_case:
    case _Flags::_Type::__scientific_upper_case:
    case _Flags::_Type::__fixed_lower_case:
    case _Flags::_Type::__fixed_upper_case:
    case _Flags::_Type::__general_lower_case:
    case _Flags::_Type::__general_upper_case:
      if (!this->__has_precision_field()) {
        // Set the default precision for the call to to_chars.
        this->__precision = 6;
        this->__precision_as_arg = false;
      }
      break;

    default:
      __throw_format_error("The format-spec type has a type not supported for "
                           "a floating-point argument");
    }
  }
};

/**
 * The parser for the std-format-spec.
 *
 * This implements the parser for the pointer types.
 *
 * See @ref __parser_string.
 */
template <class _CharT>
class _LIBCPP_TEMPLATE_VIS __parser_pointer : public __parser_width,              // provides __width(|as_arg)
                                              public __parser_fill_align<_CharT>, // provides __fill and uses __flags
                                              public _Flags                       // provides __flags
{
public:
  using char_type = _CharT;

  _LIBCPP_HIDE_FROM_ABI constexpr __parser_pointer() {
    // Implements LWG3612 Inconsistent pointer alignment in std::format.
    // The issue's current status is "Tentatively Ready" and libc++ status is
    // still experimental.
    //
    // TODO FMT Validate this with the final resolution of LWG3612.
    this->__alignment = _Flags::_Alignment::__right;
  }

  /**
   * The low-level std-format-spec parse function.
   *
   * @pre __begin points at the beginning of the std-format-spec. This means
   * directly after the ':'.
   * @pre The std-format-spec parses the entire input, or the first unmatched
   * character is a '}'.
   *
   * @returns The iterator pointing at the last parsed character.
   */
  _LIBCPP_HIDE_FROM_ABI constexpr auto parse(auto& __parse_ctx) -> decltype(__parse_ctx.begin()) {
    auto __it = __parse(__parse_ctx);
    __process_display_type();
    return __it;
  }

protected:
  /**
   * The low-level std-format-spec parse function.
   *
   * @pre __begin points at the beginning of the std-format-spec. This means
   * directly after the ':'.
   * @pre The std-format-spec parses the entire input, or the first unmatched
   * character is a '}'.
   *
   * @returns The iterator pointing at the last parsed character.
   */
  _LIBCPP_HIDE_FROM_ABI constexpr auto __parse(auto& __parse_ctx) -> decltype(__parse_ctx.begin()) {
    auto __begin = __parse_ctx.begin();
    auto __end = __parse_ctx.end();
    if (__begin == __end)
      return __begin;

    __begin = __parser_fill_align<_CharT>::__parse(__begin, __end, static_cast<_Flags&>(*this));
    if (__begin == __end)
      return __begin;

    // An integer presentation type isn't defined in the Standard.
    // Since a pointer is formatted as an integer it can be argued it's an
    // integer presentation type. However there are two LWG-issues asserting it
    // isn't an integer presentation type:
    // - LWG3612 Inconsistent pointer alignment in std::format
    // - LWG3644 std::format does not define "integer presentation type"
    //
    // There's a paper to make additional clarifications on the status of
    // formatting pointers and proposes additional fields to be valid. That
    // paper hasn't been reviewed by the Committee yet.
    // - P2510 Formatting pointers
    //
    // The current implementation assumes formatting pointers isn't covered by
    // "integer presentation type".
    // TODO FMT Apply the LWG-issues/papers after approval/rejection by the Committee.

    __begin = __parser_width::__parse(__begin, __end, __parse_ctx);
    if (__begin == __end)
      return __begin;

    __begin = __parse_type(__begin, static_cast<_Flags&>(*this));

    if (__begin != __end && *__begin != _CharT('}'))
      __throw_format_error("The format-spec should consume the input or end with a '}'");

    return __begin;
  }

  /** Processes the parsed std-format-spec based on the parsed display type. */
  _LIBCPP_HIDE_FROM_ABI constexpr void __process_display_type() {
    switch (this->__type) {
    case _Flags::_Type::__default:
      this->__type = _Flags::_Type::__pointer;
      break;
    case _Flags::_Type::__pointer:
      break;
    default:
      __throw_format_error("The format-spec type has a type not supported for a pointer argument");
    }
  }
};

/** Helper struct returned from @ref __get_string_alignment. */
template <class _CharT>
struct _LIBCPP_TEMPLATE_VIS __string_alignment {
  /** Points beyond the last character to write to the output. */
  const _CharT* __last;
  /**
   * The estimated number of columns in the output or 0.
   *
   * Only when the output needs to be aligned it's required to know the exact
   * number of columns in the output. So if the formatted output has only a
   * minimum width the exact size isn't important. It's only important to know
   * the minimum has been reached. The minimum width is the width specified in
   * the format-spec.
   *
   * For example in this code @code std::format("{:10}", MyString); @endcode
   * the width estimation can stop once the algorithm has determined the output
   * width is 10 columns.
   *
   * So if:
   * * @ref __align == @c true the @ref __size is the estimated number of
   *   columns required.
   * * @ref __align == @c false the @ref __size is the estimated number of
   *   columns required or 0 when the estimation algorithm stopped prematurely.
   */
  ptrdiff_t __size;
  /**
   * Does the output need to be aligned.
   *
   * When alignment is needed the output algorithm needs to add the proper
   * padding. Else the output algorithm just needs to copy the input up to
   * @ref __last.
   */
  bool __align;
};

#ifndef _LIBCPP_HAS_NO_UNICODE
namespace __detail {

/**
 * Unicode column width estimates.
 *
 * Unicode can be stored in several formats: UTF-8, UTF-16, and UTF-32.
 * Depending on format the relation between the number of code units stored and
 * the number of output columns differs. The first relation is the number of
 * code units forming a code point. (The text assumes the code units are
 * unsigned.)
 * - UTF-8 The number of code units is between one and four. The first 127
 *   Unicode code points match the ASCII character set. When the highest bit is
 *   set it means the code point has more than one code unit.
 * - UTF-16: The number of code units is between 1 and 2. When the first
 *   code unit is in the range [0xd800,0xdfff) it means the code point uses two
 *   code units.
 * - UTF-32: The number of code units is always one.
 *
 * The code point to the number of columns isn't well defined. The code uses the
 * estimations defined in [format.string.std]/11. This list might change in the
 * future.
 *
 * The algorithm of @ref __get_string_alignment uses two different scanners:
 * - The simple scanner @ref __estimate_column_width_fast. This scanner assumes
 *   1 code unit is 1 column. This scanner stops when it can't be sure the
 *   assumption is valid:
 *   - UTF-8 when the code point is encoded in more than 1 code unit.
 *   - UTF-16 and UTF-32 when the first multi-column code point is encountered.
 *     (The code unit's value is lower than 0xd800 so the 2 code unit encoding
 *     is irrelevant for this scanner.)
 *   Due to these assumptions the scanner is faster than the full scanner. It
 *   can process all text only containing ASCII. For UTF-16/32 it can process
 *   most (all?) European languages. (Note the set it can process might be
 *   reduced in the future, due to updates in the scanning rules.)
 * - The full scanner @ref __estimate_column_width. This scanner, if needed,
 *   converts multiple code units into one code point then converts the code
 *   point to a column width.
 *
 * See also:
 * - [format.string.general]/11
 * - https://en.wikipedia.org/wiki/UTF-8#Encoding
 * - https://en.wikipedia.org/wiki/UTF-16#U+D800_to_U+DFFF
 */

/**
 * The first 2 column code point.
 *
 * This is the point where the fast UTF-16/32 scanner needs to stop processing.
 */
inline constexpr uint32_t __two_column_code_point = 0x1100;

/** Helper concept for an UTF-8 character type. */
template <class _CharT>
concept __utf8_character = same_as<_CharT, char> || same_as<_CharT, char8_t>;

/** Helper concept for an UTF-16 character type. */
template <class _CharT>
concept __utf16_character = (same_as<_CharT, wchar_t> && sizeof(wchar_t) == 2) || same_as<_CharT, char16_t>;

/** Helper concept for an UTF-32 character type. */
template <class _CharT>
concept __utf32_character = (same_as<_CharT, wchar_t> && sizeof(wchar_t) == 4) || same_as<_CharT, char32_t>;

/** Helper concept for an UTF-16 or UTF-32 character type. */
template <class _CharT>
concept __utf16_or_32_character = __utf16_character<_CharT> || __utf32_character<_CharT>;

/**
 * Converts a code point to the column width.
 *
 * The estimations are conforming to [format.string.general]/11
 *
 * This version expects a value less than 0x1'0000, which is a 3-byte UTF-8
 * character.
 */
_LIBCPP_HIDE_FROM_ABI inline constexpr int __column_width_3(uint32_t __c) noexcept {
  _LIBCPP_ASSERT(__c < 0x1'0000,
                 "Use __column_width_4 or __column_width for larger values");

  // clang-format off
  return 1 + (__c >= 0x1100 && (__c <= 0x115f ||
             (__c >= 0x2329 && (__c <= 0x232a ||
             (__c >= 0x2e80 && (__c <= 0x303e ||
             (__c >= 0x3040 && (__c <= 0xa4cf ||
             (__c >= 0xac00 && (__c <= 0xd7a3 ||
             (__c >= 0xf900 && (__c <= 0xfaff ||
             (__c >= 0xfe10 && (__c <= 0xfe19 ||
             (__c >= 0xfe30 && (__c <= 0xfe6f ||
             (__c >= 0xff00 && (__c <= 0xff60 ||
             (__c >= 0xffe0 && (__c <= 0xffe6
             ))))))))))))))))))));
  // clang-format on
}

/**
 * @overload
 *
 * This version expects a value greater than or equal to 0x1'0000, which is a
 * 4-byte UTF-8 character.
 */
_LIBCPP_HIDE_FROM_ABI inline constexpr int __column_width_4(uint32_t __c) noexcept {
  _LIBCPP_ASSERT(__c >= 0x1'0000,
                 "Use __column_width_3 or __column_width for smaller values");

  // clang-format off
  return 1 + (__c >= 0x1'f300 && (__c <= 0x1'f64f ||
             (__c >= 0x1'f900 && (__c <= 0x1'f9ff ||
             (__c >= 0x2'0000 && (__c <= 0x2'fffd ||
             (__c >= 0x3'0000 && (__c <= 0x3'fffd
             ))))))));
  // clang-format on
}

/**
 * @overload
 *
 * The general case, accepting all values.
 */
_LIBCPP_HIDE_FROM_ABI inline constexpr int __column_width(uint32_t __c) noexcept {
  if (__c < 0x1'0000)
    return __column_width_3(__c);

  return __column_width_4(__c);
}

/**
 * Estimate the column width for the UTF-8 sequence using the fast algorithm.
 */
template <__utf8_character _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr const _CharT*
__estimate_column_width_fast(const _CharT* __first,
                             const _CharT* __last) noexcept {
  return _VSTD::find_if(__first, __last,
                        [](unsigned char __c) { return __c & 0x80; });
}

/**
 * @overload
 *
 * The implementation for UTF-16/32.
 */
template <__utf16_or_32_character _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr const _CharT*
__estimate_column_width_fast(const _CharT* __first,
                             const _CharT* __last) noexcept {
  return _VSTD::find_if(__first, __last,
                        [](uint32_t __c) { return __c >= 0x1100; });
}

template <class _CharT>
struct _LIBCPP_TEMPLATE_VIS __column_width_result {
  /** The number of output columns. */
  size_t __width;
  /**
   * The last parsed element.
   *
   * This limits the original output to fit in the wanted number of columns.
   */
  const _CharT* __ptr;
};

/**
 * Small helper to determine the width of malformed Unicode.
 *
 * @note This function's only needed for UTF-8. During scanning UTF-8 there
 * are multiple place where it can be detected that the Unicode is malformed.
 * UTF-16 only requires 1 test and UTF-32 requires no testing.
 */
template <__utf8_character _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr __column_width_result<_CharT>
__estimate_column_width_malformed(const _CharT* __first, const _CharT* __last,
                                  size_t __maximum, size_t __result) noexcept {
  size_t __size = __last - __first;
  size_t __n = _VSTD::min(__size, __maximum);
  return {__result + __n, __first + __n};
}

/**
 * Determines the number of output columns needed to render the input.
 *
 * @note When the scanner encounters malformed Unicode it acts as-if every code
 * unit at the end of the input is one output column. It's expected the output
 * terminal will replace these malformed code units with a one column
 * replacement characters.
 *
 * @param __first   Points to the first element of the input range.
 * @param __last    Points beyond the last element of the input range.
 * @param __maximum The maximum number of output columns. The returned number
 *                  of estimated output columns will not exceed this value.
 */
template <__utf8_character _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr __column_width_result<_CharT>
__estimate_column_width(const _CharT* __first, const _CharT* __last,
                        size_t __maximum) noexcept {
  size_t __result = 0;

  while (__first != __last) {
    // Based on the number of leading 1 bits the number of code units in the
    // code point can be determined. See
    // https://en.wikipedia.org/wiki/UTF-8#Encoding
    switch (_VSTD::countl_one(static_cast<unsigned char>(*__first))) {
    case 0: // 1-code unit encoding: all 1 column
      ++__result;
      ++__first;
      break;

    case 2: // 2-code unit encoding: all 1 column
      // Malformed Unicode.
      if (__last - __first < 2) [[unlikely]]
        return __estimate_column_width_malformed(__first, __last, __maximum,
                                                 __result);
      __first += 2;
      ++__result;
      break;

    case 3: // 3-code unit encoding: either 1 or 2 columns
      // Malformed Unicode.
      if (__last - __first < 3) [[unlikely]]
        return __estimate_column_width_malformed(__first, __last, __maximum,
                                                 __result);
      {
        uint32_t __c = static_cast<unsigned char>(*__first++) & 0x0f;
        __c <<= 6;
        __c |= static_cast<unsigned char>(*__first++) & 0x3f;
        __c <<= 6;
        __c |= static_cast<unsigned char>(*__first++) & 0x3f;
        __result += __column_width_3(__c);
        if (__result > __maximum)
          return {__result - 2, __first - 3};
      }
      break;
    case 4: // 4-code unit encoding: either 1 or 2 columns
      // Malformed Unicode.
      if (__last - __first < 4) [[unlikely]]
        return __estimate_column_width_malformed(__first, __last, __maximum,
                                                 __result);
      {
        uint32_t __c = static_cast<unsigned char>(*__first++) & 0x07;
        __c <<= 6;
        __c |= static_cast<unsigned char>(*__first++) & 0x3f;
        __c <<= 6;
        __c |= static_cast<unsigned char>(*__first++) & 0x3f;
        __c <<= 6;
        __c |= static_cast<unsigned char>(*__first++) & 0x3f;
        __result += __column_width_4(__c);
        if (__result > __maximum)
          return {__result - 2, __first - 4};
      }
      break;
    default:
      // Malformed Unicode.
      return __estimate_column_width_malformed(__first, __last, __maximum,
                                               __result);
    }

    if (__result >= __maximum)
      return {__result, __first};
  }
  return {__result, __first};
}

template <__utf16_character _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr __column_width_result<_CharT>
__estimate_column_width(const _CharT* __first, const _CharT* __last,
                        size_t __maximum) noexcept {
  size_t __result = 0;

  while (__first != __last) {
    uint32_t __c = *__first;
    // Is the code unit part of a surrogate pair? See
    // https://en.wikipedia.org/wiki/UTF-16#U+D800_to_U+DFFF
    if (__c >= 0xd800 && __c <= 0xDfff) {
      // Malformed Unicode.
      if (__last - __first < 2) [[unlikely]]
        return {__result + 1, __first + 1};

      __c -= 0xd800;
      __c <<= 10;
      __c += (*(__first + 1) - 0xdc00);
      __c += 0x10'000;

      __result += __column_width_4(__c);
      if (__result > __maximum)
        return {__result - 2, __first};
      __first += 2;
    } else {
      __result += __column_width_3(__c);
      if (__result > __maximum)
        return {__result - 2, __first};
      ++__first;
    }

    if (__result >= __maximum)
      return {__result, __first};
  }

  return {__result, __first};
}

template <__utf32_character _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr __column_width_result<_CharT>
__estimate_column_width(const _CharT* __first, const _CharT* __last,
                        size_t __maximum) noexcept {
  size_t __result = 0;

  while (__first != __last) {
    wchar_t __c = *__first;
    __result += __column_width(__c);

    if (__result > __maximum)
      return {__result - 2, __first};

    ++__first;
    if (__result >= __maximum)
      return {__result, __first};
  }

  return {__result, __first};
}

} // namespace __detail

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr __string_alignment<_CharT>
__get_string_alignment(const _CharT* __first, const _CharT* __last,
                       ptrdiff_t __width, ptrdiff_t __precision) noexcept {
  _LIBCPP_ASSERT(__width != 0 || __precision != -1,
                 "The function has no effect and shouldn't be used");

  // TODO FMT There might be more optimizations possible:
  // If __precision == __format::__number_max and the encoding is:
  // * UTF-8  : 4 * (__last - __first) >= __width
  // * UTF-16 : 2 * (__last - __first) >= __width
  // * UTF-32 : (__last - __first) >= __width
  // In these cases it's certain the output is at least the requested width.
  // It's unknown how often this happens in practice. For now the improvement
  // isn't implemented.

  /*
   * First assume there are no special Unicode code units in the input.
   * - Apply the precision (this may reduce the size of the input). When
   *   __precison == -1 this step is omitted.
   * - Scan for special code units in the input.
   * If our assumption was correct the __pos will be at the end of the input.
   */
  const ptrdiff_t __length = __last - __first;
  const _CharT* __limit =
      __first +
      (__precision == -1 ? __length : _VSTD::min(__length, __precision));
  ptrdiff_t __size = __limit - __first;
  const _CharT* __pos =
      __detail::__estimate_column_width_fast(__first, __limit);

  if (__pos == __limit)
    return {__limit, __size, __size < __width};

  /*
   * Our assumption was wrong, there are special Unicode code units.
   * The range [__first, __pos) contains a set of code units with the
   * following property:
   *      Every _CharT in the range will be rendered in 1 column.
   *
   * If there's no maximum width and the parsed size already exceeds the
   *   minimum required width. The real size isn't important. So bail out.
   */
  if (__precision == -1 && (__pos - __first) >= __width)
    return {__last, 0, false};

  /* If there's a __precision, truncate the output to that width. */
  ptrdiff_t __prefix = __pos - __first;
  if (__precision != -1) {
    _LIBCPP_ASSERT(__precision > __prefix, "Logic error.");
    auto __lengh_info = __detail::__estimate_column_width(
        __pos, __last, __precision - __prefix);
    __size = __lengh_info.__width + __prefix;
    return {__lengh_info.__ptr, __size, __size < __width};
  }

  /* Else use __width to determine the number of required padding characters. */
  _LIBCPP_ASSERT(__width > __prefix, "Logic error.");
  /*
   * The column width is always one or two columns. For the precision the wanted
   * column width is the maximum, for the width it's the minimum. Using the
   * width estimation with its truncating behavior will result in the wrong
   * result in the following case:
   * - The last code unit processed requires two columns and exceeds the
   *   maximum column width.
   * By increasing the __maximum by one avoids this issue. (It means it may
   * pass one code point more than required to determine the proper result;
   * that however isn't a problem for the algorithm.)
   */
  size_t __maximum = 1 + __width - __prefix;
  auto __lengh_info =
      __detail::__estimate_column_width(__pos, __last, __maximum);
  if (__lengh_info.__ptr != __last) {
    // Consumed the width number of code units. The exact size of the string
    // is unknown. We only know we don't need to align the output.
    _LIBCPP_ASSERT(static_cast<ptrdiff_t>(__lengh_info.__width + __prefix) >=
                       __width,
                   "Logic error");
    return {__last, 0, false};
  }

  __size = __lengh_info.__width + __prefix;
  return {__last, __size, __size < __width};
}
#else  // _LIBCPP_HAS_NO_UNICODE
template <class _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr __string_alignment<_CharT>
__get_string_alignment(const _CharT* __first, const _CharT* __last,
                       ptrdiff_t __width, ptrdiff_t __precision) noexcept {
  const ptrdiff_t __length = __last - __first;
  const _CharT* __limit =
      __first +
      (__precision == -1 ? __length : _VSTD::min(__length, __precision));
  ptrdiff_t __size = __limit - __first;
  return {__limit, __size, __size < __width};
}
#endif // _LIBCPP_HAS_NO_UNICODE

} // namespace __format_spec

# endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___FORMAT_PARSER_STD_FORMAT_SPEC_H
