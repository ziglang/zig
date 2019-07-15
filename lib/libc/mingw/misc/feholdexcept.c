/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <fenv.h>

/* 7.6.4.2
   The feholdexcept function saves the current floating-point
   environment in the object pointed to by envp, clears the exception
   flags, and then installs a non-stop (continue on exceptions) mode,
   if available, for all exceptions.  */

int feholdexcept (fenv_t * envp)
{
#if defined(_ARM_) || defined(__arm__)
  fenv_t _env;
  __asm__ volatile ("fmrx %0, FPSCR" : "=r" (_env));
  envp->__cw = _env.__cw;
  _env.__cw &= ~(FE_ALL_EXCEPT);
  __asm__ volatile ("fmxr FPSCR, %0" : : "r" (_env));
#elif defined(_ARM64_) || defined(__aarch64__)
  unsigned __int64 fpcr;
  __asm__ volatile ("mrs %0, fpcr" : "=r" (fpcr));
  envp->__cw = fpcr;
  fpcr &= ~(FE_ALL_EXCEPT);
  __asm__ volatile ("msr fpcr, %0" : : "r" (fpcr));
#else
  __asm__ __volatile__ ("fnstenv %0;" : "=m" (* envp)); /* save current into envp */
 /* fnstenv sets control word to non-stop for all exceptions, so all we
    need to do is clear the exception flags.  */
  __asm__ __volatile__ ("fnclex");
#endif /* defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__) */
  return 0;
}
