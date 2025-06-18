#define FE_INVALID    (1 << 1)
#define FE_DIVBYZERO  (1 << 2)
#define FE_OVERFLOW   (1 << 3)
#define FE_UNDERFLOW  (1 << 4)
#define FE_INEXACT    (1 << 5)
#define FE_ALL_EXCEPT (FE_DIVBYZERO | FE_INEXACT | FE_INVALID | \
                       FE_OVERFLOW | FE_UNDERFLOW)

#define FE_TONEAREST  0x00
#define FE_TOWARDZERO 0x01
#define FE_DOWNWARD   0x02
#define FE_UPWARD     0x03

typedef unsigned long fexcept_t;

typedef struct {
	unsigned long __cw;
} fenv_t;

#define FE_DFL_ENV      ((const fenv_t *) -1)