/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <fenv.h>

#if !(defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__))
extern int __mingw_has_sse (void);
#endif /* !(defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__)) */

/* 7.6.2.2  
   The fegetexceptflag function stores an implementation-defined
   representation of the exception flags indicated by the argument
   excepts in the object pointed to by the argument flagp.  */

int fegetexceptflag (fexcept_t * flagp, int excepts)
{
#if defined(_ARM_) || defined(__arm__)
  fenv_t _env;
  __asm__ volatile ("fmrx %0, FPSCR" : "=r" (_env));
  *flagp = _env.__cw & excepts & FE_ALL_EXCEPT;
#elif defined(_ARM64_) || defined(__aarch64__)
  unsigned __int64 fpcr;
  __asm__ volatile ("mrs %0, fpcr" : "=r" (fpcr));
  *flagp = fpcr & excepts & FE_ALL_EXCEPT;
#else
  int _mxcsr;
  unsigned short _status;

  __asm__ volatile ("fnstsw %0" : "=am" (_status));
  _mxcsr = 0;
  if (__mingw_has_sse ())
    __asm__ volatile ("stmxcsr %0" : "=m" (_mxcsr));
    
  *flagp = (_mxcsr | _status) & excepts & FE_ALL_EXCEPT;
#endif /* defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__) */
  return 0;
}
