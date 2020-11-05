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

/* See <https://en.wikipedia.org/wiki/Extended_precision#x86_extended_precision_format>.
 * Note the higher half of the mantissa has fewer significant bits than the lower
 * half, which reduces rounding errors in the more significant position but increases
 * them in the other end.
 */
typedef union x87reg_ {
  struct __attribute__((__packed__)) {
    uint64_t mlo : 33;
    uint64_t mhi : 31;
    uint16_t exp : 15;
    uint16_t sgn :  1;
  };
  long double f;
} x87reg;

static inline void break_down(x87reg *restrict lo, x87reg *restrict hi, long double x) {
  hi->f = x;
  /* Erase low-order significant bits. `hi->f` now has only 31 significant bits. */
  hi->mlo = 0;
  /* Store the low-order half. It will be normalized by the hardware. */
  lo->f = x - hi->f;
  /* Preserve signness in case of zero. */
  lo->sgn = hi->sgn;
}

long double fmal(long double x, long double y, long double z) {
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
  /* Check whether the result is finite. */
  long double ret = x * y + z;
  if(!isfinite(ret)) {
    return ret; /* If this naive check doesn't yield a finite value, the FMA isn't
                   likely to return one either. Forward the value as is. */
  }
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

#else

#error Please add FMA implementation for this platform.

#endif
