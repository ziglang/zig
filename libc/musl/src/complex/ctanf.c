#include "libm.h"

float complex ctanf(float complex z)
{
	z = ctanhf(CMPLXF(-cimagf(z), crealf(z)));
	return CMPLXF(cimagf(z), -crealf(z));
}
