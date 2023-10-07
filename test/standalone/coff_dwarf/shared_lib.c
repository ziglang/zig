#include <stdint.h>

__declspec(dllexport) uint32_t add(uint32_t a, uint32_t b, uintptr_t* addr) {
    *addr = (uintptr_t)&add;
    return a + b;
}
