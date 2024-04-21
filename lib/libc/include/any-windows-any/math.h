/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MATH_H_
#define _MATH_H_

#ifdef __GNUC__
#pragma GCC system_header
#endif /* __GNUC__ */

#include <crtdefs.h>

struct _exception;

#pragma pack(push,_CRT_PACKING)

#define	_DOMAIN		1	/* domain error in argument */
#define	_SING		2	/* singularity */
#define	_OVERFLOW	3	/* range overflow */
#define	_UNDERFLOW	4	/* range underflow */
#define	_TLOSS		5	/* total loss of precision */
#define	_PLOSS		6	/* partial loss of precision */

#ifndef __STRICT_ANSI__
#ifndef	NO_OLDNAMES

#define	DOMAIN		_DOMAIN
#define	SING		_SING
#define	OVERFLOW	_OVERFLOW
#define	UNDERFLOW	_UNDERFLOW
#define	TLOSS		_TLOSS
#define	PLOSS		_PLOSS

#endif
#endif

#if !defined(__STRICT_ANSI__) || defined(_POSIX_C_SOURCE) || defined(_POSIX_SOURCE) || defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) || defined(_BSD_SOURCE) || defined(_USE_MATH_DEFINES)
#define M_E		2.7182818284590452354
#define M_LOG2E		1.4426950408889634074
#define M_LOG10E	0.43429448190325182765
#define M_LN2		0.69314718055994530942
#define M_LN10		2.30258509299404568402
#define M_PI		3.14159265358979323846
#define M_PI_2		1.57079632679489661923
#define M_PI_4		0.78539816339744830962
#define M_1_PI		0.31830988618379067154
#define M_2_PI		0.63661977236758134308
#define M_2_SQRTPI	1.12837916709551257390
#define M_SQRT2		1.41421356237309504880
#define M_SQRT1_2	0.70710678118654752440
#endif

#ifndef __STRICT_ANSI__
/* See also float.h  */
#ifndef __MINGW_FPCLASS_DEFINED
#define __MINGW_FPCLASS_DEFINED 1
/* IEEE 754 classication */
#define	_FPCLASS_SNAN	0x0001	/* Signaling "Not a Number" */
#define	_FPCLASS_QNAN	0x0002	/* Quiet "Not a Number" */
#define	_FPCLASS_NINF	0x0004	/* Negative Infinity */
#define	_FPCLASS_NN	0x0008	/* Negative Normal */
#define	_FPCLASS_ND	0x0010	/* Negative Denormal */
#define	_FPCLASS_NZ	0x0020	/* Negative Zero */
#define	_FPCLASS_PZ	0x0040	/* Positive Zero */
#define	_FPCLASS_PD	0x0080	/* Positive Denormal */
#define	_FPCLASS_PN	0x0100	/* Positive Normal */
#define	_FPCLASS_PINF	0x0200	/* Positive Infinity */
#endif
#endif

#ifndef RC_INVOKED

#ifndef __mingw_types_compatible_p
#ifdef __cplusplus
extern "C++" {
template <typename type1, typename type2> struct __mingw_types_compatible_p {
  static const bool result = false;
};

template <typename type1> struct __mingw_types_compatible_p<type1, type1> {
 static const bool result = true;
};

template <typename type1> struct __mingw_types_compatible_p<const type1, type1> {
  static const bool result = true;
};

template <typename type1> struct __mingw_types_compatible_p<type1, const type1> {
  static const bool result = true;
};
}

#define __mingw_types_compatible_p(type1, type2) __mingw_types_compatible_p <type1, type2>::result
#else
#define __mingw_types_compatible_p(type1, type2) __builtin_types_compatible_p (type1, type2)
#endif
#endif

#ifndef __mingw_choose_expr
#ifdef __cplusplus
#define __mingw_choose_expr(C, E1, E2) ((C) ? E1 : E2)
#else
#define __mingw_choose_expr __builtin_choose_expr
#endif
#endif


#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MINGW_SOFTMATH
#define __MINGW_SOFTMATH

/* IEEE float/double type shapes.  */

  typedef union __mingw_dbl_type_t {
    double x;
    unsigned long long val;
    __C89_NAMELESS struct {
      unsigned int low, high;
    } lh;
  } __mingw_dbl_type_t;

  typedef union __mingw_flt_type_t {
    float x;
    unsigned int val;
  } __mingw_flt_type_t;

  typedef union __mingw_ldbl_type_t
  {
    long double x;
    __C89_NAMELESS struct {
      unsigned int low, high;
      int sign_exponent : 16;
      int res1 : 16;
      int res0 : 32;
    } lh;
  } __mingw_ldbl_type_t;

#endif

#ifndef _HUGE
#ifdef _UCRT
  extern double const _HUGE;
#define _HUGE _HUGE
#else
  extern double * __MINGW_IMP_SYMBOL(_HUGE);
#define _HUGE	(* __MINGW_IMP_SYMBOL(_HUGE))
#endif /* _UCRT */
#endif

#ifdef __GNUC__
#define	HUGE_VAL __builtin_huge_val()
#else
#define HUGE_VAL _HUGE
#endif /* __GNUC__ */

#ifndef _EXCEPTION_DEFINED
#define _EXCEPTION_DEFINED
  struct _exception {
    int type;
    const char *name;
    double arg1;
    double arg2;
    double retval;
  };

  void __mingw_raise_matherr (int typ, const char *name, double a1, double a2,
			      double rslt);
  void __mingw_setusermatherr (int (__cdecl *)(struct _exception *));
  _CRTIMP void __setusermatherr(int (__cdecl *)(struct _exception *));
  #define __setusermatherr __mingw_setusermatherr
#endif

  double __cdecl sin(double _X);
  double __cdecl cos(double _X);
  double __cdecl tan(double _X);
  double __cdecl sinh(double _X);
  double __cdecl cosh(double _X);
  double __cdecl tanh(double _X);
  double __cdecl asin(double _X);
  double __cdecl acos(double _X);
  double __cdecl atan(double _X);
  double __cdecl atan2(double _Y,double _X);
  double __cdecl exp(double _X);
  double __cdecl log(double _X);
  double __cdecl log10(double _X);
  double __cdecl pow(double _X,double _Y);
  double __cdecl sqrt(double _X);
  double __cdecl ceil(double _X);
  double __cdecl floor(double _X);

/* 7.12.7.2 The fabs functions: Double in C89 */
  extern  float __cdecl fabsf (float x);
  extern long double __cdecl fabsl (long double);
  extern double __cdecl fabs (double _X);

#ifndef __CRT__NO_INLINE
#if !defined (__ia64__)
  __CRT_INLINE float __cdecl fabsf (float x)
  {
#if defined(__x86_64__) || defined(__arm__) || defined(__aarch64__)
    return __builtin_fabsf (x);
#else
    float res = 0.0F;
    __asm__ __volatile__ ("fabs;" : "=t" (res) : "0" (x));
    return res;
#endif
  }

  __CRT_INLINE long double __cdecl fabsl (long double x)
  {
#if defined(__arm__) || defined(__aarch64__)
    return __builtin_fabsl (x);
#else
    long double res = 0.0l;
    __asm__ __volatile__ ("fabs;" : "=t" (res) : "0" (x));
    return res;
#endif
  }

  __CRT_INLINE double __cdecl fabs (double x)
  {
#if defined(__x86_64__) || defined(__arm__) || defined(__aarch64__)
    return __builtin_fabs (x);
#else
    double res = 0.0;
    __asm__ __volatile__ ("fabs;" : "=t" (res) : "0" (x));
    return res;
#endif
  }
#endif
#endif

  double __cdecl ldexp(double _X,int _Y);
  double __cdecl frexp(double _X,int *_Y);
  double __cdecl modf(double _X,double *_Y);
  double __cdecl fmod(double _X,double _Y);

  void __cdecl sincos (double __x, double *p_sin, double *p_cos);
  void __cdecl sincosl (long double __x, long double *p_sin, long double *p_cos);
  void __cdecl sincosf (float __x, float *p_sin, float *p_cos);

