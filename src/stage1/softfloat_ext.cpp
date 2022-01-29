#include "softfloat_ext.hpp"
#include "zigendian.h"

extern "C" {
    #include "softfloat.h"
}

void f128M_abs(const float128_t *aPtr, float128_t *zPtr) {
    // Clear the sign bit.
#if ZIG_BYTE_ORDER == ZIG_LITTLE_ENDIAN
    zPtr->v[1] = aPtr->v[1] & ~(UINT64_C(1) << 63);
    zPtr->v[0] = aPtr->v[0];
#elif ZIG_BYTE_ORDER == ZIG_BIG_ENDIAN
    zPtr->v[0] = aPtr->v[0] & ~(UINT64_C(1) << 63);
    zPtr->v[1] = aPtr->v[1];
#else
#error Unsupported endian
#endif
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

void f128M_neg(const float128_t *aPtr, float128_t *zPtr) {
    // Toggle the sign bit.
#if ZIG_BYTE_ORDER == ZIG_LITTLE_ENDIAN
    zPtr->v[1] = aPtr->v[1] ^ (UINT64_C(1) << 63);
    zPtr->v[0] = aPtr->v[0];
#elif ZIG_BYTE_ORDER == ZIG_BIG_ENDIAN
    zPtr->v[0] = aPtr->v[0] ^ (UINT64_C(1) << 63);
    zPtr->v[1] = aPtr->v[1];
#else
#error Unsupported endian
#endif
}

void extF80M_abs(const extFloat80_t *aPtr, extFloat80_t *zPtr) {
    // Clear the sign bit.
    zPtr->signExp = aPtr->signExp & UINT16_C(0x7FFF);
    zPtr->signif = aPtr->signif;
}

void extF80M_trunc(const extFloat80_t *aPtr, extFloat80_t *zPtr) {
    extFloat80_t zero_float;
    ui32_to_extF80M(0, &zero_float);
    if (extF80M_lt(aPtr, &zero_float)) {
        extF80M_roundToInt(aPtr, softfloat_round_max, false, zPtr);
    } else {
        extF80M_roundToInt(aPtr, softfloat_round_min, false, zPtr);
    } 
}

void extF80M_neg(const extFloat80_t *aPtr, extFloat80_t *zPtr) {
    // Toggle the sign bit.
    zPtr->signExp = aPtr->signExp ^ UINT16_C(0x8000);
    zPtr->signif = aPtr->signif;
}

float16_t f16_neg(const float16_t a) {
    union { uint16_t ui; float16_t f; } uA;
    // Toggle the sign bit.
    uA.ui = a.v ^ (UINT16_C(1) << 15);
    return uA.f;
}
