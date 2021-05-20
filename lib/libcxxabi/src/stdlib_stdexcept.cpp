//===------------------------ stdexcept.cpp -------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "../../libcxx/src/include/refstring.h"
#include "stdexcept"
#include "new"
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <cstddef>

static_assert(sizeof(std::__libcpp_refstring) == sizeof(const char *), "");

namespace std  // purposefully not using versioning namespace
{

logic_error::~logic_error() _NOEXCEPT {}

const char*
logic_error::what() const _NOEXCEPT
{
    return __imp_.c_str();
}

runtime_error::~runtime_error() _NOEXCEPT {}

const char*
runtime_error::what() const _NOEXCEPT
{
    return __imp_.c_str();
}

domain_error::~domain_error() _NOEXCEPT {}
invalid_argument::~invalid_argument() _NOEXCEPT {}
length_error::~length_error() _NOEXCEPT {}
out_of_range::~out_of_range() _NOEXCEPT {}

range_error::~range_error() _NOEXCEPT {}
overflow_error::~overflow_error() _NOEXCEPT {}
underflow_error::~underflow_error() _NOEXCEPT {}

}  // std