#ifndef _CRT_ABS_DEFINED
#define _CRT_ABS_DEFINED
  int __cdecl abs(int _X);
  long __cdecl labs(long _X);
#endif
#ifndef _CRT_ATOF_DEFINED
#define _CRT_ATOF_DEFINED
  double __cdecl atof(const char *_String);
  double __cdecl _atof_l(const char *_String,_locale_t _Locale);
#endif

#define EDOM 33
#define ERANGE 34

#ifndef __STRICT_ANSI__

#ifndef _COMPLEX_DEFINED
#define _COMPLEX_DEFINED
  struct _complex {
    double x;
    double y;
  };
#endif

  double __cdecl _cabs(struct _complex _ComplexA); /* Overridden to use our cabs.  */
  double __cdecl _hypot(double _X,double _Y);
  _CRTIMP double __cdecl _j0(double _X);
  _CRTIMP double __cdecl _j1(double _X);
  _CRTIMP double __cdecl _jn(int _X,double _Y);
  _CRTIMP double __cdecl _y0(double _X);
  _CRTIMP double __cdecl _y1(double _X);
  _CRTIMP double __cdecl _yn(int _X,double _Y);
#ifndef _CRT_MATHERR_DEFINED
#define _CRT_MATHERR_DEFINED
  _CRTIMP int __cdecl _matherr (struct _exception *);
#endif

/* These are also declared in Mingw float.h; needed here as well to work 
   around GCC build issues.  */
/* BEGIN FLOAT.H COPY */
/*
 * IEEE recommended functions
 */
#ifndef _SIGN_DEFINED
#define _SIGN_DEFINED
  _CRTIMP double __cdecl _chgsign (double _X);
  _CRTIMP double __cdecl _copysign (double _Number,double _Sign);
  _CRTIMP double __cdecl _logb (double);
  _CRTIMP double __cdecl _nextafter (double, double);
  _CRTIMP double __cdecl _scalb (double, long);
  _CRTIMP int __cdecl _finite (double);
  _CRTIMP int __cdecl _fpclass (double);
  _CRTIMP int __cdecl _isnan (double);
#endif

/* END FLOAT.H COPY */

#if !defined(NO_OLDNAMES)

_CRTIMP double __cdecl j0 (double) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
_CRTIMP double __cdecl j1 (double) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
_CRTIMP double __cdecl jn (int, double) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
_CRTIMP double __cdecl y0 (double) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
_CRTIMP double __cdecl y1 (double) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
_CRTIMP double __cdecl yn (int, double) __MINGW_ATTRIB_DEPRECATED_MSVC2005;

_CRTIMP double __cdecl chgsign (double);
/*
 * scalb() is a GCC built-in.
 * Exclude this _scalb() stub; the semantics are incompatible
 * with the built-in implementation.
 *
_CRTIMP double __cdecl scalb (double, long);
 *
 */
  _CRTIMP int __cdecl finite (double);
  _CRTIMP int __cdecl fpclass (double);

#define FP_SNAN    _FPCLASS_SNAN
#define FP_QNAN    _FPCLASS_QNAN
#define FP_NINF    _FPCLASS_NINF
#define FP_PINF    _FPCLASS_PINF
#define FP_NDENORM _FPCLASS_ND
#define FP_PDENORM _FPCLASS_PD
#define FP_NZERO   _FPCLASS_NZ
#define FP_PZERO   _FPCLASS_PZ
#define FP_NNORM   _FPCLASS_NN
#define FP_PNORM   _FPCLASS_PN

#endif /* !defined (_NO_OLDNAMES) && !define (NO_OLDNAMES) */

#if(defined(_X86_) && !defined(__x86_64))
  _CRTIMP int __cdecl _set_SSE2_enable(int _Flag);
#endif

#endif

#ifndef __NO_ISOCEXT
#if (defined (__STDC_VERSION__) && __STDC_VERSION__ >= 199901L) \
	|| !defined __STRICT_ANSI__ || defined __cplusplus

#ifdef __GNUC__
#define HUGE_VALF	__builtin_huge_valf()
#define HUGE_VALL	__builtin_huge_vall()
#define INFINITY	__builtin_inff()
#define NAN		__builtin_nanf("")
#else
extern const float __INFF;
#define HUGE_VALF __INFF
extern const long double  __INFL;
#define HUGE_VALL __INFL
#define INFINITY HUGE_VALF
extern const double __QNANF;
#define NAN __QNANF
#endif /* __GNUC__ */

/* Use the compiler's builtin define for FLT_EVAL_METHOD to
   set float_t and double_t.  */
#if defined (__x86_64__) || defined(__FLT_EVAL_METHOD__)  
# if defined (__x86_64__) || ( __FLT_EVAL_METHOD__== 0)
typedef float float_t;
typedef double double_t;
# elif (__FLT_EVAL_METHOD__ == 1)
typedef double float_t;
typedef double double_t;
# else /* (__FLT_EVAL_METHOD__ == 2) default ix87 FPU */
typedef long double float_t;
typedef long double double_t;
#endif
#else /* ix87 FPU default */
typedef long double float_t;
typedef long double double_t;
#endif

/* 7.12.3.1 */
/*
   Return values for fpclassify.
   These are based on Intel x87 fpu condition codes
   in the high byte of status word and differ from
   the return values for MS IEEE 754 extension _fpclass()
*/
#define FP_NAN		0x0100
#define FP_NORMAL	0x0400
#define FP_INFINITE	(FP_NAN | FP_NORMAL)
#define FP_ZERO		0x4000
#define FP_SUBNORMAL	(FP_NORMAL | FP_ZERO)
/* 0x0200 is signbit mask */

/*
  We can't inline float or double, because we want to ensure truncation
  to semantic type before classification. 
  (A normal long double value might become subnormal when 
  converted to double, and zero when converted to float.)
*/

  extern int __cdecl __fpclassifyl (long double);
  extern int __cdecl __fpclassifyf (float);
  extern int __cdecl __fpclassify (double);

#ifndef __CRT__NO_INLINE
  __CRT_INLINE int __cdecl __fpclassifyl (long double x) {
#if defined(__x86_64__) || defined(_AMD64_)
    __mingw_ldbl_type_t hlp;
    unsigned int e;
    hlp.x = x;
    e = hlp.lh.sign_exponent & 0x7fff;
    if (!e)
      {
        unsigned int h = hlp.lh.high;
        if (!(hlp.lh.low | h))
          return FP_ZERO;
        else if (!(h & 0x80000000))
          return FP_SUBNORMAL;
      }
    else if (e == 0x7fff)
      return (((hlp.lh.high & 0x7fffffff) | hlp.lh.low) == 0 ?
              FP_INFINITE : FP_NAN);
    return FP_NORMAL;
#elif defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
    return __fpclassify(x);
#elif defined(__i386__) || defined(_X86_)
    unsigned short sw;
    __asm__ __volatile__ ("fxam; fstsw %%ax;" : "=a" (sw): "t" (x));
    return sw & (FP_NAN | FP_NORMAL | FP_ZERO );
#endif
  }
  __CRT_INLINE int __cdecl __fpclassify (double x) {
#if defined(__x86_64__) || defined(_AMD64_) || defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
    __mingw_dbl_type_t hlp;
    unsigned int l, h;

    hlp.x = x;
    h = hlp.lh.high;
    l = hlp.lh.low | (h & 0xfffff);
    h &= 0x7ff00000;
    if ((h | l) == 0)
      return FP_ZERO;
    if (!h)
      return FP_SUBNORMAL;
    if (h == 0x7ff00000)
      return (l ? FP_NAN : FP_INFINITE);
    return FP_NORMAL;
#elif defined(__i386__) || defined(_X86_)
    unsigned short sw;
    __asm__ __volatile__ ("fxam; fstsw %%ax;" : "=a" (sw): "t" (x));
    return sw & (FP_NAN | FP_NORMAL | FP_ZERO );
#endif
  }
  __CRT_INLINE int __cdecl __fpclassifyf (float x) {
#if defined(__x86_64__) || defined(_AMD64_) || defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
    __mingw_flt_type_t hlp;

    hlp.x = x;
    hlp.val &= 0x7fffffff;
    if (hlp.val == 0)
      return FP_ZERO;
    if (hlp.val < 0x800000)
      return FP_SUBNORMAL;
    if (hlp.val >= 0x7f800000)
      return (hlp.val > 0x7f800000 ? FP_NAN : FP_INFINITE);
    return FP_NORMAL;
#elif defined(__i386__) || defined(_X86_)
    unsigned short sw;
    __asm__ __volatile__ ("fxam; fstsw %%ax;" : "=a" (sw): "t" (x));
    return sw & (FP_NAN | FP_NORMAL | FP_ZERO );
#endif
  }
