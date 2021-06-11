// Each of the following complex functions can be implemented with a single
// wasm instruction, so use that implementation rather than the portable
// one in libm.

#include <complex.h>

float (crealf)(float _Complex x) {
    return __builtin_crealf(x);
}

double (creal)(double _Complex x) {
    return __builtin_creal(x);
}

long double (creall)(long double _Complex x) {
    return __builtin_creall(x);
}

float (cimagf)(float _Complex x) {
    return __builtin_cimagf(x);
}

double (cimag)(double _Complex x) {
    return __builtin_cimag(x);
}

long double (cimagl)(long double _Complex x) {
    return __builtin_cimagl(x);
}
