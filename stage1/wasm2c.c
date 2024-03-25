#define EXTRA_BRACES 0

#include "FuncGen.h"
#include "InputStream.h"
#include "panic.h"
#include "wasm.h"

#include <inttypes.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct FuncType {
    const struct ResultType *param;
    const struct ResultType *result;
};
static const struct FuncType *FuncType_blockType(const struct FuncType *types, int64_t block_type) {
    if (block_type >= 0) return &types[block_type];

    static const struct ResultType none = { 0, { 0 }};
    static const struct ResultType i32 = { 1, { WasmValType_i32 } };
    static const struct ResultType i64 = { 1, { WasmValType_i64 } };
    static const struct ResultType f32 = { 1, { WasmValType_f32 } };
    static const struct ResultType f64 = { 1, { WasmValType_f64 } };

    static const struct FuncType none_i32 = { &none, &i32 };
    static const struct FuncType none_i64 = { &none, &i64 };
    static const struct FuncType none_f32 = { &none, &f32 };
    static const struct FuncType none_f64 = { &none, &f64 };
    static const struct FuncType none_none = { &none, &none };

    switch (block_type) {
        case WasmValType_i32: return &none_i32;
        case WasmValType_i64: return &none_i64;
        case WasmValType_f32: return &none_f32;
        case WasmValType_f64: return &none_f64;
        case WasmValType_empty: return &none_none;
        default: panic("unsupported block type");
    }
    return NULL;
}

static uint32_t evalExpr(struct InputStream *in) {
    uint32_t value;
    while (true) {
        switch (InputStream_readByte(in)) {
            case WasmOpcode_end: return value;

            case WasmOpcode_i32_const:
                value = (uint32_t)InputStream_readLeb128_i32(in);
                break;

            default: panic("unsupported expr opcode");
        }
    }
}

