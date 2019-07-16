#include <math.h>
#include "libm.h"

float lgammaf(float x)
{
	return __lgammaf_r(x, &__signgam);
}
