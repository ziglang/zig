#include <stdlib.h>
int main(void) {
    int i = 0;
    *&i = 42;
    if (i != 42) abort();
    return 0;
}

// run-translated-c
// c_frontend=clang
// link_libc=true
