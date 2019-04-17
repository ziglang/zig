// This file is a shim for zig1. The real implementations of these are in
// src-self-hosted/stage1.zig

#include "userland.h"

void stage2_translate_c(void) {}
void stage2_zen(const char **ptr, size_t *len) {
    *ptr = nullptr;
    *len = 0;
}