#endif

#ifdef __STDC_WANT_DEC_FP__
#define __dfp_expansion(__call,__fin,x) \
__mingw_choose_expr (                                  \
      __mingw_types_compatible_p (__typeof__ (x), _Decimal32),    \
        __call##d32(x),                                         \
    __mingw_choose_expr (                                     \
      __mingw_types_compatible_p (__typeof__ (x), _Decimal64),    \
        __call##d64(x),                                         \
    __mingw_choose_expr (                                     \
      __mingw_types_compatible_p (__typeof__ (x), _Decimal128),   \
        __call##d128(x),                                        \
__fin)))
#else
#define __dfp_expansion(__call,__fin,x) __fin
#endif

#define fpclassify(x) \
__mingw_choose_expr (                                         \
  __mingw_types_compatible_p (__typeof__ (x), double),            \
    __fpclassify(x),                                            \
    __mingw_choose_expr (                                     \
      __mingw_types_compatible_p (__typeof__ (x), float),         \
        __fpclassifyf(x),                                       \
    __mingw_choose_expr (                                     \
      __mingw_types_compatible_p (__typeof__ (x), long double),   \
        __fpclassifyl(x),                                       \
    __dfp_expansion(__fpclassify,(__builtin_trap(),0),x))))


/* 7.12.3.2 */
#define isfinite(x) ((fpclassify(x) & FP_NAN) == 0)

/* 7.12.3.3 */
#define isinf(x) (fpclassify(x) == FP_INFINITE)

/* 7.12.3.4 */
/* We don't need to worry about truncation here:
   A NaN stays a NaN. */

  extern int __cdecl __isnan (double);
  extern int __cdecl __isnanf (float);
  extern int __cdecl __isnanl (long double);

#ifndef __CRT__NO_INLINE
  __CRT_INLINE int __cdecl __isnan (double _x)
  {
#if defined(__x86_64__) || defined(_AMD64_) || defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
    __mingw_dbl_type_t hlp;
    unsigned int l, h;

    hlp.x = _x;
    l = hlp.lh.low;
    h = hlp.lh.high & 0x7fffffff;
    h |= (l | -l) >> 31;
    h = 0x7ff00000 - h;
    return (int) h >> 31;
#elif defined(__i386__) || defined(_X86_)
    unsigned short sw;
    __asm__ __volatile__ ("fxam;"
      "fstsw %%ax": "=a" (sw) : "t" (_x));
    return (sw & (FP_NAN | FP_NORMAL | FP_INFINITE | FP_ZERO | FP_SUBNORMAL))
      == FP_NAN;
#endif
  }

  __CRT_INLINE int __cdecl __isnanf (float _x)
  {
#if defined(__x86_64__) || defined(_AMD64_) || defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
    __mingw_flt_type_t hlp;
    unsigned int i;
    
    hlp.x = _x;
    i = hlp.val & 0x7fffffff;
    i = 0x7f800000 - i;
    return (int) (i >> 31);
#elif defined(__i386__) || defined(_X86_)
    unsigned short sw;
    __asm__ __volatile__ ("fxam;"
      "fstsw %%ax": "=a" (sw) : "t" (_x));
    return (sw & (FP_NAN | FP_NORMAL | FP_INFINITE | FP_ZERO | FP_SUBNORMAL))
      == FP_NAN;
#endif
  }

  __CRT_INLINE int __cdecl __isnanl (long double _x)
  {
#if defined(__x86_64__) || defined(_AMD64_)
    __mingw_ldbl_type_t ld;
    unsigned int xx, signexp;

    ld.x = _x;
    signexp = (ld.lh.sign_exponent & 0x7fff) << 1;
    xx = ld.lh.low | (ld.lh.high & 0x7fffffffu);
    signexp |= (xx | (-xx)) >> 31;
    signexp = 0xfffe - signexp;
    return (int) signexp >> 16;
#elif defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
    return __isnan(_x);
#elif defined(__i386__) || defined(_X86_)
    unsigned short sw;
    __asm__ __volatile__ ("fxam;"
      "fstsw %%ax": "=a" (sw) : "t" (_x));
    return (sw & (FP_NAN | FP_NORMAL | FP_INFINITE | FP_ZERO | FP_SUBNORMAL))
      == FP_NAN;
#endif
  }
#endif



#define isnan(x) \
__mingw_choose_expr (                                         \
  __mingw_types_compatible_p (__typeof__ (x), double),            \
    __isnan(x),                                                 \
    __mingw_choose_expr (                                     \
      __mingw_types_compatible_p (__typeof__ (x), float),         \
        __isnanf(x),                                            \
    __mingw_choose_expr (                                     \
      __mingw_types_compatible_p (__typeof__ (x), long double),   \
        __isnanl(x),                                            \
    __dfp_expansion(__isnan,(__builtin_trap(),x),x))))

/* 7.12.3.5 */
#define isnormal(x) (fpclassify(x) == FP_NORMAL)

/* 7.12.3.6 The signbit macro */
  extern int __cdecl __signbit (double);
  extern int __cdecl __signbitf (float);
  extern int __cdecl __signbitl (long double);
#ifndef __CRT__NO_INLINE
  __CRT_INLINE int __cdecl __signbit (double x) {
#if defined(__x86_64__) || defined(_AMD64_) || defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
    __mingw_dbl_type_t hlp;

    hlp.x = x;
    return ((hlp.lh.high & 0x80000000) != 0);
#elif defined(__i386__) || defined(_X86_)
    unsigned short stw;
    __asm__ __volatile__ ( "fxam; fstsw %%ax;": "=a" (stw) : "t" (x));
    return stw & 0x0200;
#endif
  }

  __CRT_INLINE int __cdecl __signbitf (float x) {
#if defined(__x86_64__) || defined(_AMD64_) || defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
    __mingw_flt_type_t hlp;
    hlp.x = x;
    return ((hlp.val & 0x80000000) != 0);
#elif defined(__i386__) || defined(_X86_)
    unsigned short stw;
    __asm__ __volatile__ ("fxam; fstsw %%ax;": "=a" (stw) : "t" (x));
    return stw & 0x0200;
#endif
  }

  __CRT_INLINE int __cdecl __signbitl (long double x) {
#if defined(__x86_64__) || defined(_AMD64_)
    __mingw_ldbl_type_t ld;
    ld.x = x;
    return ((ld.lh.sign_exponent & 0x8000) != 0);
#elif defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
    return __signbit(x);
#elif defined(__i386__) || defined(_X86_)
    unsigned short stw;
    __asm__ __volatile__ ("fxam; fstsw %%ax;": "=a" (stw) : "t" (x));
    return stw & 0x0200;
#endif
  }
#endif

