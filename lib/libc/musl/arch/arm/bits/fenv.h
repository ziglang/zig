#ifndef __ARM_PCS_VFP
#define FE_ALL_EXCEPT 0
#define FE_TONEAREST  0
#else
#define FE_INVALID    1
#define FE_DIVBYZERO  2
#define FE_OVERFLOW   4
#define FE_UNDERFLOW  8
#define FE_INEXACT    16
#define FE_ALL_EXCEPT 31
#define FE_TONEAREST  0
#define FE_DOWNWARD   0x800000
#define FE_UPWARD     0x400000
#define FE_TOWARDZERO 0xc00000
#endif

typedef unsigned long fexcept_t;

typedef struct {
	unsigned long __cw;
} fenv_t;

#define FE_DFL_ENV      ((const fenv_t *) -1)
