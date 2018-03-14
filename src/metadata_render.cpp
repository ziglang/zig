/*
 * Copyright (c) 2018 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "analyze.hpp"
#include "ast_render.hpp"
#include "metadata_render.hpp"
#include "os.hpp"

#include <stdio.h>

static const char *tld_id_str(TldId id) {
    switch (id) {
        case TldIdVar:       return "var";
        case TldIdFn:        return "fn";
        case TldIdContainer: return "container";
        case TldIdCompTime:  return "comptime";
    };
    zig_unreachable();
}

// static const char* tld_resolution_str(TldResolution resolution) {
//     switch (resolution) {
//         case TldResolutionUnresolved: return "TldResolutionUnresolved";
//         case TldResolutionResolving:  return "TldResolutionResolving";
//         case TldResolutionInvalid:    return "TldResolutionInvalid";
//         case TldResolutionOk:         return "TldResolutionOk";
//     }
//     zig_unreachable();
// };

struct JsonRender {
    CodeGen *codegen;
    ZigList<bool> needs_comma;
    bool in_object_key;
    FILE *f;
};

static bool pretty_json = true;
void json_begin(JsonRender *ar) {
    if (!ar->in_object_key && ar->needs_comma.length > 0 && ar->needs_comma.last()) {
        fprintf(ar->f, ",");

        if (pretty_json) {
            fprintf(ar->f, "\n");
            for (size_t i = 0; i < ar->needs_comma.length; ++i)
                fprintf(ar->f, "  ");
        }
    }

    if (ar->needs_comma.length > 0)
        ar->needs_comma.last() = true;

    ar->in_object_key = false;
}

void print_json_array_start(JsonRender *ar) {
    json_begin(ar);
    ar->needs_comma.append(false);

    fprintf(ar->f, "[");
    if (pretty_json)
        fprintf(ar->f, " ");
}
void print_json_array_entry(JsonRender *ar, const char* format, ...) {
    json_begin(ar);

    va_list ap;
    va_start(ap, format);
    vfprintf(ar->f, format, ap);
    va_end(ap);
}
void print_json_array_end(JsonRender *ar) {
    ar->needs_comma.pop();

    if (pretty_json)
        fprintf(ar->f, " ");
    fprintf(ar->f, "]");
}
void print_json_object_start(JsonRender *ar) {
    json_begin(ar);
    ar->needs_comma.append(false);

    fprintf(ar->f, "{");
    if (pretty_json)
        fprintf(ar->f, " ");
}
void print_json_object_key(JsonRender *ar, const char *format, ...) {
    json_begin(ar);
    ar->in_object_key = true;

    fprintf(ar->f, "\"");
    va_list ap;
    va_start(ap, format);
    vfprintf(ar->f, format, ap);
    va_end(ap);
    fprintf(ar->f, "\":");
}
void print_json_object_end(JsonRender *ar) {
    ar->needs_comma.pop();

    if (pretty_json)
        fprintf(ar->f, " ");
    fprintf(ar->f, "}");
}
void print_json_bool(JsonRender *ar, bool value) {
    json_begin(ar);

    fprintf(ar->f, value ? "true" : "false");
}
void print_json_string(JsonRender *ar, const char *format, ...) {
    json_begin(ar);

    fprintf(ar->f, "\"");
    va_list ap;
    va_start(ap, format);
    vfprintf(ar->f, format, ap);
    va_end(ap);
    fprintf(ar->f, "\"");
}
void print_json_string_start(JsonRender *ar) {
    json_begin(ar);

    fprintf(ar->f, "\"");
}
void print_json_string_end(JsonRender *ar) {
    fprintf(ar->f, "\"");
}
void print_json_value(JsonRender *ar, const char *format, ...) {
    json_begin(ar);

    va_list ap;
    va_start(ap, format);
    vfprintf(ar->f, format, ap);
    va_end(ap);
}

void print_json_location(JsonRender *ar, AstNode *node) {
    // TODO: document if we use 0 or 1 based lines.
    print_json_string(ar, "%s:%d:%d", buf_ptr(node->owner->path), node->line + 1, node->column + 1);
}

static bool str_ends_with(const char* str, const char* ending) {
  size_t end_len = strlen(ending);
  size_t str_len = strlen(str);
  return strcmp(str + str_len - end_len, ending) == 0;
}

void metadata_print(CodeGen* codegen, FILE *f, AstNode *node, const char* filename) {
    JsonRender ar0 = {0};
    ar0.codegen = codegen;
    ar0.f = f;
    JsonRender *ar = &ar0;
    print_json_array_start(ar);

    { auto it = codegen->import_table.entry_iterator(); for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        // FIXME: better limiting options
        if (!str_ends_with(buf_ptr(entry->value->path), filename))
          continue;

        { auto decl_table_it = entry->value->decls_scope->decl_table.entry_iterator(); for (;;) {
            auto* decl_table_entry = decl_table_it.next();
            if (!decl_table_entry)
                break;

            print_json_object_start(ar);

            print_json_object_key(ar, "name");
            print_json_string(ar, "%s", buf_ptr(decl_table_entry->value->name));

            print_json_object_key(ar, "id");
            print_json_string(ar, tld_id_str(decl_table_entry->value->id));

            // TODO: do not emit this, just assert it is resolved.
            assert(decl_table_entry->value->resolution == TldResolutionOk);
            // print_json_object_key(ar, "resolution");
            // print_json_string(ar, tld_resolution_str(decl_table_entry->value->resolution));

            switch (decl_table_entry->value->id) {
                case TldIdVar:
                    {
                        auto *var = (TldVar *)decl_table_entry->value;
                        if (!var->var)
                            break;

                        print_json_object_key(ar, "shadowable");
                        print_json_bool(ar, var->var->shadowable);

                        print_json_object_key(ar, "location");
                        print_json_location(ar, var->var->decl_node);
                        // printf("type entry: %s\n", buf_ptr(&var->var->value->type->name));
                        // printf("instruction id=%d", (int)var->var->decl_instruction->id);
                        // assert(var);
                    }
                    break;
                case TldIdFn:
                    {
                    }
                    break;
                case TldIdContainer:
                    {
                        auto *container = (TldContainer *)decl_table_entry->value;
                        print_json_object_key(ar, "kind");
                        print_json_string(ar, "%s", type_id_name(container->type_entry->id));
                    }
                    break;
                case TldIdCompTime:
                    {
                    }
                    break;
                default:
                    zig_unreachable();
            }

            print_json_object_end(ar);
        } }
    } }

    print_json_array_end(ar);
}
