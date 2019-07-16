#include "libm.h"

float cargf(float complex z)
{
	return atan2f(cimagf(z), crealf(z));
}