#define signbit(x) \
__mingw_choose_expr (                                         \
  __mingw_types_compatible_p (__typeof__ (x), double),            \
    __signbit(x),                                               \
    __mingw_choose_expr (                                     \
      __mingw_types_compatible_p (__typeof__ (x), float),         \
        __signbitf(x),                                          \
    __mingw_choose_expr (                                     \
      __mingw_types_compatible_p (__typeof__ (x), long double),   \
        __signbitl(x),                                          \
     __dfp_expansion(__signbit,(__builtin_trap(),x),x))))

/* 7.12.4 Trigonometric functions: Double in C89 */
  extern float __cdecl sinf(float _X);
  extern long double __cdecl sinl(long double);

  extern float __cdecl cosf(float _X);
  extern long double __cdecl cosl(long double);

  extern float __cdecl tanf(float _X);
  extern long double __cdecl tanl(long double);
  extern float __cdecl asinf(float _X);
  extern long double __cdecl asinl(long double);

  extern float __cdecl acosf (float);
  extern long double __cdecl acosl (long double);

  extern float __cdecl atanf (float);
  extern long double __cdecl atanl (long double);

  extern float __cdecl atan2f (float, float);
  extern long double __cdecl atan2l (long double, long double);

/* 7.12.5 Hyperbolic functions: Double in C89  */
  extern float __cdecl sinhf(float _X);
#if !defined(__CRT__NO_INLINE) && !defined(_UCRT)
  __CRT_INLINE float sinhf(float _X) { return ((float)sinh((double)_X)); }
#endif
  extern long double __cdecl sinhl(long double);

  extern float __cdecl coshf(float _X);
#if !defined(__CRT__NO_INLINE) && !defined(_UCRT)
  __CRT_INLINE float coshf(float _X) { return ((float)cosh((double)_X)); }
#endif
  extern long double __cdecl coshl(long double);

  extern float __cdecl tanhf(float _X);
#if !defined(__CRT__NO_INLINE) && !defined(_UCRT)
  __CRT_INLINE float tanhf(float _X) { return ((float)tanh((double)_X)); }
#endif
  extern long double __cdecl tanhl(long double);

/* Inverse hyperbolic trig functions  */ 
/* 7.12.5.1 */
  extern double __cdecl acosh (double);
  extern float __cdecl acoshf (float);
  extern long double __cdecl acoshl (long double);

/* 7.12.5.2 */
  extern double __cdecl asinh (double);
  extern float __cdecl asinhf (float);
  extern long double __cdecl asinhl (long double);

/* 7.12.5.3 */
  extern double __cdecl atanh (double);
  extern float __cdecl atanhf  (float);
  extern long double __cdecl atanhl (long double);

/* Exponentials and logarithms  */
/* 7.12.6.1 Double in C89 */
  extern float __cdecl expf(float _X);
#if !defined(__CRT__NO_INLINE) && !defined(_UCRT)
  __CRT_INLINE float expf(float _X) { return ((float)exp((double)_X)); }
#endif
  extern long double __cdecl expl(long double);

/* 7.12.6.2 */
  extern double __cdecl exp2(double);
  extern float __cdecl exp2f(float);
  extern long double __cdecl exp2l(long double);

/* 7.12.6.3 The expm1 functions */
/* TODO: These could be inlined */
  extern double __cdecl expm1(double);
  extern float __cdecl expm1f(float);
  extern long double __cdecl expm1l(long double);

/* 7.12.6.4 Double in C89 */
  extern float frexpf(float _X,int *_Y);
#if !defined(__CRT__NO_INLINE) && !defined(_UCRT)
  __CRT_INLINE float frexpf(float _X,int *_Y) { return ((float)frexp((double)_X,_Y)); }
#endif
  extern long double __cdecl frexpl(long double,int *);

/* 7.12.6.5 */
#define FP_ILOGB0 ((int)0x80000000)
#define FP_ILOGBNAN ((int)0x7fffffff)
  extern int __cdecl ilogb (double);
  extern int __cdecl ilogbf (float);
  extern int __cdecl ilogbl (long double);

/* 7.12.6.6  Double in C89 */
  extern float __cdecl ldexpf(float _X,int _Y);
#if !defined(__CRT__NO_INLINE) && !defined(_UCRT)
  __CRT_INLINE float __cdecl ldexpf (float x, int expn) { return (float) ldexp ((double)x, expn); }
#endif
  extern long double __cdecl ldexpl (long double, int);

/* 7.12.6.7 Double in C89 */
  extern float __cdecl logf (float);
  extern long double __cdecl logl(long double);

/* 7.12.6.8 Double in C89 */
  extern float __cdecl log10f (float);
  extern long double __cdecl log10l(long double);

/* 7.12.6.9 */
  extern double __cdecl log1p(double);
  extern float __cdecl log1pf(float);
  extern long double __cdecl log1pl(long double);

/* 7.12.6.10 */
  extern double __cdecl log2 (double);
  extern float __cdecl log2f (float);
  extern long double __cdecl log2l (long double);

/* 7.12.6.11 */
  extern double __cdecl logb (double);
  extern float __cdecl logbf (float);
  extern long double __cdecl logbl (long double);

#ifndef __CRT__NO_INLINE
/* When compiling with gcc, always use gcc's builtins.
 * The asm inlines below are kept here for future reference:
 * they were written for gcc and do no error handling
 * (exceptions/errno), therefore only valid if __FAST_MATH__
 * is defined (-ffast-math) .  */
#if 0 /*defined(__GNUC__) && defined(__FAST_MATH__)*/
  __CRT_INLINE double __cdecl logb (double x)
  {
#if defined(__x86_64__) || defined(_AMD64_) || defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
  __mingw_dbl_type_t hlp;
  int lx, hx;

  hlp.x = x;
  lx = hlp.lh.low;
  hx = hlp.lh.high & 0x7fffffff; /* high |x| */
  if ((hx | lx) == 0)
    return -1.0 / fabs (x);
  if (hx >= 0x7ff00000)
    return x * x;
  if ((hx >>= 20) == 0) {
    unsigned long long mantissa = hlp.val & 0xfffffffffffffULL;
    return -1023.0 - (__builtin_clzll(mantissa) - 12);
  }
  return (double) (hx - 1023);
#elif defined(__i386__) || defined(_X86_)
    double res = 0.0;
    __asm__ __volatile__ ("fxtract\n\t"
      "fstp	%%st" : "=t" (res) : "0" (x));
    return res;
#endif
  }

  __CRT_INLINE float __cdecl logbf (float x)
  {
#if defined(__x86_64__) || defined(_AMD64_) || defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
    int v;
    __mingw_flt_type_t hlp;

    hlp.x = x;
    v = hlp.val & 0x7fffffff;                     /* high |x| */
    if (!v)
      return (float)-1.0 / fabsf (x);
    if (v >= 0x7f800000)
    return x * x;
    if ((v >>= 23) == 0)
      return -127.0 - (__builtin_clzl(hlp.val & 0x7fffff) - 9);
  return (float) (v - 127);
#elif defined(__i386__) || defined(_X86_)
    float res = 0.0F;
    __asm__ __volatile__ ("fxtract\n\t"
      "fstp	%%st" : "=t" (res) : "0" (x));
    return res;
#endif
  }

  __CRT_INLINE long double __cdecl logbl (long double x)
  {
#if defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
  __mingw_ldbl_type_t hlp;
  int lx, hx;

  hlp.x = x;
  lx = hlp.lh.low;
  hx = hlp.lh.high & 0x7fffffff; /* high |x| */
  if ((hx | lx) == 0)
    return -1.0 / fabs (x);
  if (hx >= 0x7ff00000)
    return x * x;
  if ((hx >>= 20) == 0) {
    unsigned long long mantissa = hlp.val & 0xfffffffffffffULL;
    return -1023.0 - (__builtin_clzll(mantissa) - 12);
  }
  return (double) (hx - 1023);
#elif defined(__x86_64__) || defined(_AMD64_) || defined(__i386__) || defined(_X86_)
    long double res = 0.0l;
    __asm__ __volatile__ ("fxtract\n\t"
      "fstp	%%st" : "=t" (res) : "0" (x));
    return res;
#endif
  }
