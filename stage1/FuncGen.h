#ifndef FUNC_GEN_H
#define FUNC_GEN_H

#include "panic.h"
#include "wasm.h"

#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

struct Block {
    uint32_t type;
    uint32_t label;
    uint32_t stack_i;
};

struct FuncGen {
    int8_t *type;
    uint32_t *stack;
    struct Block *block;
    uint32_t type_i;
    uint32_t stack_i;
    uint32_t block_i;
    uint32_t type_len;
    uint32_t stack_len;
    uint32_t block_len;
};

static void FuncGen_init(struct FuncGen *self) {
    memset(self, 0, sizeof(struct FuncGen));
}

static void FuncGen_reset(struct FuncGen *self) {
    self->type_i = 0;
    self->stack_i = 0;
    self->block_i = 0;
}

static void FuncGen_free(struct FuncGen *self) {
    free(self->block);
    free(self->stack);
    free(self->type);
}

static void FuncGen_outdent(struct FuncGen *self, FILE *out) {
    for (uint32_t i = 0; i < self->block_i; i += 1) fputs("    ", out);
}

static void FuncGen_indent(struct FuncGen *self, FILE *out) {
    FuncGen_outdent(self, out);
    fputs("    ", out);
}

static void FuncGen_cont(struct FuncGen *self, FILE *out) {
    FuncGen_indent(self, out);
    fputs("    ", out);
}

static uint32_t FuncGen_localAlloc(struct FuncGen *self, int8_t type) {
    if (self->type_i == self->type_len) {
        self->type_len += 10;
        self->type_len *= 2;
        self->type = realloc(self->type, sizeof(int8_t) * self->type_len);
        if (self->type == NULL) panic("out of memory");
    }
    uint32_t local_i = self->type_i;
    self->type[local_i] = type;
    self->type_i += 1;
    return local_i;
}

static uint32_t FuncGen_localDeclare(struct FuncGen *self, FILE *out, enum WasmValType val_type) {
    uint32_t local_i = FuncGen_localAlloc(self, (int8_t)val_type);
    fprintf(out, "%s l%" PRIu32, WasmValType_toC(val_type), local_i);
    return local_i;
}

static enum WasmValType FuncGen_localType(const struct FuncGen *self, uint32_t local_idx) {
    return self->type[local_idx];
}

static void FuncGen_stackPush(struct FuncGen *self, FILE *out, enum WasmValType val_type) {
    if (self->stack_i == self->stack_len) {
        self->stack_len += 10;
        self->stack_len *= 2;
        self->stack = realloc(self->stack, sizeof(uint32_t) * self->stack_len);
        if (self->stack == NULL) panic("out of memory");
    }
    FuncGen_indent(self, out);
    fputs("const ", out);
    self->stack[self->stack_i] = FuncGen_localDeclare(self, out, val_type);
    self->stack_i += 1;
    fputs(" = ", out);
}

static uint32_t FuncGen_stackAt(const struct FuncGen *self, uint32_t stack_idx) {
    return self->stack[self->stack_i - 1 - stack_idx];
}

static uint32_t FuncGen_stackPop(struct FuncGen *self) {
    self->stack_i -= 1;
    return self->stack[self->stack_i];
}

static void FuncGen_label(struct FuncGen *self, FILE *out, uint32_t label) {
    FuncGen_indent(self, out);
    fprintf(out, "goto l%" PRIu32 ";\n", label);
    FuncGen_outdent(self, out);
    fprintf(out, "l%" PRIu32 ":;\n", label);
}

static void FuncGen_blockBegin(struct FuncGen *self, FILE *out, enum WasmOpcode kind, int64_t type) {
    if (self->block_i == self->block_len) {
        self->block_len += 10;
        self->block_len *= 2;
        self->block = realloc(self->block, sizeof(struct Block) * self->block_len);
        if (self->block == NULL) panic("out of memory");
    }
    uint32_t label = FuncGen_localAlloc(self, type < 0 ? ~(int8_t)kind : (int8_t)kind);
    FuncGen_indent(self, out);
    if (kind == WasmOpcode_if) fprintf(out, "if (l%" PRIu32 ") ", FuncGen_stackPop(self));
    fputs("{\n", out);
    self->block[self->block_i].type = type < 0 ? ~type : type;
    self->block[self->block_i].label = label;
    self->block[self->block_i].stack_i = self->stack_i;
    self->block_i += 1;
    if (kind == WasmOpcode_loop) FuncGen_label(self, out, label);
}

static enum WasmOpcode FuncGen_blockKind(const struct FuncGen *self, uint32_t label_idx) {
    int8_t kind = self->type[self->block[self->block_i - 1 - label_idx].label];
    return (enum WasmOpcode)(kind < 0 ? ~kind : kind);
}

static int64_t FuncGen_blockType(const struct FuncGen *self, uint32_t label_idx) {
    struct Block *block = &self->block[self->block_i - 1 - label_idx];
    return self->type[block->label] < 0 ? ~(int64_t)block->type : (int64_t)block->type;
}

static uint32_t FuncGen_blockLabel(const struct FuncGen *self, uint32_t label_idx) {
    return self->block[self->block_i - 1 - label_idx].label;
}

static void FuncGen_blockEnd(struct FuncGen *self, FILE *out) {
    enum WasmOpcode kind = FuncGen_blockKind(self, 0);
    uint32_t label = FuncGen_blockLabel(self, 0);
    if (kind != WasmOpcode_loop) FuncGen_label(self, out, label);
    self->block_i -= 1;
    FuncGen_indent(self, out);
    fputs("}\n", out);
    if (self->stack_i != self->block[self->block_i].stack_i) {
        FuncGen_indent(self, out);
        fprintf(out, "// stack mismatch %u != %u\n", self->stack_i, self->block[self->block_i].stack_i);
    }
    self->stack_i = self->block[self->block_i].stack_i;
}

static bool FuncGen_done(const struct FuncGen *self) {
    return self->block_i == 0;
}

#endif /* FUNC_GEN_H */
