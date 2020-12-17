/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "dump_analysis.hpp"
#include "analyze.hpp"
#include "ir.hpp"
#include "codegen.hpp"
#include "os.hpp"

enum JsonWriterState {
    JsonWriterStateInvalid,
    JsonWriterStateValue,
    JsonWriterStateArrayStart,
    JsonWriterStateArray,
    JsonWriterStateObjectStart,
    JsonWriterStateObject,
};

#define JSON_MAX_DEPTH 10

struct JsonWriter {
    size_t state_index;
    FILE *f;
    const char *one_indent;
    const char *nl;
    JsonWriterState state[JSON_MAX_DEPTH];
};

static void jw_init(JsonWriter *jw, FILE *f, const char *one_indent, const char *nl) {
    jw->state_index = 1;
    jw->f = f;
    jw->one_indent = one_indent;
    jw->nl = nl;
    jw->state[0] = JsonWriterStateInvalid;
    jw->state[1] = JsonWriterStateValue;
}

static void jw_nl_indent(JsonWriter *jw) {
    assert(jw->state_index >= 1);
    fprintf(jw->f, "%s", jw->nl);
    for (size_t i = 0; i < jw->state_index - 1; i += 1) {
        fprintf(jw->f, "%s", jw->one_indent);
    }
}

static void jw_push_state(JsonWriter *jw, JsonWriterState state) {
    jw->state_index += 1;
    assert(jw->state_index < JSON_MAX_DEPTH);
    jw->state[jw->state_index] = state;
}

static void jw_pop_state(JsonWriter *jw) {
    assert(jw->state_index != 0);
    jw->state_index -= 1;
}

static void jw_begin_array(JsonWriter *jw) {
    assert(jw->state[jw->state_index] == JsonWriterStateValue);
    fprintf(jw->f, "[");
    jw->state[jw->state_index] = JsonWriterStateArrayStart;
}

static void jw_begin_object(JsonWriter *jw) {
    assert(jw->state[jw->state_index] == JsonWriterStateValue);
    fprintf(jw->f, "{");
    jw->state[jw->state_index] = JsonWriterStateObjectStart;
}

static void jw_array_elem(JsonWriter *jw) {
    switch (jw->state[jw->state_index]) {
        case JsonWriterStateInvalid:
        case JsonWriterStateValue:
        case JsonWriterStateObjectStart:
        case JsonWriterStateObject:
            zig_unreachable();
        case JsonWriterStateArray:
            fprintf(jw->f, ",");
            ZIG_FALLTHROUGH;
        case JsonWriterStateArrayStart:
            jw->state[jw->state_index] = JsonWriterStateArray;
            jw_push_state(jw, JsonWriterStateValue);
            jw_nl_indent(jw);
            return;
    }
    zig_unreachable();
}

static void jw_write_escaped_string(JsonWriter *jw, const char *s) {
    fprintf(jw->f, "\"");
    for (;; s += 1) {
        switch (*s) {
            case 0:
                fprintf(jw->f, "\"");
                return;
            case '"':
                fprintf(jw->f, "\\\"");
                continue;
            case '\t':
                fprintf(jw->f, "\\t");
                continue;
            case '\r':
                fprintf(jw->f, "\\r");
                continue;
            case '\n':
                fprintf(jw->f, "\\n");
                continue;
            case '\b':
                fprintf(jw->f, "\\b");
                continue;
            case '\f':
                fprintf(jw->f, "\\f");
                continue;
            case '\\':
                fprintf(jw->f, "\\\\");
                continue;
            default:
                fprintf(jw->f, "%c", *s);
                continue;
        }
    }
}

static void jw_object_field(JsonWriter *jw, const char *name) {
    switch (jw->state[jw->state_index]) {
        case JsonWriterStateInvalid:
        case JsonWriterStateValue:
        case JsonWriterStateArray:
        case JsonWriterStateArrayStart:
            zig_unreachable();
        case JsonWriterStateObject:
            fprintf(jw->f, ",");
            ZIG_FALLTHROUGH;
        case JsonWriterStateObjectStart:
            jw->state[jw->state_index] = JsonWriterStateObject;
            jw_push_state(jw, JsonWriterStateValue);
            jw_nl_indent(jw);
            jw_write_escaped_string(jw, name);
            fprintf(jw->f, ": ");
            return;
    }
    zig_unreachable();
}

static void jw_end_array(JsonWriter *jw) {
    switch (jw->state[jw->state_index]) {
        case JsonWriterStateInvalid:
        case JsonWriterStateValue:
        case JsonWriterStateObjectStart:
        case JsonWriterStateObject:
            zig_unreachable();
        case JsonWriterStateArrayStart:
            fprintf(jw->f, "]");
            jw_pop_state(jw);
            return;
        case JsonWriterStateArray:
            jw_nl_indent(jw);
            jw_pop_state(jw);
            fprintf(jw->f, "]");
            return;
    }
    zig_unreachable();
}


static void jw_end_object(JsonWriter *jw) {
    switch (jw->state[jw->state_index]) {
        case JsonWriterStateInvalid:
            zig_unreachable();
        case JsonWriterStateValue:
            zig_unreachable();
        case JsonWriterStateArray:
            zig_unreachable();
        case JsonWriterStateArrayStart:
            zig_unreachable();
        case JsonWriterStateObjectStart:
            fprintf(jw->f, "}");
            jw_pop_state(jw);
            return;
        case JsonWriterStateObject:
            jw_nl_indent(jw);
            jw_pop_state(jw);
            fprintf(jw->f, "}");
            return;
    }
    zig_unreachable();
}

