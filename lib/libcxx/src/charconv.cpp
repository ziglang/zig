//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "charconv"
#include <string.h>

#include "include/ryu/digit_table.h"
#include "include/to_chars_floating_point.h"

_LIBCPP_BEGIN_NAMESPACE_STD

namespace __itoa
{

template <typename T>
inline _LIBCPP_INLINE_VISIBILITY char*
append1(char* buffer, T i) noexcept
{
    *buffer = '0' + static_cast<char>(i);
    return buffer + 1;
}

template <typename T>
inline _LIBCPP_INLINE_VISIBILITY char*
append2(char* buffer, T i) noexcept
{
    memcpy(buffer, &__DIGIT_TABLE[(i)*2], 2);
    return buffer + 2;
}

template <typename T>
inline _LIBCPP_INLINE_VISIBILITY char*
append3(char* buffer, T i) noexcept
{
    return append2(append1(buffer, (i) / 100), (i) % 100);
}

template <typename T>
inline _LIBCPP_INLINE_VISIBILITY char*
append4(char* buffer, T i) noexcept
{
    return append2(append2(buffer, (i) / 100), (i) % 100);
}

template <typename T>
inline _LIBCPP_INLINE_VISIBILITY char*
append2_no_zeros(char* buffer, T v) noexcept
{
    if (v < 10)
        return append1(buffer, v);
    else
        return append2(buffer, v);
}

template <typename T>
inline _LIBCPP_INLINE_VISIBILITY char*
append4_no_zeros(char* buffer, T v) noexcept
{
    if (v < 100)
        return append2_no_zeros(buffer, v);
    else if (v < 1000)
        return append3(buffer, v);
    else
        return append4(buffer, v);
}

template <typename T>
inline _LIBCPP_INLINE_VISIBILITY char*
append8_no_zeros(char* buffer, T v) noexcept
{
    if (v < 10000)
    {
        buffer = append4_no_zeros(buffer, v);
    }
    else
    {
        buffer = append4_no_zeros(buffer, v / 10000);
        buffer = append4(buffer, v % 10000);
    }
    return buffer;
}

char*
__u32toa(uint32_t value, char* buffer) noexcept
{
    if (value < 100000000)
    {
        buffer = append8_no_zeros(buffer, value);
    }
    else
    {
        // value = aabbbbcccc in decimal
        const uint32_t a = value / 100000000;  // 1 to 42
        value %= 100000000;

        buffer = append2_no_zeros(buffer, a);
        buffer = append4(buffer, value / 10000);
        buffer = append4(buffer, value % 10000);
    }

    return buffer;
}

char*
__u64toa(uint64_t value, char* buffer) noexcept
{
    if (value < 100000000)
    {
        uint32_t v = static_cast<uint32_t>(value);
        buffer = append8_no_zeros(buffer, v);
    }
    else if (value < 10000000000000000)
    {
        const uint32_t v0 = static_cast<uint32_t>(value / 100000000);
        const uint32_t v1 = static_cast<uint32_t>(value % 100000000);

        buffer = append8_no_zeros(buffer, v0);
        buffer = append4(buffer, v1 / 10000);
        buffer = append4(buffer, v1 % 10000);
    }
    else
    {
        const uint32_t a =
            static_cast<uint32_t>(value / 10000000000000000);  // 1 to 1844
        value %= 10000000000000000;

        buffer = append4_no_zeros(buffer, a);

        const uint32_t v0 = static_cast<uint32_t>(value / 100000000);
        const uint32_t v1 = static_cast<uint32_t>(value % 100000000);
        buffer = append4(buffer, v0 / 10000);
        buffer = append4(buffer, v0 % 10000);
        buffer = append4(buffer, v1 / 10000);
        buffer = append4(buffer, v1 % 10000);
    }

    return buffer;
}

}  // namespace __itoa

// The original version of floating-point to_chars was written by Microsoft and
// contributed with the following license.

// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

// This implementation is dedicated to the memory of Mary and Thavatchai.

to_chars_result to_chars(char* __first, char* __last, float __value) {
  return _Floating_to_chars<_Floating_to_chars_overload::_Plain>(__first, __last, __value, chars_format{}, 0);
}

to_chars_result to_chars(char* __first, char* __last, double __value) {
  return _Floating_to_chars<_Floating_to_chars_overload::_Plain>(__first, __last, __value, chars_format{}, 0);
}

to_chars_result to_chars(char* __first, char* __last, long double __value) {
  return _Floating_to_chars<_Floating_to_chars_overload::_Plain>(__first, __last, static_cast<double>(__value),
                                                                 chars_format{}, 0);
}

to_chars_result to_chars(char* __first, char* __last, float __value, chars_format __fmt) {
  return _Floating_to_chars<_Floating_to_chars_overload::_Format_only>(__first, __last, __value, __fmt, 0);
}

to_chars_result to_chars(char* __first, char* __last, double __value, chars_format __fmt) {
  return _Floating_to_chars<_Floating_to_chars_overload::_Format_only>(__first, __last, __value, __fmt, 0);
}

to_chars_result to_chars(char* __first, char* __last, long double __value, chars_format __fmt) {
  return _Floating_to_chars<_Floating_to_chars_overload::_Format_only>(__first, __last, static_cast<double>(__value),
                                                                       __fmt, 0);
}

to_chars_result to_chars(char* __first, char* __last, float __value, chars_format __fmt, int __precision) {
  return _Floating_to_chars<_Floating_to_chars_overload::_Format_precision>(__first, __last, __value, __fmt,
                                                                            __precision);
}

to_chars_result to_chars(char* __first, char* __last, double __value, chars_format __fmt, int __precision) {
  return _Floating_to_chars<_Floating_to_chars_overload::_Format_precision>(__first, __last, __value, __fmt,
                                                                            __precision);
}

to_chars_result to_chars(char* __first, char* __last, long double __value, chars_format __fmt, int __precision) {
  return _Floating_to_chars<_Floating_to_chars_overload::_Format_precision>(
      __first, __last, static_cast<double>(__value), __fmt, __precision);
}

_LIBCPP_END_NAMESPACE_STD
