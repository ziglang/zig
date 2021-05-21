#include "complex_impl.h"

float complex ccosf(float complex z)
{
	return ccoshf(CMPLXF(-cimagf(z), crealf(z)));
}