static void jw_null(JsonWriter *jw) {
    assert(jw->state[jw->state_index] == JsonWriterStateValue);
    fprintf(jw->f, "null");
    jw_pop_state(jw);
}

static void jw_bool(JsonWriter *jw, bool x) {
    assert(jw->state[jw->state_index] == JsonWriterStateValue);
    if (x) {
        fprintf(jw->f, "true");
    } else {
        fprintf(jw->f, "false");
    }
    jw_pop_state(jw);
}

static void jw_int(JsonWriter *jw, int64_t x) {
    assert(jw->state[jw->state_index] == JsonWriterStateValue);
    if (x > 4503599627370496 || x < -4503599627370496) {
        fprintf(jw->f, "\"%" ZIG_PRI_i64 "\"", x);
    } else {
        fprintf(jw->f, "%" ZIG_PRI_i64, x);
    }
    jw_pop_state(jw);
}

static void jw_bigint(JsonWriter *jw, const BigInt *x) {
    assert(jw->state[jw->state_index] == JsonWriterStateValue);
    Buf *str = buf_alloc();
    bigint_append_buf(str, x, 10);

    if (bigint_fits_in_bits(x, 52, true)) {
        fprintf(jw->f, "%s", buf_ptr(str));
    } else {
        fprintf(jw->f, "\"%s\"", buf_ptr(str));
    }
    jw_pop_state(jw);

    buf_destroy(str);
}

static void jw_string(JsonWriter *jw, const char *s) {
    assert(jw->state[jw->state_index] == JsonWriterStateValue);
    jw_write_escaped_string(jw, s);
    jw_pop_state(jw);
}


static void tree_print(FILE *f, ZigType *ty, size_t indent);

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
        TypeStructField *field = struct_type->data.structure.fields[i];
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
    zig_pretty_print_bytes(f, ty->abi_size);
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

struct AnalDumpCtx {
    CodeGen *g;
    JsonWriter jw;

    ZigList<ZigType *> type_list;
    HashMap<const ZigType *, uint32_t, type_ptr_hash, type_ptr_eql> type_map;

    ZigList<ZigPackage *> pkg_list;
    HashMap<const ZigPackage *, uint32_t, pkg_ptr_hash, pkg_ptr_eql> pkg_map;

    ZigList<Buf *> file_list;
    HashMap<Buf *, uint32_t, buf_hash, buf_eql_buf> file_map;

    ZigList<Tld *> decl_list;
    HashMap<const Tld *, uint32_t, tld_ptr_hash, tld_ptr_eql> decl_map;

    ZigList<ZigFn *> fn_list;
    HashMap<const ZigFn *, uint32_t, fn_ptr_hash, fn_ptr_eql> fn_map;
    HashMap<const ZigFn *, uint32_t, fn_ptr_hash, fn_ptr_eql> fn_decl_map;

    ZigList<AstNode *> node_list;
    HashMap<const AstNode *, uint32_t, node_ptr_hash, node_ptr_eql> node_map;

    ZigList<ErrorTableEntry *> err_list;
    HashMap<const ErrorTableEntry *, uint32_t, err_ptr_hash, err_ptr_eql> err_map;
};

static uint32_t anal_dump_get_type_id(AnalDumpCtx *ctx, ZigType *ty);
static void anal_dump_value(AnalDumpCtx *ctx, AstNode *source_node, ZigType *ty, ZigValue *value);

static void anal_dump_poke_value(AnalDumpCtx *ctx, AstNode *source_node, ZigType *ty, ZigValue *value) {
    Error err;
    if (value->type != ty) {
        return;
    }
    if ((err = ir_resolve_lazy(ctx->g, source_node, value))) {
        codegen_report_errors_and_exit(ctx->g);
    }
    if (value->special == ConstValSpecialUndef) {
        return;
    }
    if (value->special == ConstValSpecialRuntime) {
        return;
    }
    switch (ty->id) {
        case ZigTypeIdMetaType: {
            ZigType *val_ty = value->data.x_type;
            (void)anal_dump_get_type_id(ctx, val_ty);
            return;
        }
        default:
            return;
    }
    zig_unreachable();
}

static uint32_t anal_dump_get_type_id(AnalDumpCtx *ctx, ZigType *ty) {
    uint32_t type_id = ctx->type_list.length;
    auto existing_entry = ctx->type_map.put_unique(ty, type_id);
    if (existing_entry == nullptr) {
        ctx->type_list.append(ty);
    } else {
        type_id = existing_entry->value;
    }
    return type_id;
}

static uint32_t anal_dump_get_pkg_id(AnalDumpCtx *ctx, ZigPackage *pkg) {
    assert(pkg != nullptr);
    uint32_t pkg_id = ctx->pkg_list.length;
    auto existing_entry = ctx->pkg_map.put_unique(pkg, pkg_id);
    if (existing_entry == nullptr) {
        ctx->pkg_list.append(pkg);
    } else {
        pkg_id = existing_entry->value;
    }
    return pkg_id;
}

