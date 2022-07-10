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

#include <__config>
#include <__format/format_error.h>
#include <__format/format_fwd.h>
#include <__format/format_string.h>
#include <__format/formatter.h>
#include <__format/parser_std_format_spec.h>
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

namespace __format_spec {

template <__formatter::__char_type _CharT>
class _LIBCPP_TEMPLATE_VIS __formatter_string : public __parser_string<_CharT> {
public:
  _LIBCPP_HIDE_FROM_ABI auto format(basic_string_view<_CharT> __str,
                                    auto& __ctx) -> decltype(__ctx.out()) {

    _LIBCPP_ASSERT(this->__alignment != _Flags::_Alignment::__default,
                   "The parser should not use these defaults");

    if (this->__width_needs_substitution())
      this->__substitute_width_arg_id(__ctx.arg(this->__width));

    if (this->__precision_needs_substitution())
      this->__substitute_precision_arg_id(__ctx.arg(this->__precision));

    return __formatter::__write_unicode(
        __ctx.out(), __str, this->__width,
        this->__has_precision_field() ? this->__precision : -1, this->__fill,
        this->__alignment);
  }
};

} //namespace __format_spec

// [format.formatter.spec]/2.2 For each charT, the string type specializations

// Formatter const char*.
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT
    formatter<const _CharT*, _CharT>
    : public __format_spec::__formatter_string<_CharT> {
  using _Base = __format_spec::__formatter_string<_CharT>;

  _LIBCPP_HIDE_FROM_ABI auto format(const _CharT* __str, auto& __ctx)
      -> decltype(__ctx.out()) {
    _LIBCPP_ASSERT(__str, "The basic_format_arg constructor should have "
                          "prevented an invalid pointer.");

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
    if (this->__has_width_field() || this->__has_precision_field())
      return _Base::format(__str, __ctx);

    // No formatting required, copy the string to the output.
    auto __out_it = __ctx.out();
    while (*__str)
      *__out_it++ = *__str++;
    return __out_it;
  }
};

// Formatter char*.
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT
    formatter<_CharT*, _CharT> : public formatter<const _CharT*, _CharT> {
  using _Base = formatter<const _CharT*, _CharT>;

  _LIBCPP_HIDE_FROM_ABI auto format(_CharT* __str, auto& __ctx)
      -> decltype(__ctx.out()) {
    return _Base::format(__str, __ctx);
  }
};

// Formatter const char[].
template <__formatter::__char_type _CharT, size_t _Size>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT
    formatter<const _CharT[_Size], _CharT>
    : public __format_spec::__formatter_string<_CharT> {
  using _Base = __format_spec::__formatter_string<_CharT>;

  _LIBCPP_HIDE_FROM_ABI auto format(const _CharT __str[_Size], auto& __ctx)
      -> decltype(__ctx.out()) {
    return _Base::format(basic_string_view<_CharT>(__str, _Size), __ctx);
  }
};

// Formatter std::string.
template <__formatter::__char_type _CharT, class _Traits, class _Allocator>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT
    formatter<basic_string<_CharT, _Traits, _Allocator>, _CharT>
    : public __format_spec::__formatter_string<_CharT> {
  using _Base = __format_spec::__formatter_string<_CharT>;

  _LIBCPP_HIDE_FROM_ABI auto
  format(const basic_string<_CharT, _Traits, _Allocator>& __str, auto& __ctx)
      -> decltype(__ctx.out()) {
    // drop _Traits and _Allocator
    return _Base::format(basic_string_view<_CharT>(__str.data(), __str.size()), __ctx);
  }
};

// Formatter std::string_view.
template <__formatter::__char_type _CharT, class _Traits>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<basic_string_view<_CharT, _Traits>, _CharT>
    : public __format_spec::__formatter_string<_CharT> {
  using _Base = __format_spec::__formatter_string<_CharT>;

  _LIBCPP_HIDE_FROM_ABI auto
  format(basic_string_view<_CharT, _Traits> __str, auto& __ctx)
      -> decltype(__ctx.out()) {
    // drop _Traits
    return _Base::format(basic_string_view<_CharT>(__str.data(), __str.size()), __ctx);
  }
};

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___FORMAT_FORMATTER_STRING_H
