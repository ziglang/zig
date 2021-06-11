#include <math.h>
#include <float.h>

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double fmaxl(long double x, long double y)
{
	return fmax(x, y);
}
#else
long double fmaxl(long double x, long double y)
{
	if (isnan(x))
		return y;
	if (isnan(y))
		return x;
	/* handle signed zeros, see C99 Annex F.9.9.2 */
	if (signbit(x) != signbit(y))
		return signbit(x) ? y : x;
	return x < y ? y : x;
}
#endif
