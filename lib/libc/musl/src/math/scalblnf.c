#include <limits.h>
#include <math.h>

float scalblnf(float x, long n)
{
	if (n > INT_MAX)
		n = INT_MAX;
	else if (n < INT_MIN)
		n = INT_MIN;
	return scalbnf(x, n);
}
