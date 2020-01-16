// This file is a shim for zig1. The real implementations of these are in
// src-self-hosted/stage1.zig

#include "userland.h"
#include "ast_render.hpp"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

Error stage2_translate_c(struct Stage2Ast **out_ast,
        struct Stage2ErrorMsg **out_errors_ptr, size_t *out_errors_len,
        const char **args_begin, const char **args_end, const char *resources_path)
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

void stage2_attach_segfault_handler(void) { }

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

int stage2_fmt(int argc, char **argv) {
    const char *msg = "stage0 called stage2_fmt";
    stage2_panic(msg, strlen(msg));
}

stage2_DepTokenizer stage2_DepTokenizer_init(const char *input, size_t len) {
    const char *msg = "stage0 called stage2_DepTokenizer_init";
    stage2_panic(msg, strlen(msg));
}

void stage2_DepTokenizer_deinit(stage2_DepTokenizer *self) {
    const char *msg = "stage0 called stage2_DepTokenizer_deinit";
    stage2_panic(msg, strlen(msg));
}

stage2_DepNextResult stage2_DepTokenizer_next(stage2_DepTokenizer *self) {
    const char *msg = "stage0 called stage2_DepTokenizer_next";
    stage2_panic(msg, strlen(msg));
}


struct Stage2Progress {
    int trash;
};

struct Stage2ProgressNode {
    int trash;
};

Stage2Progress *stage2_progress_create(void) {
    return nullptr;
}

void stage2_progress_destroy(Stage2Progress *progress) {}

Stage2ProgressNode *stage2_progress_start_root(Stage2Progress *progress,
        const char *name_ptr, size_t name_len, size_t estimated_total_items)
{
    return nullptr;
}
Stage2ProgressNode *stage2_progress_start(Stage2ProgressNode *node,
        const char *name_ptr, size_t name_len, size_t estimated_total_items)
{
    return nullptr;
}
void stage2_progress_end(Stage2ProgressNode *node) {}
void stage2_progress_complete_one(Stage2ProgressNode *node) {}
void stage2_progress_disable_tty(Stage2Progress *progress) {}
void stage2_progress_update_node(Stage2ProgressNode *node, size_t completed_count, size_t estimated_total_items){}
