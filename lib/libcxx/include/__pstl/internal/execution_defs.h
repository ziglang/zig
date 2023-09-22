// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _PSTL_EXECUTION_POLICY_DEFS_H
#define _PSTL_EXECUTION_POLICY_DEFS_H

#include <__config>
#include <__type_traits/decay.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/integral_constant.h>

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

namespace __pstl {
namespace execution {
inline namespace v1 {

// 2.4, Sequential execution policy
class sequenced_policy {};

// 2.5, Parallel execution policy
class parallel_policy {};

// 2.6, Parallel+Vector execution policy
class parallel_unsequenced_policy {};

class unsequenced_policy {};

// 2.8, Execution policy objects
constexpr sequenced_policy seq{};
constexpr parallel_policy par{};
constexpr parallel_unsequenced_policy par_unseq{};
constexpr unsequenced_policy unseq{};

// 2.3, Execution policy type trait
template <class>
struct is_execution_policy : std::false_type {};

template <>
struct is_execution_policy<__pstl::execution::sequenced_policy> : std::true_type {};
template <>
struct is_execution_policy<__pstl::execution::parallel_policy> : std::true_type {};
template <>
struct is_execution_policy<__pstl::execution::parallel_unsequenced_policy> : std::true_type {};
template <>
struct is_execution_policy<__pstl::execution::unsequenced_policy> : std::true_type {};

template <class _Tp>
constexpr bool is_execution_policy_v = __pstl::execution::is_execution_policy<_Tp>::value;
} // namespace v1
} // namespace execution

namespace __internal {
template <class _ExecPolicy, class _Tp>
using __enable_if_execution_policy =
    typename std::enable_if<__pstl::execution::is_execution_policy<typename std::decay<_ExecPolicy>::type>::value,
                            _Tp>::type;

template <class _IsVector>
struct __serial_tag;
template <class _IsVector>
struct __parallel_tag;

} // namespace __internal

} // namespace __pstl

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif /* _PSTL_EXECUTION_POLICY_DEFS_H */
