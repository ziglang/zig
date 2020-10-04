#ifndef ZIG_SOFTFLOAT_EXT_HPP
#define ZIG_SOFTFLOAT_EXT_HPP

#include "softfloat_types.h"

void f128M_abs(const float128_t *aPtr, float128_t *zPtr);
void f128M_trunc(const float128_t *aPtr, float128_t *zPtr);

#endif