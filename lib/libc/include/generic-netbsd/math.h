/*	$NetBSD: math.h,v 1.67.2.1 2024/10/11 19:01:11 martin Exp $	*/

/*
 * ====================================================
 * Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
 *
 * Developed at SunPro, a Sun Microsystems, Inc. business.
 * Permission to use, copy, modify, and distribute this
 * software is freely granted, provided that this notice
 * is preserved.
 * ====================================================
 */

/*
 * @(#)fdlibm.h 5.1 93/09/24
 */

#ifndef _MATH_H_
#define _MATH_H_

#include <sys/cdefs.h>
#include <sys/featuretest.h>

union __float_u {
	unsigned char __dummy[sizeof(float)];
	float __val;
};

union __double_u {
	unsigned char __dummy[sizeof(double)];
	double __val;
};

union __long_double_u {
	unsigned char __dummy[sizeof(long double)];
	long double __val;
};

#include <machine/math.h>		/* may use __float_u, __double_u,
					   or __long_double_u */
#include <limits.h>			/* for INT_{MIN,MAX} */

#if (!defined(_ANSI_SOURCE) && !defined(_POSIX_C_SOURCE) && \
    !defined(_XOPEN_SOURCE)) || ((_POSIX_C_SOURCE - 0) >= 200809L || \
     defined(_ISOC99_SOURCE) || (__STDC_VERSION__ - 0) >= 199901L || \
     (__cplusplus - 0) >= 201103L || defined(_NETBSD_SOURCE))
#define __MATH_C99_FEATURES
#endif

#ifdef __MATH_C99_FEATURES
#  if defined(__FLT_EVAL_METHOD__) && (__FLT_EVAL_METHOD__ - 0) == 0
typedef double double_t;
typedef float float_t;
#  elif (__FLT_EVAL_METHOD__ - 0) == 1
typedef double double_t;
typedef double float_t;
#  elif (__FLT_EVAL_METHOD__ - 0) == 2
typedef long double double_t;
typedef long double float_t;
#  endif
#endif

