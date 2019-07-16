/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _FENV_H_
#define _FENV_H_

#include <crtdefs.h>

#if defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__)

/* FPU status word exception flags */
#define FE_INVALID      0x01
#define FE_DIVBYZERO    0x02
#define FE_OVERFLOW     0x04
#define FE_UNDERFLOW    0x08
#define FE_INEXACT      0x10
#define FE_ALL_EXCEPT   (FE_INVALID | FE_DIVBYZERO | FE_OVERFLOW | FE_UNDERFLOW | FE_INEXACT)

/* FPU control word rounding flags */
#define FE_TONEAREST    0x00000000
#define FE_UPWARD       0x00400000
#define FE_DOWNWARD     0x00800000
#define FE_TOWARDZERO   0x00c00000

/* Amount to shift by to convert an exception to a mask bit.  */
#define FE_EXCEPT_SHIFT 0x08

#else

#define FE_INVALID	0x01
#define FE_DENORMAL	0x02
#define FE_DIVBYZERO	0x04
#define FE_OVERFLOW	0x08
#define FE_UNDERFLOW	0x10
#define FE_INEXACT	0x20
#define FE_ALL_EXCEPT (FE_INVALID | FE_DENORMAL | FE_DIVBYZERO \
		       | FE_OVERFLOW | FE_UNDERFLOW | FE_INEXACT)

/* FPU control word rounding flags */
#define FE_TONEAREST	0x0000
#define FE_DOWNWARD	0x0400
#define FE_UPWARD	0x0800
#define FE_TOWARDZERO	0x0c00

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

#if defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__)

/* Type representing exception flags. */
typedef unsigned int fexcept_t;

/* Type representing floating-point environment.  */
typedef struct
{
    unsigned int __cw;
} fenv_t;

/* If the default argument is used we use this value.  */
#define FE_DFL_ENV  ((const fenv_t *) -1l)

#else

/*
  For now, support only for the basic abstraction of flags that are
  either set or clear. fexcept_t could be  structure that holds more
  info about the fp environment.
*/
typedef unsigned short fexcept_t;

/* This 32-byte struct represents the entire floating point
   environment as stored by fnstenv or fstenv, augmented by
   the  contents of the MXCSR register, as stored by stmxcsr
   (if CPU supports it). */
typedef struct
{
  unsigned short __control_word;
  unsigned short __unused0;
  unsigned short __status_word;
  unsigned short __unused1;
  unsigned short __tag_word;
  unsigned short __unused2;  
  unsigned int	 __ip_offset;    /* instruction pointer offset */
  unsigned short __ip_selector;  
  unsigned short __opcode;
  unsigned int	 __data_offset;
  unsigned short __data_selector;  
  unsigned short __unused3;
  unsigned int   __mxcsr; /* contents of the MXCSR register  */
} fenv_t;


/*The C99 standard (7.6.9) allows us to define implementation-specific macros for
  different fp environments */
  
/* The default Intel x87 floating point environment (64-bit mantissa) */
#define FE_PC64_ENV ((const fenv_t *)-1)

/* The floating point environment set by MSVCRT _fpreset (53-bit mantissa) */
#define FE_PC53_ENV ((const fenv_t *)-2)

/* The FE_DFL_ENV macro is required by standard.
  fesetenv will use the environment set at app startup.*/
#define FE_DFL_ENV ((const fenv_t *) 0)

#endif /* defined(_ARM_) || defined(__arm__) */

#ifdef __cplusplus
extern "C" {
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
