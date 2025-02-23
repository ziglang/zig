int foo(void) __attribute__((__visibility__("default")));

#ifndef NO_MAIN
int main(void) {
    return foo();
}
#endif

int __attribute__ ((__target__("default"))) foo_impl(void) {
    return 1;
}
int __attribute__ ((__target__("avx2"))) foo_impl(void) {
    return 2;
}
int __attribute__ ((__target__("avx512vnni"))) foo_impl(void) {
    return 3;
}

int foo(void) {
    return foo_impl();
}