static uint32_t anal_dump_get_file_id(AnalDumpCtx *ctx, Buf *file) {
    uint32_t file_id = ctx->file_list.length;
    auto existing_entry = ctx->file_map.put_unique(file, file_id);
    if (existing_entry == nullptr) {
        ctx->file_list.append(file);
    } else {
        file_id = existing_entry->value;
    }
    return file_id;
}

static uint32_t anal_dump_get_node_id(AnalDumpCtx *ctx, AstNode *node) {
    uint32_t node_id = ctx->node_list.length;
    auto existing_entry = ctx->node_map.put_unique(node, node_id);
    if (existing_entry == nullptr) {
        ctx->node_list.append(node);
    } else {
        node_id = existing_entry->value;
    }
    return node_id;
}

static uint32_t anal_dump_get_fn_id(AnalDumpCtx *ctx, ZigFn *fn) {
    uint32_t fn_id = ctx->fn_list.length;
    auto existing_entry = ctx->fn_map.put_unique(fn, fn_id);
    if (existing_entry == nullptr) {
        ctx->fn_list.append(fn);

        // poke the fn
        (void)anal_dump_get_type_id(ctx, fn->type_entry);
        (void)anal_dump_get_node_id(ctx, fn->proto_node);
    } else {
        fn_id = existing_entry->value;
    }
    return fn_id;
}

static uint32_t anal_dump_get_err_id(AnalDumpCtx *ctx, ErrorTableEntry *err) {
    uint32_t err_id = ctx->err_list.length;
    auto existing_entry = ctx->err_map.put_unique(err, err_id);
    if (existing_entry == nullptr) {
        ctx->err_list.append(err);
    } else {
        err_id = existing_entry->value;
    }
    return err_id;
}

static uint32_t anal_dump_get_decl_id(AnalDumpCtx *ctx, Tld *tld) {
    uint32_t decl_id = ctx->decl_list.length;
    auto existing_entry = ctx->decl_map.put_unique(tld, decl_id);
    if (existing_entry == nullptr) {
        ctx->decl_list.append(tld);

        if (tld->import != nullptr) {
            (void)anal_dump_get_type_id(ctx, tld->import);
        }

        // poke the types
        switch (tld->id) {
            case TldIdVar: {
                TldVar *tld_var = reinterpret_cast<TldVar *>(tld);
                ZigVar *var = tld_var->var;

                if (var != nullptr) {
                    (void)anal_dump_get_type_id(ctx, var->var_type);

                    if (var->const_value != nullptr) {
                        anal_dump_poke_value(ctx, var->decl_node, var->var_type, var->const_value);
                    }
                }
                break;
            }
            case TldIdFn: {
                TldFn *tld_fn = reinterpret_cast<TldFn *>(tld);
                ZigFn *fn = tld_fn->fn_entry;

                if (fn != nullptr) {
                    (void)anal_dump_get_type_id(ctx, fn->type_entry);
                    ctx->fn_decl_map.put_unique(fn, decl_id);
                }
                break;
            }
            default:
                break;
        }

    } else {
        decl_id = existing_entry->value;
    }
    return decl_id;
}

static void anal_dump_type_ref(AnalDumpCtx *ctx, ZigType *ty) {
    uint32_t type_id = anal_dump_get_type_id(ctx, ty);
    jw_int(&ctx->jw, type_id);
}

static void anal_dump_pkg_ref(AnalDumpCtx *ctx, ZigPackage *pkg) {
    uint32_t pkg_id = anal_dump_get_pkg_id(ctx, pkg);
    jw_int(&ctx->jw, pkg_id);
}

static void anal_dump_file_ref(AnalDumpCtx *ctx, Buf *file) {
    uint32_t file_id = anal_dump_get_file_id(ctx, file);
    jw_int(&ctx->jw, file_id);
}

static void anal_dump_node_ref(AnalDumpCtx *ctx, AstNode *node) {
    uint32_t node_id = anal_dump_get_node_id(ctx, node);
    jw_int(&ctx->jw, node_id);
}

static void anal_dump_fn_ref(AnalDumpCtx *ctx, ZigFn *fn) {
    uint32_t fn_id = anal_dump_get_fn_id(ctx, fn);
    jw_int(&ctx->jw, fn_id);
}

static void anal_dump_err_ref(AnalDumpCtx *ctx, ErrorTableEntry *err) {
    uint32_t err_id = anal_dump_get_err_id(ctx, err);
    jw_int(&ctx->jw, err_id);
}

static void anal_dump_decl_ref(AnalDumpCtx *ctx, Tld *tld) {
    uint32_t decl_id = anal_dump_get_decl_id(ctx, tld);
    jw_int(&ctx->jw, decl_id);
}

static void anal_dump_pkg(AnalDumpCtx *ctx, ZigPackage *pkg) {
    JsonWriter *jw = &ctx->jw;

    Buf full_path_buf = BUF_INIT;
    os_path_join(&pkg->root_src_dir, &pkg->root_src_path, &full_path_buf);
    Buf *resolve_paths[] = { &full_path_buf, };
    Buf *resolved_path = buf_alloc();
    *resolved_path = os_path_resolve(resolve_paths, 1);

    auto import_entry = ctx->g->import_table.maybe_get(resolved_path);
    if (!import_entry) {
        return;
    }

    jw_array_elem(jw);
    jw_begin_object(jw);

    jw_object_field(jw, "name");
    jw_string(jw, buf_ptr(&pkg->pkg_path));

    jw_object_field(jw, "file");
    anal_dump_file_ref(ctx, resolved_path);

    jw_object_field(jw, "main");
    anal_dump_type_ref(ctx, import_entry->value);

    jw_object_field(jw, "table");
    jw_begin_object(jw);
    auto it = pkg->package_table.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        ZigPackage *child_pkg = entry->value;
        if (child_pkg != nullptr) {
            jw_object_field(jw, buf_ptr(entry->key));
            anal_dump_pkg_ref(ctx, child_pkg);
        }
    }
    jw_end_object(jw);

    jw_end_object(jw);
}

