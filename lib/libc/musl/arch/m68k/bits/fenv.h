#if __HAVE_68881__ || __mcffpu__

#define FE_INEXACT    8
#define FE_DIVBYZERO  16
#define FE_UNDERFLOW  32
#define FE_OVERFLOW   64
#define FE_INVALID    128

#define FE_ALL_EXCEPT 0xf8

#define FE_TONEAREST  0
#define FE_TOWARDZERO 16
#define FE_DOWNWARD   32
#define FE_UPWARD     48

#else

#define FE_ALL_EXCEPT 0
#define FE_TONEAREST  0

#endif

typedef unsigned fexcept_t;

typedef struct {
	unsigned __control_register, __status_register, __instruction_address;
} fenv_t;

#define FE_DFL_ENV      ((const fenv_t *) -1)
