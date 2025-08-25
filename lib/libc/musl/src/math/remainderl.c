#include <math.h>
#include <float.h>

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double remainderl(long double x, long double y)
{
	return remainder(x, y);
}
#else
long double remainderl(long double x, long double y)
{
	int q;
	return remquol(x, y, &q);
}
#endif
