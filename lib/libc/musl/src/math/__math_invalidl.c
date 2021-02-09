#include <float.h>
#include "libm.h"

#if LDBL_MANT_DIG != DBL_MANT_DIG
long double __math_invalidl(long double x)
{
	return (x - x) / (x - x);
}
#endif
