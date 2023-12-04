#include <stdio.h>

int foo(void) __attribute__ ((__target__("default")));
int foo(void) __attribute__ ((__target__("avx2")));
int foo(void) __attribute__ ((__target__("avx512vnni")));

int main() {
    printf("%d\n", foo());
}

int __attribute__ ((__target__("default"))) foo(void) {
    return 1;
}
int __attribute__ ((__target__("avx2"))) foo(void) {
    return 2;
}
int __attribute__ ((__target__("avx512vnni"))) foo(void) {
    return 3;
}
