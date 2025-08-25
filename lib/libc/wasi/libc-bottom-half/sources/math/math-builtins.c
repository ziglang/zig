// Each of the following math functions can be implemented with a single
// wasm instruction, so use that implementation rather than the portable
// one in libm.

#include <math.h>

float fabsf(float x) {
    return __builtin_fabsf(x);
}

double fabs(double x) {
    return __builtin_fabs(x);
}

float sqrtf(float x) {
    return __builtin_sqrtf(x);
}

double sqrt(double x) {
    return __builtin_sqrt(x);
}

float copysignf(float x, float y) {
    return __builtin_copysignf(x, y);
}

double copysign(double x, double y) {
    return __builtin_copysign(x, y);
}

float ceilf(float x) {
    return __builtin_ceilf(x);
}

double ceil(double x) {
    return __builtin_ceil(x);
}

float floorf(float x) {
    return __builtin_floorf(x);
}

double floor(double x) {
    return __builtin_floor(x);
}

float truncf(float x) {
    return __builtin_truncf(x);
}

double trunc(double x) {
    return __builtin_trunc(x);
}

float nearbyintf(float x) {
    return __builtin_nearbyintf(x);
}

double nearbyint(double x) {
    return __builtin_nearbyint(x);
}

float rintf(float x) {
    return __builtin_rintf(x);
}

double rint(double x) {
    return __builtin_rint(x);
}
