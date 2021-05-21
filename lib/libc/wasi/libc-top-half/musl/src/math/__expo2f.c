#include "libm.h"

/* k is such that k*ln2 has minimal relative error and x - kln2 > log(FLT_MIN) */
static const int k = 235;
static const float kln2 = 0x1.45c778p+7f;

/* expf(x)/2 for x >= log(FLT_MAX), slightly better than 0.5f*expf(x/2)*expf(x/2) */
#ifdef __wasilibc_unmodified_upstream // Wasm doesn't have alternate rounding modes
float __expo2f(float x, float sign)
#else
float __expo2f(float x)
#endif
{
	float scale;

	/* note that k is odd and scale*scale overflows */
	SET_FLOAT_WORD(scale, (uint32_t)(0x7f + k/2) << 23);
	/* exp(x - k ln2) * 2**(k-1) */
#ifdef __wasilibc_unmodified_upstream // Wasm doesn't have alternate rounding modes
	/* in directed rounding correct sign before rounding or overflow is important */
	return expf(x - kln2) * (sign * scale) * scale;
#else
	return expf(x - kln2) * scale * scale;
#endif
}
