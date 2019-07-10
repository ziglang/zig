/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
long double fmal(long double x, long double y, long double z);

#if defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__)

double fma(double x, double y, double z);

/* On ARM `long double` is 64 bits. And ARM has hardware FMA. */
long double fmal(long double x, long double y, long double z){
  return fma(x, y, z);
}

#elif defined(_AMD64_) || defined(__x86_64__) || defined(_X86_) || defined(__i386__)

/**
 * x87-specific software-emulated FMA by LH_Mouse (lh_mouse at 126 dot com).
 * This file is donated to the mingw-w64 project.
 * Note: This file requires C99 support to compile.
 */

#include <math.h>
#include <stdint.h>
#include <limits.h>
#include <stdbool.h>

/* https://en.wikipedia.org/wiki/Extended_precision#x86_extended_precision_format */
typedef union x87reg_ {
  struct __attribute__((__packed__)) {
    union {
      uint64_t f64;
      struct {
        uint32_t flo;
        uint32_t fhi;
      };
    };
    uint16_t exp : 15;
    uint16_t sgn :  1;
  };
  long double f;
} x87reg;

static inline void break_down(x87reg *restrict lo, x87reg *restrict hi, long double x){
  hi->f = x;
  const uint32_t flo = hi->flo;
  const long     exp = hi->exp;
  const bool     sgn = hi->sgn;
  /* Erase low-order significant bits. `hi->f` now has only 32 significant bits. */
  hi->flo = 0;

  if(flo == 0){
    /* If the low-order significant bits are all zeroes, return zero in `lo->f`. */
    lo->f64 = 0;
    lo->exp = 0;
  } else {
    /* How many bits should we shift to normalize the floating point value? */
    const long shn = __builtin_clzl(flo) - (sizeof(long) - sizeof(uint32_t)) * CHAR_BIT + 32;
#if 0 /* Naive implementation */
    if(shn < exp){
      /* `x` can be normalized, normalize it. */
      lo->f64 = (uint64_t)flo << shn;
      lo->exp = (exp - shn) & 0x7FFF;
    } else {
      /* Otherwise, go with a denormal number. */
      if(exp > 0){
        /* Denormalize the source normal number. */
        lo->f64 = (uint64_t)flo << (exp - 1);
      } else {
        /* Leave the source denormal number as is. */
        lo->f64 = flo;
      }
      lo->exp = 0;
    }
#else /* Optimal implementation */
    const long mask = (shn - exp) >> 31; /* mask = (shn < exp) ? -1 : 0 */
    long expm1 = exp - 1;
    expm1 &= ~(expm1 >> 31);             /* expm1 = (exp - 1 >= 0) ? (exp - 1) : 0 */
    lo->f64 = (uint64_t)flo << (((shn ^ expm1) & mask) ^ expm1);
                                         /* f64  = flo << ((shn < exp) ? shn : expm1) */
    lo->exp = (exp - shn) & mask;        /* exp  = (shn < exp) ? (exp - shn) : 0 */
#endif
  }
  lo->sgn = sgn;
}
static inline long double fpu_fma(long double x, long double y, long double z){
  /*
    POSIX-2013:
    1. If x or y are NaN, a NaN shall be returned.
    2. If x multiplied by y is an exact infinity and z is also an infinity
       but with the opposite sign, a domain error shall occur, and either a NaN
       (if supported), or an implementation-defined value shall be returned.
    3. If one of x and y is infinite, the other is zero, and z is not a NaN,
       a domain error shall occur, and either a NaN (if supported), or an
       implementation-defined value shall be returned.
    4. If one of x and y is infinite, the other is zero, and z is a NaN, a NaN
       shall be returned and a domain error may occur.
    5. If x* y is not 0*Inf nor Inf*0 and z is a NaN, a NaN shall be returned.
  */
  if(__fpclassifyl(x) == FP_NAN){
    return x; /* Handle case 1. */
  }
  if(__fpclassifyl(y) == FP_NAN){
    return y; /* Handle case 1. */
  }
  /* Handle case 2, 3 and 4 universally. Thanks to x87 a NaN is generated
     if an INF is multiplied with zero, saving us a huge amount of work. */
  const long double xy = x * y;
  if(__fpclassifyl(xy) == FP_NAN){
    return xy; /* Handle case 2, 3 and 4. */
  }
  if(__fpclassifyl(z) == FP_NAN){
    return z; /* Handle case 5. */
  }
  /* Check whether the result is finite. */
  const long double xyz = xy + z;
  const int cxyz = __fpclassifyl(xyz);
  if((cxyz == FP_NAN) || (cxyz == FP_INFINITE)){
    return xyz; /* If this naive check doesn't yield a finite value, the FMA isn't
                   likely to return one either. Forward the value as is. */
  }

  long double ret;
  x87reg xlo, xhi, ylo, yhi;
  break_down(&xlo, &xhi, x);
  break_down(&ylo, &yhi, y);
  /* The order of these four statements is essential. Don't move them around. */
  ret = z;
  ret += xhi.f * yhi.f;                 /* The most significant item comes first. */
  ret += xhi.f * ylo.f + xlo.f * yhi.f; /* They are equally significant. */
  ret += xlo.f * ylo.f;                 /* The least significant item comes last. */
  return ret;
}

long double fmal(long double x, long double y, long double z){
  return fpu_fma(x, y, z);
}

#else

#error Please add FMA implementation for this platform.

#endif