static void anal_dump_decl(AnalDumpCtx *ctx, Tld *tld) {
    JsonWriter *jw = &ctx->jw;

    bool make_obj = tld->id == TldIdVar || tld->id == TldIdFn;
    if (make_obj) {
        jw_array_elem(jw);
        jw_begin_object(jw);

        jw_object_field(jw, "import");
        anal_dump_type_ref(ctx, tld->import);

        jw_object_field(jw, "src");
        anal_dump_node_ref(ctx, tld->source_node);

        jw_object_field(jw, "name");
        jw_string(jw, buf_ptr(tld->name));
    }

    switch (tld->id) {
        case TldIdVar: {
            TldVar *tld_var = reinterpret_cast<TldVar *>(tld);
            ZigVar *var = tld_var->var;

            if (var != nullptr) {
                jw_object_field(jw, "kind");
                if (var->src_is_const) {
                    jw_string(jw, "const");
                } else {
                    jw_string(jw, "var");
                }

                if (var->is_thread_local) {
                    jw_object_field(jw, "threadlocal");
                    jw_bool(jw, true);
                }

                jw_object_field(jw, "type");
                anal_dump_type_ref(ctx, var->var_type);

                if (var->const_value != nullptr) {
                    jw_object_field(jw, "value");
                    anal_dump_value(ctx, var->decl_node, var->var_type, var->const_value);
                }
            }
            break;
        }
        case TldIdFn: {
            TldFn *tld_fn = reinterpret_cast<TldFn *>(tld);
            ZigFn *fn = tld_fn->fn_entry;

            if (fn != nullptr) {
                jw_object_field(jw, "kind");
                jw_string(jw, "const");

                jw_object_field(jw, "type");
                anal_dump_type_ref(ctx, fn->type_entry);

                jw_object_field(jw, "value");
                anal_dump_fn_ref(ctx, fn);
            }
            break;
        }
        default:
            break;
    }

    if (make_obj) {
        jw_end_object(jw);
    }
}

static void anal_dump_file(AnalDumpCtx *ctx, Buf *file) {
    JsonWriter *jw = &ctx->jw;
    jw_string(jw, buf_ptr(file));
}

static void anal_dump_value(AnalDumpCtx *ctx, AstNode *source_node, ZigType *ty, ZigValue *value) {
    Error err;

    if (value->type != ty) {
        jw_null(&ctx->jw);
        return;
    }
    if ((err = ir_resolve_lazy(ctx->g, source_node, value))) {
        codegen_report_errors_and_exit(ctx->g);
    }
    if (value->special == ConstValSpecialUndef) {
        jw_string(&ctx->jw, "undefined");
        return;
    }
    if (value->special == ConstValSpecialRuntime) {
        jw_null(&ctx->jw);
        return;
    }
    switch (ty->id) {
        case ZigTypeIdMetaType: {
            ZigType *val_ty = value->data.x_type;
            anal_dump_type_ref(ctx, val_ty);
            return;
        }
        case ZigTypeIdFn: {
            if (value->data.x_ptr.special == ConstPtrSpecialFunction) {
                ZigFn *val_fn = value->data.x_ptr.data.fn.fn_entry;
                anal_dump_fn_ref(ctx, val_fn);
            } else {
                jw_null(&ctx->jw);
            }
            return;
        }
        case ZigTypeIdOptional: {
            if(optional_value_is_null(value)){
                jw_string(&ctx->jw, "null");
            } else {
                jw_null(&ctx->jw);
            }
            return;
        }
        case ZigTypeIdBool: {
            jw_string(&ctx->jw, value->data.x_bool ? "true" : "false");
            return;
        }
        case ZigTypeIdInt: {
            jw_bigint(&ctx->jw, &value->data.x_bigint);
            return;
        }
        default:
            jw_null(&ctx->jw);
            return;
    }
    zig_unreachable();
}

static void anal_dump_pointer_attrs(AnalDumpCtx *ctx, ZigType *ty) {
    JsonWriter *jw = &ctx->jw;
    if (ty->data.pointer.explicit_alignment != 0) {
        jw_object_field(jw, "align");
        jw_int(jw, ty->data.pointer.explicit_alignment);
    }
    if (ty->data.pointer.is_const) {
        jw_object_field(jw, "const");
        jw_bool(jw, true);
    }
    if (ty->data.pointer.is_volatile) {
        jw_object_field(jw, "volatile");
        jw_bool(jw, true);
    }
    if (ty->data.pointer.allow_zero) {
        jw_object_field(jw, "allowZero");
        jw_bool(jw, true);
    }
    if (ty->data.pointer.host_int_bytes != 0) {
        jw_object_field(jw, "hostIntBytes");
        jw_int(jw, ty->data.pointer.host_int_bytes);

        jw_object_field(jw, "bitOffsetInHost");
        jw_int(jw, ty->data.pointer.bit_offset_in_host);
    }

    jw_object_field(jw, "elem");
    anal_dump_type_ref(ctx, ty->data.pointer.child_type);
}

