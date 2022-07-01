// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMATTER_POINTER_H
#define _LIBCPP___FORMAT_FORMATTER_POINTER_H

#include <__algorithm/copy.h>
#include <__availability>
#include <__config>
#include <__debug>
#include <__format/format_error.h>
#include <__format/format_fwd.h>
#include <__format/formatter.h>
#include <__format/formatter_integral.h>
#include <__format/parser_std_format_spec.h>
#include <__iterator/access.h>
#include <__nullptr>
#include <cstdint>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

// TODO FMT Remove this once we require compilers with proper C++20 support.
// If the compiler has no concepts support, the format header will be disabled.
// Without concepts support enable_if needs to be used and that too much effort
// to support compilers with partial C++20 support.
#  if !defined(_LIBCPP_HAS_NO_CONCEPTS)

namespace __format_spec {

template <__formatter::__char_type _CharT>
class _LIBCPP_TEMPLATE_VIS __formatter_pointer : public __parser_pointer<_CharT> {
public:
  _LIBCPP_HIDE_FROM_ABI auto format(const void* __ptr, auto& __ctx) -> decltype(__ctx.out()) {
    _LIBCPP_ASSERT(this->__alignment != _Flags::_Alignment::__default,
                   "The call to parse should have updated the alignment");
    if (this->__width_needs_substitution())
      this->__substitute_width_arg_id(__ctx.arg(this->__width));

    // This code looks a lot like the code to format a hexadecimal integral,
    // but that code isn't public. Making that code public requires some
    // refactoring.
    // TODO FMT Remove code duplication.
    char __buffer[2 + 2 * sizeof(uintptr_t)];
    __buffer[0] = '0';
    __buffer[1] = 'x';
    char* __last = __to_buffer(__buffer + 2, _VSTD::end(__buffer), reinterpret_cast<uintptr_t>(__ptr), 16);

    unsigned __size = __last - __buffer;
    if (__size >= this->__width)
      return _VSTD::copy(__buffer, __last, __ctx.out());

    return __formatter::__write(__ctx.out(), __buffer, __last, __size, this->__width, this->__fill, this->__alignment);
  }
};

} // namespace __format_spec

// [format.formatter.spec]/2.4
// For each charT, the pointer type specializations template<>
// - struct formatter<nullptr_t, charT>;
// - template<> struct formatter<void*, charT>;
// - template<> struct formatter<const void*, charT>;
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<nullptr_t, _CharT>
    : public __format_spec::__formatter_pointer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<void*, _CharT>
    : public __format_spec::__formatter_pointer<_CharT> {};
template <__formatter::__char_type _CharT>
struct _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT formatter<const void*, _CharT>
    : public __format_spec::__formatter_pointer<_CharT> {};

#  endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FORMAT_FORMATTER_POINTER_H
