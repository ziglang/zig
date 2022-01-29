#ifndef ZIG_SOFTFLOAT_EXT_HPP
#define ZIG_SOFTFLOAT_EXT_HPP

#include "softfloat_types.h"

void f128M_abs(const float128_t *aPtr, float128_t *zPtr);
void f128M_trunc(const float128_t *aPtr, float128_t *zPtr);
void f128M_neg(const float128_t *aPtr, float128_t *zPtr);

void extF80M_abs(const extFloat80_t *aPtr, extFloat80_t *zPtr);
void extF80M_trunc(const extFloat80_t *aPtr, extFloat80_t *zPtr);
void extF80M_neg(const extFloat80_t *aPtr, extFloat80_t *zPtr);

float16_t f16_neg(const float16_t a);

#endif