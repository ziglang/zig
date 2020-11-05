/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
float fmaf(float x, float y, float z);

#if defined(_ARM_) || defined(__arm__)

/* Use hardware FMA on ARM. */
float fmaf(float x, float y, float z){
  __asm__ (
    "fmacs %0, %1, %2 \n"
    : "+t"(z)
    : "t"(x), "t"(y)
  );
  return z;
}

#elif defined(_ARM64_) || defined(__aarch64__)

/* Use hardware FMA on ARM64. */
float fmaf(float x, float y, float z){
  __asm__ (
    "fmadd %s0, %s1, %s2, %s0 \n"
    : "+w"(z)
    : "w"(x), "w"(y)
  );
  return z;
}

#elif defined(_AMD64_) || defined(__x86_64__) || defined(_X86_) || defined(__i386__)

#include <math.h>
#include <stdint.h>

/* This is in accordance with the IEC 559 single-precision format.
 * Be advised that due to the hidden bit, the higher half actually has 11 bits.
 * Multiplying two 13-bit numbers will cause a 1-ULP error, which we cannot
 * avoid. It is kept in the very last position.
 */
typedef union iec559_float_ {
  struct __attribute__((__packed__)) {
    uint32_t mlo : 13;
    uint32_t mhi : 10;
    uint32_t exp :  8;
    uint32_t sgn :  1;
  };
  float f;
} iec559_float;

static inline void break_down(iec559_float *restrict lo, iec559_float *restrict hi, float x) {
  hi->f = x;
  /* Erase low-order significant bits. `hi->f` now has only 11 significant bits. */
  hi->mlo = 0;
  /* Store the low-order half. It will be normalized by the hardware. */
  lo->f = x - hi->f;
  /* Preserve signness in case of zero. */
  lo->sgn = hi->sgn;
}

float fmaf(float x, float y, float z) {
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
  float ret = x * y + z;
  if(!isfinite(ret)) {
    return ret; /* If this naive check doesn't yield a finite value, the FMA isn't
                   likely to return one either. Forward the value as is. */
  }
  iec559_float xlo, xhi, ylo, yhi;
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
