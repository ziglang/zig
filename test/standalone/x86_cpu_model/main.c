#include <stdio.h>

int __attribute__ ((__target_clones__("default,avx2"))) foo(void) {
    return 0;
}

int main() {
    return foo();
}
