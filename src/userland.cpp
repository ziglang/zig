// This file is a shim for zig1. The real implementations of these are in
// src-self-hosted/stage1.zig

#include "userland.h"
#include "ast_render.hpp"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

Error stage2_translate_c(struct Stage2Ast **out_ast,
        struct Stage2ErrorMsg **out_errors_ptr, size_t *out_errors_len,
        const char **args_begin, const char **args_end, enum Stage2TranslateMode mode,
        const char *resources_path)
{
    const char *msg = "stage0 called stage2_translate_c";
    stage2_panic(msg, strlen(msg));
}

void stage2_free_clang_errors(struct Stage2ErrorMsg *ptr, size_t len) {
    const char *msg = "stage0 called stage2_free_clang_errors";
    stage2_panic(msg, strlen(msg));
}

void stage2_zen(const char **ptr, size_t *len) {
    const char *msg = "stage0 called stage2_zen";
    stage2_panic(msg, strlen(msg));
}

void stage2_panic(const char *ptr, size_t len) {
    fwrite(ptr, 1, len, stderr);
    fprintf(stderr, "\n");
    fflush(stderr);
    abort();
}

void stage2_render_ast(struct Stage2Ast *ast, FILE *output_file) {
    const char *msg = "stage0 called stage2_render_ast";
    stage2_panic(msg, strlen(msg));
}
