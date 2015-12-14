/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "parseh.hpp"
#include "config.h"

#include <clang-c/Index.h>

#include <string.h>

struct TypeDef {
    Buf alias;
    Buf target;
};

struct Arg {
    Buf name;
    Buf *type;
};

struct Fn {
    Buf name;
    Buf *return_type;
    Arg *args;
    int arg_count;
    bool is_variadic;
};

struct Field {
    Buf name;
    Buf *type;
};

struct Struct {
    Buf name;
    ZigList<Field*> fields;
    bool have_def;
};

struct ParseH {
    CXTranslationUnit tu;
    FILE *f;
    ZigList<Fn *> fn_list;
    ZigList<Struct *> struct_list;
    ZigList<TypeDef *> type_def_list;
    ZigList<Struct *> incomplete_struct_list;
    Fn *cur_fn;
    Struct *cur_struct;
    int arg_index;
    int cur_indent;
    CXSourceRange range;
    CXSourceLocation location;
};

static const int indent_size = 4;

struct TypeMapping {
    const char *c_name;
    const char *zig_name;
};

static const TypeMapping type_mappings[] = {
    {
        "int8_t",
        "i8",
    },
    {
        "uint8_t",
        "u8",
    },
    {
        "uint16_t",
        "u16",
    },
    {
        "uint32_t",
        "u32",
    },
    {
        "uint64_t",
        "u64",
    },
    {
        "int16_t",
        "i16",
    },
    {
        "int32_t",
        "i32",
    },
    {
        "int64_t",
        "i64",
    },
    {
        "intptr_t",
        "isize",
    },
    {
        "uintptr_t",
        "usize",
    },
};

static bool have_struct_def(ParseH *p, Buf *name) {
    for (int i = 0; i < p->struct_list.length; i += 1) {
        Struct *struc = p->struct_list.at(i);
        if (struc->fields.length > 0 && buf_eql_buf(&struc->name, name)) {
            return true;
        }
    }
    return false;
}

static const char *c_to_zig_name(const char *name) {
    for (int i = 0; i < array_length(type_mappings); i += 1) {
        const TypeMapping *mapping = &type_mappings[i];
        if (strcmp(mapping->c_name, name) == 0)
            return mapping->zig_name;
    }
    return nullptr;
}

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

static void print_location(ParseH *p) {
    CXFile file;
    unsigned line, column, offset;
    clang_getFileLocation(p->location, &file, &line, &column, &offset);
    CXString file_name = clang_getFileName(file);

    fprintf(stderr, "%s line %u, column %u\n", clang_getCString(file_name), line, column);
}

static bool resolves_to_void(ParseH *p, CXType raw_type) {
    if (raw_type.kind == CXType_Unexposed) {
        CXType canonical = clang_getCanonicalType(raw_type);
        if (canonical.kind == CXType_Unexposed)
            zig_panic("clang C api insufficient");
        else
            return resolves_to_void(p, canonical);
    }
    if (raw_type.kind == CXType_Void) {
        return true;
    } else if (raw_type.kind == CXType_Typedef) {
        CXCursor typedef_cursor = clang_getTypeDeclaration(raw_type);
        CXType underlying_type = clang_getTypedefDeclUnderlyingType(typedef_cursor);
        return resolves_to_void(p, underlying_type);
    }
    return false;
}