#endif /* defined(__GNUC__) && defined(__FAST_MATH__) */
#endif /* __CRT__NO_INLINE */

/* 7.12.6.12  Double in C89 */
  extern float __cdecl modff (float, float*);
  extern long double __cdecl modfl (long double, long double*);

/* 7.12.6.13 */
  extern double __cdecl scalbn (double, int);
  extern float __cdecl scalbnf (float, int);
  extern long double __cdecl scalbnl (long double, int);

  extern double __cdecl scalbln (double, long);
  extern float __cdecl scalblnf (float, long);
  extern long double __cdecl scalblnl (long double, long);

/* 7.12.7.1 */
/* Implementations adapted from Cephes versions */ 
  extern double __cdecl cbrt (double);
  extern float __cdecl cbrtf (float);
  extern long double __cdecl cbrtl (long double);

/* 7.12.7.3  */
  extern double __cdecl hypot (double, double) __MINGW_ATTRIB_DEPRECATED_MSVC2005; /* in libmoldname.a */
  extern float __cdecl hypotf (float x, float y);
#if !defined(__CRT__NO_INLINE) && !defined(_UCRT)
  __CRT_INLINE float __cdecl hypotf (float x, float y) { return (float) hypot ((double)x, (double)y);}
#endif
  extern long double __cdecl hypotl (long double, long double);

/* 7.12.7.4 The pow functions. Double in C89 */
  extern float __cdecl powf(float _X,float _Y);
#if !defined(__CRT__NO_INLINE) && !defined(_UCRT)
  __CRT_INLINE float powf(float _X,float _Y) { return ((float)pow((double)_X,(double)_Y)); }
#endif
  extern long double __cdecl powl (long double, long double);

/* 7.12.7.5 The sqrt functions. Double in C89. */
  extern float __cdecl sqrtf (float);
  extern long double sqrtl(long double);

/* 7.12.8.1 The erf functions  */
  extern double __cdecl erf (double);
  extern float __cdecl erff (float);
  extern long double __cdecl erfl (long double);

/* 7.12.8.2 The erfc functions  */
  extern double __cdecl erfc (double);
  extern float __cdecl erfcf (float);
  extern long double __cdecl erfcl (long double);

/* 7.12.8.3 The lgamma functions */
  extern double __cdecl lgamma (double);
  extern float __cdecl lgammaf (float);
  extern long double __cdecl lgammal (long double);

  extern int signgam;

/* 7.12.8.4 The tgamma functions */
  extern double __cdecl tgamma (double);
  extern float __cdecl tgammaf (float);
  extern long double __cdecl tgammal (long double);

/* 7.12.9.1 Double in C89 */
  extern float __cdecl ceilf (float);
  extern long double __cdecl ceill (long double);

/* 7.12.9.2 Double in C89 */
  extern float __cdecl floorf (float);
  extern long double __cdecl floorl (long double);

/* 7.12.9.3 */
  extern double __cdecl nearbyint ( double);
  extern float __cdecl nearbyintf (float);
  extern long double __cdecl nearbyintl (long double);

/* 7.12.9.4 */
/* round, using fpu control word settings */
extern double __cdecl rint (double);
extern float __cdecl rintf (float);
extern long double __cdecl rintl (long double);

/* 7.12.9.5 */
extern long __cdecl lrint (double);
extern long __cdecl lrintf (float);
extern long __cdecl lrintl (long double);

__MINGW_EXTENSION long long __cdecl llrint (double);
__MINGW_EXTENSION long long __cdecl llrintf (float);
__MINGW_EXTENSION long long __cdecl llrintl (long double);

#ifndef __CRT__NO_INLINE
/* When compiling with gcc, always use gcc's builtins.
 * The asm inlines below are kept here for future reference:
 * they were written for gcc and do no error handling
 * (exceptions/errno), therefore only valid if __FAST_MATH__
 * is defined (-ffast-math) .  */
#if 0 /*defined(__GNUC__) && defined(__FAST_MATH__)*/
  __CRT_INLINE double __cdecl rint (double x)
  {
    double retval = 0.0;
    __asm__ __volatile__ ("frndint;": "=t" (retval) : "0" (x));
    return retval;
  }

  __CRT_INLINE float __cdecl rintf (float x)
  {
    float retval = 0.0;
    __asm__ __volatile__ ("frndint;" : "=t" (retval) : "0" (x) );
    return retval;
  }

  __CRT_INLINE long double __cdecl rintl (long double x)
  {
    long double retval = 0.0l;
    __asm__ __volatile__ ("frndint;" : "=t" (retval) : "0" (x) );
    return retval;
  }

  __CRT_INLINE long __cdecl lrint (double x) 
  {
    long retval = 0;
    __asm__ __volatile__							      \
      ("fistpl %0"  : "=m" (retval) : "t" (x) : "st");				      \
      return retval;
  }

  __CRT_INLINE long __cdecl lrintf (float x) 
  {
    long retval = 0;
    __asm__ __volatile__							      \
      ("fistpl %0"  : "=m" (retval) : "t" (x) : "st");				      \
      return retval;
  }

  __CRT_INLINE long __cdecl lrintl (long double x) 
  {
    long retval = 0;
    __asm__ __volatile__							      \
      ("fistpl %0"  : "=m" (retval) : "t" (x) : "st");				      \
      return retval;
  }

  __MINGW_EXTENSION __CRT_INLINE long long __cdecl llrint (double x) 
  {
    __MINGW_EXTENSION long long retval = 0ll;
    __asm__ __volatile__							      \
      ("fistpll %0"  : "=m" (retval) : "t" (x) : "st");				      \
      return retval;
  }

  __MINGW_EXTENSION __CRT_INLINE long long __cdecl llrintf (float x) 
  {
    __MINGW_EXTENSION long long retval = 0ll;
    __asm__ __volatile__							      \
      ("fistpll %0"  : "=m" (retval) : "t" (x) : "st");				      \
      return retval;
  }

  __MINGW_EXTENSION __CRT_INLINE long long __cdecl llrintl (long double x) 
  {
    __MINGW_EXTENSION long long retval = 0ll;
    __asm__ __volatile__							      \
      ("fistpll %0"  : "=m" (retval) : "t" (x) : "st");				      \
      return retval;
  }
#endif /* defined(__GNUC__) && defined(__FAST_MATH__) */
#endif /* !__CRT__NO_INLINE */

/* 7.12.9.6 */
/* round away from zero, regardless of fpu control word settings */
  extern double __cdecl round (double);
  extern float __cdecl roundf (float);
  extern long double __cdecl roundl (long double);

/* 7.12.9.7  */
  extern long __cdecl lround (double);
  extern long __cdecl lroundf (float);
  extern long __cdecl lroundl (long double);
  __MINGW_EXTENSION long long __cdecl llround (double);
  __MINGW_EXTENSION long long __cdecl llroundf (float);
  __MINGW_EXTENSION long long __cdecl llroundl (long double);
  
/* 7.12.9.8 */
/* round towards zero, regardless of fpu control word settings */
  extern double __cdecl trunc (double);
  extern float __cdecl truncf (float);
  extern long double __cdecl truncl (long double);

/* 7.12.10.1 Double in C89 */
  extern float __cdecl fmodf (float, float);
  extern long double __cdecl fmodl (long double, long double);

/* 7.12.10.2 */ 
  extern double __cdecl remainder (double, double);
  extern float __cdecl remainderf (float, float);
  extern long double __cdecl remainderl (long double, long double);

/* 7.12.10.3 */
  extern double __cdecl remquo(double, double, int *);
  extern float __cdecl remquof(float, float, int *);
  extern long double __cdecl remquol(long double, long double, int *);

