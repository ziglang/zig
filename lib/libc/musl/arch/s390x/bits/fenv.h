#define FE_TONEAREST	0
#define FE_TOWARDZERO	1
#define FE_UPWARD	2
#define FE_DOWNWARD	3

#define FE_INEXACT	0x00080000
#define FE_UNDERFLOW	0x00100000
#define FE_OVERFLOW	0x00200000
#define FE_DIVBYZERO	0x00400000
#define FE_INVALID	0x00800000

#define FE_ALL_EXCEPT	0x00f80000

typedef unsigned fexcept_t;
typedef unsigned fenv_t;

#define FE_DFL_ENV ((const fenv_t *)-1)
