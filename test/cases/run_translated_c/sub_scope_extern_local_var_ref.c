#include <stdlib.h>
int a = 42;
int foo(int bar) {
    extern int a;
    if (bar) {
        return a;
    }
    return 0;
}
int main() {
    int result1 = foo(0);
    if (result1 != 0) abort();
    int result2 = foo(1);
    if (result2 != 42) abort();
    a = 100;
    int result3 = foo(1);
    if (result3 != 100) abort();
    return 0;
}

// run-translated-c
// c_frontend=clang