/* 7.12.11.1 */
  extern double __cdecl copysign (double, double); /* in libmoldname.a */
  extern float __cdecl copysignf (float, float);
  extern long double __cdecl copysignl (long double, long double);

#ifndef __CRT__NO_INLINE
#if !defined (__ia64__)
  __CRT_INLINE double __cdecl copysign (double x, double y)
  {
    __mingw_dbl_type_t hx, hy;
    hx.x = x; hy.x = y;
    hx.lh.high = (hx.lh.high & 0x7fffffff) | (hy.lh.high & 0x80000000);
    return hx.x;
  }
  __CRT_INLINE float __cdecl copysignf (float x, float y)
  {
    __mingw_flt_type_t hx, hy;
    hx.x = x; hy.x = y;
    hx.val = (hx.val & 0x7fffffff) | (hy.val & 0x80000000);
    return hx.x;
  }
#endif
#endif

/* 7.12.11.2 Return a NaN */
  extern double __cdecl nan(const char *tagp);
  extern float __cdecl nanf(const char *tagp);
  extern long double __cdecl nanl(const char *tagp);

#ifndef __STRICT_ANSI__
#define _nan() nan("")
#define _nanf() nanf("")
#define _nanl() nanl("")
#endif

/* 7.12.11.3 */
  extern double __cdecl nextafter (double, double); /* in libmoldname.a */
  extern float __cdecl nextafterf (float, float);
  extern long double __cdecl nextafterl (long double, long double);

/* 7.12.11.4 The nexttoward functions */
  extern double __cdecl nexttoward (double,  long double);
  extern float __cdecl nexttowardf (float,  long double);
  extern long double __cdecl nexttowardl (long double, long double);

/* 7.12.12.1 */
/*  x > y ? (x - y) : 0.0  */
  extern double __cdecl fdim (double x, double y);
  extern float __cdecl fdimf (float x, float y);
  extern long double __cdecl fdiml (long double x, long double y);

/* fmax and fmin.
   NaN arguments are treated as missing data: if one argument is a NaN
   and the other numeric, then these functions choose the numeric
   value. */

/* 7.12.12.2 */
  extern double __cdecl fmax  (double, double);
  extern float __cdecl fmaxf (float, float);
  extern long double __cdecl fmaxl (long double, long double);

/* 7.12.12.3 */
  extern double __cdecl fmin (double, double);
  extern float __cdecl fminf (float, float);
  extern long double __cdecl fminl (long double, long double);

/* 7.12.13.1 */
/* return x * y + z as a ternary op */ 
  extern double __cdecl fma (double, double, double);
  extern float __cdecl fmaf (float, float, float);
  extern long double __cdecl fmal (long double, long double, long double);

/* 7.12.14 */
/* 
 *  With these functions, comparisons involving quiet NaNs set the FP
 *  condition code to "unordered".  The IEEE floating-point spec
 *  dictates that the result of floating-point comparisons should be
 *  false whenever a NaN is involved, with the exception of the != op, 
 *  which always returns true: yes, (NaN != NaN) is true).
 */

#ifdef __GNUC__

#define isgreater(x, y) __builtin_isgreater(x, y)
#define isgreaterequal(x, y) __builtin_isgreaterequal(x, y)
#define isless(x, y) __builtin_isless(x, y)
#define islessequal(x, y) __builtin_islessequal(x, y)
#define islessgreater(x, y) __builtin_islessgreater(x, y)
#define isunordered(x, y) __builtin_isunordered(x, y)

#else
/*  helper  */
#ifndef __CRT__NO_INLINE
  __CRT_INLINE int  __cdecl
    __fp_unordered_compare (long double x, long double y){
      unsigned short retval;
      __asm__ __volatile__ ("fucom %%st(1);"
	"fnstsw;": "=a" (retval) : "t" (x), "u" (y));
      return retval;
  }
#endif /* __GNUC__ */

#define isgreater(x, y) ((__fp_unordered_compare(x, y)  & 0x4500) == 0)
#define isless(x, y) ((__fp_unordered_compare (y, x)  & 0x4500) == 0)
#define isgreaterequal(x, y) ((__fp_unordered_compare (x, y)  & FP_INFINITE) == 0)
#define islessequal(x, y) ((__fp_unordered_compare(y, x)  & FP_INFINITE) == 0)
#define islessgreater(x, y) ((__fp_unordered_compare(x, y)  & FP_SUBNORMAL) == 0)
#define isunordered(x, y) ((__fp_unordered_compare(x, y)  & 0x4500) == 0x4500)

#endif

#endif /* __STDC_VERSION__ >= 199901L */
#endif /* __NO_ISOCEXT */

#if defined(_X86_) && !defined(__x86_64)
  _CRTIMP float __cdecl _hypotf(float _X,float _Y);
#endif

#if !defined(__ia64__)
   _CRTIMP float __cdecl _copysignf (float _Number,float _Sign);
   _CRTIMP float __cdecl _chgsignf (float _X);
   _CRTIMP float __cdecl _logbf(float _X);
   _CRTIMP float __cdecl _nextafterf(float _X,float _Y);
   _CRTIMP int __cdecl _finitef(float _X);
   _CRTIMP int __cdecl _isnanf(float _X);
   _CRTIMP int __cdecl _fpclassf(float _X);
#endif

#ifdef _SIGN_DEFINED
   extern long double __cdecl _chgsignl (long double);
#define _copysignl copysignl
#endif /* _SIGN_DEFINED */

#define _hypotl hypotl

#ifndef	NO_OLDNAMES
#define matherr _matherr
#define HUGE	_HUGE
#endif

/* Documentation on decimal float math
   http://h21007.www2.hp.com/portal/site/dspp/menuitem.863c3e4cbcdc3f3515b49c108973a801?ciid=8cf166fedd1aa110VgnVCM100000a360ea10RCRD 
 */
#ifdef __STDC_WANT_DEC_FP__

#define DEC_INFINITY __builtin_infd32()
#define DEC_NAN __builtin_nand32("")

  extern int __cdecl __isnand32(_Decimal32 x);
  extern int __cdecl __isnand64(_Decimal64 x);
  extern int __cdecl __isnand128(_Decimal128 x);
  extern int __cdecl __fpclassifyd32 (_Decimal32);
  extern int __cdecl __fpclassifyd64 (_Decimal64);
  extern int __cdecl __fpclassifyd128 (_Decimal128);
  extern int __cdecl __signbitd32 (_Decimal32);
  extern int __cdecl __signbitd64 (_Decimal64);
  extern int __cdecl __signbitd128 (_Decimal128);

#ifndef __CRT__NO_INLINE
  __CRT_INLINE __cdecl __isnand32(_Decimal32 x){
    return __builtin_isnand32(x);
  }

  __CRT_INLINE __cdecl __isnand64(_Decimal64 x){
    return __builtin_isnand64(x);
  }

  __CRT_INLINE __cdecl __isnand128(_Decimal128 x){
    return __builtin_isnand128(x);
  }

  __CRT_INLINE int __cdecl __signbitd32 (_Decimal32 x){
    return __buintin_signbitd32(x);
  }

  __CRT_INLINE int __cdecl __signbitd64 (_Decimal64 x){
    return __buintin_signbitd64(x);
  }

  __CRT_INLINE int __cdecl __signbitd128 (_Decimal128 x){
    return __buintin_signbitd128(x);
  }

#endif

/* Still missing 
#define HUGE_VAL_D32
#define HUGE_VAL_D64
#define HUGE_VAL_D128
*/

/*** exponentials ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/expd64.3m.htm */
_Decimal64 __cdecl expd64(_Decimal64 _X);
_Decimal128 __cdecl expd128(_Decimal128 _X);
_Decimal32 __cdecl expd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/exp2d64.3m.htm */
_Decimal64 __cdecl exp2d64(_Decimal64 _X);
_Decimal128 __cdecl exp2d128(_Decimal128 _X);
_Decimal32 __cdecl exp2d32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/exp10d64.3m.htm */
_Decimal64 __cdecl exp10d64(_Decimal64 _X);
_Decimal128 __cdecl exp10d128(_Decimal128 _X);
_Decimal32 __cdecl exp10d32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/expm1d64.3m.htm */
_Decimal64 __cdecl expm1d64(_Decimal64 _X);
_Decimal128 __cdecl expm1d128(_Decimal128 _X);
_Decimal32 __cdecl expm1d32(_Decimal32 _X);