static Buf *to_zig_type(ParseH *p, CXType raw_type) {
    if (raw_type.kind == CXType_Unexposed) {
        CXType canonical = clang_getCanonicalType(raw_type);
        if (canonical.kind == CXType_Unexposed)
            zig_panic("clang C api insufficient");
        else
            return to_zig_type(p, canonical);
    }
    switch (raw_type.kind) {
        case CXType_Invalid:
        case CXType_Unexposed:
            zig_unreachable();
        case CXType_Void:
            zig_panic("void type encountered");
        case CXType_Bool:
            return buf_create_from_str("bool");
        case CXType_SChar:
            return buf_create_from_str("i8");
        case CXType_UChar:
        case CXType_Char_U:
        case CXType_Char_S:
            return buf_create_from_str("u8");
        case CXType_WChar:
            print_location(p);
            zig_panic("TODO wchar");
        case CXType_Char16:
            print_location(p);
            zig_panic("TODO char16");
        case CXType_Char32:
            print_location(p);
            zig_panic("TODO char32");
        case CXType_UShort:
            return buf_create_from_str("c_ushort");
        case CXType_UInt:
            return buf_create_from_str("c_uint");
        case CXType_ULong:
            return buf_create_from_str("c_ulong");
        case CXType_ULongLong:
            return buf_create_from_str("c_ulonglong");
        case CXType_UInt128:
            print_location(p);
            zig_panic("TODO uint128");
        case CXType_Short:
            return buf_create_from_str("c_short");
        case CXType_Int:
            return buf_create_from_str("c_int");
        case CXType_Long:
            return buf_create_from_str("c_long");
        case CXType_LongLong:
            return buf_create_from_str("c_longlong");
        case CXType_Int128:
            print_location(p);
            zig_panic("TODO int128");
        case CXType_Float:
            return buf_create_from_str("f32");
        case CXType_Double:
            return buf_create_from_str("f64");
        case CXType_LongDouble:
            return buf_create_from_str("f128");
        case CXType_IncompleteArray:
            {
                CXType pointee_type = clang_getArrayElementType(raw_type);
                Buf *pointee_buf = to_zig_type(p, pointee_type);
                if (clang_isConstQualifiedType(pointee_type)) {
                    return buf_sprintf("*const %s", buf_ptr(pointee_buf));
                } else {
                    return buf_sprintf("*mut %s", buf_ptr(pointee_buf));
                }
            }
        case CXType_Pointer:
            {
                CXType pointee_type = clang_getPointeeType(raw_type);
                Buf *pointee_buf;
                if (resolves_to_void(p, pointee_type)) {
                    pointee_buf = buf_create_from_str("u8");
                } else {
                    pointee_buf = to_zig_type(p, pointee_type);
                }
                if (clang_isConstQualifiedType(pointee_type)) {
                    return buf_sprintf("*const %s", buf_ptr(pointee_buf));
                } else {
                    return buf_sprintf("*mut %s", buf_ptr(pointee_buf));
                }
            }
        case CXType_Record:
            {
                const char *name = prefixes_stripped(raw_type);
                return buf_sprintf("%s", name);
            }
        case CXType_Enum:
            {
                const char *name = prefixes_stripped(raw_type);
                return buf_sprintf("%s", name);
            }
        case CXType_Typedef:
            {
                const char *name = prefixes_stripped(raw_type);
                const char *zig_name = c_to_zig_name(name);
                if (zig_name) {
                    return buf_create_from_str(zig_name);
                } else {
                    CXCursor typedef_cursor = clang_getTypeDeclaration(raw_type);
                    CXType underlying_type = clang_getTypedefDeclUnderlyingType(typedef_cursor);
                    if (resolves_to_void(p, underlying_type)) {
                        return buf_create_from_str("u8");
                    } else {
                        return buf_create_from_str(name);
                    }
                }
            }
        case CXType_ConstantArray:
            {
                CXType child_type = clang_getArrayElementType(raw_type);
                Buf *zig_child_type = to_zig_type(p, child_type);
                long size = (long)clang_getArraySize(raw_type);
                return buf_sprintf("[%s; %ld]", buf_ptr(zig_child_type), size);
            }
        case CXType_FunctionProto:
            fprintf(stderr, "warning: TODO function proto\n");
            print_location(p);
            return buf_create_from_str("u8");
        case CXType_FunctionNoProto:
            print_location(p);
            zig_panic("TODO function no proto");
        case CXType_BlockPointer:
            print_location(p);
            zig_panic("TODO block pointer");
        case CXType_Vector:
            print_location(p);
            zig_panic("TODO vector");
        case CXType_LValueReference:
        case CXType_RValueReference:
        case CXType_VariableArray:
        case CXType_DependentSizedArray:
        case CXType_MemberPointer:
        case CXType_ObjCInterface:
        case CXType_ObjCObjectPointer:
        case CXType_NullPtr:
        case CXType_Overload:
        case CXType_Dependent:
        case CXType_ObjCId:
        case CXType_ObjCClass:
        case CXType_ObjCSel:
        case CXType_Complex:
            print_location(p);
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

static enum CXChildVisitResult visit_fn_children(CXCursor cursor, CXCursor parent, CXClientData client_data) {
    ParseH *p = (ParseH*)client_data;
    enum CXCursorKind kind = clang_getCursorKind(cursor);

    switch (kind) {
    case CXCursor_ParmDecl:
        {
            assert(p->cur_fn);
            assert(p->arg_index < p->cur_fn->arg_count);
            CXString name = clang_getCursorSpelling(cursor);
            Buf *arg_name = &p->cur_fn->args[p->arg_index].name;
            buf_init_from_str(arg_name, clang_getCString(name));
            if (buf_len(arg_name) == 0) {
                buf_appendf(arg_name, "arg%d", p->arg_index);
            }

            p->arg_index += 1;
            return CXChildVisit_Continue;
        }
    default:
        return CXChildVisit_Recurse;
    }
}

static enum CXChildVisitResult visit_struct_children(CXCursor cursor, CXCursor parent, CXClientData client_data) {
    ParseH *p = (ParseH*)client_data;
    enum CXCursorKind kind = clang_getCursorKind(cursor);

    switch (kind) {
    case CXCursor_FieldDecl:
        {
            assert(p->cur_struct);
            CXString name = clang_getCursorSpelling(cursor);
            Field *field = allocate<Field>(1);
            buf_init_from_str(&field->name, clang_getCString(name));
            CXType cursor_type = clang_getCursorType(cursor);
            field->type = to_zig_type(p, cursor_type);

            p->cur_struct->fields.append(field);

            return CXChildVisit_Continue;
        }
    default:
        return CXChildVisit_Recurse;
    }
}

static bool handle_struct_cursor(ParseH *p, CXCursor cursor, const char *name, bool expect_name) {
    p->cur_struct = allocate<Struct>(1);

    buf_init_from_str(&p->cur_struct->name, name);

    bool got_name = (buf_len(&p->cur_struct->name) != 0);
    if (expect_name != got_name)
        return false;

    clang_visitChildren(cursor, visit_struct_children, p);

    if (p->cur_struct->fields.length > 0) {
        p->struct_list.append(p->cur_struct);
    } else {
        p->incomplete_struct_list.append(p->cur_struct);
    }

    p->cur_struct = nullptr;

    return true;
}


static enum CXChildVisitResult fn_visitor(CXCursor cursor, CXCursor parent, CXClientData client_data) {
    ParseH *p = (ParseH*)client_data;
    enum CXCursorKind kind = clang_getCursorKind(cursor);
    CXString name = clang_getCursorSpelling(cursor);

    p->range = clang_getCursorExtent(cursor);
    p->location = clang_getRangeStart(p->range);

    switch (kind) {
    case CXCursor_FunctionDecl:
        {
            CX_StorageClass storage_class = clang_Cursor_getStorageClass(cursor);
            if (!is_storage_class_export(storage_class))
                return CXChildVisit_Continue;

            CXType fn_type = clang_getCursorType(cursor);
            if (clang_getFunctionTypeCallingConv(fn_type) != CXCallingConv_C) {
                print_location(p);
                fprintf(stderr, "warning: skipping non c calling convention function, not yet supported\n");
                return CXChildVisit_Continue;
            }

            assert(!p->cur_fn);
            p->cur_fn = allocate<Fn>(1);

            p->cur_fn->is_variadic = clang_isFunctionTypeVariadic(fn_type);

            CXType return_type = clang_getResultType(fn_type);
            if (!resolves_to_void(p, return_type)) {
                p->cur_fn->return_type = to_zig_type(p, return_type);
            }

            buf_init_from_str(&p->cur_fn->name, clang_getCString(name));

            p->cur_fn->arg_count = clang_getNumArgTypes(fn_type);
            p->cur_fn->args = allocate<Arg>(p->cur_fn->arg_count);

            for (int i = 0; i < p->cur_fn->arg_count; i += 1) {
                CXType param_type = clang_getArgType(fn_type, i);
                p->cur_fn->args[i].type = to_zig_type(p, param_type);
            }

            p->arg_index = 0;

            clang_visitChildren(cursor, visit_fn_children, p);

            p->fn_list.append(p->cur_fn);
            p->cur_fn = nullptr;

            return CXChildVisit_Recurse;
        }
    case CXCursor_CompoundStmt:
    case CXCursor_FieldDecl:
    case CXCursor_TypedefDecl:
        {
            CXType underlying_type = clang_getTypedefDeclUnderlyingType(cursor);

            if (resolves_to_void(p, underlying_type)) {
                return CXChildVisit_Continue;
            }

            if (underlying_type.kind == CXType_Unexposed) {
                underlying_type = clang_getCanonicalType(underlying_type);
            }
            bool skip_typedef;
            if (underlying_type.kind == CXType_Unexposed) {
                fprintf(stderr, "warning: unexposed type\n");
                print_location(p);
                skip_typedef = true;
            } else if (underlying_type.kind == CXType_Record) {
                CXCursor decl_cursor = clang_getTypeDeclaration(underlying_type);
                skip_typedef = handle_struct_cursor(p, decl_cursor, clang_getCString(name), false);
            } else if (underlying_type.kind == CXType_Invalid) {
                fprintf(stderr, "warning: invalid type\n");
                print_location(p);
                skip_typedef = true;
            } else {
                skip_typedef = false;
            }

            CXType typedef_type = clang_getCursorType(cursor);
            const char *name_str = prefixes_stripped(typedef_type);
            if (!skip_typedef && c_to_zig_name(name_str)) {
                skip_typedef = true;
            }

            if (!skip_typedef) {
                TypeDef *type_def = allocate<TypeDef>(1);
                buf_init_from_str(&type_def->alias, name_str);
                buf_init_from_buf(&type_def->target, to_zig_type(p, underlying_type));
                p->type_def_list.append(type_def);
            }

            return CXChildVisit_Continue;
        }
    case CXCursor_StructDecl:
        {
            handle_struct_cursor(p, cursor, clang_getCString(name), true);

            return CXChildVisit_Continue;
        }
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
    CXIndex index = clang_createIndex(1, 0);

    char *ZIG_PARSEH_CFLAGS = getenv("ZIG_PARSEH_CFLAGS");
    if (ZIG_PARSEH_CFLAGS) {
        Buf tmp_buf = BUF_INIT;
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
    clang_argv->append("-isystem");
    clang_argv->append(ZIG_HEADERS_DIR);

    clang_argv->append(nullptr);

    enum CXErrorCode err_code;
    if ((err_code = clang_parseTranslationUnit2(index, target_path,
            clang_argv->items, clang_argv->length - 1,
            NULL, 0, CXTranslationUnit_None, &p->tu)))
    {
        zig_panic("parse translation unit failure");
    }


    unsigned diag_count = clang_getNumDiagnostics(p->tu);

    if (diag_count > 0) {
        for (unsigned i = 0; i < diag_count; i += 1) {
            CXDiagnostic diagnostic = clang_getDiagnostic(p->tu, i);
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


    CXCursor cursor = clang_getTranslationUnitCursor(p->tu);
    clang_visitChildren(cursor, fn_visitor, p);

    for (int struct_i = 0; struct_i < p->struct_list.length; struct_i += 1) {
        Struct *struc = p->struct_list.at(struct_i);
        fprintf(f, "struct %s {\n", buf_ptr(&struc->name));
        p->cur_indent += indent_size;
        for (int field_i = 0; field_i < struc->fields.length; field_i += 1) {
            Field *field = struc->fields.at(field_i);
            print_indent(p);
            fprintf(f, "%s: %s,\n", buf_ptr(&field->name), buf_ptr(field->type));
        }

        p->cur_indent -= indent_size;
        fprintf(f, "}\n\n");
    }

    int total_typedef_count = p->type_def_list.length;
    for (int i = 0; i < p->incomplete_struct_list.length; i += 1) {
        Struct *struc = p->incomplete_struct_list.at(i);
        struc->have_def = have_struct_def(p, &struc->name);
        total_typedef_count += (int)!struc->have_def;
    }

    if (total_typedef_count) {
        for (int i = 0; i < p->incomplete_struct_list.length; i += 1) {
            Struct *struc = p->incomplete_struct_list.at(i);
            if (struc->have_def)
                continue;

            fprintf(f, "struct %s;\n", buf_ptr(&struc->name));
        }

        for (int type_def_i = 0; type_def_i < p->type_def_list.length; type_def_i += 1) {
            TypeDef *type_def = p->type_def_list.at(type_def_i);
            fprintf(f, "type %s = %s;\n", buf_ptr(&type_def->alias), buf_ptr(&type_def->target));
        }

        fprintf(f, "\n");
    }

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
                if (arg_i + 1 < fn->arg_count || fn->is_variadic) {
                    fprintf(p->f, ", ");
                }
            }
            if (fn->is_variadic) {
                fprintf(p->f, "...");
            }
            fprintf(p->f, ")");
            if (fn->return_type) {
                fprintf(p->f, " -> %s", buf_ptr(fn->return_type));
            }
            fprintf(p->f, ";\n");
        }
        p->cur_indent -= indent_size;
        fprintf(f, "}\n");
    }
}
