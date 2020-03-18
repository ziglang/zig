/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw.h>
#include <fenv.h>
#include <float.h>

#if !(defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__))
extern int __mingw_has_sse (void);
#endif /* !(defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__)) */

/* 7.6.4.3
   The fesetenv function establishes the floating-point environment
   represented by the object pointed to by envp. The argument envp
   points to an object set by a call to fegetenv or feholdexcept, or
   equal the macro FE_DFL_ENV or an implementation-defined environment
   macro. Note that fesetenv merely installs the state of the exception
   flags represented through its argument, and does not raise these
   exceptions.
 */

extern void (* __MINGW_IMP_SYMBOL(_fpreset))(void);
extern void _fpreset(void);

int fesetenv (const fenv_t * envp)
{
#if defined(_ARM_) || defined(__arm__)
  if (envp == FE_DFL_ENV)
    /* Use the choice made at app startup */ 
    _fpreset();
  else
    __asm__ volatile ("fmxr FPSCR, %0" : : "r" (*envp));
#elif defined(_ARM64_) || defined(__aarch64__)
  if (envp == FE_DFL_ENV) {
    /* Use the choice made at app startup */
    _fpreset();
  } else {
    unsigned __int64 fpcr = envp->__cw;
    __asm__ volatile ("msr fpcr, %0" : : "r" (fpcr));
  }
#else
  if (envp == FE_PC64_ENV)
   /*
    *  fninit initializes the control register to 0x37f,
    *  the status register to zero and the tag word to 0FFFFh.
    *  The other registers are unaffected.
    */
    __asm__ __volatile__ ("fninit");

  else if (envp == FE_PC53_ENV)
   /*
    * MS _fpreset() does same *except* it sets control word
    * to 0x27f (53-bit precision).
    * We force calling _fpreset in msvcrt.dll
    */

   (* __MINGW_IMP_SYMBOL(_fpreset))();

  else if (envp == FE_DFL_ENV)
    /* Use the choice made at app startup */ 
    _fpreset();

  else
    {
      fenv_t env = *envp;
      int has_sse = __mingw_has_sse ();
      int _mxcsr;
      /*_mxcsr = ((int)envp->__unused0 << 16) | (int)envp->__unused1; *//* mxcsr low and high */
      if (has_sse)
        __asm__ ("stmxcsr %0" : "=m" (*&_mxcsr));
      env.__unused0 = 0xffff;
      env.__unused1 = 0xffff;
      __asm__ volatile ("fldenv %0" : : "m" (env)
			: "st", "st(1)", "st(2)", "st(3)", "st(4)",
			"st(5)", "st(6)", "st(7)");
      if (has_sse)
        __asm__ volatile ("ldmxcsr %0" : : "m" (*&_mxcsr));
    }

#endif /* defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__) */
  return 0;
}