/*** logarithms ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/logd64.3m.htm */
_Decimal64 __cdecl logd64(_Decimal64 _X);
_Decimal128 __cdecl logd128(_Decimal128 _X);
_Decimal32 __cdecl logd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/log2d64.3m.htm */
_Decimal64 __cdecl log2d64(_Decimal64 _X);
_Decimal128 __cdecl log2d128(_Decimal128 _X);
_Decimal32 __cdecl log2d32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/log10d64.3m.htm */
_Decimal64 __cdecl log10d64(_Decimal64 _X);
_Decimal128 __cdecl log10d128(_Decimal128 _X);
_Decimal32 __cdecl log10d32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/log1pd64.3m.htm */
_Decimal64 __cdecl log1pd64(_Decimal64 _X);
_Decimal128 __cdecl log1pd128(_Decimal128 _X);
_Decimal32 __cdecl log1pd32(_Decimal32 _X);

/*** trigonometrics ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/cosd64.3m.htm */
_Decimal64 __cdecl cosd64(_Decimal64 _X);
_Decimal128 __cdecl cosd128(_Decimal128 _X);
_Decimal32 __cdecl cosd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/sind64.3m.htm */
_Decimal64 __cdecl sind64(_Decimal64 _X);
_Decimal128 __cdecl sind128(_Decimal128 _X);
_Decimal32 __cdecl sind32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/tand64.3m.htm */
_Decimal64 __cdecl tand64(_Decimal64 _X);
_Decimal128 __cdecl tand128(_Decimal128 _X);
_Decimal32 __cdecl tand32(_Decimal32 _X);

/*** inverse trigonometrics ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/acosd64.3m.htm */
_Decimal64 __cdecl acosd64(_Decimal64 _X);
_Decimal128 __cdecl acosd128(_Decimal128 _X);
_Decimal32 __cdecl acosd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/asind64.3m.htm */
_Decimal64 __cdecl asind64(_Decimal64 _X);
_Decimal128 __cdecl asind128(_Decimal128 _X);
_Decimal32 __cdecl asind32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/atand64.3m.htm */
_Decimal64 __cdecl atand64(_Decimal64 _X);
_Decimal128 __cdecl atand128(_Decimal128 _X);
_Decimal32 __cdecl atand32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/atan2d64.3m.htm */
_Decimal64 __cdecl atan2d64(_Decimal64 _X, _Decimal64 _Y);
_Decimal128 __cdecl atan2d128(_Decimal128 _X, _Decimal128 _Y);
_Decimal32 __cdecl atan2d32(_Decimal32 _X, _Decimal32 _Y);

/*** hyperbolics ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/coshd64.3m.htm */
_Decimal64 __cdecl coshd64(_Decimal64 _X);
_Decimal128 __cdecl coshd128(_Decimal128 _X);
_Decimal32 __cdecl coshd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/sinhd64.3m.htm */
_Decimal64 __cdecl sinhd64(_Decimal64 _X);
_Decimal128 __cdecl sinhd128(_Decimal128 _X);
_Decimal32 __cdecl sinhd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/tanhd64.3m.htm */
_Decimal64 __cdecl tanhd64(_Decimal64 _X);
_Decimal128 __cdecl tanhd128(_Decimal128 _X);
_Decimal32 __cdecl tanhd32(_Decimal32 _X);

/*** inverse hyperbolics ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/acoshd64.3m.htm */
_Decimal64 __cdecl acoshd64(_Decimal64 _X);
_Decimal128 __cdecl acoshd128(_Decimal128 _X);
_Decimal32 __cdecl acoshd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/asinhd64.3m.htm */
_Decimal64 __cdecl asinhd64(_Decimal64 _X);
_Decimal128 __cdecl asinhd128(_Decimal128 _X);
_Decimal32 __cdecl asinhd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/atanhd64.3m.htm */
_Decimal64 __cdecl atanhd64(_Decimal64 _X);
_Decimal128 __cdecl atanhd128(_Decimal128 _X);
_Decimal32 __cdecl atanhd32(_Decimal32 _X);

/*** square & cube roots, hypotenuse ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/sqrtd64.3m.htm */
_Decimal64 __cdecl sqrtd64(_Decimal64 _X);
_Decimal128 __cdecl sqrtd128(_Decimal128 _X);
_Decimal32 __cdecl sqrtd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/cbrtd64.3m.htm */
_Decimal64 __cdecl cbrtd64(_Decimal64 _X);
_Decimal128 __cdecl cbrtd128(_Decimal128 _X);
_Decimal32 __cdecl cbrtd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/hypotd64.3m.htm */
_Decimal64 __cdecl hypotd64(_Decimal64 _X, _Decimal64 _Y);
_Decimal128 __cdecl hypotd128(_Decimal128 _X, _Decimal128 _Y);
_Decimal32 __cdecl hypotd32(_Decimal32 _X, _Decimal32 _Y);

/*** floating multiply-add ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/fmad64.3m.htm */
_Decimal64 __cdecl fmad64(_Decimal64 _X, _Decimal64 y, _Decimal64 _Z);
_Decimal128 __cdecl fmad128(_Decimal128 _X, _Decimal128 y, _Decimal128 _Z);
_Decimal32 __cdecl fmad32(_Decimal32 _X, _Decimal32 y, _Decimal32 _Z);

/*** exponent/significand ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/logbd64.3m.htm */
_Decimal64 __cdecl logbd64(_Decimal64 _X);
_Decimal128 __cdecl logbd128(_Decimal128 _X);
_Decimal32 __cdecl logbd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/ilogbd64.3m.htm */
int __cdecl ilogbd64(_Decimal64 _X);
int __cdecl ilogbd128(_Decimal128 _X);
int __cdecl ilogbd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/frexpd64.3m.htm */
_Decimal64 __cdecl frexpd64(_Decimal64 _X, int *_Y);
_Decimal128 __cdecl frexpd128(_Decimal128 _X, int *_Y);
_Decimal32 __cdecl frexpd32(_Decimal32 _X, int *_Y);

/*** quantum ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/quantized64.3m.htm */
_Decimal64 __cdecl quantized64(_Decimal64 _X, _Decimal64 _Y);
_Decimal128 __cdecl quantized128(_Decimal128 _X, _Decimal128 _Y);
_Decimal32 __cdecl quantized32(_Decimal32 _X, _Decimal32 _Y);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/samequantumd64.3m.htm */
_Bool __cdecl samequantumd64(_Decimal64 _X, _Decimal64 _Y);
_Bool __cdecl samequantumd128(_Decimal128 _X, _Decimal128 _Y);
_Bool __cdecl samequantumd32(_Decimal32 _X, _Decimal32 _Y);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/quantexpd64.3m.htm */
int __cdecl quantexpd64(_Decimal64 _X);
int __cdecl quantexpd128(_Decimal128 _X);
int __cdecl quantexpd32(_Decimal32 _X);

/*** scaling ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/scalbnd64.3m.htm */
_Decimal64 __cdecl scalbnd64(_Decimal64 _X, int _Y);
_Decimal128 __cdecl scalbnd128(_Decimal128 _X, int _Y);
_Decimal32 __cdecl scalbnd32(_Decimal32 _X, int _Y);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/scalblnd64.3m.htm */
_Decimal64 __cdecl scalblnd64(_Decimal64 _X, long int _Y);
_Decimal128 __cdecl scalblnd128(_Decimal128 _X, long int _Y);
_Decimal32 __cdecl scalblnd32(_Decimal32 _X, long int _Y);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/ldexpd64.3m.htm */
_Decimal64 __cdecl ldexpd64(_Decimal64 _X, int _Y);
_Decimal128 __cdecl ldexpd128(_Decimal128 _X, int _Y);
_Decimal32 __cdecl ldexpd32(_Decimal32 _X, int _Y);

