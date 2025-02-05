#define FE_INEXACT    0x010000
#define FE_UNDERFLOW  0x020000
#define FE_OVERFLOW   0x040000
#define FE_DIVBYZERO  0x080000
#define FE_INVALID    0x100000

#define FE_ALL_EXCEPT 0x1F0000

#define FE_TONEAREST  0x000
#define FE_TOWARDZERO 0x100
#define FE_UPWARD     0x200
#define FE_DOWNWARD   0x300

typedef unsigned fexcept_t;

typedef struct {
	unsigned __cw;
} fenv_t;

#define FE_DFL_ENV ((const fenv_t *) -1)