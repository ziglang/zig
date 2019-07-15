#include "libm.h"

#if FLT_EVAL_METHOD==2
#undef sqrtf
#define sqrtf sqrtl
#elif FLT_EVAL_METHOD==1
#undef sqrtf
#define sqrtf sqrt
#endif

/* acosh(x) = log(x + sqrt(x*x-1)) */
float acoshf(float x)
{
	union {float f; uint32_t i;} u = {x};
	uint32_t a = u.i & 0x7fffffff;

	if (a < 0x3f800000+(1<<23))
		/* |x| < 2, invalid if x < 1 or nan */
		/* up to 2ulp error in [1,1.125] */
		return log1pf(x-1 + sqrtf((x-1)*(x-1)+2*(x-1)));
	if (a < 0x3f800000+(12<<23))
		/* |x| < 0x1p12 */
		return logf(2*x - 1/(x+sqrtf(x*x-1)));
	/* x >= 0x1p12 */
	return logf(x) + 0.693147180559945309417232121458176568f;
}
