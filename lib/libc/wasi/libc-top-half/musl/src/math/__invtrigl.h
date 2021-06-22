#include <features.h>

/* shared by acosl, asinl and atan2l */
#define pio2_hi __pio2_hi
#define pio2_lo __pio2_lo
hidden extern const long double pio2_hi, pio2_lo;

hidden long double __invtrigl_R(long double z);
