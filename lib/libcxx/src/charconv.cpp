//===------------------------- charconv.cpp -------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "charconv"
#include <string.h>

_LIBCPP_BEGIN_NAMESPACE_STD

namespace __itoa
{

static constexpr char cDigitsLut[200] = {
    '0', '0', '0', '1', '0', '2', '0', '3', '0', '4', '0', '5', '0', '6', '0',
    '7', '0', '8', '0', '9', '1', '0', '1', '1', '1', '2', '1', '3', '1', '4',
    '1', '5', '1', '6', '1', '7', '1', '8', '1', '9', '2', '0', '2', '1', '2',
    '2', '2', '3', '2', '4', '2', '5', '2', '6', '2', '7', '2', '8', '2', '9',
    '3', '0', '3', '1', '3', '2', '3', '3', '3', '4', '3', '5', '3', '6', '3',
    '7', '3', '8', '3', '9', '4', '0', '4', '1', '4', '2', '4', '3', '4', '4',
    '4', '5', '4', '6', '4', '7', '4', '8', '4', '9', '5', '0', '5', '1', '5',
    '2', '5', '3', '5', '4', '5', '5', '5', '6', '5', '7', '5', '8', '5', '9',
    '6', '0', '6', '1', '6', '2', '6', '3', '6', '4', '6', '5', '6', '6', '6',
    '7', '6', '8', '6', '9', '7', '0', '7', '1', '7', '2', '7', '3', '7', '4',
    '7', '5', '7', '6', '7', '7', '7', '8', '7', '9', '8', '0', '8', '1', '8',
    '2', '8', '3', '8', '4', '8', '5', '8', '6', '8', '7', '8', '8', '8', '9',
    '9', '0', '9', '1', '9', '2', '9', '3', '9', '4', '9', '5', '9', '6', '9',
    '7', '9', '8', '9', '9'};

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
    memcpy(buffer, &cDigitsLut[(i)*2], 2);
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
__u32toa(uint32_t value, char* buffer) _NOEXCEPT
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
__u64toa(uint64_t value, char* buffer) _NOEXCEPT
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

_LIBCPP_END_NAMESPACE_STD
