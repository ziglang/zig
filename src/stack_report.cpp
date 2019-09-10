/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "stack_report.hpp"

static void tree_print(FILE *f, ZigType *ty, size_t indent);

static void pretty_print_bytes(FILE *f, double n) {
    if (n > 1024.0 * 1024.0 * 1024.0) {
        fprintf(f, "%.02f GiB", n / 1024.0 / 1024.0 / 1024.0);
        return;
    }
    if (n > 1024.0 * 1024.0) {
        fprintf(f, "%.02f MiB", n / 1024.0 / 1024.0);
        return;
    }
    if (n > 1024.0) {
        fprintf(f, "%.02f KiB", n / 1024.0);
        return;
    }
    fprintf(f, "%.02f bytes", n );
    return;
}

static int compare_type_abi_sizes_desc(const void *a, const void *b) {
    uint64_t size_a = (*(ZigType * const*)(a))->abi_size;
    uint64_t size_b = (*(ZigType * const*)(b))->abi_size;
    if (size_a > size_b)
        return -1;
    if (size_a < size_b)
        return 1;
    return 0;
}

static void start_child(FILE *f, size_t indent) {
    fprintf(f, "\n");
    for (size_t i = 0; i < indent; i += 1) {
        fprintf(f, " ");
    }
}

static void start_peer(FILE *f, size_t indent) {
    fprintf(f, ",\n");
    for (size_t i = 0; i < indent; i += 1) {
        fprintf(f, " ");
    }
}

static void tree_print_struct(FILE *f, ZigType *struct_type, size_t indent) {
    ZigList<ZigType *> children = {};
    uint64_t sum_from_fields = 0;
    for (size_t i = 0; i < struct_type->data.structure.src_field_count; i += 1) {
        TypeStructField *field = &struct_type->data.structure.fields[i];
        children.append(field->type_entry);
        sum_from_fields += field->type_entry->abi_size;
    }
    qsort(children.items, children.length, sizeof(ZigType *), compare_type_abi_sizes_desc);

    start_peer(f, indent);
    fprintf(f, "\"padding\": \"%" ZIG_PRI_u64 "\"", struct_type->abi_size - sum_from_fields);

    start_peer(f, indent);
    fprintf(f, "\"fields\": [");

    for (size_t i = 0; i < children.length; i += 1) {
        if (i == 0) {
            start_child(f, indent + 1);
        } else {
            start_peer(f, indent + 1);
        }
        fprintf(f, "{");

        ZigType *child_type = children.at(i);
        tree_print(f, child_type, indent + 2);

        start_child(f, indent + 1);
        fprintf(f, "}");
    }

    start_child(f, indent);
    fprintf(f, "]");
}

static void tree_print(FILE *f, ZigType *ty, size_t indent) {
    start_child(f, indent);
    fprintf(f, "\"type\": \"%s\"", buf_ptr(&ty->name));

    start_peer(f, indent);
    fprintf(f, "\"sizef\": \"");
    pretty_print_bytes(f, ty->abi_size);
    fprintf(f, "\"");

    start_peer(f, indent);
    fprintf(f, "\"size\": \"%" ZIG_PRI_usize "\"", ty->abi_size);

    switch (ty->id) {
        case ZigTypeIdFnFrame:
            return tree_print_struct(f, ty->data.frame.locals_struct, indent);
        case ZigTypeIdStruct:
            return tree_print_struct(f, ty, indent);
        default:
            start_child(f, indent);
            return;
    }
}

void zig_print_stack_report(CodeGen *g, FILE *f) {
    if (g->largest_frame_fn == nullptr) {
        fprintf(f, "{\"error\": \"No async function frames in entire compilation.\"}\n");
        return;
    }
    fprintf(f, "{");
    tree_print(f, g->largest_frame_fn->frame_type, 1);

    start_child(f, 0);
    fprintf(f, "}\n");
}
