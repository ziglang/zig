#include "parseh.hpp"

#include <clang-c/Index.h>

#include <string.h>

struct Arg {
    Buf name;
    Buf *type;
};

struct Fn {
    Buf name;
    Buf *return_type;
    Arg *args;
    int arg_count;
};

struct ParseH {
    FILE *f;
    ZigList<Fn *> fn_list;
    Fn *cur_fn;
    int arg_index;
    int cur_indent;
};

static const int indent_size = 4;

static bool str_has_prefix(const char *str, const char *prefix) {
    while (*prefix) {
        if (*str && *str == *prefix) {
            str += 1;
            prefix += 1;
        } else {
            return false;
        }
    }
    return true;
}

static const char *prefixes_stripped(CXType type) {
    CXString name = clang_getTypeSpelling(type);
    const char *c_name = clang_getCString(name);

    static const char *prefixes[] = {
        "struct ",
        "enum ",
        "const ",
    };

start_over:

    for (int i = 0; i < array_length(prefixes); i += 1) {
        const char *prefix = prefixes[i];
        if (str_has_prefix(c_name, prefix)) {
            c_name += strlen(prefix);
            goto start_over;
        }
    }
    return c_name;
}

static Buf *to_zig_type(CXType raw_type) {
    CXType canonical = clang_getCanonicalType(raw_type);
    switch (canonical.kind) {
        case CXType_Invalid:
            zig_unreachable();
        case CXType_Unexposed:
            zig_panic("clang C api insufficient");
        case CXType_Void:
            return buf_create_from_str("void");
        case CXType_Bool:
            return buf_create_from_str("bool");
        case CXType_SChar:
            return buf_create_from_str("i8");
        case CXType_Char_U:
        case CXType_Char_S:
        case CXType_UChar:
            return buf_create_from_str("u8");
        case CXType_WChar:
            zig_panic("TODO");
        case CXType_Char16:
            zig_panic("TODO");
        case CXType_Char32:
            zig_panic("TODO");
        case CXType_UShort:
            return buf_create_from_str("c_ushort");
        case CXType_UInt:
            return buf_create_from_str("c_uint");
        case CXType_ULong:
            return buf_create_from_str("c_ulong");
        case CXType_ULongLong:
            return buf_create_from_str("c_ulonglong");
        case CXType_UInt128:
            zig_panic("TODO");
        case CXType_Short:
            return buf_create_from_str("c_short");
        case CXType_Int:
            return buf_create_from_str("c_int");
        case CXType_Long:
            return buf_create_from_str("c_long");
        case CXType_LongLong:
            return buf_create_from_str("c_longlong");
        case CXType_Int128:
            zig_panic("TODO");
        case CXType_Float:
            return buf_create_from_str("f32");
        case CXType_Double:
            return buf_create_from_str("f64");
        case CXType_LongDouble:
            return buf_create_from_str("f128");
        case CXType_NullPtr:
            zig_panic("TODO");
        case CXType_Overload:
            zig_panic("TODO");
        case CXType_Dependent:
            zig_panic("TODO");
        case CXType_ObjCId:
            zig_panic("TODO");
        case CXType_ObjCClass:
            zig_panic("TODO");
        case CXType_ObjCSel:
            zig_panic("TODO");
        case CXType_Complex:
            zig_panic("TODO");
        case CXType_Pointer:
            {
                CXType pointee_type = clang_getPointeeType(canonical);
                Buf *pointee_buf = to_zig_type(pointee_type);
                if (clang_isConstQualifiedType(pointee_type)) {
                    return buf_sprintf("*const %s", buf_ptr(pointee_buf));
                } else {
                    return buf_sprintf("*mut %s", buf_ptr(pointee_buf));
                }
            }
        case CXType_BlockPointer:
            zig_panic("TODO");
        case CXType_LValueReference:
            zig_panic("TODO");
        case CXType_RValueReference:
            zig_panic("TODO");
        case CXType_Record:
            {
                const char *name = prefixes_stripped(canonical);
                return buf_sprintf("%s", name);
            }
        case CXType_Enum:
            {
                const char *name = prefixes_stripped(canonical);
                return buf_sprintf("%s", name);
            }
        case CXType_Typedef:
            zig_panic("TODO");
        case CXType_ObjCInterface:
            zig_panic("TODO");
        case CXType_ObjCObjectPointer:
            zig_panic("TODO");
        case CXType_FunctionNoProto:
            zig_panic("TODO");
        case CXType_FunctionProto:
            zig_panic("TODO");
        case CXType_ConstantArray:
            zig_panic("TODO");
        case CXType_Vector:
            zig_panic("TODO");
        case CXType_IncompleteArray:
            zig_panic("TODO");
        case CXType_VariableArray:
            zig_panic("TODO");
        case CXType_DependentSizedArray:
            zig_panic("TODO");
        case CXType_MemberPointer:
            zig_panic("TODO");
    }

    zig_unreachable();
}

static bool is_storage_class_export(CX_StorageClass storage_class) {
    switch (storage_class) {
        case CX_SC_Invalid:
            zig_unreachable();
        case CX_SC_None:
        case CX_SC_Extern:
        case CX_SC_Auto:
            return true;
        case CX_SC_Static:
        case CX_SC_PrivateExtern:
        case CX_SC_OpenCLWorkGroupLocal:
        case CX_SC_Register:
            return false;
    }
    zig_unreachable();
}

static void begin_fn(ParseH *p) {
    assert(!p->cur_fn);
    p->cur_fn = allocate<Fn>(1);
}

