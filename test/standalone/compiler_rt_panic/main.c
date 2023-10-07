#include <stddef.h>

void* __memset(void* dest, char c, size_t n, size_t dest_n);

char foo[128];

int main() {
    __memset(&foo[0], 0xff, 128, 128);
    return foo[64];
}

