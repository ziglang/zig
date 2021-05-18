#include <math.h>

long double ldexpl(long double x, int n)
{
	return scalbnl(x, n);
}
