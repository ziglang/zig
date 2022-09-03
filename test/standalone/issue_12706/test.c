#include <stdarg.h>

void testFnPtr(int n, ...) {
    va_list ap;
    va_start(ap, n);

    void (*fnPtr)(int) = va_arg(ap, void (*)(int));
    int arg = va_arg(ap, int);
    fnPtr(arg);
    va_end(ap);
}