#define _GNU_SOURCE
#include <math.h>

double significand(double x)
{
	return scalbn(x, -ilogb(x));
}
