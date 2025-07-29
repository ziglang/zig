/*-
 * Copyright (c) 2023 Dag-Erling Smørgrav
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef __STDC_VERSION_STDCKDINT_H__
#define __STDC_VERSION_STDCKDINT_H__ 202311L

#include <sys/cdefs.h>

#if __BSD_VISIBLE || __ISO_C_VISIBLE >= 2023

#if __GNUC_PREREQ__(5, 1) || __has_builtin(__builtin_add_overflow)
#define ckd_add(result, a, b)						\
	(_Bool)__builtin_add_overflow((a), (b), (result))
#else
#define ckd_add(result, a, b)						\
	_Static_assert(0, "checked addition not supported")
#endif

#if __GNUC_PREREQ__(5, 1) || __has_builtin(__builtin_sub_overflow)
#define ckd_sub(result, a, b)						\
	(_Bool)__builtin_sub_overflow((a), (b), (result))
#else
#define ckd_sub(result, a, b)						\
	_Static_assert(0, "checked subtraction not supported")
#endif

#if __GNUC_PREREQ__(5, 1) || __has_builtin(__builtin_mul_overflow)
#define ckd_mul(result, a, b)						\
	(_Bool)__builtin_mul_overflow((a), (b), (result))
#else
#define ckd_mul(result, a, b)						\
	_Static_assert(0, "checked multiplication not supported")
#endif

#endif

#endif