/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
double fma(double x, double y, double z);

#if defined(_ARM_) || defined(__arm__)

/* Use hardware FMA on ARM. */
double fma(double x, double y, double z){
  __asm__ (
    "fmacd %0, %1, %2 \n"
    : "+w"(z)
    : "w"(x), "w"(y)
  );
  return z;
}

#elif defined(_ARM64_) || defined(__aarch64__)

/* Use hardware FMA on ARM64. */
double fma(double x, double y, double z){
  __asm__ (
    "fmadd %d0, %d1, %d2, %d0 \n"
    : "+w"(z)
    : "w"(x), "w"(y)
  );
  return z;
}

#else

long double fmal(long double x, long double y, long double z);

/* For platforms that don't have hardware FMA, emulate it. */
double fma(double x, double y, double z){
  return (double)fmal(x, y, z);
}

#endif
