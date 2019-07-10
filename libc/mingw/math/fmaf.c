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

#else

long double fmal(long double x, long double y, long double z);

/* For platforms that don't have hardware FMA, emulate it. */
float fmaf(float x, float y, float z){
  return (float)fmal(x, y, z);
}

#endif
