// test.cpp
#include <new>
#include <cstdio>

int main() {
    int *x = new int;
    *x = 5;
    fprintf(stderr, "x: %d\n", *x);
    delete x;
}
