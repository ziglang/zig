#ifndef __SH_FPU_ANY__

#define FE_ALL_EXCEPT 0
#define FE_TONEAREST  0

#else

#define FE_TONEAREST  0
#define FE_TOWARDZERO 1

#define FE_INEXACT    0x04
#define FE_UNDERFLOW  0x08
#define FE_OVERFLOW   0x10
#define FE_DIVBYZERO  0x20
#define FE_INVALID    0x40
#define FE_ALL_EXCEPT 0x7c

#endif

typedef unsigned long fexcept_t;

typedef struct {
	unsigned long __cw;
} fenv_t;

#define FE_DFL_ENV    ((const fenv_t *) -1)