static void anal_dump_type(AnalDumpCtx *ctx, ZigType *ty) {
    JsonWriter *jw = &ctx->jw;
    jw_array_elem(jw);
    jw_begin_object(jw);

    jw_object_field(jw, "kind");
    jw_int(jw, type_id_index(ty));

    switch (ty->id) {
        case ZigTypeIdMetaType:
        case ZigTypeIdBool:
        case ZigTypeIdEnumLiteral:
            break;
        case ZigTypeIdStruct: {
            if (ty->data.structure.special == StructSpecialSlice) {
                jw_object_field(jw, "len");
                jw_int(jw, 2);
                anal_dump_pointer_attrs(ctx, ty->data.structure.fields[slice_ptr_index]->type_entry);
                break;
            }

            jw_object_field(jw, "name");
            jw_string(jw, buf_ptr(&ty->name));

            jw_object_field(jw, "src");
            anal_dump_node_ref(ctx, ty->data.structure.decl_node);

            {
                jw_object_field(jw, "pubDecls");
                jw_begin_array(jw);

                ScopeDecls *decls_scope = ty->data.structure.decls_scope;
                auto it = decls_scope->decl_table.entry_iterator();
                for (;;) {
                    auto *entry = it.next();
                    if (!entry)
                        break;

                    Tld *tld = entry->value;
                    if (tld->visib_mod == VisibModPub) {
                        jw_array_elem(jw);
                        anal_dump_decl_ref(ctx, tld);
                    }
                }
                jw_end_array(jw);
            }

            {
                jw_object_field(jw, "privDecls");
                jw_begin_array(jw);

                ScopeDecls *decls_scope = ty->data.structure.decls_scope;
                auto it = decls_scope->decl_table.entry_iterator();
                for (;;) {
                    auto *entry = it.next();
                    if (!entry)
                        break;

                    Tld *tld = entry->value;
                    if (tld->visib_mod == VisibModPrivate) {
                        jw_array_elem(jw);
                        anal_dump_decl_ref(ctx, tld);
                    }
                }
                jw_end_array(jw);
            }

            if (ty->data.structure.src_field_count != 0) {
                jw_object_field(jw, "fields");
                jw_begin_array(jw);

                for(size_t i = 0; i < ty->data.structure.src_field_count; i += 1) {
                    jw_array_elem(jw);
                    anal_dump_type_ref(ctx, ty->data.structure.fields[i]->type_entry);
                }
                jw_end_array(jw);
            }

            if (ty->data.structure.root_struct != nullptr) {
                Buf *path_buf = ty->data.structure.root_struct->path;

                jw_object_field(jw, "file");
                anal_dump_file_ref(ctx, path_buf);
            }
            break;
        }
        case ZigTypeIdUnion: {
            jw_object_field(jw, "name");
            jw_string(jw, buf_ptr(&ty->name));

            jw_object_field(jw, "src");
            anal_dump_node_ref(ctx, ty->data.unionation.decl_node);

            {
                jw_object_field(jw, "pubDecls");
                jw_begin_array(jw);

                ScopeDecls *decls_scope = ty->data.unionation.decls_scope;
                auto it = decls_scope->decl_table.entry_iterator();
                for (;;) {
                    auto *entry = it.next();
                    if (!entry)
                        break;

                    Tld *tld = entry->value;
                    if (tld->visib_mod == VisibModPub) {
                        jw_array_elem(jw);
                        anal_dump_decl_ref(ctx, tld);
                    }
                }
                jw_end_array(jw);
            }

            {
                jw_object_field(jw, "privDecls");
                jw_begin_array(jw);

                ScopeDecls *decls_scope = ty->data.unionation.decls_scope;
                auto it = decls_scope->decl_table.entry_iterator();
                for (;;) {
                    auto *entry = it.next();
                    if (!entry)
                        break;

                    Tld *tld = entry->value;
                    if (tld->visib_mod == VisibModPrivate) {
                        jw_array_elem(jw);
                        anal_dump_decl_ref(ctx, tld);
                    }
                }
                jw_end_array(jw);
            }

            if (ty->data.unionation.src_field_count != 0) {
                jw_object_field(jw, "fields");
                jw_begin_array(jw);

                for(size_t i = 0; i < ty->data.unionation.src_field_count; i += 1) {
                    jw_array_elem(jw);
                    anal_dump_type_ref(ctx, ty->data.unionation.fields[i].type_entry);
                }
                jw_end_array(jw);
            }
            break;
        }
        case ZigTypeIdEnum: {
            jw_object_field(jw, "name");
            jw_string(jw, buf_ptr(&ty->name));

            jw_object_field(jw, "src");
            anal_dump_node_ref(ctx, ty->data.enumeration.decl_node);

            {
                jw_object_field(jw, "pubDecls");
                jw_begin_array(jw);

                ScopeDecls *decls_scope = ty->data.enumeration.decls_scope;
                auto it = decls_scope->decl_table.entry_iterator();
                for (;;) {
                    auto *entry = it.next();
                    if (!entry)
                        break;

                    Tld *tld = entry->value;
                    if (tld->visib_mod == VisibModPub) {
                        jw_array_elem(jw);
                        anal_dump_decl_ref(ctx, tld);
                    }
                }
                jw_end_array(jw);
            }

            {
                jw_object_field(jw, "privDecls");
                jw_begin_array(jw);

                ScopeDecls *decls_scope = ty->data.enumeration.decls_scope;
                auto it = decls_scope->decl_table.entry_iterator();
                for (;;) {
                    auto *entry = it.next();
                    if (!entry)
                        break;

                    Tld *tld = entry->value;
                    if (tld->visib_mod == VisibModPrivate) {
                        jw_array_elem(jw);
                        anal_dump_decl_ref(ctx, tld);
                    }
                }
                jw_end_array(jw);
            }

            if (ty->data.enumeration.src_field_count != 0) {
                jw_object_field(jw, "fields");
                jw_begin_array(jw);

                for(size_t i = 0; i < ty->data.enumeration.src_field_count; i += 1) {
                    jw_array_elem(jw);
                    jw_bigint(jw, &ty->data.enumeration.fields[i].value);
                }
                jw_end_array(jw);
            }
            break;
        }
        case ZigTypeIdFloat: {
            jw_object_field(jw, "bits");
            jw_int(jw, ty->data.floating.bit_count);
            break;
        }
        case ZigTypeIdInt: {
            if (ty->data.integral.is_signed) {
                jw_object_field(jw, "i");
            } else {
                jw_object_field(jw, "u");
            }
            jw_int(jw, ty->data.integral.bit_count);
            break;
        }
        case ZigTypeIdFn: {
            jw_object_field(jw, "name");
            jw_string(jw, buf_ptr(&ty->name));

            jw_object_field(jw, "generic");
            jw_bool(jw, ty->data.fn.is_generic);

            if (ty->data.fn.fn_type_id.return_type != nullptr) {
                jw_object_field(jw, "ret");
                anal_dump_type_ref(ctx, ty->data.fn.fn_type_id.return_type);
            }

            if (ty->data.fn.fn_type_id.param_count != 0) {
                jw_object_field(jw, "args");
                jw_begin_array(jw);
                for (size_t i = 0; i < ty->data.fn.fn_type_id.param_count; i += 1) {
                    jw_array_elem(jw);
                    if (ty->data.fn.fn_type_id.param_info[i].type != nullptr) {
                        anal_dump_type_ref(ctx, ty->data.fn.fn_type_id.param_info[i].type);
                    } else {
                        jw_null(jw);
                    }
                }
                jw_end_array(jw);
            }
            break;
        }
        case ZigTypeIdOptional: {
            jw_object_field(jw, "child");
            anal_dump_type_ref(ctx, ty->data.maybe.child_type);
            break;
        }
        case ZigTypeIdPointer: {
            switch (ty->data.pointer.ptr_len) {
                case PtrLenSingle:
                    break;
                case PtrLenUnknown:
                    jw_object_field(jw, "len");
                    jw_int(jw, 1);
                    break;
                case PtrLenC:
                    jw_object_field(jw, "len");
                    jw_int(jw, 3);
                    break;
            }
            anal_dump_pointer_attrs(ctx, ty);
            break;
        }
        case ZigTypeIdErrorSet: {
            if (type_is_global_error_set(ty)) {
                break;
            }
            jw_object_field(jw, "name");
            jw_string(jw, buf_ptr(&ty->name));

            if (ty->data.error_set.infer_fn != nullptr) {
                jw_object_field(jw, "fn");
                anal_dump_fn_ref(ctx, ty->data.error_set.infer_fn);
            }
            jw_object_field(jw, "errors");
            jw_begin_array(jw);
            for (uint32_t i = 0; i < ty->data.error_set.err_count; i += 1) {
                jw_array_elem(jw);
                ErrorTableEntry *err = ty->data.error_set.errors[i];
                anal_dump_err_ref(ctx, err);
            }
            jw_end_array(jw);
            break;
        }
        case ZigTypeIdErrorUnion: {
            jw_object_field(jw, "err");
            anal_dump_type_ref(ctx, ty->data.error_union.err_set_type);

            jw_object_field(jw, "payload");
            anal_dump_type_ref(ctx, ty->data.error_union.payload_type);

            break;
        }
        case ZigTypeIdArray: {
            jw_object_field(jw, "len");
            jw_int(jw, ty->data.array.len);

            jw_object_field(jw, "elem");
            anal_dump_type_ref(ctx, ty->data.array.child_type);
            break;
        }
        case ZigTypeIdVector: {
            jw_object_field(jw, "len");
            jw_int(jw, ty->data.vector.len);

            jw_object_field(jw, "elem");
            anal_dump_type_ref(ctx, ty->data.vector.elem_type);
            break;
        }
        case ZigTypeIdAnyFrame: {
            if (ty->data.any_frame.result_type != nullptr) {
                jw_object_field(jw, "result");
                anal_dump_type_ref(ctx, ty->data.any_frame.result_type);
            }
            break;
        }
        case ZigTypeIdFnFrame: {
            jw_object_field(jw, "fnName");
            jw_string(jw, buf_ptr(&ty->data.frame.fn->symbol_name));

            jw_object_field(jw, "fn");
            anal_dump_fn_ref(ctx, ty->data.frame.fn);
            break;
        }
        case ZigTypeIdInvalid:
            zig_unreachable();
        default:
            jw_object_field(jw, "name");
            jw_string(jw, buf_ptr(&ty->name));
            break;
    }
    jw_end_object(jw);
}