static void end_fn(ParseH *p) {
    if (p->cur_fn) {
        p->fn_list.append(p->cur_fn);
        p->cur_fn = nullptr;
    }
}

static enum CXChildVisitResult fn_visitor(CXCursor cursor, CXCursor parent, CXClientData client_data) {
    ParseH *p = (ParseH*)client_data;
    enum CXCursorKind kind = clang_getCursorKind(cursor);
    CXString name = clang_getCursorSpelling(cursor);

    switch (kind) {
    case CXCursor_FunctionDecl:
        {
            CX_StorageClass storage_class = clang_Cursor_getStorageClass(cursor);
            if (!is_storage_class_export(storage_class))
                return CXChildVisit_Continue;

            end_fn(p);
            begin_fn(p);

            CXType fn_type = clang_getCursorType(cursor);
            if (clang_isFunctionTypeVariadic(fn_type)) {
                zig_panic("TODO support variadic function");
            }
            if (clang_getFunctionTypeCallingConv(fn_type) != CXCallingConv_C) {
                zig_panic("TODO support non c calling convention");
            }
            CXType return_type = clang_getResultType(fn_type);
            p->cur_fn->return_type = to_zig_type(return_type);

            buf_init_from_str(&p->cur_fn->name, clang_getCString(name));

            p->cur_fn->arg_count = clang_getNumArgTypes(fn_type);
            p->cur_fn->args = allocate<Arg>(p->cur_fn->arg_count);

            for (int i = 0; i < p->cur_fn->arg_count; i += 1) {
                CXType param_type = clang_getArgType(fn_type, i);
                p->cur_fn->args[i].type = to_zig_type(param_type);
            }

            p->arg_index = 0;

            return CXChildVisit_Recurse;
        }
    case CXCursor_ParmDecl:
        {
            assert(p->cur_fn);
            assert(p->arg_index < p->cur_fn->arg_count);
            buf_init_from_str(&p->cur_fn->args[p->arg_index].name, clang_getCString(name));
            p->arg_index += 1;
            return CXChildVisit_Continue;
        }
    case CXCursor_UnexposedAttr:
    case CXCursor_CompoundStmt:
    case CXCursor_FieldDecl:
        return CXChildVisit_Continue;
    default:
        return CXChildVisit_Recurse;
    }
}

static void print_indent(ParseH *p) {
    for (int i = 0; i < p->cur_indent; i += 1) {
        fprintf(p->f, " ");
    }
}

void parse_h_file(const char *target_path, ZigList<const char *> *clang_argv, FILE *f) {
    ParseH parse_h = {0};
    ParseH *p = &parse_h;
    p->f = f;
    CXTranslationUnit tu;
    CXIndex index = clang_createIndex(1, 0);

    char *ZIG_PARSEH_CFLAGS = getenv("ZIG_PARSEH_CFLAGS");
    if (ZIG_PARSEH_CFLAGS) {
        Buf tmp_buf = {0};
        char *start = ZIG_PARSEH_CFLAGS;
        char *space = strstr(start, " ");
        while (space) {
            if (space - start > 0) {
                buf_init_from_mem(&tmp_buf, start, space - start);
                clang_argv->append(buf_ptr(buf_create_from_buf(&tmp_buf)));
            }
            start = space + 1;
            space = strstr(start, " ");
        }
        buf_init_from_str(&tmp_buf, start);
        clang_argv->append(buf_ptr(buf_create_from_buf(&tmp_buf)));
    }

    clang_argv->append(nullptr);

    enum CXErrorCode err_code;
    if ((err_code = clang_parseTranslationUnit2(index, target_path,
            clang_argv->items, clang_argv->length - 1,
            NULL, 0, CXTranslationUnit_None, &tu)))
    {
        zig_panic("parse translation unit failure");
    }


    unsigned diag_count = clang_getNumDiagnostics(tu);

    if (diag_count > 0) {
        for (unsigned i = 0; i < diag_count; i += 1) {
            CXDiagnostic diagnostic = clang_getDiagnostic(tu, i);
            CXSourceLocation location = clang_getDiagnosticLocation(diagnostic);

            CXFile file;
            unsigned line, column, offset;
            clang_getSpellingLocation(location, &file, &line, &column, &offset);
            CXString text = clang_getDiagnosticSpelling(diagnostic);
            CXString file_name = clang_getFileName(file);
            fprintf(stderr, "%s line %u, column %u: %s\n", clang_getCString(file_name),
                    line, column, clang_getCString(text));
        }

        exit(1);
    }


    CXCursor cursor = clang_getTranslationUnitCursor(tu);
    clang_visitChildren(cursor, fn_visitor, p);
    end_fn(p);

    if (p->fn_list.length) {
        fprintf(f, "extern {\n");
        p->cur_indent += indent_size;
        for (int fn_i = 0; fn_i < p->fn_list.length; fn_i += 1) {
            Fn *fn = p->fn_list.at(fn_i);
            print_indent(p);
            fprintf(p->f, "fn %s(", buf_ptr(&fn->name));
            for (int arg_i = 0; arg_i < fn->arg_count; arg_i += 1) {
                Arg *arg = &fn->args[arg_i];
                fprintf(p->f, "%s: %s", buf_ptr(&arg->name), buf_ptr(arg->type));
                if (arg_i + 1 < fn->arg_count) {
                    fprintf(p->f, ", ");
                }
            }
            fprintf(p->f, ")");
            if (!buf_eql_str(fn->return_type, "void")) {
                fprintf(p->f, " -> %s", buf_ptr(fn->return_type));
            }
            fprintf(p->f, ";\n");
        }
        fprintf(f, "}\n");
    }
}
