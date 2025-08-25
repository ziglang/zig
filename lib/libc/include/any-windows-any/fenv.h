/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _FENV_H_
#define _FENV_H_

#include <float.h>


/* FPU status word exception flags */
#define FE_INEXACT     _SW_INEXACT
#define FE_UNDERFLOW   _SW_UNDERFLOW
#define FE_OVERFLOW    _SW_OVERFLOW
#define FE_DIVBYZERO   _SW_ZERODIVIDE
#define FE_INVALID     _SW_INVALID
#define FE_ALL_EXCEPT  (FE_DIVBYZERO | FE_INEXACT | FE_INVALID | FE_OVERFLOW | FE_UNDERFLOW)

/* FPU control word rounding flags */
#define FE_TONEAREST   _RC_NEAR
#define FE_UPWARD      _RC_UP
#define FE_DOWNWARD    _RC_DOWN
#define FE_TOWARDZERO  _RC_CHOP

#if defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__)

/* Amount to shift by to convert an exception to a mask bit.  */
#define FE_EXCEPT_SHIFT 0x08

#else

/* The MXCSR exception flags are the same as the
   FE flags. */
#define __MXCSR_EXCEPT_FLAG_SHIFT 0

/* How much to shift FE status word exception flags
   to get the MXCSR exeptions masks,  */
#define __MXCSR_EXCEPT_MASK_SHIFT 7

/* How much to shift FE status word exception flags
   to get MXCSR rounding flags,  */
#define __MXCSR_ROUND_FLAG_SHIFT 3

#endif /* defined(_ARM_) || defined(__arm__) */

#ifndef RC_INVOKED

typedef struct
{
    unsigned long _Fe_ctl;
    unsigned long _Fe_stat;
} fenv_t;

/* Type representing exception flags. */
typedef unsigned long fexcept_t;

#ifdef __cplusplus
extern "C" {
#endif

/* The FE_DFL_ENV macro is required by standard.
   fesetenv will use the environment set at app startup.*/
extern const fenv_t __mingw_fe_dfl_env;
#define FE_DFL_ENV (&__mingw_fe_dfl_env)

/* The C99 standard (7.6.9) allows us to define implementation-specific macros for
   different fp environments */
#if defined(__i386__) || defined(__x86_64__)

/* The default Intel x87 floating point environment (64-bit mantissa) */
extern const fenv_t __mingw_fe_pc64_env;
#define FE_PC64_ENV (&__mingw_fe_pc64_env)

/* The floating point environment set by MSVCRT _fpreset (53-bit mantissa) */
extern const fenv_t __mingw_fe_pc53_env;
#define FE_PC53_ENV (&__mingw_fe_pc53_env)

#endif

/*TODO: Some of these could be inlined */
/* 7.6.2 Exception */

extern int __cdecl feclearexcept (int);
extern int __cdecl fegetexceptflag (fexcept_t * flagp, int excepts);
extern int __cdecl feraiseexcept (int excepts );
extern int __cdecl fesetexceptflag (const fexcept_t *, int);
extern int __cdecl fetestexcept (int excepts);

/* 7.6.3 Rounding */

extern int __cdecl fegetround (void);
extern int __cdecl fesetround (int mode);

/* 7.6.4 Environment */

extern int __cdecl fegetenv(fenv_t * envp);
extern int __cdecl fesetenv(const fenv_t * );
extern int __cdecl feupdateenv(const fenv_t *);
extern int __cdecl feholdexcept(fenv_t *);

#ifdef __cplusplus
}
#endif
#endif	/* Not RC_INVOKED */

#endif /* ndef _FENV_H */
