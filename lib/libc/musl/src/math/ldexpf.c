#include <math.h>

float ldexpf(float x, int n)
{
	return scalbnf(x, n);
}