static void anal_dump_node(AnalDumpCtx *ctx, const AstNode *node) {
    JsonWriter *jw = &ctx->jw;

    jw_begin_object(jw);

    jw_object_field(jw, "file");
    anal_dump_file_ref(ctx, node->owner->data.structure.root_struct->path);

    jw_object_field(jw, "line");
    jw_int(jw, node->line);

    jw_object_field(jw, "col");
    jw_int(jw, node->column);

    const Buf *doc_comments_buf = nullptr;
    const Buf *name_buf = nullptr;
    const ZigList<AstNode *> *field_nodes = nullptr;
    bool is_var_args = false;
    bool is_noalias = false;
    bool is_comptime = false;

    switch (node->type) {
        case NodeTypeParamDecl:
            doc_comments_buf = &node->data.param_decl.doc_comments;
            name_buf = node->data.param_decl.name;
            is_var_args = node->data.param_decl.is_var_args;
            is_noalias = node->data.param_decl.is_noalias;
            is_comptime = node->data.param_decl.is_comptime;
            break;
        case NodeTypeFnProto:
            doc_comments_buf = &node->data.fn_proto.doc_comments;
            field_nodes = &node->data.fn_proto.params;
            is_var_args = node->data.fn_proto.is_var_args;
            break;
        case NodeTypeVariableDeclaration:
            doc_comments_buf = &node->data.variable_declaration.doc_comments;
            break;
        case NodeTypeErrorSetField:
            doc_comments_buf = &node->data.err_set_field.doc_comments;
            break;
        case NodeTypeStructField:
            doc_comments_buf = &node->data.struct_field.doc_comments;
            name_buf = node->data.struct_field.name;
            break;
        case NodeTypeContainerDecl:
            field_nodes = &node->data.container_decl.fields;
            doc_comments_buf = &node->data.container_decl.doc_comments;
            break;
        default:
            break;
    }

    if (doc_comments_buf != nullptr && doc_comments_buf->list.length != 0) {
        jw_object_field(jw, "docs");
        jw_string(jw, buf_ptr(doc_comments_buf));
    }

    if (name_buf != nullptr) {
        jw_object_field(jw, "name");
        jw_string(jw, buf_ptr(name_buf));
    }

    if (field_nodes != nullptr) {
        jw_object_field(jw, "fields");
        jw_begin_array(jw);
        for (size_t i = 0; i < field_nodes->length; i += 1) {
            jw_array_elem(jw);
            anal_dump_node_ref(ctx, field_nodes->at(i));
        }
        jw_end_array(jw);
    }

    if (is_var_args) {
        jw_object_field(jw, "varArgs");
        jw_bool(jw, true);
    }

    if (is_comptime) {
        jw_object_field(jw, "comptime");
        jw_bool(jw, true);
    }

    if (is_noalias) {
        jw_object_field(jw, "noalias");
        jw_bool(jw, true);
    }

    jw_end_object(jw);
}