#ifdef __HAVE_LONG_DOUBLE
#define	__fpmacro_unary_floating(__name, __arg0)			\
	/* LINTED */							\
	((sizeof (__arg0) == sizeof (float))				\
	?	__ ## __name ## f (__arg0)				\
	: (sizeof (__arg0) == sizeof (double))				\
	?	__ ## __name ## d (__arg0)				\
	:	__ ## __name ## l (__arg0))
#else
#define	__fpmacro_unary_floating(__name, __arg0)			\
	/* LINTED */							\
	((sizeof (__arg0) == sizeof (float))				\
	?	__ ## __name ## f (__arg0)				\
	:	__ ## __name ## d (__arg0))
#endif /* __HAVE_LONG_DOUBLE */

/*
 * ANSI/POSIX
 */
/* 7.12#3 HUGE_VAL, HUGELF, HUGE_VALL */
#if __GNUC_PREREQ__(3, 3)
#define HUGE_VAL	__builtin_huge_val()
#else
extern const union __double_u __infinity;
#define HUGE_VAL	__infinity.__val
#endif

/*
 * ISO C99
 */
#if defined(__MATH_C99_FEATURES) || \
    (_POSIX_C_SOURCE - 0) >= 200112L || (_XOPEN_SOURCE  - 0) >= 600
/* 7.12#3 HUGE_VAL, HUGELF, HUGE_VALL */
#if __GNUC_PREREQ__(3, 3)
#define	HUGE_VALF	__builtin_huge_valf()
#define	HUGE_VALL	__builtin_huge_vall()
#else
extern const union __float_u __infinityf;
#define	HUGE_VALF	__infinityf.__val

extern const union __long_double_u __infinityl;
#define	HUGE_VALL	__infinityl.__val
#endif

/* 7.12#4 INFINITY */
#if defined(__INFINITY)
#define	INFINITY	__INFINITY	/* float constant which overflows */
#elif __GNUC_PREREQ__(3, 3)
#define	INFINITY	__builtin_inff()
#else
#define	INFINITY	HUGE_VALF	/* positive infinity */
#endif /* __INFINITY */

/* 7.12#5 NAN: a quiet NaN, if supported */
#ifdef __HAVE_NANF
#if __GNUC_PREREQ__(3,3)
#define	NAN	__builtin_nanf("")
#else
extern const union __float_u __nanf;
#define	NAN		__nanf.__val
#endif
#endif /* __HAVE_NANF */

/* 7.12#6 number classification macros */
#define	FP_INFINITE	0x00
#define	FP_NAN		0x01
#define	FP_NORMAL	0x02
#define	FP_SUBNORMAL	0x03
#define	FP_ZERO		0x04
/* NetBSD extensions */
#define	_FP_LOMD	0x80		/* range for machine-specific classes */
#define	_FP_HIMD	0xff

/* 7.12#7 fast fma(3) feature test macros */
#if __GNUC_PREREQ__(4, 4)
#  ifdef __FP_FAST_FMA
#    define	FP_FAST_FMA	1
#  endif
#  ifdef __FP_FAST_FMAF
#    define	FP_FAST_FMAF	1
#  endif
#  ifdef __FP_FAST_FMAL
#    define	FP_FAST_FMAL	1
#  endif
#endif

/* 7.12#8 ilogb exceptional input result value macros */
#define	FP_ILOGB0	INT_MIN
#define	FP_ILOGBNAN	INT_MAX

/* 7.12#9 error handling (__math_errhandling from machine/math.h) */
#define	MATH_ERRNO		1
#define	MATH_ERREXCEPT		2
#ifdef __vax__			/* XXX !__HAVE_FENV */
#define	math_errhandling	MATH_ERRNO
#else
#define	math_errhandling	MATH_ERREXCEPT
#endif

#endif /* C99 || _XOPEN_SOURCE >= 600 */

/*
 * XOPEN/SVID
 */
#if defined(_XOPEN_SOURCE) || defined(_NETBSD_SOURCE)
#define	M_E		2.7182818284590452354	/* e */
#define	M_LOG2E		1.4426950408889634074	/* log 2e */
#define	M_LOG10E	0.43429448190325182765	/* log 10e */
#define	M_LN2		0.69314718055994530942	/* log e2 */
#define	M_LN10		2.30258509299404568402	/* log e10 */
#define	M_PI		3.14159265358979323846	/* pi */
#define	M_PI_2		1.57079632679489661923	/* pi/2 */
#define	M_PI_4		0.78539816339744830962	/* pi/4 */
#define	M_1_PI		0.31830988618379067154	/* 1/pi */
#define	M_2_PI		0.63661977236758134308	/* 2/pi */
#define	M_2_SQRTPI	1.12837916709551257390	/* 2/sqrt(pi) */
#define	M_SQRT2		1.41421356237309504880	/* sqrt(2) */
#define	M_SQRT1_2	0.70710678118654752440	/* 1/sqrt(2) */

#define	MAXFLOAT	((float)3.40282346638528860e+38)
extern int signgam;
#endif /* _XOPEN_SOURCE || _NETBSD_SOURCE */

#if defined(_NETBSD_SOURCE)
enum fdversion {fdlibm_ieee = -1, fdlibm_svid, fdlibm_xopen, fdlibm_posix};

#define _LIB_VERSION_TYPE enum fdversion
#define _LIB_VERSION _fdlib_version

/* if global variable _LIB_VERSION is not desirable, one may
 * change the following to be a constant by:
 *	#define _LIB_VERSION_TYPE const enum version
 * In that case, after one initializes the value _LIB_VERSION (see
 * s_lib_version.c) during compile time, it cannot be modified
 * in the middle of a program
 */
extern  _LIB_VERSION_TYPE  _LIB_VERSION;

#define _IEEE_  fdlibm_ieee
#define _SVID_  fdlibm_svid
#define _XOPEN_ fdlibm_xopen
#define _POSIX_ fdlibm_posix

#ifndef __cplusplus
struct exception {
	int type;
	const char *name;
	double arg1;
	double arg2;
	double retval;
};
#endif

#define	HUGE		MAXFLOAT

/*
 * set X_TLOSS = pi*2**52, which is possibly defined in <values.h>
 * (one may replace the following line by "#include <values.h>")
 */

#define X_TLOSS		1.41484755040568800000e+16

#define	DOMAIN		1
#define	SING		2
#define	OVERFLOW	3
#define	UNDERFLOW	4
#define	TLOSS		5
#define	PLOSS		6

#endif /* _NETBSD_SOURCE */

__BEGIN_DECLS
/*
 * ANSI/POSIX
 */
double	acos(double);
double	asin(double);
double	atan(double);
double	atan2(double, double);
double	cos(double);
double	sin(double);
double	tan(double);

double	cosh(double);
double	sinh(double);
double	tanh(double);

double	exp(double);
double	exp2(double);
double	frexp(double, int *);
double	ldexp(double, int);
double	log(double);
double	log2(double);
double	log10(double);
double	modf(double, double *);

double	pow(double, double);
double	sqrt(double);

double	ceil(double);
double	fabs(double);
double	floor(double);
double	fmod(double, double);

#if defined(__MATH_C99_FEATURES) || defined(_XOPEN_SOURCE)
double	erf(double);
double	erfc(double);
double	hypot(double, double);
#endif

#if defined(_XOPEN_SOURCE) || defined(_NETBSD_SOURCE)
int	finite(double);
double	gamma(double);
double	j0(double);
double	j1(double);
double	jn(int, double);
double	y0(double);
double	y1(double);
double	yn(int, double);

#if (_XOPEN_SOURCE - 0) >= 500 || defined(_NETBSD_SOURCE)
double	scalb(double, double);
#endif /* (_XOPEN_SOURCE - 0) >= 500 || defined(_NETBSD_SOURCE)*/
#endif /* _XOPEN_SOURCE || _NETBSD_SOURCE */

/*
 * ISO C99
 */
#if defined(__MATH_C99_FEATURES) || (_XOPEN_SOURCE - 0) >= 500
double	acosh(double);
double	asinh(double);
double	atanh(double);
double	cbrt(double);
double	expm1(double);
int	ilogb(double);
double	log1p(double);
double	logb(double);
double	nextafter(double, double);
double	remainder(double, double);
double	rint(double);
#endif

#if defined(__MATH_C99_FEATURES) || (_XOPEN_SOURCE - 0) >= 600 || \
    (_POSIX_C_SOURCE - 0) >= 200112L
/* 7.12.3.1 int fpclassify(real-floating x) */
#define	fpclassify(__x)	__fpmacro_unary_floating(fpclassify, __x)

/* 7.12.3.2 int isfinite(real-floating x) */
#define	isfinite(__x)	__fpmacro_unary_floating(isfinite, __x)

/* 7.12.3.5 int isnormal(real-floating x) */
#define	isnormal(__x)	(fpclassify(__x) == FP_NORMAL)

/* 7.12.3.6 int signbit(real-floating x) */
#define	signbit(__x)	__fpmacro_unary_floating(signbit, __x)

/* 7.12.4 trigonometric */

float	acosf(float);
float	asinf(float);
float	atanf(float);
float	atan2f(float, float);
float	cosf(float);
float	sinf(float);
float	tanf(float);

long double	acosl(long double);
long double	asinl(long double);
long double	atanl(long double);
long double	atan2l(long double, long double);
long double	cosl(long double);
long double	sinl(long double);
long double	tanl(long double);

/* 7.12.5 hyperbolic */

float	acoshf(float);
float	asinhf(float);
float	atanhf(float);
float	coshf(float);
float	sinhf(float);
float	tanhf(float);
long double	acoshl(long double);
long double	asinhl(long double);
long double	atanhl(long double);
long double	coshl(long double);
long double	sinhl(long double);
long double	tanhl(long double);

/* 7.12.6 exp / log */
double	scalbn(double, int);
double	scalbln(double, long);

float	expf(float);
float	exp2f(float);
float	expm1f(float);
float	frexpf(float, int *);
int	ilogbf(float);
float	ldexpf(float, int);
float	logf(float);
float	log2f(float);
float	log10f(float);
float	log1pf(float);
float	logbf(float);
float	modff(float, float *);
float	scalbnf(float, int);
float	scalblnf(float, long);

long double	expl(long double);
long double	exp2l(long double);
long double	expm1l(long double);
long double	frexpl(long double, int *);
int		ilogbl(long double);
long double	ldexpl(long double, int);
long double	logl(long double);
long double	log2l(long double);
long double	log10l(long double);
long double	log1pl(long double);
long double	logbl(long double);
long double	modfl(long double, long double *);
long double	scalbnl(long double, int);
long double	scalblnl(long double, long);


/* 7.12.7 power / absolute */

float	cbrtf(float);
float	fabsf(float);
float	hypotf(float, float);
float	powf(float, float);
float	sqrtf(float);
long double	cbrtl(long double);
long double	fabsl(long double);
long double	hypotl(long double, long double);
long double	powl(long double, long double);
long double	sqrtl(long double);

/* 7.12.8 error / gamma */

double	lgamma(double);
double	tgamma(double);
float	erff(float);
float	erfcf(float);
float	lgammaf(float);
float	tgammaf(float);
long double	erfl(long double);
long double	erfcl(long double);
long double	lgammal(long double);
long double	tgammal(long double);

/* 7.12.9 nearest integer */

/* LONGLONG */
long long int	llrint(double);
long int	lround(double);
/* LONGLONG */
long long int	llround(double);
long int	lrint(double);
double	round(double);
double	trunc(double);

float	ceilf(float);
float	floorf(float);
/* LONGLONG */
long long int	llrintf(float);
long int	lroundf(float);
/* LONGLONG */
long long int	llroundf(float);
long int	lrintf(float);
float	rintf(float);
float	roundf(float);
float	truncf(float);
long double	ceill(long double);
long double	floorl(long double);
/* LONGLONG */
long long int	llrintl(long double);
long int	lroundl(long double);
/* LONGLONG */
long long int	llroundl(long double);
long int	lrintl(long double);
long double	rintl(long double);
long double	roundl(long double);
long double	truncl(long double);

/* 7.12.10 remainder */

float	fmodf(float, float);
float	remainderf(float, float);
long double	fmodl(long double, long double);
long double	remainderl(long double, long double);

/* 7.12.10.3 The remquo functions */
double	remquo(double, double, int *);
float	remquof(float, float, int *);
long double	remquol(long double, long double, int *);

/* 7.12.11 manipulation */

double	copysign(double, double);
double	nan(const char *);
double	nearbyint(double);
double	nexttoward(double, long double);
float	copysignf(float, float);
float	nanf(const char *);
float	nearbyintf(float);
float	nextafterf(float, float);
float	nexttowardf(float, long double);
long double	copysignl(long double, long double);
long double	nanl(const char *);
long double	nearbyintl(long double);
long double     nextafterl(long double, long double);
long double	nexttowardl(long double, long double);

/* 7.12.14 comparison */

#define isunordered(x, y)	(isnan(x) || isnan(y))
#define isgreater(x, y)		(!isunordered((x), (y)) && (x) > (y))
#define isgreaterequal(x, y)	(!isunordered((x), (y)) && (x) >= (y))
#define isless(x, y)		(!isunordered((x), (y)) && (x) < (y))
#define islessequal(x, y)	(!isunordered((x), (y)) && (x) <= (y))
#define islessgreater(x, y)	(!isunordered((x), (y)) && \
				 ((x) > (y) || (y) > (x)))
double	fdim(double, double);
double	fma(double, double, double);
double	fmax(double, double);
double	fmin(double, double);
float	fdimf(float, float);
float	fmaf(float, float, float);
float	fmaxf(float, float);
float	fminf(float, float);
long double fdiml(long double, long double);
long double fmal(long double, long double, long double);
long double fmaxl(long double, long double);
long double fminl(long double, long double);

#endif /* !_ANSI_SOURCE && ... */

#if defined(__MATH_C99_FEATURES) || (_POSIX_C_SOURCE - 0) >= 200112L
/* 7.12.3.3 int isinf(real-floating x) */
#if defined(__isinf) || defined(__HAVE_INLINE___ISINF)
#define	isinf(__x)	__isinf(__x)
#else
#define	isinf(__x)	__fpmacro_unary_floating(isinf, __x)
#endif

/* 7.12.3.4 int isnan(real-floating x) */
#if defined(__isnan) || defined(__HAVE_INLINE___ISNAN)
#define	isnan(__x)	__isnan(__x)
#else
#define	isnan(__x)	__fpmacro_unary_floating(isnan, __x)
#endif
#endif /* !_ANSI_SOURCE && ... */

#if defined(_NETBSD_SOURCE)
#ifndef __cplusplus
int	matherr(struct exception *);
#endif

/*
 * IEEE Test Vector
 */
double	significand(double);

/*
 * BSD math library entry points
 */
double	drem(double, double);

#endif /* _NETBSD_SOURCE */

#if defined(_NETBSD_SOURCE) || defined(_REENTRANT)
/*
 * Reentrant version of gamma & lgamma; passes signgam back by reference
 * as the second argument; user must allocate space for signgam.
 */
double	gamma_r(double, int *);
double	lgamma_r(double, int *);
#endif /* _NETBSD_SOURCE || _REENTRANT */


#if defined(_NETBSD_SOURCE)

/* float versions of ANSI/POSIX functions */

float	gammaf(float);
int	isinff(float);
int	isnanf(float);
int	finitef(float);
float	j0f(float);
float	j1f(float);
float	jnf(int, float);
float	y0f(float);
float	y1f(float);
float	ynf(int, float);

float	scalbf(float, float);

/*
 * float version of IEEE Test Vector
 */
float	significandf(float);

/*
 * float versions of BSD math library entry points
 */
float	dremf(float, float);

void		sincos(double, double *, double *);
void		sincosf(float, float *, float *);
void		sincosl(long double, long double *, long double *);
#endif /* _NETBSD_SOURCE */

#if defined(_NETBSD_SOURCE) || defined(_REENTRANT)
/*
 * Float versions of reentrant version of gamma & lgamma; passes
 * signgam back by reference as the second argument; user must
 * allocate space for signgam.
 */
float	gammaf_r(float, int *);
float	lgammaf_r(float, int *);
#endif /* !... || _REENTRANT */

/*
 * Library implementation
 */
int	__fpclassifyf(float);
int	__fpclassifyd(double);
int	__isfinitef(float);
int	__isfinited(double);
int	__isinff(float);
int	__isinfd(double);
int	__isnanf(float);
int	__isnand(double);
int	__signbitf(float);
int	__signbitd(double);

#ifdef __HAVE_LONG_DOUBLE
int	__fpclassifyl(long double);
int	__isfinitel(long double);
int	__isinfl(long double);
int	__isnanl(long double);
int	__signbitl(long double);
#endif

__END_DECLS

#endif /* _MATH_H_ */