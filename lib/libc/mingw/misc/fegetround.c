/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <fenv.h>

/* 7.6.3.1
   The fegetround function returns the value of the rounding direction
   macro representing the current rounding direction.  */

int
fegetround (void)
{
#if defined(_ARM_) || defined(__arm__)
  fenv_t _env;
  __asm__ volatile ("fmrx %0, FPSCR" : "=r" (_env));
  return (_env.__cw & (FE_TONEAREST | FE_DOWNWARD |  FE_UPWARD | FE_TOWARDZERO));
#elif defined(_ARM64_) || defined(__aarch64__)
  unsigned __int64 fpcr;
  __asm__ volatile ("mrs %0, fpcr" : "=r" (fpcr));
  return (fpcr & (FE_TONEAREST | FE_DOWNWARD |  FE_UPWARD | FE_TOWARDZERO));
#else
  int _control;
  __asm__ volatile ("fnstcw %0" : "=m" (*&_control));
  return (_control & (FE_TONEAREST | FE_DOWNWARD |  FE_UPWARD | FE_TOWARDZERO));
#endif /* defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__) */
}