/*** rounding to integral floating ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/ceild64.3m.htm */
_Decimal64 __cdecl ceild64(_Decimal64 _X);
_Decimal128 __cdecl ceild128(_Decimal128 _X);
_Decimal32 __cdecl ceild32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/floord64.3m.htm */
_Decimal64 __cdecl floord64(_Decimal64 _X);
_Decimal128 __cdecl floord128(_Decimal128 _X);
_Decimal32 __cdecl floord32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/truncd64.3m.htm */
_Decimal64 __cdecl truncd64(_Decimal64 _X);
_Decimal128 __cdecl truncd128(_Decimal128 _X);
_Decimal32 __cdecl truncd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/roundd64.3m.htm */
_Decimal64 __cdecl roundd64(_Decimal64 _X);
_Decimal128 __cdecl roundd128(_Decimal128 _X);
_Decimal32 __cdecl roundd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/rintd64.3m.htm */
_Decimal64 __cdecl rintd64(_Decimal64 _X);
_Decimal128 __cdecl rintd128(_Decimal128 _X);
_Decimal32 __cdecl rintd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/nearbyintd64.3m.htm */
_Decimal64 __cdecl nearbyintd64(_Decimal64 _X);
_Decimal128 __cdecl nearbyintd128(_Decimal128 _X);
_Decimal32 __cdecl nearbyintd32(_Decimal32 _X);

/*** rounding to integer ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/lroundd64.3m.htm */
long int __cdecl lroundd64(_Decimal64 _X);
long int __cdecl lroundd128(_Decimal128 _X);
long int __cdecl lroundd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/llroundd64.3m.htm */
long long int __cdecl llroundd64(_Decimal64 _X);
long long int __cdecl llroundd128(_Decimal128 _X);
long long int __cdecl llroundd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/lrintd64.3m.htm */
long int __cdecl lrintd64(_Decimal64 _X);
long int __cdecl lrintd128(_Decimal128 _X);
long int __cdecl lrintd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/llrintd64.3m.htm */
long long int __cdecl llrintd64(_Decimal64 _X);
long long int __cdecl llrintd128(_Decimal128 _X);
long long int __cdecl llrintd32(_Decimal32 _X);

/*** integral and fractional parts ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/modfd64.3m.htm */
_Decimal64 __cdecl modfd64(_Decimal64 _X, _Decimal64 *_Y);
_Decimal128 __cdecl modfd128(_Decimal128 _X, _Decimal128 *_Y);
_Decimal32 __cdecl modfd32(_Decimal32 _X, _Decimal32 *_Y);

/** remainder/mod ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/remainderd64.3m.htm */
_Decimal64 __cdecl remainderd64(_Decimal64 _X, _Decimal64 _Y);
_Decimal128 __cdecl remainderd128(_Decimal128 _X, _Decimal128 _Y);
_Decimal32 __cdecl remainderd32(_Decimal32 _X, _Decimal32 _Y);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/fmodd64.3m.htm */
_Decimal64 __cdecl fmodd64(_Decimal64 _X, _Decimal64 _Y);
_Decimal128 __cdecl fmodd128(_Decimal128 _X, _Decimal128 _Y);
_Decimal32 __cdecl fmodd32(_Decimal32 _X, _Decimal32 _Y);

/*** error functions ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/erfd64.3m.htm */
_Decimal64 __cdecl erfd64(_Decimal64 _X);
_Decimal128 __cdecl erfd128(_Decimal128 _X);
_Decimal32 __cdecl erfd32(_Decimal32 _X);
_Decimal64 __cdecl erfcd64(_Decimal64 _X);
_Decimal128 __cdecl erfcd128(_Decimal128 _X);
_Decimal32 __cdecl erfcd32(_Decimal32 _X);

/*** gamma functions ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/lgammad64.3m.htm */
_Decimal64 __cdecl lgammad64(_Decimal64 _X);
_Decimal128 __cdecl lgammad128(_Decimal128 _X);
_Decimal32 __cdecl lgammad32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/tgammad64.3m.htm */
_Decimal64 __cdecl tgammad64(_Decimal64 _X);
_Decimal128 __cdecl tgammad128(_Decimal128 _X);
_Decimal32 __cdecl tgammad32(_Decimal32 _X);

/*** next value ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/nextafterd64.3m.htm */
_Decimal64 __cdecl nextafterd64(_Decimal64 _X, _Decimal64 _Y);
_Decimal128 __cdecl nextafterd128(_Decimal128 _X, _Decimal128 _Y);
_Decimal32 __cdecl nextafterd32(_Decimal32 _X, _Decimal32 _Y);
_Decimal64 __cdecl nexttowardd64(_Decimal64 _X, _Decimal128 _Y);
_Decimal128 __cdecl nexttowardd128(_Decimal128 _X, _Decimal128 _Y);
_Decimal32 __cdecl nexttowardd32(_Decimal32 _X, _Decimal128 _Y);

/*** absolute value, copy sign ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/fabsd64.3m.htm */
_Decimal64 __cdecl fabsd64(_Decimal64 _X);
_Decimal128 __cdecl fabsd128(_Decimal128 _X);
_Decimal32 __cdecl fabsd32(_Decimal32 _X);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/copysignd64.3m.htm */
_Decimal64 __cdecl copysignd64(_Decimal64 _X, _Decimal64 _Y);
_Decimal128 __cdecl copysignd128(_Decimal128 _X, _Decimal128 _Y);
_Decimal32 __cdecl copysignd32(_Decimal32 _X, _Decimal32 _Y);

/*** max, min, positive difference ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/fmaxd64.3m.htm */
_Decimal64 __cdecl fmaxd64(_Decimal64 _X, _Decimal64 y_Y);
_Decimal128 __cdecl fmaxd128(_Decimal128 _X, _Decimal128 _Y);
_Decimal32 __cdecl fmaxd32(_Decimal32 _X, _Decimal32 _Y);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/fmind64.3m.htm */
_Decimal64 __cdecl fmind64(_Decimal64 _X, _Decimal64 _Y);
_Decimal128 __cdecl fmind128(_Decimal128 _X, _Decimal128 _Y);
_Decimal32 __cdecl fmind32(_Decimal32 _X, _Decimal32 _Y);

/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/fdimd64.3m.htm */
_Decimal64 __cdecl fdimd64(_Decimal64 _X, _Decimal64 _Y);
_Decimal128 __cdecl fdimd128(_Decimal128 _X, _Decimal128 _Y);
_Decimal32 __cdecl fdimd32(_Decimal32 _X, _Decimal32 _Y);

/*** not-a-number ***/
/* http://h21007.www2.hp.com/portal/download/files/unprot/fp/manpages/nand64.3m.htm */
_Decimal64 __cdecl nand64(__UNUSED_PARAM(const char *_X));
_Decimal128 __cdecl nand128(__UNUSED_PARAM(const char *_X));
_Decimal32 __cdecl nand32(__UNUSED_PARAM(const char *_X));

/*** classifiers ***/
int __cdecl isinfd64(_Decimal64 _X);
int __cdecl isinfd128(_Decimal128 _X);
int __cdecl isinfd32(_Decimal32 _X);
int __cdecl isnand64(_Decimal64 _X);
int __cdecl isnand128(_Decimal128 _X);
int __cdecl isnand32(_Decimal32 _X);

#endif /* __STDC_WANT_DEC_FP__ */

#ifdef __cplusplus
}
#endif

#endif	/* Not RC_INVOKED */

#pragma pack(pop)

#endif /* End _MATH_H_ */

