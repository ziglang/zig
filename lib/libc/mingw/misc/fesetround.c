/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <fenv.h>

#if !(defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__))
int __mingw_has_sse (void);
#endif /* !(defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__)) */

 /* 7.6.3.2
    The fesetround function establishes the rounding direction
    represented by its argument round. If the argument is not equal
    to the value of a rounding direction macro, the rounding direction
    is not changed.  */

int fesetround (int mode)
{
#if defined(_ARM_) || defined(__arm__)
  fenv_t _env;
  if ((mode & ~(FE_TONEAREST | FE_DOWNWARD | FE_UPWARD | FE_TOWARDZERO)) != 0)
    return -1;
  __asm__ volatile ("fmrx %0, FPSCR" : "=r" (_env));
  _env.__cw &= ~(FE_TONEAREST | FE_DOWNWARD |  FE_UPWARD | FE_TOWARDZERO);
  _env.__cw |= mode;
  __asm__ volatile ("fmxr FPSCR, %0" : : "r" (_env));
#elif defined(_ARM64_) || defined(__aarch64__)
  unsigned __int64 fpcr;
  if ((mode & ~(FE_TONEAREST | FE_DOWNWARD | FE_UPWARD | FE_TOWARDZERO)) != 0)
    return -1;
  __asm__ volatile ("mrs %0, fpcr" : "=r" (fpcr));
  fpcr &= ~(FE_TONEAREST | FE_DOWNWARD |  FE_UPWARD | FE_TOWARDZERO);
  fpcr |= mode;
  __asm__ volatile ("msr fpcr, %0" : : "r" (fpcr));
#else
  unsigned short _cw;
  if ((mode & ~(FE_TONEAREST | FE_DOWNWARD | FE_UPWARD | FE_TOWARDZERO))
      != 0)
    return -1;
  __asm__ volatile ("fnstcw %0;": "=m" (*&_cw));
  _cw &= ~0xc00;
  _cw |= mode;
  __asm__ volatile ("fldcw %0;" : : "m" (*&_cw));
  
  if (__mingw_has_sse ())
    {
      int mxcsr;

      __asm__ volatile ("stmxcsr %0" : "=m" (*&mxcsr));
      mxcsr &= ~0x6000;
      mxcsr |= mode << 3;
      __asm__ volatile ("ldmxcsr %0" : : "m" (*&mxcsr));
    }
#endif /* defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__) */
  return 0;
}
