#include "softfloat_ext.hpp"

extern "C" {
    #include "platform.h"
    #include "internals.h"
    #include "softfloat.h"
}

void f128M_abs(const float128_t *aPtr, float128_t *zPtr) {
    float128_t zero_float;
    ui32_to_f128M(0, &zero_float);
    if (f128M_lt(aPtr, &zero_float)) {
        f128M_sub(&zero_float, aPtr, zPtr);
    } else {
        *zPtr = *aPtr;
    } 
}

void f128M_trunc(const float128_t *aPtr, float128_t *zPtr) {
    float128_t zero_float;
    ui32_to_f128M(0, &zero_float);
    if (f128M_lt(aPtr, &zero_float)) {
        f128M_roundToInt(aPtr, softfloat_round_max, false, zPtr);
    } else {
        f128M_roundToInt(aPtr, softfloat_round_min, false, zPtr);
    } 
}

float16_t f16_neg(const float16_t a) {
    union ui16_f16 uZ;
    uZ.ui = a.v ^ (UINT16_C(1) << 15);
    return uZ.f;
}

void f128M_neg(const float128_t *aPtr, float128_t *zPtr) {
    zPtr->v[indexWord(2,1)] = aPtr->v[indexWord(2,1)] ^ (UINT64_C(1) << 63);
    zPtr->v[indexWord(2,0)] = aPtr->v[indexWord(2,0)];
}