/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <fenv.h>

#if !(defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__))
extern int __mingw_has_sse (void);
#endif /* !(defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__)) */

/* 7.6.2.4
   The fesetexceptflag function sets the complete status for those
   exception flags indicated by the argument excepts, according to the
   representation in the object pointed to by flagp. The value of
   *flagp shall have been set by a previous call to fegetexceptflag
   whose second argument represented at least those exceptions
   represented by the argument excepts. This function does not raise
   exceptions, but only sets the state of the flags. */ 

int fesetexceptflag (const fexcept_t * flagp, int excepts) 
{
  fenv_t _env;

  excepts &= FE_ALL_EXCEPT;

#if defined(_ARM_) || defined(__arm__)
  __asm__ volatile ("fmrx %0, FPSCR" : "=r" (_env));
  _env.__cw &= ~excepts;
  _env.__cw |= (*flagp & excepts);
  __asm__ volatile ("fmxr FPSCR, %0" : : "r" (_env));
#elif defined(_ARM64_) || defined(__aarch64__)
  unsigned __int64 fpcr;
  (void) _env;
  __asm__ volatile ("mrs %0, fpcr" : "=r" (fpcr));
  fpcr &= ~excepts;
  fpcr |= (*flagp & excepts);
  __asm__ volatile ("msr fpcr, %0" : : "r" (fpcr));
#else
  __asm__ volatile ("fnstenv %0;" : "=m" (_env));
  _env.__status_word &= ~excepts;
  _env.__status_word |= (*flagp & excepts);
  __asm__ volatile ("fldenv %0;" : : "m" (_env));

  if (__mingw_has_sse ())
    {
      int sse_cw;
      __asm__ volatile ("stmxcsr %0;" : "=m" (sse_cw));
      sse_cw &= ~(excepts << 7);
      sse_cw |= ((*flagp & excepts) << 7);
      __asm__ volatile ("ldmxcsr %0" : : "m" (sse_cw));
    }

#endif /* defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__) */
  return 0;
}
