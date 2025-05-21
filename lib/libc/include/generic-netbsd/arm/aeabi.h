/*	$NetBSD: aeabi.h,v 1.6 2021/10/06 05:33:15 skrll Exp $	*/

/*-
 * Copyright (c) 2012 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
#ifndef _ARM_AEABI_H_
#define	_ARM_AEABI_H_

#if defined(_KERNEL) || defined(_STANDALONE)
#include <sys/types.h>
#else
#include <stddef.h>
#endif

#define	__value_in_regs		/* nothing */
#define	__aapcs			__attribute__((__pcs__("aapcs")))

/*
 * Standard double precision floating-point arithmetic helper functions
 */
double __aeabi_dadd(double, double) __aapcs;	// double-precision addition
double __aeabi_ddiv(double n, double d) __aapcs;	// double-precision division, n / d
double __aeabi_dmul(double, double) __aapcs;	// double-precision multiplication
double __aeabi_drsub(double x, double y) __aapcs;	// double-precision reverse subtraction, y - x
double __aeabi_dsub(double x, double y) __aapcs;	// double-precision subtraction, x - y
double __aeabi_dneg(double) __aapcs;	// double-precision negation (obsolete, to be removed in r2.09)

/*
 * Double precision floating-point comparison helper functions
 */
void __aeabi_cdcmpeq(double, double) __aapcs; // non-excepting equality comparison [1], result in PSR ZC flags
void __aeabi_cdcmple(double, double) __aapcs; // 3-way (<, =, >) compare [1], result in PSR ZC flags
void __aeabi_cdrcmple(double, double) __aapcs; // reversed 3-way (<, =, >) compare [1], result in PSR ZC flags
int __aeabi_dcmpeq(double, double) __aapcs; // result (1, 0) denotes (=, <>) [2], use for C == and !=
int __aeabi_dcmplt(double, double) __aapcs; // result (1, 0) denotes (<, >=) [2], use for C <
int __aeabi_dcmple(double, double) __aapcs; // result (1, 0) denotes (<=, >) [2], use for C <=
int __aeabi_dcmpge(double, double) __aapcs; // result (1, 0) denotes (>=, <) [2], use for C >=
int __aeabi_dcmpgt(double, double) __aapcs; // result (1, 0) denotes (>, <=) [2], use for C >
int __aeabi_dcmpun(double, double) __aapcs; // result (1, 0) denotes (?, <=>) [2], use for C99 isunordered()

/*
 * Standard single precision floating-point arithmetic helper functions
 */
float __aeabi_fadd(float, float) __aapcs; // single-precision addition
float __aeabi_fdiv(float n, float d) __aapcs; // single-precision division, n / d
float __aeabi_fmul(float, float) __aapcs; // single-precision multiplication
float __aeabi_frsub(float x, float y) __aapcs; // single-precision reverse subtraction, y - x
float __aeabi_fsub(float x, float y) __aapcs; // single-precision subtraction, x - y
float __aeabi_fneg(float) __aapcs; // single-precision negation (obsolete, to be removed in r2.09)

/*
 * Standard single precision floating-point comparison helper functions
 */
void __aeabi_cfcmpeq(float, float) __aapcs; // non-excepting equality comparison [1], result in PSR ZC flags
void __aeabi_cfcmple(float, float) __aapcs; // 3-way (<, =, ?>) compare [1], result in PSR ZC flags
void __aeabi_cfrcmple(float, float) __aapcs; // reversed 3-way (<, =, ?>) compare [1], result in PSR ZC flags
int __aeabi_fcmpeq(float, float) __aapcs; // result (1, 0) denotes (=, <>) [2], use for C == and !=
int __aeabi_fcmplt(float, float) __aapcs; // result (1, 0) denotes (<, >=) [2], use for C <
int __aeabi_fcmple(float, float) __aapcs; // result (1, 0) denotes (<=, >) [2], use for C <=
int __aeabi_fcmpge(float, float) __aapcs; // result (1, 0) denotes (>=, <) [2], use for C >=
int __aeabi_fcmpgt(float, float) __aapcs; // result (1, 0) denotes (>, <=) [2], use for C >
int __aeabi_fcmpun(float, float) __aapcs; // result (1, 0) denotes (?, <=>) [2], use for C99 isunordered()

/*
 * Standard conversions between floating types
 */
float __aeabi_d2f(double) __aapcs;	// double to float (single precision) conversion
double __aeabi_f2d(float) __aapcs;	// float (single precision) to double conversion
float __aeabi_h2f(short hf) __aapcs;	// IEEE 754 binary16 storage format (VFP half precision) to binary32 (float) conversion [4, 5]
short __aeabi_f2h(float f) __aapcs;	// IEEE 754 binary32 (float) to binary16 storage format (VFP half precision) conversion [4, 6]
float __aeabi_h2f_alt(short hf) __aapcs;	// __aeabi_h2f_alt converts from VFP alternative format [7].
short __aeabi_f2h_alt(float f) __aapcs;	// __aeabi_f2h_alt converts to VFP alternative format [8].

/*
 * Standard floating-point to integer conversions
 */
