#include <math.h>

float logbf(float x)
{
	if (!isfinite(x))
		return x * x;
	if (x == 0)
		return -1/(x*x);
	return ilogbf(x);
}
