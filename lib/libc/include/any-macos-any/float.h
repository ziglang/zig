/* Copyright (c) 2017 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 *
 * The contents of this file constitute Original Code as defined in and
 * are subject to the Apple Public Source License Version 1.1 (the
 * "License").  You may not use this file except in compliance with the
 * License.  Please obtain a copy of the License at
 * http://www.apple.com/publicsource and read it before using this file.
 *
 * This Original Code and all software distributed under the License are
 * distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE OR NON-INFRINGEMENT.  Please see the
 * License for the specific language governing rights and limitations
 * under the License.
 *
 * @APPLE_LICENSE_HEADER_END@
 */

#ifndef __FLOAT_H
#define __FLOAT_H

/* Undefine anything that we'll be redefining below. */
#undef FLT_EVAL_METHOD
#undef FLT_ROUNDS
#undef FLT_RADIX
#undef FLT_MANT_DIG
#undef DBL_MANT_DIG
#undef LDBL_MANT_DIG
#undef FLT_DIG
#undef DBL_DIG
#undef LDBL_DIG
#undef FLT_MIN_EXP
#undef DBL_MIN_EXP
#undef LDBL_MIN_EXP
#undef FLT_MIN_10_EXP
#undef DBL_MIN_10_EXP
#undef LDBL_MIN_10_EXP
#undef FLT_MAX_EXP
#undef DBL_MAX_EXP
#undef LDBL_MAX_EXP
#undef FLT_MAX_10_EXP
#undef DBL_MAX_10_EXP
#undef LDBL_MAX_10_EXP
#undef FLT_MAX
#undef DBL_MAX
#undef LDBL_MAX
#undef FLT_EPSILON
#undef DBL_EPSILON
#undef LDBL_EPSILON
#undef FLT_MIN
#undef DBL_MIN
#undef LDBL_MIN

#if __STDC_VERSION__ >= 199901L || !defined(__STRICT_ANSI__)
#  undef DECIMAL_DIG
#endif

#if __STDC_VERSION__ >= 201112L || !defined(__STRICT_ANSI__)
#  undef FLT_HAS_SUBNORM
#  undef DBL_HAS_SUBNORM
#  undef LDBL_HAS_SUBNORM
#  undef FLT_TRUE_MIN
#  undef DBL_TRUE_MIN
#  undef LDBL_TRUE_MIN
#  undef FLT_DECIMAL_DIG
#  undef DBL_DECIMAL_DIG
#  undef LDBL_DECIMAL_DIG
#endif

/* Characteristics of floating point types, C99 5.2.4.2.2 */

#define FLT_EVAL_METHOD __FLT_EVAL_METHOD__
#define FLT_ROUNDS (__builtin_flt_rounds())
#define FLT_RADIX __FLT_RADIX__

#define FLT_MANT_DIG __FLT_MANT_DIG__
#define DBL_MANT_DIG __DBL_MANT_DIG__
#define LDBL_MANT_DIG __LDBL_MANT_DIG__

#define FLT_DIG __FLT_DIG__
#define DBL_DIG __DBL_DIG__
#define LDBL_DIG __LDBL_DIG__

#define FLT_MIN_EXP __FLT_MIN_EXP__
#define DBL_MIN_EXP __DBL_MIN_EXP__
#define LDBL_MIN_EXP __LDBL_MIN_EXP__

#define FLT_MIN_10_EXP __FLT_MIN_10_EXP__
#define DBL_MIN_10_EXP __DBL_MIN_10_EXP__
#define LDBL_MIN_10_EXP __LDBL_MIN_10_EXP__

#define FLT_MAX_EXP __FLT_MAX_EXP__
#define DBL_MAX_EXP __DBL_MAX_EXP__
#define LDBL_MAX_EXP __LDBL_MAX_EXP__

#define FLT_MAX_10_EXP __FLT_MAX_10_EXP__
#define DBL_MAX_10_EXP __DBL_MAX_10_EXP__
#define LDBL_MAX_10_EXP __LDBL_MAX_10_EXP__

#define FLT_MAX __FLT_MAX__
#define DBL_MAX __DBL_MAX__
#define LDBL_MAX __LDBL_MAX__

#define FLT_EPSILON __FLT_EPSILON__
#define DBL_EPSILON __DBL_EPSILON__
#define LDBL_EPSILON __LDBL_EPSILON__

#define FLT_MIN __FLT_MIN__
#define DBL_MIN __DBL_MIN__
#define LDBL_MIN __LDBL_MIN__

#if __STDC_VERSION__ >= 199901L || !defined(__STRICT_ANSI__)
#  define DECIMAL_DIG __DECIMAL_DIG__
#endif

#if __STDC_VERSION__ >= 201112L || !defined(__STRICT_ANSI__)
#  if defined __arm__ /*  On 32-bit arm, denorms are not supported.           */
#    define FLT_HAS_SUBNORM 0
#    define DBL_HAS_SUBNORM 0
#    define LDBL_HAS_SUBNORM 0
#    define FLT_TRUE_MIN __FLT_MIN__
#    define DBL_TRUE_MIN __DBL_MIN__
#    define LDBL_TRUE_MIN __LDBL_MIN__
#  else /* All Apple platforms except 32-bit arm have denorms.                */
#    define FLT_HAS_SUBNORM 1
#    define DBL_HAS_SUBNORM 1
#    define LDBL_HAS_SUBNORM 1
#    define FLT_TRUE_MIN __FLT_DENORM_MIN__
#    define DBL_TRUE_MIN __DBL_DENORM_MIN__
#    define LDBL_TRUE_MIN __LDBL_DENORM_MIN__
#  endif
#  define FLT_DECIMAL_DIG __FLT_DECIMAL_DIG__
#  define DBL_DECIMAL_DIG __DBL_DECIMAL_DIG__
#  define LDBL_DECIMAL_DIG __LDBL_DECIMAL_DIG__
#endif

#endif /* __FLOAT_H */