static void anal_dump_err(AnalDumpCtx *ctx, const ErrorTableEntry *err) {
    JsonWriter *jw = &ctx->jw;

    jw_begin_object(jw);

    jw_object_field(jw, "src");
    anal_dump_node_ref(ctx, err->decl_node);

    jw_object_field(jw, "name");
    jw_string(jw, buf_ptr(&err->name));

    jw_end_object(jw);
}

static void anal_dump_fn(AnalDumpCtx *ctx, ZigFn *fn) {
    JsonWriter *jw = &ctx->jw;

    jw_begin_object(jw);

    jw_object_field(jw, "src");
    anal_dump_node_ref(ctx, fn->proto_node);

    jw_object_field(jw, "type");
    anal_dump_type_ref(ctx, fn->type_entry);

    auto entry = ctx->fn_decl_map.maybe_get(fn);
    if (entry != nullptr) {
      jw_object_field(jw, "decl");
      jw_int(jw, entry->value);
    }

    jw_end_object(jw);
}

void zig_print_analysis_dump(CodeGen *g, FILE *f, const char *one_indent, const char *nl) {
    AnalDumpCtx ctx = {};
    ctx.g = g;
    JsonWriter *jw = &ctx.jw;
    jw_init(jw, f, one_indent, nl);
    ctx.type_map.init(16);
    ctx.pkg_map.init(16);
    ctx.file_map.init(16);
    ctx.decl_map.init(16);
    ctx.node_map.init(16);
    ctx.fn_map.init(16);
    ctx.fn_decl_map.init(16);
    ctx.err_map.init(16);

    jw_begin_object(jw);

    jw_object_field(jw, "typeKinds");
    jw_begin_array(jw);
    for (size_t i = 0; i < type_id_len(); i += 1) {
        jw_array_elem(jw);
        jw_string(jw, type_id_name(type_id_at_index(i)));
    }
    jw_end_array(jw);

    jw_object_field(jw, "params");
    jw_begin_object(jw);
    {
        jw_object_field(jw, "zigVersion");
        jw_string(jw, stage2_version_string());

        jw_object_field(jw, "builds");
        jw_begin_array(jw);
        jw_array_elem(jw);
        jw_begin_object(jw);
        jw_object_field(jw, "target");
        Buf triple_buf = BUF_INIT;
        target_triple_zig(&triple_buf, g->zig_target);
        jw_string(jw, buf_ptr(&triple_buf));
        jw_end_object(jw);
        jw_end_array(jw);

        jw_object_field(jw, "rootName");
        jw_string(jw, buf_ptr(g->root_out_name));
    }
    jw_end_object(jw);

    jw_object_field(jw, "rootPkg");
    anal_dump_pkg_ref(&ctx, g->main_pkg);

    // FIXME: Remove this ugly workaround.
    //        Right now the code in docs/main.js relies on the root of the main package being itself.
    g->main_pkg->package_table.put(buf_create_from_str("root"), g->main_pkg);

    // Poke the functions
    for (size_t i = 0; i < g->fn_defs.length; i += 1) {
        ZigFn *fn = g->fn_defs.at(i);
        (void)anal_dump_get_fn_id(&ctx, fn);
    }

    jw_object_field(jw, "calls");
    jw_begin_array(jw);
    {
        ZigList<ZigVar *> var_stack = {};

        auto it = g->memoized_fn_eval_table.entry_iterator();
        for (;;) {
            auto *entry = it.next();
            if (!entry)
                break;

            var_stack.resize(0);
            ZigFn *fn = nullptr;

            Scope *scope = entry->key;
            while (scope != nullptr) {
                if (scope->id == ScopeIdVarDecl) {
                    ZigVar *var = reinterpret_cast<ScopeVarDecl *>(scope)->var;
                    var_stack.append(var);
                } else if (scope->id == ScopeIdFnDef) {
                    fn = reinterpret_cast<ScopeFnDef *>(scope)->fn_entry;
                    break;
                }
                scope = scope->parent;
            }
            ZigValue *result = entry->value;

            assert(fn != nullptr);

            jw_array_elem(jw);
            jw_begin_object(jw);

            jw_object_field(jw, "fn");
            anal_dump_fn_ref(&ctx, fn);

            jw_object_field(jw, "result");
            {
                jw_begin_object(jw);

                jw_object_field(jw, "type");
                anal_dump_type_ref(&ctx, result->type);

                jw_object_field(jw, "value");
                anal_dump_value(&ctx, scope->source_node, result->type, result);

                jw_end_object(jw);
            }

            if (var_stack.length != 0) {
                jw_object_field(jw, "args");
                jw_begin_array(jw);

                while (var_stack.length != 0) {
                    ZigVar *var = var_stack.pop();

                    jw_array_elem(jw);
                    jw_begin_object(jw);

                    jw_object_field(jw, "type");
                    anal_dump_type_ref(&ctx, var->var_type);

                    jw_object_field(jw, "value");
                    anal_dump_value(&ctx, scope->source_node, var->var_type, var->const_value);

                    jw_end_object(jw);
                }
                jw_end_array(jw);
            }

            jw_end_object(jw);
        }

        var_stack.deinit();
    }
    jw_end_array(jw);

    jw_object_field(jw, "packages");
    jw_begin_array(jw);
    for (uint32_t i = 0; i < ctx.pkg_list.length; i += 1) {
        anal_dump_pkg(&ctx, ctx.pkg_list.at(i));
    }
    jw_end_array(jw);

    jw_object_field(jw, "types");
    jw_begin_array(jw);

    for (uint32_t i = 0; i < ctx.type_list.length; i += 1) {
        ZigType *ty = ctx.type_list.at(i);
        anal_dump_type(&ctx, ty);
    }
    jw_end_array(jw);

    jw_object_field(jw, "decls");
    jw_begin_array(jw);
    for (uint32_t i = 0; i < ctx.decl_list.length; i += 1) {
        Tld *decl = ctx.decl_list.at(i);
        anal_dump_decl(&ctx, decl);
    }
    jw_end_array(jw);

    jw_object_field(jw, "fns");
    jw_begin_array(jw);
    for (uint32_t i = 0; i < ctx.fn_list.length; i += 1) {
        ZigFn *fn = ctx.fn_list.at(i);
        jw_array_elem(jw);
        anal_dump_fn(&ctx, fn);
    }
    jw_end_array(jw);

    jw_object_field(jw, "errors");
    jw_begin_array(jw);
    for (uint32_t i = 0; i < ctx.err_list.length; i += 1) {
        const ErrorTableEntry *err = ctx.err_list.at(i);
        jw_array_elem(jw);
        anal_dump_err(&ctx, err);
    }
    jw_end_array(jw);

    jw_object_field(jw, "astNodes");
    jw_begin_array(jw);
    for (uint32_t i = 0; i < ctx.node_list.length; i += 1) {
        const AstNode *node = ctx.node_list.at(i);
        jw_array_elem(jw);
        anal_dump_node(&ctx, node);
    }
    jw_end_array(jw);

    jw_object_field(jw, "files");
    jw_begin_array(jw);
    for (uint32_t i = 0; i < ctx.file_list.length; i += 1) {
        Buf *file = ctx.file_list.at(i);
        jw_array_elem(jw);
        anal_dump_file(&ctx, file);
    }
    jw_end_array(jw);

    jw_end_object(jw);
}
