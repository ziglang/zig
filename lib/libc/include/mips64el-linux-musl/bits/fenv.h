#ifdef __mips_soft_float
#define FE_ALL_EXCEPT 0
#define FE_TONEAREST  0
#else
#define FE_INEXACT    4
#define FE_UNDERFLOW  8
#define FE_OVERFLOW   16
#define FE_DIVBYZERO  32
#define FE_INVALID    64

#define FE_ALL_EXCEPT 124

#define FE_TONEAREST  0
#define FE_TOWARDZERO 1
#define FE_UPWARD     2
#define FE_DOWNWARD   3
#endif

typedef unsigned short fexcept_t;

typedef struct {
	unsigned __cw;
} fenv_t;

#define FE_DFL_ENV ((const fenv_t *) -1)