static void renderExpr(FILE *out, struct InputStream *in) {
    while (true) {
        switch (InputStream_readByte(in)) {
            case WasmOpcode_end: return;

            case WasmOpcode_i32_const: {
                uint32_t value = (uint32_t)InputStream_readLeb128_i32(in);
                fprintf(out, "UINT32_C(0x%" PRIX32 ")", value);
                break;
            }

            default: panic("unsupported expr opcode");
        }
    }
}

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "usage: %s in.wasm.zst out.c\n", argv[0]);
        return 1;
    }

    const char *mod = "wasm";
    bool is_big_endian = false; // TODO

    struct InputStream in;
    InputStream_open(&in, argv[1]);

    if (InputStream_readByte(&in) != '\0' ||
        InputStream_readByte(&in) != 'a'  ||
        InputStream_readByte(&in) != 's'  ||
        InputStream_readByte(&in) != 'm') panic("input is not a zstd-compressed wasm file");
    if (InputStream_readLittle_u32(&in) != 1) panic("unsupported wasm version");

    FILE *out = fopen(argv[2], "wb");
    if (out == NULL) panic("unable to open output file");
    fputs("#include <math.h>\n"
          "#include <stdint.h>\n"
          "#include <stdlib.h>\n"
          "#include <string.h>\n"
          "\n"
          "static uint16_t i16_byteswap(uint16_t src) {\n"
          "    return (uint16_t)(uint8_t)(src >> 0) << 8 |\n"
          "           (uint16_t)(uint8_t)(src >> 8) << 0;\n"
          "}\n"
          "static uint32_t i32_byteswap(uint32_t src) {\n"
          "    return (uint32_t)i16_byteswap(src >>  0) << 16 |\n"
          "           (uint32_t)i16_byteswap(src >> 16) <<  0;\n"
          "}\n"
          "static uint64_t i64_byteswap(uint64_t src) {\n"
          "    return (uint64_t)i32_byteswap(src >>  0) << 32 |\n"
          "           (uint64_t)i32_byteswap(src >> 32) <<  0;\n"
          "}\n"
          "\n", out);
    fputs("static uint16_t load16_align0(const uint8_t *ptr) {\n"
          "    uint16_t val;\n"
          "    memcpy(&val, ptr, sizeof(val));\n", out);
    if (is_big_endian) fputs("    val = i16_byteswap(val);", out);
    fputs("    return val;\n"
          "}\n"
          "static uint16_t load16_align1(const uint16_t *ptr) {\n"
          "    uint16_t val;\n"
          "    memcpy(&val, ptr, sizeof(val));\n", out);
    if (is_big_endian) fputs("    val = i16_byteswap(val);", out);
    fputs("    return val;\n"
          "}\n"
          "static uint32_t load32_align0(const uint8_t *ptr) {\n"
          "    uint32_t val;\n"
          "    memcpy(&val, ptr, sizeof(val));\n", out);
    if (is_big_endian) fputs("    val = i32_byteswap(val);", out);
    fputs("    return val;\n"
          "}\n"
          "static uint32_t load32_align1(const uint16_t *ptr) {\n"
          "    uint32_t val;\n"
          "    memcpy(&val, ptr, sizeof(val));\n", out);
    if (is_big_endian) fputs("    val = i32_byteswap(val);", out);
    fputs("    return val;\n"
          "}\n"
          "static uint32_t load32_align2(const uint32_t *ptr) {\n"
          "    uint32_t val;\n"
          "    memcpy(&val, ptr, sizeof(val));\n", out);
    if (is_big_endian) fputs("    val = i32_byteswap(val);", out);
    fputs("    return val;\n"
          "}\n"
          "static uint64_t load64_align0(const uint8_t *ptr) {\n"
          "    uint64_t val;\n"
          "    memcpy(&val, ptr, sizeof(val));\n", out);
    if (is_big_endian) fputs("    val = i64_byteswap(val);", out);
    fputs("    return val;\n"
          "}\n"
          "static uint64_t load64_align1(const uint16_t *ptr) {\n"
          "    uint64_t val;\n"
          "    memcpy(&val, ptr, sizeof(val));\n", out);
    if (is_big_endian) fputs("    val = i64_byteswap(val);", out);
    fputs("    return val;\n"
          "}\n"
          "static uint64_t load64_align2(const uint32_t *ptr) {\n"
          "    uint64_t val;\n"
          "    memcpy(&val, ptr, sizeof(val));\n", out);
    if (is_big_endian) fputs("    val = i64_byteswap(val);", out);
    fputs("    return val;\n"
          "}\n"
          "static uint64_t load64_align3(const uint64_t *ptr) {\n"
          "    uint64_t val;\n"
          "    memcpy(&val, ptr, sizeof(val));\n", out);
    if (is_big_endian) fputs("    val = i64_byteswap(val);", out);
    fputs("    return val;\n"
          "}\n"
          "\n"
          "static uint32_t i32_popcnt(uint32_t lhs) {\n"
          "    lhs = lhs - ((lhs >> 1) & UINT32_C(0x55555555));\n"
          "    lhs = (lhs & UINT32_C(0x33333333)) + ((lhs >> 2) & UINT32_C(0x33333333));\n"
          "    lhs = (lhs + (lhs >> 4)) & UINT32_C(0x0F0F0F0F);\n"
          "    return (lhs * UINT32_C(0x01010101)) >> 24;\n"
          "}\n"
          "static uint32_t i32_ctz(uint32_t lhs) {\n"
          "    return i32_popcnt(~lhs & (lhs - 1));\n"
          "}\n"
          "static uint32_t i32_clz(uint32_t lhs) {\n"
          "    lhs = i32_byteswap(lhs);\n"
          "    lhs = (lhs & UINT32_C(0x0F0F0F0F)) << 4 | (lhs & UINT32_C(0xF0F0F0F0)) >> 4;\n"
          "    lhs = (lhs & UINT32_C(0x33333333)) << 2 | (lhs & UINT32_C(0xCCCCCCCC)) >> 2;\n"
          "    lhs = (lhs & UINT32_C(0x55555555)) << 1 | (lhs & UINT32_C(0xAAAAAAAA)) >> 1;\n"
          "    return i32_ctz(lhs);\n"
          "}\n"
          "static uint64_t i64_popcnt(uint64_t lhs) {\n"
          "    lhs = lhs - ((lhs >> 1) & UINT64_C(0x5555555555555555));\n"
          "    lhs = (lhs & UINT64_C(0x3333333333333333)) + ((lhs >> 2) & UINT64_C(0x3333333333333333));\n"
          "    lhs = (lhs + (lhs >> 4)) & UINT64_C(0x0F0F0F0F0F0F0F0F);\n"
          "    return (lhs * UINT64_C(0x0101010101010101)) >> 56;\n"
          "}\n"
          "static uint64_t i64_ctz(uint64_t lhs) {\n"
          "    return i64_popcnt(~lhs & (lhs - 1));\n"
          "}\n"
          "static uint64_t i64_clz(uint64_t lhs) {\n"
          "    lhs = i64_byteswap(lhs);\n"
          "    lhs = (lhs & UINT64_C(0x0F0F0F0F0F0F0F0F)) << 4 | (lhs & UINT32_C(0xF0F0F0F0F0F0F0F0)) >> 4;\n"
          "    lhs = (lhs & UINT64_C(0x3333333333333333)) << 2 | (lhs & UINT32_C(0xCCCCCCCCCCCCCCCC)) >> 2;\n"
          "    lhs = (lhs & UINT64_C(0x5555555555555555)) << 1 | (lhs & UINT32_C(0xAAAAAAAAAAAAAAAA)) >> 1;\n"
          "    return i64_ctz(lhs);\n"
          "}\n"
          "\n"
          "static void store16_align0(uint8_t *ptr, uint16_t val) {\n", out);
    if (is_big_endian) fputs("    val = i16_byteswap(val);", out);
    fputs("    memcpy(ptr, &val, sizeof(val));\n"
          "}\n"
          "static void store16_align1(uint16_t *ptr, uint16_t val) {\n", out);
    if (is_big_endian) fputs("    val = i16_byteswap(val);", out);
    fputs("    memcpy(ptr, &val, sizeof(val));\n"
          "}\n"
          "static void store32_align0(uint8_t *ptr, uint32_t val) {\n", out);
    if (is_big_endian) fputs("    val = i32_byteswap(val);", out);
    fputs("    memcpy(ptr, &val, sizeof(val));\n"
          "}\n"
          "static void store32_align1(uint16_t *ptr, uint32_t val) {\n", out);
    if (is_big_endian) fputs("    val = i32_byteswap(val);", out);
    fputs("    memcpy(ptr, &val, sizeof(val));\n"
          "}\n"
          "static void store32_align2(uint32_t *ptr, uint32_t val) {\n", out);
    if (is_big_endian) fputs("    val = i32_byteswap(val);", out);
    fputs("    memcpy(ptr, &val, sizeof(val));\n"
          "}\n"
          "static void store64_align0(uint8_t *ptr, uint64_t val) {\n", out);
    if (is_big_endian) fputs("    val = i64_byteswap(val);", out);
    fputs("    memcpy(ptr, &val, sizeof(val));\n"
          "}\n"
          "static void store64_align1(uint16_t *ptr, uint64_t val) {\n", out);
    if (is_big_endian) fputs("    val = i64_byteswap(val);", out);
    fputs("    memcpy(ptr, &val, sizeof(val));\n"
          "}\n"
          "static void store64_align2(uint32_t *ptr, uint64_t val) {\n", out);
    if (is_big_endian) fputs("    val = i64_byteswap(val);", out);
    fputs("    memcpy(ptr, &val, sizeof(val));\n"
          "}\n"
          "static void store64_align3(uint64_t *ptr, uint64_t val) {\n", out);
    if (is_big_endian) fputs("    val = i64_byteswap(val);", out);
    fputs("    memcpy(ptr, &val, sizeof(val));\n"
          "}\n"
          "\n"
          "static uint32_t i32_reinterpret_f32(const float src) {\n"
          "    uint32_t dst;\n"
          "    memcpy(&dst, &src, sizeof(dst));\n"
          "    return dst;\n"
          "}\n"
          "static uint64_t i64_reinterpret_f64(const double src) {\n"
          "    uint64_t dst;\n"
          "    memcpy(&dst, &src, sizeof(dst));\n"
          "    return dst;\n"
          "}\n"
          "static float f32_reinterpret_i32(const uint32_t src) {\n"
          "    float dst;\n"
          "    memcpy(&dst, &src, sizeof(dst));\n"
          "    return dst;\n"
          "}\n"
          "static double f64_reinterpret_i64(const uint64_t src) {\n"
          "    double dst;\n"
          "    memcpy(&dst, &src, sizeof(dst));\n"
          "    return dst;\n"
          "}\n"
          "\n"
          "static uint32_t memory_grow(uint8_t **m, uint32_t *p, uint32_t *c, uint32_t n) {\n"
          "    uint8_t *new_m = *m;\n"
          "    uint32_t r = *p;\n"
          "    uint32_t new_p = r + n;\n"
          "    if (new_p > UINT32_C(0xFFFF)) return UINT32_C(0xFFFFFFFF);\n"
          "    uint32_t new_c = *c;\n"
          "    if (new_c < new_p) {\n"
          "        do new_c += new_c / 2 + 8; while (new_c < new_p);\n"
          "        if (new_c > UINT32_C(0xFFFF)) new_c = UINT32_C(0xFFFF);\n"
          "        new_m = realloc(new_m, new_c << 16);\n"
          "        if (new_m == NULL) return UINT32_C(0xFFFFFFFF);\n"
          "        *m = new_m;\n"
          "        *c = new_c;\n"
          "    }\n"
          "    *p = new_p;\n"
          "    memset(&new_m[r << 16], 0, n << 16);\n"
          "    return r;\n"
          "}\n"
          "\n"
          "static int inited;\n"
          "static void init_elem(void);\n"
          "static void init_data(void);\n"
          "static void init(void) {\n"
          "    if (inited != 0) return;\n"
          "    init_elem();\n"
          "    init_data();\n"
          "    inited = 1;\n"
          "}\n"
          "\n", out);

    struct FuncType *types;
    uint32_t max_param_len = 0;
    (void)InputStream_skipToSection(&in, WasmSectionId_type);
    {
        uint32_t len = InputStream_readLeb128_u32(&in);
        types = malloc(sizeof(struct FuncType) * len);
        if (types == NULL) panic("out of memory");
        for (uint32_t i = 0; i < len; i += 1) {
            if (InputStream_readByte(&in) != 0x60) panic("expected functype");
            types[i].param = InputStream_readResultType(&in);
            if (types[i].param->len > max_param_len) max_param_len = types[i].param->len;
            types[i].result = InputStream_readResultType(&in);
        }
    }

    struct Import {
        const char *mod;
        const char *name;
        uint32_t type_idx;
    } *imports;
    (void)InputStream_skipToSection(&in, WasmSectionId_import);
    uint32_t imports_len = InputStream_readLeb128_u32(&in);
    {
        imports = malloc(sizeof(struct Import) * imports_len);
        if (imports == NULL) panic("out of memory");
        for (uint32_t i = 0; i < imports_len; i += 1) {
            imports[i].mod = InputStream_readName(&in);
            imports[i].name = InputStream_readName(&in);
            switch (InputStream_readByte(&in)) {
                case 0x00: { // func
                    imports[i].type_idx = InputStream_readLeb128_u32(&in);
                    const struct FuncType *func_type = &types[imports[i].type_idx];
                    switch (func_type->result->len) {
                        case 0: fputs("void", out); break;
                        case 1: fputs(WasmValType_toC(func_type->result->types[0]), out); break;
                        default: panic("multiple function returns not supported");
                    }
                    fprintf(out, " %s_%s(", imports[i].mod, imports[i].name);
                    if (func_type->param->len == 0) fputs("void", out);
                    for (uint32_t param_i = 0; param_i < func_type->param->len; param_i += 1) {
                        if (param_i > 0) fputs(", ", out);
                        fputs(WasmValType_toC(func_type->param->types[param_i]), out);
                    }
                    fputs(");\n", out);
                    break;
                }

                case 0x01: // table
                case 0x02: // mem
                case 0x03: // global
                default:
                    panic("unsupported import type");
            }
        }
        fputc('\n', out);
    }

    struct Func {
        uint32_t type_idx;
    } *funcs;
    (void)InputStream_skipToSection(&in, WasmSectionId_func);
    {
        uint32_t len = InputStream_readLeb128_u32(&in);
        funcs = malloc(sizeof(struct Func) * len);
        if (funcs == NULL) panic("out of memory");
        for (uint32_t i = 0; i < len; i += 1) {
            funcs[i].type_idx = InputStream_readLeb128_u32(&in);
            const struct FuncType *func_type = &types[funcs[i].type_idx];
            fputs("static ", out);
            switch (func_type->result->len) {
                case 0: fputs("void", out); break;
                case 1: fputs(WasmValType_toC(func_type->result->types[0]), out); break;
                default: panic("multiple function returns not supported");
            }
            fprintf(out, " f%" PRIu32 "(", i);
            if (func_type->param->len == 0) fputs("void", out);
            for (uint32_t param_i = 0; param_i < func_type->param->len; param_i += 1) {
                if (param_i > 0) fputs(", ", out);
                fprintf(out, "%s", WasmValType_toC(func_type->param->types[param_i]));
            }
            fputs(");\n", out);
        }
        fputc('\n', out);
    }

    struct Table {
        int8_t type;
        struct Limits limits;
    } *tables;
    (void)InputStream_skipToSection(&in, WasmSectionId_table);
    {
        uint32_t len = InputStream_readLeb128_u32(&in);
        tables = malloc(sizeof(struct Table) * len);
        if (tables == NULL) panic("out of memory");
        for (uint32_t i = 0; i < len; i += 1) {
            int64_t ref_type = InputStream_readLeb128_i64(&in);
            switch (ref_type) {
                case WasmValType_funcref:
                    break;

                default: panic("unsupported reftype");
            }
            tables[i].type = ref_type;
            tables[i].limits = InputStream_readLimits(&in);
            if (tables[i].limits.min != tables[i].limits.max) panic("growable table not supported");
            fprintf(out, "static void (*t%" PRIu32 "[UINT32_C(%" PRIu32 ")])(void);\n",
                    i, tables[i].limits.min);
        }
        fputc('\n', out);
    }

    struct Mem {
        struct Limits limits;
    } *mems;
    (void)InputStream_skipToSection(&in, WasmSectionId_mem);
    uint32_t mems_len = InputStream_readLeb128_u32(&in);
    {
        mems = malloc(sizeof(struct Mem) * mems_len);
        if (mems == NULL) panic("out of memory");
        for (uint32_t i = 0; i < mems_len; i += 1) {
            mems[i].limits = InputStream_readLimits(&in);
            fprintf(out, "static uint8_t *m%" PRIu32 ";\n"
                    "static uint32_t p%" PRIu32 ";\n"
                    "static uint32_t c%" PRIu32 ";\n", i, i, i);
        }
        fputc('\n', out);
    }

    struct Global {
        bool mut;
        int8_t val_type;
    } *globals;
    (void)InputStream_skipToSection(&in, WasmSectionId_global);
    {
        uint32_t len = InputStream_readLeb128_u32(&in);
        globals = malloc(sizeof(struct Global) * len);
        if (globals == NULL) panic("out of memory");
        for (uint32_t i = 0; i < len; i += 1) {
            int64_t val_type = InputStream_readLeb128_i64(&in);
            enum WasmMut mut = InputStream_readByte(&in);
            fprintf(out, "%s%s g%" PRIu32 " = ", WasmMut_toC(mut), WasmValType_toC(val_type), i);
            renderExpr(out, &in);
            fputs(";\n", out);
            globals[i].mut = mut;
            globals[i].val_type = val_type;
        }
        fputc('\n', out);
    }

    (void)InputStream_skipToSection(&in, WasmSectionId_export);
    {
        uint32_t len = InputStream_readLeb128_u32(&in);
        for (uint32_t i = 0; i < len; i += 1) {
            char *name = InputStream_readName(&in);
            uint8_t kind = InputStream_readByte(&in);
            uint32_t idx = InputStream_readLeb128_u32(&in);
            switch (kind) {
                case 0x00: {
                    if (idx < imports_len) panic("can't export an import");
                    const struct FuncType *func_type = &types[funcs[idx - imports_len].type_idx];
                    switch (func_type->result->len) {
                        case 0: fputs("void", out); break;
                        case 1: fputs(WasmValType_toC(func_type->result->types[0]), out); break;
                        default: panic("multiple function returns not supported");
                    }
                    fprintf(out, " %s_%s(", mod, name);
                    if (func_type->param->len == 0) fputs("void", out);
                    for (uint32_t param_i = 0; param_i < func_type->param->len; param_i += 1) {
                        if (param_i > 0) fputs(", ", out);
                        fprintf(out, "%s l%" PRIu32, WasmValType_toC(func_type->param->types[param_i]), param_i);
                    }
                    fprintf(out,
                            ") {\n"
                            "    init();\n"
                            "    %sf%" PRIu32 "(",
                            func_type->result->len > 0 ? "return " : "", idx - imports_len);
                    for (uint32_t param_i = 0; param_i < func_type->param->len; param_i += 1) {
                        if (param_i > 0) fputs(", ", out);
                        fprintf(out, "l%" PRIu32, param_i);
                    }
                    fputs(");\n}\n", out);
                    break;
                }

                case 0x02:
                    fprintf(out, "uint8_t **const %s_%s = &m%" PRIu32 ";\n", mod, name, idx);
                    break;

                default: panic("unsupported export kind");
            }
            free(name);
        }
        fputc('\n', out);
    }

    (void)InputStream_skipToSection(&in, WasmSectionId_elem);
    {
        uint32_t len = InputStream_readLeb128_u32(&in);
        fputs("static void init_elem(void) {\n", out);
        for (uint32_t segment_i = 0; segment_i < len; segment_i += 1) {
            uint32_t table_idx = 0;
            uint32_t elem_type = InputStream_readLeb128_u32(&in);
            if (elem_type != 0x00) panic("unsupported elem type");
            uint32_t offset = evalExpr(&in);
            uint32_t segment_len = InputStream_readLeb128_u32(&in);
            for (uint32_t i = 0; i < segment_len; i += 1) {
                uint32_t func_id = InputStream_readLeb128_u32(&in);
                fprintf(out, "    t%" PRIu32 "[UINT32_C(%" PRIu32 ")] = (void (*)(void))&",
                        table_idx, offset + i);
                if (func_id < imports_len)
                    fprintf(out, "%s_%s", imports[func_id].mod, imports[func_id].name);
                else
                    fprintf(out, "f%" PRIu32, func_id - imports_len);
                fputs(";\n", out);
            }
        }
        fputs("}\n\n", out);
    }

    (void)InputStream_skipToSection(&in, WasmSectionId_code);
    {
        struct FuncGen fg;
        FuncGen_init(&fg);
        bool *param_used = malloc(sizeof(bool) * max_param_len);
        uint32_t *param_stash = malloc(sizeof(uint32_t) * max_param_len);

        uint32_t len = InputStream_readLeb128_u32(&in);
        for (uint32_t func_i = 0; func_i < len; func_i += 1) {
            FuncGen_reset(&fg);

            InputStream_readLeb128_u32(&in);
            const struct FuncType *func_type = &types[funcs[func_i].type_idx];
            fputs("static ", out);
            switch (func_type->result->len) {
                case 0: fputs("void", out); break;
                case 1: fputs(WasmValType_toC(func_type->result->types[0]), out); break;
                default: panic("multiple function returns not supported");
            }
            fprintf(out, " f%" PRIu32 "(", func_i);
            if (func_type->param->len == 0) fputs("void", out);
            for (uint32_t param_i = 0; param_i < func_type->param->len; param_i += 1) {
                param_used[param_i] = false;
                int8_t param_type = func_type->param->types[param_i];
                if (param_i > 0) fputs(", ", out);
                FuncGen_localDeclare(&fg, out, param_type);
            }
            fputs(") {\n", out);

            for (uint32_t local_sets_remaining = InputStream_readLeb128_u32(&in);
                 local_sets_remaining > 0; local_sets_remaining -= 1) {
                uint32_t local_set_len = InputStream_readLeb128_u32(&in);
                int64_t val_type = InputStream_readLeb128_i64(&in);
                for (; local_set_len > 0; local_set_len -= 1) {
                    FuncGen_indent(&fg, out);
                    FuncGen_localDeclare(&fg, out, val_type);
                    fputs(" = 0;\n", out);
                }
            }

            uint32_t unreachable_depth = 0;
            for (uint32_t result_i = func_type->result->len; result_i > 0; ) {
                result_i -= 1;
                FuncGen_indent(&fg, out);
                (void)FuncGen_localDeclare(&fg, out,
                                           func_type->result->types[result_i]);
                fputs(";\n", out);
            }
            FuncGen_blockBegin(&fg, out, WasmOpcode_block, funcs[func_i].type_idx);
            while (!FuncGen_done(&fg)) {
                //static const char *mnemonics[] = {
                //    [WasmOpcode_unreachable]         = "unreachable",
                //    [WasmOpcode_nop]                 = "nop",
                //    [WasmOpcode_block]               = "block",
                //    [WasmOpcode_loop]                = "loop",
                //    [WasmOpcode_if]                  = "if",
                //    [WasmOpcode_else]                = "else",
                //    [WasmOpcode_end]                 = "end",
                //    [WasmOpcode_br]                  = "br",
                //    [WasmOpcode_br_if]               = "br_if",
                //    [WasmOpcode_br_table]            = "br_table",
                //    [WasmOpcode_return]              = "return",
                //    [WasmOpcode_call]                = "call",
                //    [WasmOpcode_call_indirect]       = "call_indirect",
                //
                //    [WasmOpcode_drop]                = "drop",
                //    [WasmOpcode_select]              = "select",
                //    [WasmOpcode_select_t]            = "select t",
                //
                //    [WasmOpcode_local_get]           = "local.get",
                //    [WasmOpcode_local_set]           = "local.set",
                //    [WasmOpcode_local_tee]           = "local.tee",
                //    [WasmOpcode_global_get]          = "global.get",
                //    [WasmOpcode_global_set]          = "global.set",
                //    [WasmOpcode_table_get]           = "table.get",
                //    [WasmOpcode_table_set]           = "table.set",
                //
                //    [WasmOpcode_i32_load]            = "i32.load",
                //    [WasmOpcode_i64_load]            = "i64.load",
                //    [WasmOpcode_f32_load]            = "f32.load",
                //    [WasmOpcode_f64_load]            = "f64.load",
                //    [WasmOpcode_i32_load8_s]         = "i32.load8_s",
                //    [WasmOpcode_i32_load8_u]         = "i32.load8_u",
                //    [WasmOpcode_i32_load16_s]        = "i32.load16_s",
                //    [WasmOpcode_i32_load16_u]        = "i32.load16_u",
                //    [WasmOpcode_i64_load8_s]         = "i64.load8_s",
                //    [WasmOpcode_i64_load8_u]         = "i64.load8_u",
                //    [WasmOpcode_i64_load16_s]        = "i64.load16_s",
                //    [WasmOpcode_i64_load16_u]        = "i64.load16_u",
                //    [WasmOpcode_i64_load32_s]        = "i64.load32_s",
                //    [WasmOpcode_i64_load32_u]        = "i64.load32_u",
                //    [WasmOpcode_i32_store]           = "i32.store",
                //    [WasmOpcode_i64_store]           = "i64.store",
                //    [WasmOpcode_f32_store]           = "f32.store",
                //    [WasmOpcode_f64_store]           = "f64.store",
                //    [WasmOpcode_i32_store8]          = "i32.store8",
                //    [WasmOpcode_i32_store16]         = "i32.store16",
                //    [WasmOpcode_i64_store8]          = "i64.store8",
                //    [WasmOpcode_i64_store16]         = "i64.store16",
                //    [WasmOpcode_i64_store32]         = "i64.store32",
                //    [WasmOpcode_memory_size]         = "memory.size",
                //    [WasmOpcode_memory_grow]         = "memory.grow",
                //
                //    [WasmOpcode_i32_const]           = "i32.const",
                //    [WasmOpcode_i64_const]           = "i64.const",
                //    [WasmOpcode_f32_const]           = "f32.const",
                //    [WasmOpcode_f64_const]           = "f64.const",
                //
                //    [WasmOpcode_i32_eqz]             = "i32.eqz",
                //    [WasmOpcode_i32_eq]              = "i32.eq",
                //    [WasmOpcode_i32_ne]              = "i32.ne",
                //    [WasmOpcode_i32_lt_s]            = "i32.lt_s",
                //    [WasmOpcode_i32_lt_u]            = "i32.lt_u",
                //    [WasmOpcode_i32_gt_s]            = "i32.gt_s",
                //    [WasmOpcode_i32_gt_u]            = "i32.gt_u",
                //    [WasmOpcode_i32_le_s]            = "i32.le_s",
                //    [WasmOpcode_i32_le_u]            = "i32.le_u",
                //    [WasmOpcode_i32_ge_s]            = "i32.ge_s",
                //    [WasmOpcode_i32_ge_u]            = "i32.ge_u",
                //
                //    [WasmOpcode_i64_eqz]             = "i64.eqz",
                //    [WasmOpcode_i64_eq]              = "i64.eq",
                //    [WasmOpcode_i64_ne]              = "i64.ne",
                //    [WasmOpcode_i64_lt_s]            = "i64.lt_s",
                //    [WasmOpcode_i64_lt_u]            = "i64.lt_u",
                //    [WasmOpcode_i64_gt_s]            = "i64.gt_s",
                //    [WasmOpcode_i64_gt_u]            = "i64.gt_u",
                //    [WasmOpcode_i64_le_s]            = "i64.le_s",
                //    [WasmOpcode_i64_le_u]            = "i64.le_u",
                //    [WasmOpcode_i64_ge_s]            = "i64.ge_s",
                //    [WasmOpcode_i64_ge_u]            = "i64.ge_u",
                //
                //    [WasmOpcode_f32_eq]              = "f32.eq",
                //    [WasmOpcode_f32_ne]              = "f32.ne",
                //    [WasmOpcode_f32_lt]              = "f32.lt",
                //    [WasmOpcode_f32_gt]              = "f32.gt",
                //    [WasmOpcode_f32_le]              = "f32.le",
                //    [WasmOpcode_f32_ge]              = "f32.ge",
                //
                //    [WasmOpcode_f64_eq]              = "f64.eq",
                //    [WasmOpcode_f64_ne]              = "f64.ne",
                //    [WasmOpcode_f64_lt]              = "f64.lt",
                //    [WasmOpcode_f64_gt]              = "f64.gt",
                //    [WasmOpcode_f64_le]              = "f64.le",
                //    [WasmOpcode_f64_ge]              = "f64.ge",
                //
                //    [WasmOpcode_i32_clz]             = "i32.clz",
                //    [WasmOpcode_i32_ctz]             = "i32.ctz",
                //    [WasmOpcode_i32_popcnt]          = "i32.popcnt",
                //    [WasmOpcode_i32_add]             = "i32.add",
                //    [WasmOpcode_i32_sub]             = "i32.sub",
                //    [WasmOpcode_i32_mul]             = "i32.mul",
                //    [WasmOpcode_i32_div_s]           = "i32.div_s",
                //    [WasmOpcode_i32_div_u]           = "i32.div_u",
                //    [WasmOpcode_i32_rem_s]           = "i32.rem_s",
                //    [WasmOpcode_i32_rem_u]           = "i32.rem_u",
                //    [WasmOpcode_i32_and]             = "i32.and",
                //    [WasmOpcode_i32_or]              = "i32.or",
                //    [WasmOpcode_i32_xor]             = "i32.xor",
                //    [WasmOpcode_i32_shl]             = "i32.shl",
                //    [WasmOpcode_i32_shr_s]           = "i32.shr_s",
                //    [WasmOpcode_i32_shr_u]           = "i32.shr_u",
                //    [WasmOpcode_i32_rotl]            = "i32.rotl",
                //    [WasmOpcode_i32_rotr]            = "i32.rotr",
                //
                //    [WasmOpcode_i64_clz]             = "i64.clz",
                //    [WasmOpcode_i64_ctz]             = "i64.ctz",
                //    [WasmOpcode_i64_popcnt]          = "i64.popcnt",
                //    [WasmOpcode_i64_add]             = "i64.add",
                //    [WasmOpcode_i64_sub]             = "i64.sub",
                //    [WasmOpcode_i64_mul]             = "i64.mul",
                //    [WasmOpcode_i64_div_s]           = "i64.div_s",
                //    [WasmOpcode_i64_div_u]           = "i64.div_u",
                //    [WasmOpcode_i64_rem_s]           = "i64.rem_s",
                //    [WasmOpcode_i64_rem_u]           = "i64.rem_u",
                //    [WasmOpcode_i64_and]             = "i64.and",
                //    [WasmOpcode_i64_or]              = "i64.or",
                //    [WasmOpcode_i64_xor]             = "i64.xor",
                //    [WasmOpcode_i64_shl]             = "i64.shl",
                //    [WasmOpcode_i64_shr_s]           = "i64.shr_s",
                //    [WasmOpcode_i64_shr_u]           = "i64.shr_u",
                //    [WasmOpcode_i64_rotl]            = "i64.rotl",
                //    [WasmOpcode_i64_rotr]            = "i64.rotr",
                //
                //    [WasmOpcode_f32_abs]             = "f32.abs",
                //    [WasmOpcode_f32_neg]             = "f32.neg",
                //    [WasmOpcode_f32_ceil]            = "f32.ceil",
                //    [WasmOpcode_f32_floor]           = "f32.floor",
                //    [WasmOpcode_f32_trunc]           = "f32.trunc",
                //    [WasmOpcode_f32_nearest]         = "f32.nearest",
                //    [WasmOpcode_f32_sqrt]            = "f32.sqrt",
                //    [WasmOpcode_f32_add]             = "f32.add",
                //    [WasmOpcode_f32_sub]             = "f32.sub",
                //    [WasmOpcode_f32_mul]             = "f32.mul",
                //    [WasmOpcode_f32_div]             = "f32.div",
                //    [WasmOpcode_f32_min]             = "f32.min",
                //    [WasmOpcode_f32_max]             = "f32.max",
                //    [WasmOpcode_f32_copysign]        = "f32.copysign",
                //
                //    [WasmOpcode_f64_abs]             = "f64.abs",
                //    [WasmOpcode_f64_neg]             = "f64.neg",
                //    [WasmOpcode_f64_ceil]            = "f64.ceil",
                //    [WasmOpcode_f64_floor]           = "f64.floor",
                //    [WasmOpcode_f64_trunc]           = "f64.trunc",
                //    [WasmOpcode_f64_nearest]         = "f64.nearest",
                //    [WasmOpcode_f64_sqrt]            = "f64.sqrt",
                //    [WasmOpcode_f64_add]             = "f64.add",
                //    [WasmOpcode_f64_sub]             = "f64.sub",
                //    [WasmOpcode_f64_mul]             = "f64.mul",
                //    [WasmOpcode_f64_div]             = "f64.div",
                //    [WasmOpcode_f64_min]             = "f64.min",
                //    [WasmOpcode_f64_max]             = "f64.max",
                //    [WasmOpcode_f64_copysign]        = "f64.copysign",
                //
                //    [WasmOpcode_i32_wrap_i64]        = "i32.wrap_i64",
                //    [WasmOpcode_i32_trunc_f32_s]     = "i32.trunc_f32_s",
                //    [WasmOpcode_i32_trunc_f32_u]     = "i32.trunc_f32_u",
                //    [WasmOpcode_i32_trunc_f64_s]     = "i32.trunc_f64_s",
                //    [WasmOpcode_i32_trunc_f64_u]     = "i32.trunc_f64_u",
                //    [WasmOpcode_i64_extend_i32_s]    = "i64.extend_i32_s",
                //    [WasmOpcode_i64_extend_i32_u]    = "i64.extend_i32_u",
                //    [WasmOpcode_i64_trunc_f32_s]     = "i64.trunc_f32_s",
                //    [WasmOpcode_i64_trunc_f32_u]     = "i64.trunc_f32_u",
                //    [WasmOpcode_i64_trunc_f64_s]     = "i64.trunc_f64_s",
                //    [WasmOpcode_i64_trunc_f64_u]     = "i64.trunc_f64_u",
                //    [WasmOpcode_f32_convert_i32_s]   = "f32.convert_i32_s",
                //    [WasmOpcode_f32_convert_i32_u]   = "f32.convert_i32_u",
                //    [WasmOpcode_f32_convert_i64_s]   = "f32.convert_i64_s",
                //    [WasmOpcode_f32_convert_i64_u]   = "f32.convert_i64_u",
                //    [WasmOpcode_f32_demote_f64]      = "f32.demote_f64",
                //    [WasmOpcode_f64_convert_i32_s]   = "f64.convert_i32_s",
                //    [WasmOpcode_f64_convert_i32_u]   = "f64.convert_i32_u",
                //    [WasmOpcode_f64_convert_i64_s]   = "f64.convert_i64_s",
                //    [WasmOpcode_f64_convert_i64_u]   = "f64.convert_i64_u",
                //    [WasmOpcode_f64_promote_f32]     = "f64.promote_f32",
                //    [WasmOpcode_i32_reinterpret_f32] = "i32.reinterpret_f32",
                //    [WasmOpcode_i64_reinterpret_f64] = "i64.reinterpret_f64",
                //    [WasmOpcode_f32_reinterpret_i32] = "f32.reinterpret_i32",
                //    [WasmOpcode_f64_reinterpret_i64] = "f64.reinterpret_i64",
                //
                //    [WasmOpcode_i32_extend8_s]       = "i32.extend8_s",
                //    [WasmOpcode_i32_extend16_s]      = "i32.extend16_s",
                //    [WasmOpcode_i64_extend8_s]       = "i64.extend8_s",
                //    [WasmOpcode_i64_extend16_s]      = "i64.extend16_s",
                //    [WasmOpcode_i64_extend32_s]      = "i64.extend32_s",
                //
                //    [WasmOpcode_prefixed]            = "prefixed",
                //};
                uint8_t opcode = InputStream_readByte(&in);
                //FuncGen_indent(&fg, out);
                //fprintf(out, "// %2u: ", fg.stack_i);
                //if (mnemonics[opcode])
                //    fprintf(out, "%s\n", mnemonics[opcode]);
                //else
                //    fprintf(out, "%02hhX\n", opcode);
                //fflush(out); // DEBUG
                switch (opcode) {
                    case WasmOpcode_unreachable:
                        if (unreachable_depth == 0) {
                            FuncGen_indent(&fg, out);
                            fprintf(out, "abort();\n");
                            unreachable_depth += 1;
                        }
                        break;
                    case WasmOpcode_nop:
                        break;
                    case WasmOpcode_block:
                    case WasmOpcode_loop:
                    case WasmOpcode_if: {
                        int64_t block_type = InputStream_readLeb128_i64(&in);
                        if (unreachable_depth == 0) {
                            const struct FuncType *func_type = FuncType_blockType(types, block_type);
                            for (uint32_t param_i = func_type->param->len; param_i > 0; ) {
                                param_i -= 1;
                                FuncGen_indent(&fg, out);
                                param_stash[param_i] =
                                    FuncGen_localDeclare(&fg, out, func_type->param->types[param_i]);
                                fprintf(out, " = l%" PRIu32 ";\n", FuncGen_stackPop(&fg));
                            }
                            for (uint32_t result_i = func_type->result->len; result_i > 0; ) {
                                result_i -= 1;
                                FuncGen_indent(&fg, out);
                                (void)FuncGen_localDeclare(&fg, out,
                                                           func_type->result->types[result_i]);
                                fputs(";\n", out);
                            }
                            FuncGen_blockBegin(&fg, out, opcode, block_type);
                            for (uint32_t param_i = 0; param_i < func_type->param->len; param_i += 1) {
                                FuncGen_stackPush(&fg, out, func_type->param->types[param_i]);
                                fprintf(out, " = l%" PRIu32 ";\n", param_stash[param_i]);
                            }
                        } else unreachable_depth += 1;
                        break;
                    }
                    case WasmOpcode_else:
                    case WasmOpcode_end:
                        if (unreachable_depth <= 1) {
                            const struct ResultType *result_type =
                                FuncType_blockType(types, FuncGen_blockType(&fg, 0))->result;
                            uint32_t label = FuncGen_blockLabel(&fg, 0);
                            if (unreachable_depth == 0) {
                                const struct ResultType *result_type =
                                    FuncType_blockType(types, FuncGen_blockType(&fg, 0))->result;
                                for (uint32_t result_i = result_type->len; result_i > 0; ) {
                                    result_i -= 1;
                                    FuncGen_indent(&fg, out);
                                    fprintf(out, "l%" PRIu32 " = l%" PRIu32 ";\n",
                                            label - result_type->len + result_i, FuncGen_stackPop(&fg));
                                }
                            } else unreachable_depth -= 1;
                            switch (opcode) {
                                case WasmOpcode_else:
                                    FuncGen_reuseReset(&fg);
                                    FuncGen_outdent(&fg, out);
                                    fputs("} else {\n", out);
                                    break;
                                case WasmOpcode_end:
                                    FuncGen_blockEnd(&fg, out);
                                    for (uint32_t result_i = 0; result_i < result_type->len;
                                         result_i += 1) {
                                        FuncGen_stackPush(&fg, out, result_type->types[result_i]);
                                        fprintf(out, "l%" PRIu32 ";\n",
                                                label - result_type->len + result_i);
                                    }
                                    break;
                            }
                        } else if (opcode == WasmOpcode_end) unreachable_depth -= 1;
                        break;
                    case WasmOpcode_br:
                    case WasmOpcode_br_if: {
                        uint32_t label_idx = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            enum WasmOpcode kind = FuncGen_blockKind(&fg, label_idx);
                            const struct FuncType *func_type =
                                FuncType_blockType(types, FuncGen_blockType(&fg, label_idx));
                            uint32_t label = FuncGen_blockLabel(&fg, label_idx);

                            if (opcode == WasmOpcode_br_if) {
                                FuncGen_indent(&fg, out);
                                fprintf(out, "if (l%" PRIu32 ") {\n", FuncGen_stackPop(&fg));
                            } else if (EXTRA_BRACES) {
                                FuncGen_indent(&fg, out);
                                fputs("{\n", out);
                            }

                            const struct ResultType *label_type;
                            uint32_t lhs;
                            switch (kind) {
                                case WasmOpcode_loop:
                                    label_type = func_type->param;
                                    lhs = label - func_type->result->len - func_type->param->len;
                                    break;
                                default:
                                    label_type = func_type->result;
                                    lhs = label - func_type->result->len;
                                    break;
                            }
                            for (uint32_t stack_i = 0; stack_i < label_type->len; stack_i += 1) {
                                uint32_t rhs;
                                switch (opcode) {
                                    case WasmOpcode_br:
                                        rhs = FuncGen_stackPop(&fg);
                                        break;
                                    case WasmOpcode_br_if:
                                        rhs = FuncGen_stackAt(&fg, stack_i);
                                        break;
                                    default: panic("unexpected opcode");
                                }
                                FuncGen_cont(&fg, out);
                                fprintf(out, "l%" PRIu32 " = l%" PRIu32 ";\n", lhs, rhs);
                                lhs += 1;
                            }
                            FuncGen_cont(&fg, out);
                            fprintf(out, "goto l%" PRIu32 ";\n", label);
                            if (EXTRA_BRACES || opcode == WasmOpcode_br_if) {
                                FuncGen_indent(&fg, out);
                                fputs("}\n", out);
                            }
                            if (opcode == WasmOpcode_br) unreachable_depth += 1;
                        }
                        break;
                    }
                    case WasmOpcode_br_table: {
                        if (unreachable_depth == 0) {
                            FuncGen_indent(&fg, out);
                            fprintf(out, "switch (l%" PRIu32 ") {\n", FuncGen_stackPop(&fg));
                        }
                        uint32_t label_len = InputStream_readLeb128_u32(&in);
                        for (uint32_t i = 0; i < label_len; i += 1) {
                            uint32_t label = InputStream_readLeb128_u32(&in);
                            if (unreachable_depth == 0) {
                                FuncGen_indent(&fg, out);
                                fprintf(out, "case %u: goto l%" PRIu32 ";\n",
                                        i, FuncGen_blockLabel(&fg, label));
                            }
                        }
                        uint32_t label = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            FuncGen_indent(&fg, out);
                            fprintf(out, "default: goto l%" PRIu32 ";\n",
                                    FuncGen_blockLabel(&fg, label));
                            FuncGen_indent(&fg, out);
                            fputs("}\n", out);
                            unreachable_depth += 1;
                        }
                        break;
                    }
                    case WasmOpcode_return:
                        if (unreachable_depth == 0) {
                            FuncGen_indent(&fg, out);
                            fputs("return", out);
                            switch (func_type->result->len) {
                                case 0: break;
                                case 1: fprintf(out, " l%" PRIu32, FuncGen_stackPop(&fg)); break;
                                default: panic("multiple function returns not supported");
                            }
                            fputs(";\n", out);
                            unreachable_depth += 1;
                        }
                        break;
                    case WasmOpcode_call:
                    case WasmOpcode_call_indirect: {
                        uint32_t func_id;
                        uint32_t type_idx;
                        uint32_t table_idx;
                        switch (opcode) {
                            case WasmOpcode_call:
                                func_id = InputStream_readLeb128_u32(&in);
                                if (func_id < imports_len)
                                    type_idx = imports[func_id].type_idx;
                                else
                                    type_idx = funcs[func_id - imports_len].type_idx;
                                break;
                            case WasmOpcode_call_indirect:
                                type_idx = InputStream_readLeb128_u32(&in);
                                table_idx = InputStream_readLeb128_u32(&in);
                                func_id = FuncGen_stackPop(&fg);
                                break;
                        }
                        if (unreachable_depth == 0) {
                            const struct FuncType *callee_func_type = &types[type_idx];
                            for (uint32_t param_i = callee_func_type->param->len; param_i > 0; ) {
                                param_i -= 1;
                                param_stash[param_i] = FuncGen_stackPop(&fg);
                            }
                            switch (callee_func_type->result->len) {
                                case 0: FuncGen_indent(&fg, out); break;
                                case 1: FuncGen_stackPush(&fg, out, callee_func_type->result->types[0]); break;
                                default: panic("multiple function returns not supported");
                            }
                            switch (opcode) {
                                case WasmOpcode_call:
                                    if (func_id < imports_len)
                                        fprintf(out, "%s_%s", imports[func_id].mod, imports[func_id].name);
                                    else
                                        fprintf(out, "f%" PRIu32, func_id - imports_len);
                                    break;
                                case WasmOpcode_call_indirect:
                                    fputs("(*(", out);
                                    switch (callee_func_type->result->len) {
                                        case 0: fputs("void", out); break;
                                        case 1: fputs(WasmValType_toC(callee_func_type->result->types[0]), out); break;
                                        default: panic("multiple function returns not supported");
                                    }
                                    fputs(" (*)(", out);
                                    if (callee_func_type->param->len == 0) fputs("void", out);
                                    for (uint32_t param_i = 0; param_i < callee_func_type->param->len; param_i += 1) {
                                        if (param_i > 0) fputs(", ", out);
                                        fputs(WasmValType_toC(callee_func_type->param->types[param_i]), out);
                                    }
                                    fprintf(out, "))t%" PRIu32 "[l%" PRIu32 "])", table_idx, func_id);
                                    break;
                            }
                            fputc('(', out);
                            for (uint32_t param_i = 0; param_i < callee_func_type->param->len;
                                 param_i += 1) {
                                if (param_i > 0) fputs(", ", out);
                                fprintf(out, "l%" PRIu32, param_stash[param_i]);
                            }
                            fputs(");\n", out);
                        }
                        break;
                    }

                    case WasmOpcode_drop:
                        if (unreachable_depth == 0) {
                            FuncGen_indent(&fg, out);
                            fprintf(out, "(void)l%" PRIu32 ";\n", FuncGen_stackPop(&fg));
                        }
                        break;
                    case WasmOpcode_select:
                        if (unreachable_depth == 0) {
                            uint32_t cond = FuncGen_stackPop(&fg);
                            uint32_t rhs = FuncGen_stackPop(&fg);
                            uint32_t lhs = FuncGen_stackAt(&fg, 0);
                            FuncGen_indent(&fg, out);
                            fprintf(out, "l%"PRIu32" = l%" PRIu32 " ? l%" PRIu32 " : l%" PRIu32 ";\n",
                                    lhs, cond, lhs, rhs);
                        }
                        break;

                    case WasmOpcode_local_get: {
                        uint32_t local_idx = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            if (local_idx < func_type->param->len) param_used[local_idx] = true;
                            FuncGen_stackPush(&fg, out, FuncGen_localType(&fg, local_idx));
                            fprintf(out, "l%" PRIu32 ";\n", local_idx);
                        }
                        break;
                    }
                    case WasmOpcode_local_set: {
                        uint32_t local_idx = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            if (local_idx < func_type->param->len) param_used[local_idx] = true;
                            FuncGen_indent(&fg, out);
                            fprintf(out, "l%" PRIu32 " = l%" PRIu32 ";\n",
                                    local_idx, FuncGen_stackPop(&fg));
                        }
                        break;
                    }
                    case WasmOpcode_local_tee: {
                        uint32_t local_idx = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            if (local_idx < func_type->param->len) param_used[local_idx] = true;
                            FuncGen_indent(&fg, out);
                            fprintf(out, "l%" PRIu32 " = l%" PRIu32 ";\n",
                                    local_idx, FuncGen_stackAt(&fg, 0));
                        }
                        break;
                    }

                    case WasmOpcode_global_get: {
                        uint32_t global_idx = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            FuncGen_stackPush(&fg, out, globals[global_idx].val_type);
                            fprintf(out, "g%" PRIu32 ";\n", global_idx);
                        }
                        break;
                    }
                    case WasmOpcode_global_set: {
                        uint32_t global_idx = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            FuncGen_indent(&fg, out);
                            fprintf(out, "g%" PRIu32 " = l%" PRIu32 ";\n",
                                    global_idx, FuncGen_stackPop(&fg));
                        }
                        break;
                    }

                    case WasmOpcode_table_get:
                    case WasmOpcode_table_set:
                        (void)InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) panic("unimplemented opcode");
                        break;

                    case WasmOpcode_i32_load: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "load32_align%" PRIu32 "((const uint%" PRIu32 "_t *)&m%" PRIu32
                                    "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")]);\n",
                                    align, 8 << align, 0, base, offset);
                        }
                        break;
                    }
                    case WasmOpcode_i64_load: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "load64_align%" PRIu32 "((const uint%" PRIu32 "_t *)&m%" PRIu32
                                    "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")]);\n",
                                    align, 8 << align, 0, base, offset);
                        }
                        break;
                    }
                    case WasmOpcode_f32_load: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_f32);
                            fprintf(out, "f32_reinterpret_i32(load32_align%" PRIu32 "((const uint%" PRIu32
                                    "_t *)&m%" PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")]));\n",
                                    align, 8 << align, 0, base, offset);
                        }
                        break;
                    }
                    case WasmOpcode_f64_load: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_f64);
                            fprintf(out, "f64_reinterpret_i64(load64_align%" PRIu32 "((const uint%" PRIu32
                                    "_t *)&m%" PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")]));\n",
                                    align, 8 << align, 0, base, offset);
                        }
                        break;
                    }
                    case WasmOpcode_i32_load8_s: {
                        (void)InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "(int8_t)m%" PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")];\n",
                                    0, base, offset);
                        }
                        break;
                    }
                    case WasmOpcode_i32_load8_u: {
                        (void)InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "m%" PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")];\n",
                                    0, base, offset);
                        }
                        break;
                    }
                    case WasmOpcode_i32_load16_s: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "(int16_t)load16_align%" PRIu32 "((const uint%" PRIu32 "_t *)&m%"
                                    PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")]);\n",
                                    align, 8 << align, 0, base, offset);
                        }
                        break;
                    }
                    case WasmOpcode_i32_load16_u: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "load16_align%" PRIu32 "((const uint%" PRIu32 "_t *)&m%"
                                    PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")]);\n",
                                    align, 8 << align, 0, base, offset);
                        }
                        break;
                    }
                    case WasmOpcode_i64_load8_s: {
                        (void)InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "(int8_t)m%" PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")];\n",
                                    0, base, offset);
                        }
                        break;
                    }
                    case WasmOpcode_i64_load8_u: {
                        (void)InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "m%" PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")];\n",
                                    0, base, offset);
                        }
                        break;
                    }
                    case WasmOpcode_i64_load16_s: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "(int16_t)load16_align%" PRIu32 "((const uint%" PRIu32 "_t *)&m%"
                                    PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")]);\n",
                                    align, 8 << align, 0, base, offset);
                        }
                        break;
                    }
                    case WasmOpcode_i64_load16_u: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "load16_align%" PRIu32 "((const uint%" PRIu32 "_t *)&m%"
                                    PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")]);\n",
                                    align, 8 << align, 0, base, offset);
                        }
                        break;
                    }
                    case WasmOpcode_i64_load32_s: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "(int32_t)load32_align%" PRIu32 "((const uint%" PRIu32 "_t *)&m%"
                                    PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")]);\n",
                                    align, 8 << align, 0, base, offset);
                        }
                        break;
                    }
                    case WasmOpcode_i64_load32_u: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "load32_align%" PRIu32 "((const uint%" PRIu32 "_t *)&m%"
                                    PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")]);\n",
                                    align, 8 << align, 0, base, offset);
                        }
                        break;
                    }

                    case WasmOpcode_i32_store: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t value = FuncGen_stackPop(&fg);
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_indent(&fg, out);
                            fprintf(out, "store32_align%" PRIu32 "((uint%" PRIu32 "_t *)&m%"
                                    PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")], l%" PRIu32 ");\n",
                                    align, 8 << align, 0, base, offset, value);
                        }
                        break;
                    }
                    case WasmOpcode_i64_store: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t value = FuncGen_stackPop(&fg);
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_indent(&fg, out);
                            fprintf(out, "store64_align%" PRIu32 "((uint%" PRIu32 "_t *)&m%"
                                    PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")], l%" PRIu32 ");\n",
                                    align, 8 << align, 0, base, offset, value);
                        }
                        break;
                    }
                    case WasmOpcode_f32_store: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t value = FuncGen_stackPop(&fg);
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_indent(&fg, out);
                            fprintf(out, "store32_align%" PRIu32 "((uint%" PRIu32 "_t *)&m%"
                                    PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")], "
                                    "i32_reinterpret_f32(l%" PRIu32 "));\n",
                                    align, 8 << align, 0, base, offset, value);
                        }
                        break;
                    }
                    case WasmOpcode_f64_store: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t value = FuncGen_stackPop(&fg);
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_indent(&fg, out);
                            fprintf(out, "store64_align%" PRIu32 "((uint%" PRIu32 "_t *)&m%"
                                    PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")], "
                                    "i64_reinterpret_f64(l%" PRIu32 "));\n",
                                    align, 8 << align, 0, base, offset, value);
                        }
                        break;
                    }
                    case WasmOpcode_i32_store8: {
                        (void)InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t value = FuncGen_stackPop(&fg);
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_indent(&fg, out);
                            fprintf(out, "m%" PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32
                                    ")] = (uint8_t)l%" PRIu32 ";\n", 0, base, offset, value);
                        }
                        break;
                    }
                    case WasmOpcode_i32_store16: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t value = FuncGen_stackPop(&fg);
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_indent(&fg, out);
                            fprintf(out, "store16_align%" PRIu32 "((uint%" PRIu32 "_t *)&m%"
                                    PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")], "
                                    "(uint16_t)l%" PRIu32 ");\n",
                                    align, 8 << align, 0, base, offset, value);
                        }
                        break;
                    }
                    case WasmOpcode_i64_store8: {
                        (void)InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t value = FuncGen_stackPop(&fg);
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_indent(&fg, out);
                            fprintf(out, "m%" PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32
                                    ")] = (uint8_t)l%" PRIu32 ";\n", 0, base, offset, value);
                        }
                        break;
                    }
                    case WasmOpcode_i64_store16: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t value = FuncGen_stackPop(&fg);
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_indent(&fg, out);
                            fprintf(out, "store16_align%" PRIu32 "((uint%" PRIu32 "_t *)&m%"
                                    PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")], "
                                    "(uint16_t)l%" PRIu32 ");\n",
                                    align, 8 << align, 0, base, offset, value);
                        }
                        break;
                    }
                    case WasmOpcode_i64_store32: {
                        uint32_t align = InputStream_readLeb128_u32(&in);
                        uint32_t offset = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t value = FuncGen_stackPop(&fg);
                            uint32_t base = FuncGen_stackPop(&fg);
                            FuncGen_indent(&fg, out);
                            fprintf(out, "store32_align%" PRIu32 "((uint%" PRIu32 "_t *)&m%"
                                    PRIu32 "[l%" PRIu32 " + UINT32_C(%" PRIu32 ")], "
                                    "(uint32_t)l%" PRIu32 ");\n",
                                    align, 8 << align, 0, base, offset, value);
                        }
                        break;
                    }

                    case WasmOpcode_memory_size: {
                        uint32_t mem_idx = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "p%" PRIu32 ";\n", mem_idx);
                        }
                        break;
                    }
                    case WasmOpcode_memory_grow: {
                        uint32_t mem_idx = InputStream_readLeb128_u32(&in);
                        if (unreachable_depth == 0) {
                            uint32_t pages = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "memory_grow(&m%" PRIu32 ", &p%" PRIu32 ", &c%" PRIu32
                                    ", l%" PRIu32 ");\n", mem_idx, mem_idx, mem_idx, pages);
                        }
                        break;
                    }

                    case WasmOpcode_i32_const: {
                        uint32_t value = (uint32_t)InputStream_readLeb128_i32(&in);
                        if (unreachable_depth == 0) {
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "UINT32_C(0x%" PRIX32 ");\n", value);
                        }
                        break;
                    }
                    case WasmOpcode_i64_const: {
                        uint64_t value = (uint64_t)InputStream_readLeb128_i64(&in);
                        if (unreachable_depth == 0) {
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "UINT64_C(0x%" PRIX64 ");\n", value);
                        }
                        break;
                    }
                    case WasmOpcode_f32_const: {
                        uint32_t value = InputStream_readLittle_u32(&in);
                        if (unreachable_depth == 0) {
                            FuncGen_stackPush(&fg, out, WasmValType_f32);
                            fprintf(out, "f32_reinterpret_i32(UINT32_C(0x%" PRIX32 "));\n", value);
                        }
                        break;
                    }
                    case WasmOpcode_f64_const: {
                        uint64_t value = InputStream_readLittle_u64(&in);
                        if (unreachable_depth == 0) {
                            FuncGen_stackPush(&fg, out, WasmValType_f64);
                            fprintf(out, "f64_reinterpret_i64(UINT64_C(0x%" PRIX64 "));\n", value);
                        }
                        break;
                    }

                    case WasmOpcode_i32_eqz:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackAt(&fg, 0);
                            FuncGen_indent(&fg, out);
                            fprintf(out, "l%" PRIu32 " = !l%" PRIu32 ";\n", lhs, lhs);
                        }
                        break;
                    case WasmOpcode_i32_eq:
                    case WasmOpcode_i32_ne:
                    case WasmOpcode_i32_lt_u:
                    case WasmOpcode_i32_gt_u:
                    case WasmOpcode_i32_le_u:
                    case WasmOpcode_i32_ge_u:
                        // i32 unsigned comparisons
                        if (unreachable_depth == 0) {
                            uint32_t rhs = FuncGen_stackPop(&fg);
                            uint32_t lhs = FuncGen_stackAt(&fg, 0);
                            const char *operator;
                            switch (opcode) {
                                case WasmOpcode_i32_eq:   operator = "=="; break;
                                case WasmOpcode_i32_ne:   operator = "!="; break;
                                case WasmOpcode_i32_lt_u: operator = "<";  break;
                                case WasmOpcode_i32_gt_u: operator = ">";  break;
                                case WasmOpcode_i32_le_u: operator = "<="; break;
                                case WasmOpcode_i32_ge_u: operator = ">="; break;
                                default: panic("unreachable");
                            }
                            FuncGen_indent(&fg, out);
                            fprintf(out, "l%" PRIu32 " = l%" PRIu32 " %s l%" PRIu32 ";\n",
                                    lhs, lhs, operator, rhs);
                        }
                        break;
                    case WasmOpcode_i32_lt_s:
                    case WasmOpcode_i32_gt_s:
                    case WasmOpcode_i32_le_s:
                    case WasmOpcode_i32_ge_s:
                        // i32 signed comparisons
                        if (unreachable_depth == 0) {
                            uint32_t rhs = FuncGen_stackPop(&fg);
                            uint32_t lhs = FuncGen_stackAt(&fg, 0);
                            const char *operator;
                            switch (opcode) {
                                case WasmOpcode_i32_lt_s: operator = "<";  break;
                                case WasmOpcode_i32_gt_s: operator = ">";  break;
                                case WasmOpcode_i32_le_s: operator = "<="; break;
                                case WasmOpcode_i32_ge_s: operator = ">="; break;
                                default: panic("unreachable");
                            }
                            FuncGen_indent(&fg, out);
                            fprintf(out, "l%" PRIu32 " = (int32_t)l%" PRIu32 " %s (int32_t)l%" PRIu32
                                    ";\n", lhs, lhs, operator, rhs);
                        }
                        break;

                    case WasmOpcode_i64_eqz:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "!l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_i64_eq:
                    case WasmOpcode_i64_ne:
                    case WasmOpcode_i64_lt_u:
                    case WasmOpcode_i64_gt_u:
                    case WasmOpcode_i64_le_u:
                    case WasmOpcode_i64_ge_u:
                    case WasmOpcode_f32_eq:
                    case WasmOpcode_f32_ne:
                    case WasmOpcode_f32_lt:
                    case WasmOpcode_f32_gt:
                    case WasmOpcode_f32_le:
                    case WasmOpcode_f32_ge:
                    case WasmOpcode_f64_eq:
                    case WasmOpcode_f64_ne:
                    case WasmOpcode_f64_lt:
                    case WasmOpcode_f64_gt:
                    case WasmOpcode_f64_le:
                    case WasmOpcode_f64_ge:
                        // non-i32 unsigned comparisons
                        if (unreachable_depth == 0) {
                            uint32_t rhs = FuncGen_stackPop(&fg);
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            const char *operator;
                            switch (opcode) {
                                case WasmOpcode_i64_eq:
                                case WasmOpcode_f32_eq:
                                case WasmOpcode_f64_eq:
                                    operator = "==";
                                    break;
                                case WasmOpcode_i64_ne:
                                case WasmOpcode_f32_ne:
                                case WasmOpcode_f64_ne:
                                    operator = "!=";
                                    break;
                                case WasmOpcode_i64_lt_u:
                                case WasmOpcode_f32_lt:
                                case WasmOpcode_f64_lt:
                                    operator = "<";
                                    break;
                                case WasmOpcode_i64_gt_u:
                                case WasmOpcode_f32_gt:
                                case WasmOpcode_f64_gt:
                                    operator = ">";
                                    break;
                                case WasmOpcode_i64_le_u:
                                case WasmOpcode_f32_le:
                                case WasmOpcode_f64_le:
                                    operator = "<=";
                                    break;
                                case WasmOpcode_i64_ge_u:
                                case WasmOpcode_f32_ge:
                                case WasmOpcode_f64_ge:
                                    operator = ">=";
                                    break;
                                default: panic("unreachable");
                            }
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "l%" PRIu32 " = l%" PRIu32 " %s l%" PRIu32 ";\n",
                                    lhs, lhs, operator, rhs);
                        }
                        break;
                    case WasmOpcode_i64_lt_s:
                    case WasmOpcode_i64_gt_s:
                    case WasmOpcode_i64_le_s:
                    case WasmOpcode_i64_ge_s:
                        // i64 signed comparisons
                        if (unreachable_depth == 0) {
                            uint32_t rhs = FuncGen_stackPop(&fg);
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            const char *operator;
                            switch (opcode) {
                                case WasmOpcode_i64_lt_s: operator = "<";  break;
                                case WasmOpcode_i64_gt_s: operator = ">";  break;
                                case WasmOpcode_i64_le_s: operator = "<="; break;
                                case WasmOpcode_i64_ge_s: operator = ">="; break;
                                default: panic("unreachable");
                            }
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "l%" PRIu32 " = (int64_t)l%" PRIu32 " %s (int64_t)l%" PRIu32
                                    ";\n", lhs, lhs, operator, rhs);
                        }
                        break;

                    case WasmOpcode_i32_clz:
                    case WasmOpcode_i32_ctz:
                    case WasmOpcode_i32_popcnt:
                    case WasmOpcode_i64_clz:
                    case WasmOpcode_i64_ctz:
                    case WasmOpcode_i64_popcnt:
                    case WasmOpcode_f32_abs:
                    case WasmOpcode_f32_neg:
                    case WasmOpcode_f32_ceil:
                    case WasmOpcode_f32_floor:
                    case WasmOpcode_f32_trunc:
                    case WasmOpcode_f32_nearest:
                    case WasmOpcode_f32_sqrt:
                    case WasmOpcode_f64_abs:
                    case WasmOpcode_f64_neg:
                    case WasmOpcode_f64_ceil:
                    case WasmOpcode_f64_floor:
                    case WasmOpcode_f64_trunc:
                    case WasmOpcode_f64_nearest:
                    case WasmOpcode_f64_sqrt:
                        // unary functions
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackAt(&fg, 0);
                            const char *function;
                            switch (opcode) {
                                case WasmOpcode_i32_clz:     function = "i32_clz";    break;
                                case WasmOpcode_i32_ctz:     function = "i32_ctz";    break;
                                case WasmOpcode_i32_popcnt:  function = "i32_popcnt"; break;
                                case WasmOpcode_i64_clz:     function = "i64_clz";    break;
                                case WasmOpcode_i64_ctz:     function = "i64_ctz";    break;
                                case WasmOpcode_i64_popcnt:  function = "i64_popcnt"; break;
                                case WasmOpcode_f32_abs:     function = "fabsf";      break;
                                case WasmOpcode_f32_neg:
                                case WasmOpcode_f64_neg:     function = "-";          break;
                                case WasmOpcode_f32_ceil:    function = "ceilf";      break;
                                case WasmOpcode_f32_floor:   function = "floorf";     break;
                                case WasmOpcode_f32_trunc:   function = "truncf";     break;
                                case WasmOpcode_f32_nearest: function = "roundf";     break;
                                case WasmOpcode_f32_sqrt:    function = "sqrtf";      break;
                                case WasmOpcode_f64_abs:     function = "fabs";       break;
                                case WasmOpcode_f64_ceil:    function = "ceil";       break;
                                case WasmOpcode_f64_floor:   function = "floor";      break;
                                case WasmOpcode_f64_trunc:   function = "trunc";      break;
                                case WasmOpcode_f64_nearest: function = "round";      break;
                                case WasmOpcode_f64_sqrt:    function = "sqrt";       break;
                                default: panic("unreachable");
                            }
                            FuncGen_indent(&fg, out);
                            fprintf(out, "l%" PRIu32 " = %s(l%" PRIu32 ");\n", lhs, function, lhs);
                        }
                        break;
                    case WasmOpcode_i32_add:
                    case WasmOpcode_i32_sub:
                    case WasmOpcode_i32_mul:
                    case WasmOpcode_i32_div_u:
                    case WasmOpcode_i32_rem_u:
                    case WasmOpcode_i32_and:
                    case WasmOpcode_i32_or:
                    case WasmOpcode_i32_xor:
                    case WasmOpcode_i64_add:
                    case WasmOpcode_i64_sub:
                    case WasmOpcode_i64_mul:
                    case WasmOpcode_i64_div_u:
                    case WasmOpcode_i64_rem_u:
                    case WasmOpcode_i64_and:
                    case WasmOpcode_i64_or:
                    case WasmOpcode_i64_xor:
                    case WasmOpcode_f32_add:
                    case WasmOpcode_f32_sub:
                    case WasmOpcode_f32_mul:
                    case WasmOpcode_f32_div:
                    case WasmOpcode_f64_add:
                    case WasmOpcode_f64_sub:
                    case WasmOpcode_f64_mul:
                    case WasmOpcode_f64_div:
                        // unsigned binary operators
                        if (unreachable_depth == 0) {
                            uint32_t rhs = FuncGen_stackPop(&fg);
                            uint32_t lhs = FuncGen_stackAt(&fg, 0);
                            char operator;
                            switch (opcode) {
                                case WasmOpcode_i32_add:
                                case WasmOpcode_i64_add:
                                case WasmOpcode_f32_add:
                                case WasmOpcode_f64_add:
                                    operator = '+';
                                    break;
                                case WasmOpcode_i32_sub:
                                case WasmOpcode_i64_sub:
                                case WasmOpcode_f32_sub:
                                case WasmOpcode_f64_sub:
                                    operator = '-';
                                    break;
                                case WasmOpcode_i32_mul:
                                case WasmOpcode_i64_mul:
                                case WasmOpcode_f32_mul:
                                case WasmOpcode_f64_mul:
                                    operator = '*';
                                    break;
                                case WasmOpcode_i32_div_u:
                                case WasmOpcode_i64_div_u:
                                case WasmOpcode_f32_div:
                                case WasmOpcode_f64_div:
                                    operator = '/';
                                    break;
                                case WasmOpcode_i32_rem_u:
                                case WasmOpcode_i64_rem_u:
                                    operator = '%';
                                    break;
                                case WasmOpcode_i32_and:
                                case WasmOpcode_i64_and:
                                    operator = '&';
                                    break;
                                case WasmOpcode_i32_or:
                                case WasmOpcode_i64_or:
                                    operator = '|';
                                    break;
                                case WasmOpcode_i32_xor:
                                case WasmOpcode_i64_xor:
                                    operator = '^';
                                    break;
                                default: panic("unreachable");
                            }
                            FuncGen_indent(&fg, out);
                            fprintf(out, "l%" PRIu32 " %c= l%" PRIu32 ";\n", lhs, operator, rhs);
                        }
                        break;
                    case WasmOpcode_i32_div_s:
                    case WasmOpcode_i32_rem_s:
                    case WasmOpcode_i64_div_s:
                    case WasmOpcode_i64_rem_s:
                        // signed binary operators
                        if (unreachable_depth == 0) {
                            uint32_t rhs = FuncGen_stackPop(&fg);
                            uint32_t lhs = FuncGen_stackAt(&fg, 0);
                            char operator;
                            unsigned width;
                            switch (opcode) {
                                case WasmOpcode_i32_div_s:
                                case WasmOpcode_i64_div_s:
                                    operator = '/';
                                    break;
                                case WasmOpcode_i32_rem_s:
                                case WasmOpcode_i64_rem_s:
                                    operator = '%';
                                    break;
                                default: panic("unreachable");
                            }
                            switch (opcode) {
                                case WasmOpcode_i32_div_s:
                                case WasmOpcode_i32_rem_s:
                                    width = 32;
                                    break;
                                case WasmOpcode_i64_div_s:
                                case WasmOpcode_i64_rem_s:
                                    width = 64;
                                    break;
                                default: panic("unreachable");
                            }
                            FuncGen_indent(&fg, out);
                            fprintf(out, "l%" PRIu32 " = (uint%u_t)((int%u_t)l%" PRIu32 " %c "
                                    "(int%u_t)l%" PRIu32 ");\n",
                                    lhs, width, width, lhs, operator, width, rhs);
                        }
                        break;
                    case WasmOpcode_i32_shl:
                    case WasmOpcode_i32_shr_u:
                    case WasmOpcode_i64_shl:
                    case WasmOpcode_i64_shr_u:
                        // unsigned shift operators
                        if (unreachable_depth == 0) {
                            uint32_t rhs = FuncGen_stackPop(&fg);
                            uint32_t lhs = FuncGen_stackAt(&fg, 0);
                            char operator;
                            unsigned width;
                            switch (opcode) {
                                case WasmOpcode_i32_shl:
                                case WasmOpcode_i64_shl:
                                    operator = '<';
                                    break;
                                case WasmOpcode_i32_shr_u:
                                case WasmOpcode_i64_shr_u:
                                    operator = '>';
                                    break;
                                default: panic("unreachable");
                            }
                            switch (opcode) {
                                case WasmOpcode_i32_shl:
                                case WasmOpcode_i32_shr_u:
                                    width = 32;
                                    break;
                                case WasmOpcode_i64_shl:
                                case WasmOpcode_i64_shr_u:
                                    width = 64;
                                    break;
                                default: panic("unreachable");
                            }
                            FuncGen_indent(&fg, out);
                            fprintf(out, "l%" PRIu32 " %c%c= l%" PRIu32 " & 0x%X;\n",
                                    lhs, operator, operator, rhs, width - 1);
                        }
                        break;
                    case WasmOpcode_i32_shr_s:
                    case WasmOpcode_i64_shr_s:
                        // signed shift operators
                        if (unreachable_depth == 0) {
                            uint32_t rhs = FuncGen_stackPop(&fg);
                            uint32_t lhs = FuncGen_stackAt(&fg, 0);
                            char operator;
                            unsigned width;
                            switch (opcode) {
                                case WasmOpcode_i32_shr_s:
                                case WasmOpcode_i64_shr_s:
                                    operator = '>';
                                    break;
                                default: panic("unreachable");
                            }
                            switch (opcode) {
                                case WasmOpcode_i32_shr_s:
                                    width = 32;
                                    break;
                                case WasmOpcode_i64_shr_s:
                                    width = 64;
                                    break;
                                default: panic("unreachable");
                            }
                            FuncGen_indent(&fg, out);
                            fprintf(out, "l%" PRIu32 " = (uint%u_t)((int%u_t)l%" PRIu32 " %c%c "
                                    "(l%" PRIu32 " & 0x%X));\n",
                                    lhs, width, width, lhs, operator, operator, rhs, width - 1);
                        }
                        break;
                    case WasmOpcode_i32_rotl:
                    case WasmOpcode_i32_rotr:
                    case WasmOpcode_i64_rotl:
                    case WasmOpcode_i64_rotr:
                        // rotate operators
                        if (unreachable_depth == 0) {
                            uint32_t rhs = FuncGen_stackPop(&fg);
                            uint32_t lhs = FuncGen_stackAt(&fg, 0);
                            char forward_operator;
                            char reverse_operator;
                            unsigned width;
                            switch (opcode) {
                                case WasmOpcode_i32_rotl:
                                case WasmOpcode_i64_rotl:
                                    forward_operator = '<';
                                    reverse_operator = '>';
                                    break;
                                case WasmOpcode_i32_rotr:
                                case WasmOpcode_i64_rotr:
                                    forward_operator = '>';
                                    reverse_operator = '<';
                                    break;
                                default: panic("unreachable");
                            }
                            switch (opcode) {
                                case WasmOpcode_i32_rotl:
                                case WasmOpcode_i32_rotr:
                                    width = 32;
                                    break;
                                case WasmOpcode_i64_rotl:
                                case WasmOpcode_i64_rotr:
                                    width = 64;
                                    break;
                                default: panic("unreachable");
                            }
                            FuncGen_indent(&fg, out);
                            fprintf(out, "l%" PRIu32" = l%" PRIu32 " %c%c (l%" PRIu32 " & 0x%X) | "
                                    "l%" PRIu32 " %c%c (-l%" PRIu32" & 0x%X);\n", lhs,
                                    lhs, forward_operator, forward_operator, rhs, width - 1,
                                    lhs, reverse_operator, reverse_operator, rhs, width - 1);
                        }
                        break;
                    case WasmOpcode_f32_min:
                    case WasmOpcode_f32_max:
                    case WasmOpcode_f32_copysign:
                    case WasmOpcode_f64_min:
                    case WasmOpcode_f64_max:
                    case WasmOpcode_f64_copysign:
                        // binary functions
                        if (unreachable_depth == 0) {
                            uint32_t rhs = FuncGen_stackPop(&fg);
                            uint32_t lhs = FuncGen_stackAt(&fg, 0);
                            const char *function;
                            switch (opcode) {
                                case WasmOpcode_f32_min:      function = "fminf";     break;
                                case WasmOpcode_f32_max:      function = "fmaxf";     break;
                                case WasmOpcode_f32_copysign: function = "copysignf"; break;
                                case WasmOpcode_f64_min:      function = "fmin";      break;
                                case WasmOpcode_f64_max:      function = "fmax";      break;
                                case WasmOpcode_f64_copysign: function = "copysign";  break;
                                default: panic("unreachable");
                            }
                            FuncGen_indent(&fg, out);
                            fprintf(out, "l%" PRIu32 " = %s(l%" PRIu32 ", l%" PRIu32 ");\n",
                                    lhs, function, lhs, rhs);
                        }
                        break;

                    case WasmOpcode_i32_wrap_i64:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "(uint32_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_i32_trunc_f32_s:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "(int32_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_i32_trunc_f32_u:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "(uint32_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_i32_trunc_f64_s:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "(int32_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_i32_trunc_f64_u:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "(uint32_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_i64_extend_i32_s:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "(int32_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_i64_extend_i32_u:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "(uint32_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_i64_trunc_f32_s:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "(int64_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_i64_trunc_f32_u:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "(uint64_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_i64_trunc_f64_s:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "(int64_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_i64_trunc_f64_u:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "(uint64_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_f32_convert_i32_s:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_f32);
                            fprintf(out, "(int32_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_f32_convert_i32_u:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_f32);
                            fprintf(out, "(uint32_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_f32_convert_i64_s:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_f32);
                            fprintf(out, "(int64_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_f32_convert_i64_u:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_f32);
                            fprintf(out, "(uint64_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_f32_demote_f64:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_f32);
                            fprintf(out, "(float)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_f64_convert_i32_s:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_f64);
                            fprintf(out, "(int32_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_f64_convert_i32_u:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_f64);
                            fprintf(out, "(uint32_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_f64_convert_i64_s:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_f64);
                            fprintf(out, "(int64_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_f64_convert_i64_u:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_f64);
                            fprintf(out, "(uint64_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_f64_promote_f32:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_f64);
                            fprintf(out, "(double)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_i32_reinterpret_f32:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "i32_reinterpret_f32(l%" PRIu32 ");\n", lhs);
                        }
                        break;
                    case WasmOpcode_i64_reinterpret_f64:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "i64_reinterpret_f64(l%" PRIu32 ");\n", lhs);
                        }
                        break;
                    case WasmOpcode_f32_reinterpret_i32:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_f32);
                            fprintf(out, "f32_reinterpret_i32(l%" PRIu32 ");\n", lhs);
                        }
                        break;
                    case WasmOpcode_f64_reinterpret_i64:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_f64);
                            fprintf(out, "f64_reinterpret_i64(l%" PRIu32 ");\n", lhs);
                        }
                        break;

                    case WasmOpcode_i32_extend8_s:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "(int8_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_i32_extend16_s:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i32);
                            fprintf(out, "(int16_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_i64_extend8_s:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "(int8_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_i64_extend16_s:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "(int16_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;
                    case WasmOpcode_i64_extend32_s:
                        if (unreachable_depth == 0) {
                            uint32_t lhs = FuncGen_stackPop(&fg);
                            FuncGen_stackPush(&fg, out, WasmValType_i64);
                            fprintf(out, "(int32_t)l%" PRIu32 ";\n", lhs);
                        }
                        break;

                    case WasmOpcode_prefixed:
                        switch (InputStream_readLeb128_u32(&in)) {
                            case WasmPrefixedOpcode_i32_trunc_sat_f32_s:
                            case WasmPrefixedOpcode_i32_trunc_sat_f32_u:
                            case WasmPrefixedOpcode_i32_trunc_sat_f64_s:
                            case WasmPrefixedOpcode_i32_trunc_sat_f64_u:
                            case WasmPrefixedOpcode_i64_trunc_sat_f32_s:
                            case WasmPrefixedOpcode_i64_trunc_sat_f32_u:
                            case WasmPrefixedOpcode_i64_trunc_sat_f64_s:
                            case WasmPrefixedOpcode_i64_trunc_sat_f64_u:
                                if (unreachable_depth == 0) panic("unimplemented opcode");

                            case WasmPrefixedOpcode_memory_init:
                                (void)InputStream_readLeb128_u32(&in);
                                (void)InputStream_readByte(&in);
                                if (unreachable_depth == 0) panic("unimplemented opcode");

                            case WasmPrefixedOpcode_data_drop:
                                (void)InputStream_readLeb128_u32(&in);
                                if (unreachable_depth == 0) panic("unimplemented opcode");

                            case WasmPrefixedOpcode_memory_copy: {
                                uint32_t dst_mem_idx = InputStream_readLeb128_u32(&in);
                                uint32_t src_mem_idx = InputStream_readLeb128_u32(&in);
                                if (unreachable_depth == 0) {
                                    uint32_t n = FuncGen_stackPop(&fg);
                                    uint32_t src = FuncGen_stackPop(&fg);
                                    uint32_t dst = FuncGen_stackPop(&fg);
                                    FuncGen_indent(&fg, out);
                                    fprintf(out, "memmove(&m%" PRIu32 "[l%" PRIu32 "], "
                                            "&m%" PRIu32 "[l%" PRIu32 "], l%" PRIu32 ");\n",
                                            dst_mem_idx, dst, src_mem_idx, src, n);
                                }
                                break;
                            }

                            case WasmPrefixedOpcode_memory_fill: {
                                uint32_t mem_idx = InputStream_readLeb128_u32(&in);
                                if (unreachable_depth == 0) {
                                    uint32_t n = FuncGen_stackPop(&fg);
                                    uint32_t c = FuncGen_stackPop(&fg);
                                    uint32_t s = FuncGen_stackPop(&fg);
                                    FuncGen_indent(&fg, out);
                                    fprintf(out, "memset(&m%" PRIu32 "[l%" PRIu32 "], "
                                            "l%" PRIu32 ", l%" PRIu32 ");\n", mem_idx, s, c, n);
                                }
                                break;
                            }

                            case WasmPrefixedOpcode_table_init:
                                (void)InputStream_readLeb128_u32(&in);
                                (void)InputStream_readLeb128_u32(&in);
                                if (unreachable_depth == 0) panic("unimplemented opcode");

                            case WasmPrefixedOpcode_elem_drop:
                                (void)InputStream_readLeb128_u32(&in);
                                if (unreachable_depth == 0) panic("unimplemented opcode");

                            case WasmPrefixedOpcode_table_copy:
                                (void)InputStream_readLeb128_u32(&in);
                                (void)InputStream_readLeb128_u32(&in);
                                if (unreachable_depth == 0) panic("unimplemented opcode");

                            case WasmPrefixedOpcode_table_grow:
                                (void)InputStream_readLeb128_u32(&in);
                                if (unreachable_depth == 0) panic("unimplemented opcode");

                            case WasmPrefixedOpcode_table_size:
                                (void)InputStream_readLeb128_u32(&in);
                                if (unreachable_depth == 0) panic("unimplemented opcode");

                            case WasmPrefixedOpcode_table_fill:
                                (void)InputStream_readLeb128_u32(&in);
                                if (unreachable_depth == 0) panic("unimplemented opcode");
                        }
                        break;
                }
            }
            for (uint32_t param_i = 0; param_i < func_type->param->len; param_i += 1) {
                if (param_used[param_i]) continue;
                FuncGen_indent(&fg, out);
                fprintf(out, "(void)l%" PRIu32 ";\n", param_i);
            }
            switch (func_type->result->len) {
                case 0: break;
                case 1:
                    FuncGen_indent(&fg, out);
                    fprintf(out, "return l%" PRIu32 ";\n", FuncGen_stackPop(&fg));
                    break;
                default: panic("multiple function returns not supported");
            }
            fputs("}\n\n", out);
        }
    }

    (void)InputStream_skipToSection(&in, WasmSectionId_data);
    {
        uint32_t len = InputStream_readLeb128_u32(&in);
        fputs("static void init_data(void) {\n", out);
        for (uint32_t i = 0; i < mems_len; i += 1)
            fprintf(out, "    p%" PRIu32 " = UINT32_C(%" PRIu32 ");\n"
                    "    c%" PRIu32 " = p%" PRIu32 ";\n"
                    "    m%" PRIu32 " = calloc(c%" PRIu32 ", UINT32_C(1) << 16);\n",
                    i, mems[i].limits.min, i, i, i, i);
        for (uint32_t segment_i = 0; segment_i < len; segment_i += 1) {
            uint32_t mem_idx;
            switch (InputStream_readLeb128_u32(&in)) {
                case 0:
                    mem_idx = 0;
                    break;

                case 2:
                    mem_idx = InputStream_readLeb128_u32(&in);
                    break;

                default: panic("unsupported data kind");
            }
            uint32_t offset = evalExpr(&in);
            uint32_t segment_len = InputStream_readLeb128_u32(&in);
            fputc('\n', out);
            fprintf(out, "    static const uint8_t s%" PRIu32 "[UINT32_C(%" PRIu32 ")] = {",
                    segment_i, segment_len);
            for (uint32_t i = 0; i < segment_len; i += 1) {
                if (i % 32 == 0) fputs("\n       ", out);
                fprintf(out, " 0x%02hhX,", InputStream_readByte(&in));
            }
            fprintf(out, "\n"
                    "    };\n"
                    "    memcpy(&m%" PRIu32 "[UINT32_C(0x%" PRIX32 ")], s%" PRIu32 ", UINT32_C(%" PRIu32 "));\n",
                    mem_idx, offset, segment_i, segment_len);
        }
        fputs("}\n", out);
    }

    InputStream_close(&in);
    fclose(out);
}