int __aeabi_d2iz(double) __aapcs;	// double to integer C-style conversion [3]
unsigned __aeabi_d2uiz(double) __aapcs;	// double to unsigned C-style conversion [3]
long long __aeabi_d2lz(double) __aapcs;	// double to long long C-style conversion [3]
unsigned long long __aeabi_d2ulz(double) __aapcs;	// double to unsigned long long C-style conversion [3]
int __aeabi_f2iz(float) __aapcs;	// float (single precision) to integer C-style conversion [3]
unsigned __aeabi_f2uiz(float) __aapcs;	// float (single precision) to unsigned C-style conversion [3]
long long __aeabi_f2lz(float) __aapcs;	// float (single precision) to long long C-style conversion [3]
unsigned long long __aeabi_f2ulz(float) __aapcs;	// float to unsigned long long C-style conversion [3]

/*
 * Standard integer to floating-point conversions
 */
double __aeabi_i2d(int) __aapcs;		// integer to double conversion
double __aeabi_ui2d(unsigned) __aapcs;	// unsigned to double conversion
double __aeabi_l2d(long long) __aapcs;	// long long to double conversion
double __aeabi_ul2d(unsigned long long) __aapcs;	// unsigned long long to double conversion
float __aeabi_i2f(int) __aapcs;	// integer to float (single precision) conversion
float __aeabi_ui2f(unsigned) __aapcs;	// unsigned to float (single precision) conversion
float __aeabi_l2f(long long) __aapcs;	// long long to float (single precision) conversion
float __aeabi_ul2f(unsigned long long) __aapcs;	// ￼unsigned long long to float (single precision) conversion

/*
 * Long long functions
 */
long long __aeabi_lmul(long long, long long); // multiplication

/*
 * A pair of (unsigned) long longs is returned in {{r0, r1}, {r2, r3}},
 * the quotient in {r0, r1}, and the remainder in {r2, r3}.
 */
typedef struct { long long quot; long long rem; } lldiv_t;
__value_in_regs lldiv_t __aeabi_ldivmod(long long n, long long d); // signed long long division and remainder, {q, r} = n / d [2]

typedef struct { unsigned long long quot; unsigned long long rem; } ulldiv_t;
__value_in_regs ulldiv_t __aeabi_uldivmod(unsigned long long n, unsigned long long d); // unsigned signed ll division, remainder, {q, r} = n / d [2]

/*
 * Because of 2's complement number representation, these functions work
 * identically with long long replaced uniformly by unsigned long long.
 * Each returns its result in {r0, r1}, as specified by the [AAPCS].
 */
long long __aeabi_llsl(long long, int); // logical shift left [1]
long long __aeabi_llsr(long long, int); // logical shift right [1]
long long __aeabi_lasr(long long, int); // arithmetic shift right [1]

/*
 * The comparison functions return negative, zero, or a positive integer
 * according to whether the comparison result is <, ==, or >, respectively
 * (like strcmp).
 */
int __aeabi_lcmp(long long, long long); // signed long long comparison
int __aeabi_ulcmp(unsigned long long, unsigned long long); // unsigned long long comparison

int __aeabi_idiv(int numerator, int denominator);
unsigned __aeabi_uidiv(unsigned numerator, unsigned denominator);
typedef struct { int quot, rem; } idiv_return;
typedef struct { unsigned int quot, rem; } uidiv_return;
__value_in_regs idiv_return __aeabi_idivmod(int, int);
__value_in_regs uidiv_return __aeabi_uidivmod(unsigned int, unsigned int);

/*
 * Division by zero
 *
 * If an integer or long long division helper function is called upon to
 * divide by 0, it should return as quotient the value returned by a call
 * to __aeabi_idiv0 or __aeabi_ldiv0, respectively. A *divmod helper should
 * return as remainder either 0 or the original numerator.
 */
int __aeabi_idiv0(int);
long long __aeabi_ldiv0(long long);

/*
 * These functions read and write 4-byte and 8-byte values at arbitrarily
 * aligned addresses.  Write functions return the value written,
 * read functions the value read.
 */
int __aeabi_uread4(void *);
int __aeabi_uwrite4(int, void *);
long long __aeabi_uread8(void *);
long long __aeabi_uwrite8(long long, void *);

/*
 * Memory copying, clearing, and setting
 */
void __aeabi_memcpy8(void *, const void *, size_t);
void __aeabi_memcpy4(void *, const void *, size_t);
void __aeabi_memcpy(void *, const void *, size_t);
void __aeabi_memmove8(void *, const void *, size_t);
void __aeabi_memmove4(void *, const void *, size_t);
void __aeabi_memmove(void *, const void *, size_t);

/*
 * Memory clearing and setting
 */
void __aeabi_memset8(void *, size_t, int);
void __aeabi_memset4(void *, size_t, int);
void __aeabi_memset(void *, size_t, int);
void __aeabi_memclr8(void *, size_t);
void __aeabi_memclr4(void *, size_t);
void __aeabi_memclr(void *, size_t);

void *__aeabi_read_tp(void); // return the value of $tp

#undef	__aapcs

#endif /* _ARM_AEABI_H_ */