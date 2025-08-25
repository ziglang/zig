/*
 * Copyright (c) 2002-2013 Apple Inc. All rights reserved.
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

/******************************************************************************
 *                                                                            *
 *     File:  complex.h                                                       *
 *                                                                            *
 *     Contains: prototypes and macros germane to C99 complex math.           *
 *                                                                            *
 ******************************************************************************/

#ifndef __COMPLEX_H__
#define __COMPLEX_H__

#include <sys/cdefs.h>

#undef complex
#define complex _Complex
#undef _Complex_I
/*  Constant expression of type const float _Complex                          */
#define _Complex_I (__extension__ 1.0iF)
#undef I
#define I _Complex_I

#if (__STDC_VERSION__ > 199901L || __DARWIN_C_LEVEL >= __DARWIN_C_FULL) \
    && defined __clang__

/*  Complex initializer macros.  These are a C11 feature, but are also provided
    as an extension in C99 so long as strict POSIX conformance is not
    requested.  They are available only when building with the llvm-clang
    compiler, as there is no way to support them with the gcc-4.2 frontend.
    These may be used for static initialization of complex values, like so:
 
        static const float complex someVariable = CMPLXF(1.0, INFINITY);
 
    they may, of course, be used outside of static contexts as well.          */

#define  CMPLX(__real,__imag) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Wcomplex-component-init\"") \
    (double _Complex){(__real),(__imag)} \
    _Pragma("clang diagnostic pop")

#define CMPLXF(__real,__imag) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Wcomplex-component-init\"") \
    (float _Complex){(__real),(__imag)} \
    _Pragma("clang diagnostic pop")

#define CMPLXL(__real,__imag) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Wcomplex-component-init\"") \
    (long double _Complex){(__real),(__imag)} \
    _Pragma("clang diagnostic pop")

#endif /* End C11 features.                                                   */

__BEGIN_DECLS
extern float complex cacosf(float complex);
extern double complex cacos(double complex);
extern long double complex cacosl(long double complex);

extern float complex casinf(float complex);
extern double complex casin(double complex);
extern long double complex casinl(long double complex);

extern float complex catanf(float complex);
extern double complex catan(double complex);
extern long double complex catanl(long double complex);

extern float complex ccosf(float complex);
extern double complex ccos(double complex);
extern long double complex ccosl(long double complex);

extern float complex csinf(float complex);
extern double complex csin(double complex);
extern long double complex csinl(long double complex);

extern float complex ctanf(float complex);
extern double complex ctan(double complex);
extern long double complex ctanl(long double complex);

extern float complex cacoshf(float complex);
extern double complex cacosh(double complex);
extern long double complex cacoshl(long double complex);

extern float complex casinhf(float complex);
extern double complex casinh(double complex);
extern long double complex casinhl(long double complex);

extern float complex catanhf(float complex);
extern double complex catanh(double complex);
extern long double complex catanhl(long double complex);

extern float complex ccoshf(float complex);
extern double complex ccosh(double complex);
extern long double complex ccoshl(long double complex);

extern float complex csinhf(float complex);
extern double complex csinh(double complex);
extern long double complex csinhl(long double complex);

extern float complex ctanhf(float complex);
extern double complex ctanh(double complex);
extern long double complex ctanhl(long double complex);

extern float complex cexpf(float complex);
extern double complex cexp(double complex);
extern long double complex cexpl(long double complex);

extern float complex clogf(float complex);
extern double complex clog(double complex);
extern long double complex clogl(long double complex);

extern float cabsf(float complex);
extern double cabs(double complex);
extern long double cabsl(long double complex);

extern float complex cpowf(float complex, float complex);
extern double complex cpow(double complex, double complex);
extern long double complex cpowl(long double complex, long double complex);

extern float complex csqrtf(float complex);
extern double complex csqrt(double complex);
extern long double complex csqrtl(long double complex);

extern float cargf(float complex);
extern double carg(double complex);
extern long double cargl(long double complex);

extern float cimagf(float complex);
extern double cimag(double complex);
extern long double cimagl(long double complex);

extern float complex conjf(float complex);
extern double complex conj(double complex);
extern long double complex conjl(long double complex);

extern float complex cprojf(float complex);
extern double complex cproj(double complex);
extern long double complex cprojl(long double complex);

extern float crealf(float complex);
extern double creal(double complex);
extern long double creall(long double complex);
__END_DECLS

#endif /* __COMPLEX_H__ */
