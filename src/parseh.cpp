/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "parseh.hpp"
#include "config.h"
#include "os.hpp"
#include "error.hpp"
#include "parser.hpp"
#include "all_types.hpp"
#include "tokenizer.hpp"

#include <clang/Frontend/ASTUnit.h>
#include <clang/Frontend/CompilerInstance.h>

#include <string.h>

using namespace clang;

struct Context {
    ImportTableEntry *import;
    ZigList<ErrorMsg *> *errors;
    bool warnings_on;
    VisibMod visib_mod;
    bool have_c_void_decl_node;
    AstNode *root;
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> root_type_table;
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> struct_type_table;
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> enum_type_table;
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> fn_table;
    SourceManager *source_manager;
    ZigList<AstNode *> aliases;
};

static AstNode *make_qual_type_node(Context *c, QualType qt, const Decl *decl);
static AstNode *make_qual_type_node_with_table(Context *c, QualType qt, const Decl *decl,
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> *type_table);

__attribute__ ((format (printf, 3, 4)))
static void emit_warning(Context *c, const Decl *decl, const char *format, ...) {
    if (!c->warnings_on) {
        return;
    }

    va_list ap;
    va_start(ap, format);
    Buf *msg = buf_vprintf(format, ap);
    va_end(ap);

    SourceLocation sl = decl->getLocation();

    StringRef filename = c->source_manager->getFilename(sl);
    const char *filename_bytes = (const char *)filename.bytes_begin();
    Buf *path;
    if (filename_bytes) {
        path = buf_create_from_str(filename_bytes);
    } else {
        path = buf_sprintf("(no file)");
    }
    unsigned line = c->source_manager->getSpellingLineNumber(sl);
    unsigned column = c->source_manager->getSpellingColumnNumber(sl);
    fprintf(stderr, "%s:%u:%u: warning: %s\n", buf_ptr(path), line, column, buf_ptr(msg));
}

static AstNode *create_node(Context *c, NodeType type) {
    AstNode *node = allocate<AstNode>(1);
    node->type = type;
    node->owner = c->import;
    return node;
}

static AstNode *create_symbol_node(Context *c, const char *type_name) {
    AstNode *node = create_node(c, NodeTypeSymbol);
    buf_init_from_str(&node->data.symbol_expr.symbol, type_name);
    return node;
}

static AstNode *create_field_access_node(Context *c, const char *lhs, const char *rhs) {
    AstNode *node = create_node(c, NodeTypeFieldAccessExpr);
    node->data.field_access_expr.struct_expr = create_symbol_node(c, lhs);
    buf_init_from_str(&node->data.field_access_expr.field_name, rhs);
    normalize_parent_ptrs(node);
    return node;
}

static ZigList<AstNode *> *create_empty_directives(Context *c) {
    return allocate<ZigList<AstNode*>>(1);
}

static AstNode *create_var_decl_node(Context *c, const char *var_name, AstNode *expr_node) {
    AstNode *node = create_node(c, NodeTypeVariableDeclaration);
    buf_init_from_str(&node->data.variable_declaration.symbol, var_name);
    node->data.variable_declaration.is_const = true;
    node->data.variable_declaration.visib_mod = c->visib_mod;
    node->data.variable_declaration.expr = expr_node;
    node->data.variable_declaration.directives = create_empty_directives(c);
    normalize_parent_ptrs(node);
    return node;
}

static AstNode *create_prefix_node(Context *c, PrefixOp op, AstNode *child_node) {
    AstNode *node = create_node(c, NodeTypePrefixOpExpr);
    node->data.prefix_op_expr.prefix_op = op;
    node->data.prefix_op_expr.primary_expr = child_node;
    normalize_parent_ptrs(node);
    return node;
}

static AstNode *create_struct_field_node(Context *c, const char *name, AstNode *type_node) {
    assert(type_node);
    AstNode *node = create_node(c, NodeTypeStructField);
    buf_init_from_str(&node->data.struct_field.name, name);
    node->data.struct_field.directives = create_empty_directives(c);
    node->data.struct_field.visib_mod = VisibModPub;
    node->data.struct_field.type = type_node;

    normalize_parent_ptrs(node);
    return node;
}

static const char *decl_name(const Decl *decl) {
    const NamedDecl *named_decl = static_cast<const NamedDecl *>(decl);
    return (const char *)named_decl->getName().bytes_begin();
}


static AstNode *add_typedef_node(Context *c, Buf *new_name, AstNode *target_node) {
    if (!target_node) {
        return nullptr;
    }
    AstNode *node = create_var_decl_node(c, buf_ptr(new_name), target_node);

    c->root_type_table.put(new_name, true);
    c->root->data.root.top_level_decls.append(node);
    return node;
}

static AstNode *convert_to_c_void(Context *c, AstNode *type_node) {
    if (type_node->type == NodeTypeSymbol &&
        buf_eql_str(&type_node->data.symbol_expr.symbol, "void"))
    {
        if (!c->have_c_void_decl_node) {
            add_typedef_node(c, buf_create_from_str("c_void"), create_symbol_node(c, "u8"));
            c->have_c_void_decl_node = true;
        }
        return create_symbol_node(c, "c_void");
    } else {
        return type_node;
    }
}

static AstNode *pointer_to_type(Context *c, AstNode *type_node, bool is_const) {
    if (!type_node) {
        return nullptr;
    }
    PrefixOp op = is_const ? PrefixOpConstAddressOf : PrefixOpAddressOf;
    AstNode *child_node = create_prefix_node(c, op, convert_to_c_void(c, type_node));
    return create_prefix_node(c, PrefixOpMaybe, child_node);
}

static AstNode *make_type_node(Context *c, const Type *ty, const Decl *decl,
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> *type_table)
{
    switch (ty->getTypeClass()) {
        case Type::Builtin:
            {
                const BuiltinType *builtin_ty = static_cast<const BuiltinType*>(ty);
                switch (builtin_ty->getKind()) {
                    case BuiltinType::Void:
                        return create_symbol_node(c, "void");
                    case BuiltinType::Bool:
                        return create_symbol_node(c, "bool");
                    case BuiltinType::Char_U:
                    case BuiltinType::UChar:
                    case BuiltinType::Char_S:
                        return create_symbol_node(c, "u8");
                    case BuiltinType::SChar:
                        return create_symbol_node(c, "i8");
                    case BuiltinType::UShort:
                        return create_symbol_node(c, "c_ushort");
                    case BuiltinType::UInt:
                        return create_symbol_node(c, "c_uint");
                    case BuiltinType::ULong:
                        return create_symbol_node(c, "c_ulong");
                    case BuiltinType::ULongLong:
                        return create_symbol_node(c, "c_ulonglong");
                    case BuiltinType::Short:
                        return create_symbol_node(c, "c_short");
                    case BuiltinType::Int:
                        return create_symbol_node(c, "c_int");
                    case BuiltinType::Long:
                        return create_symbol_node(c, "c_long");
                    case BuiltinType::LongLong:
                        return create_symbol_node(c, "c_longlong");
                    case BuiltinType::Float:
                        return create_symbol_node(c, "f32");
                    case BuiltinType::Double:
                        return create_symbol_node(c, "f64");
                    case BuiltinType::LongDouble:
                    case BuiltinType::WChar_U:
                    case BuiltinType::Char16:
                    case BuiltinType::Char32:
                    case BuiltinType::UInt128:
                    case BuiltinType::WChar_S:
                    case BuiltinType::Int128:
                    case BuiltinType::Half:
                    case BuiltinType::NullPtr:
                    case BuiltinType::ObjCId:
                    case BuiltinType::ObjCClass:
                    case BuiltinType::ObjCSel:
                    case BuiltinType::OCLImage1d:
                    case BuiltinType::OCLImage1dArray:
                    case BuiltinType::OCLImage1dBuffer:
                    case BuiltinType::OCLImage2d:
                    case BuiltinType::OCLImage2dArray:
                    case BuiltinType::OCLImage3d:
                    case BuiltinType::OCLSampler:
                    case BuiltinType::OCLEvent:
                    case BuiltinType::Dependent:
                    case BuiltinType::Overload:
                    case BuiltinType::BoundMember:
                    case BuiltinType::PseudoObject:
                    case BuiltinType::UnknownAny:
                    case BuiltinType::BuiltinFn:
                    case BuiltinType::ARCUnbridgedCast:
                        emit_warning(c, decl, "missed a builtin type");
                        return nullptr;
                }
                break;
            }
        case Type::Pointer:
            {
                const PointerType *pointer_ty = static_cast<const PointerType*>(ty);
                QualType child_qt = pointer_ty->getPointeeType();
                AstNode *type_node = make_qual_type_node(c, child_qt, decl);
                return pointer_to_type(c, type_node, child_qt.isConstQualified());
            }
        case Type::Typedef:
            {
                const TypedefType *typedef_ty = static_cast<const TypedefType*>(ty);
                const TypedefNameDecl *typedef_decl = typedef_ty->getDecl();
                Buf *type_name = buf_create_from_str(decl_name(typedef_decl));
                if (buf_eql_str(type_name, "uint8_t")) {
                    return create_symbol_node(c, "u8");
                } else if (buf_eql_str(type_name, "int8_t")) {
                    return create_symbol_node(c, "i8");
                } else if (buf_eql_str(type_name, "uint16_t")) {
                    return create_symbol_node(c, "u16");
                } else if (buf_eql_str(type_name, "int16_t")) {
                    return create_symbol_node(c, "i16");
                } else if (buf_eql_str(type_name, "uint32_t")) {
                    return create_symbol_node(c, "u32");
                } else if (buf_eql_str(type_name, "int32_t")) {
                    return create_symbol_node(c, "i32");
                } else if (buf_eql_str(type_name, "uint64_t")) {
                    return create_symbol_node(c, "u64");
                } else if (buf_eql_str(type_name, "int64_t")) {
                    return create_symbol_node(c, "i64");
                } else if (buf_eql_str(type_name, "intptr_t")) {
                    return create_symbol_node(c, "isize");
                } else if (buf_eql_str(type_name, "uintptr_t")) {
                    return create_symbol_node(c, "usize");
                } else {
                    auto entry = type_table->maybe_get(type_name);
                    if (entry) {
                        return create_symbol_node(c, buf_ptr(type_name));
                    } else {
                        return nullptr;
                    }
                }
            }
        case Type::Elaborated:
            {
                const ElaboratedType *elaborated_ty = static_cast<const ElaboratedType*>(ty);
                switch (elaborated_ty->getKeyword()) {
                    case ETK_Struct:
                        return make_qual_type_node_with_table(c, elaborated_ty->getNamedType(),
                                decl, &c->struct_type_table);
                    case ETK_Enum:
                        return make_qual_type_node_with_table(c, elaborated_ty->getNamedType(),
                                decl, &c->enum_type_table);
                    case ETK_Interface:
                    case ETK_Union:
                    case ETK_Class:
                    case ETK_Typename:
                    case ETK_None:
                        emit_warning(c, decl, "unsupported elaborated type");
                        return nullptr;
                }
            }
        case Type::FunctionProto:
            emit_warning(c, decl, "ignoring function type");
            return nullptr;
        case Type::Record:
            {
                const RecordType *record_ty = static_cast<const RecordType*>(ty);
                Buf *record_name = buf_create_from_str(decl_name(record_ty->getDecl()));
                if (type_table->maybe_get(record_name)) {
                    const char *prefix_str;
                    if (type_table == &c->enum_type_table) {
                        prefix_str = "enum_";
                    } else if (type_table == &c->struct_type_table) {
                        prefix_str = "struct_";
                    } else {
                        prefix_str = "";
                    }
                    return create_symbol_node(c, buf_ptr(buf_sprintf("%s%s", prefix_str, buf_ptr(record_name))));
                } else {
                    return nullptr;
                }
            }
        case Type::Enum:
            {
                const EnumType *enum_ty = static_cast<const EnumType*>(ty);
                Buf *record_name = buf_create_from_str(decl_name(enum_ty->getDecl()));
                if (type_table->maybe_get(record_name)) {
                    const char *prefix_str;
                    if (type_table == &c->enum_type_table) {
                        prefix_str = "enum_";
                    } else if (type_table == &c->struct_type_table) {
                        prefix_str = "struct_";
                    } else {
                        prefix_str = "";
                    }
                    return create_symbol_node(c, buf_ptr(buf_sprintf("%s%s", prefix_str, buf_ptr(record_name))));
                } else {
                    return nullptr;
                }
            }
        case Type::BlockPointer:
        case Type::LValueReference:
        case Type::RValueReference:
        case Type::MemberPointer:
        case Type::ConstantArray:
        case Type::IncompleteArray:
        case Type::VariableArray:
        case Type::DependentSizedArray:
        case Type::DependentSizedExtVector:
        case Type::Vector:
        case Type::ExtVector:
        case Type::FunctionNoProto:
        case Type::UnresolvedUsing:
        case Type::Paren:
        case Type::Adjusted:
        case Type::Decayed:
        case Type::TypeOfExpr:
        case Type::TypeOf:
        case Type::Decltype:
        case Type::UnaryTransform:
        case Type::Attributed:
        case Type::TemplateTypeParm:
        case Type::SubstTemplateTypeParm:
        case Type::SubstTemplateTypeParmPack:
        case Type::TemplateSpecialization:
        case Type::Auto:
        case Type::InjectedClassName:
        case Type::DependentName:
        case Type::DependentTemplateSpecialization:
        case Type::PackExpansion:
        case Type::ObjCObject:
        case Type::ObjCInterface:
        case Type::Complex:
        case Type::ObjCObjectPointer:
        case Type::Atomic:
            emit_warning(c, decl, "missed a '%s' type", ty->getTypeClassName());
            return nullptr;
    }
}

static AstNode *make_qual_type_node_with_table(Context *c, QualType qt, const Decl *decl,
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> *type_table)
{
    return make_type_node(c, qt.getTypePtr(), decl, type_table);
}

static AstNode *make_qual_type_node(Context *c, QualType qt, const Decl *decl) {
    return make_qual_type_node_with_table(c, qt, decl, &c->root_type_table);
}

static void visit_fn_decl(Context *c, const FunctionDecl *fn_decl) {
    AstNode *node = create_node(c, NodeTypeFnProto);
    buf_init_from_str(&node->data.fn_proto.name, decl_name(fn_decl));

    auto fn_entry = c->fn_table.maybe_get(&node->data.fn_proto.name);
    if (fn_entry) {
        // we already saw this function
        return;
    }

    node->data.fn_proto.is_extern = true;
    node->data.fn_proto.visib_mod = c->visib_mod;
    node->data.fn_proto.directives = create_empty_directives(c);
    node->data.fn_proto.is_var_args = fn_decl->isVariadic();

    int arg_count = fn_decl->getNumParams();
    for (int i = 0; i < arg_count; i += 1) {
        const ParmVarDecl *param = fn_decl->getParamDecl(i);
        AstNode *param_decl_node = create_node(c, NodeTypeParamDecl);
        const char *name = decl_name(param);
        if (strlen(name) == 0) {
            name = buf_ptr(buf_sprintf("arg%d", i));
        }
        buf_init_from_str(&param_decl_node->data.param_decl.name, name);
        QualType qt = param->getOriginalType();
        param_decl_node->data.param_decl.is_noalias = qt.isRestrictQualified();
        param_decl_node->data.param_decl.type = make_qual_type_node(c, qt, fn_decl);
        if (!param_decl_node->data.param_decl.type) {
            emit_warning(c, param, "skipping function %s, unresolved param type\n",
                    buf_ptr(&node->data.fn_proto.name));
            return;
        }

        normalize_parent_ptrs(param_decl_node);
        node->data.fn_proto.params.append(param_decl_node);
    }

    if (fn_decl->isNoReturn()) {
        node->data.fn_proto.return_type = create_symbol_node(c, "unreachable");
    } else {
        node->data.fn_proto.return_type = make_qual_type_node(c, fn_decl->getReturnType(), fn_decl);
    }

    if (!node->data.fn_proto.return_type) {
        emit_warning(c, fn_decl, "skipping function %s, unresolved return type\n",
                buf_ptr(&node->data.fn_proto.name));
        return;
    }

    normalize_parent_ptrs(node);

    c->fn_table.put(&node->data.fn_proto.name, true);
    c->root->data.root.top_level_decls.append(node);
}

static void visit_typedef_decl(Context *c, const TypedefNameDecl *typedef_decl) {
    QualType child_qt = typedef_decl->getUnderlyingType();
    Buf *type_name = buf_create_from_str(decl_name(typedef_decl));

    if (buf_eql_str(type_name, "uint8_t") ||
        buf_eql_str(type_name, "int8_t") ||
        buf_eql_str(type_name, "uint16_t") ||
        buf_eql_str(type_name, "int16_t") ||
        buf_eql_str(type_name, "uint32_t") ||
        buf_eql_str(type_name, "int32_t") ||
        buf_eql_str(type_name, "uint64_t") ||
        buf_eql_str(type_name, "int64_t") ||
        buf_eql_str(type_name, "intptr_t") ||
        buf_eql_str(type_name, "uintptr_t"))
    {
        // special case we can just use the builtin types
        return;
    }

    add_typedef_node(c, type_name, make_qual_type_node(c, child_qt, typedef_decl));
}

static void add_alias(Context *c, const char *new_name, const char *target_name) {
    AstNode *alias_node = create_var_decl_node(c, new_name, create_symbol_node(c, target_name));
    c->aliases.append(alias_node);
}

static void visit_enum_decl(Context *c, const EnumDecl *enum_decl) {
    Buf *bare_name = buf_create_from_str(decl_name(enum_decl));
    Buf *full_type_name = buf_sprintf("enum_%s", buf_ptr(bare_name));

    if (c->enum_type_table.maybe_get(bare_name)) {
        // we've already seen it
        return;
    }

    const EnumDecl *enum_def = enum_decl->getDefinition();

    if (!enum_def) {
        // this is a type that we can point to but that's it, same as `struct Foo;`.
        add_typedef_node(c, full_type_name, create_symbol_node(c, "u8"));
        add_alias(c, buf_ptr(bare_name), buf_ptr(full_type_name));
        return;
    }

    AstNode *node = create_node(c, NodeTypeStructDecl);
    buf_init_from_buf(&node->data.struct_decl.name, full_type_name);

    node->data.struct_decl.kind = ContainerKindEnum;
    node->data.struct_decl.visib_mod = VisibModExport;
    node->data.struct_decl.directives = create_empty_directives(c);

    ZigList<AstNode *> var_decls = {0};
    int i = 0;
    for (auto it = enum_def->enumerator_begin(),
              it_end = enum_def->enumerator_end();
              it != it_end; ++it, i += 1)
    {
        const EnumConstantDecl *enum_const = *it;
        if (enum_const->getInitExpr()) {
            emit_warning(c, enum_const, "skipping enum %s - has init expression\n", buf_ptr(bare_name));
            return;
        }
        Buf enum_val_name = BUF_INIT;
        buf_init_from_str(&enum_val_name, decl_name(enum_const));

        Buf field_name = BUF_INIT;

        if (buf_starts_with_buf(&enum_val_name, bare_name)) {
            Buf *slice = buf_slice(&enum_val_name, buf_len(bare_name), buf_len(&enum_val_name));
            if (valid_symbol_starter(buf_ptr(slice)[0])) {
                buf_init_from_buf(&field_name, slice);
            } else {
                buf_resize(&field_name, 0);
                buf_appendf(&field_name, "_%s", buf_ptr(slice));
            }
        } else {
            buf_init_from_buf(&field_name, &enum_val_name);
        }

        AstNode *field_node = create_struct_field_node(c, buf_ptr(&field_name), create_symbol_node(c, "void"));
        node->data.struct_decl.fields.append(field_node);

        // in C each enum value is in the global namespace. so we put them there too.
        AstNode *field_access_node = create_field_access_node(c, buf_ptr(full_type_name), buf_ptr(&field_name));
        AstNode *var_node = create_var_decl_node(c, buf_ptr(&enum_val_name), field_access_node);
        var_decls.append(var_node);
    }

    c->enum_type_table.put(bare_name, true);

    normalize_parent_ptrs(node);
    c->root->data.root.top_level_decls.append(node);

    for (int i = 0; i < var_decls.length; i += 1) {
        AstNode *var_node = var_decls.at(i);
        c->root->data.root.top_level_decls.append(var_node);
    }

    // make an alias without the "enum_" prefix. this will get emitted at the
    // end if it doesn't conflict with anything else
    add_alias(c, buf_ptr(bare_name), buf_ptr(full_type_name));
}

static void visit_record_decl(Context *c, const RecordDecl *record_decl) {
    Buf *bare_name = buf_create_from_str(decl_name(record_decl));

    if (!record_decl->isStruct()) {
        emit_warning(c, record_decl, "skipping record %s, not a struct", buf_ptr(bare_name));
        return;
    }

    Buf *full_type_name = buf_sprintf("struct_%s", buf_ptr(bare_name));

    if (c->struct_type_table.maybe_get(bare_name)) {
        // we've already seen it
        return;
    }

    RecordDecl *record_def = record_decl->getDefinition();
    if (!record_def) {
        // this is a type that we can point to but that's it, such as `struct Foo;`.
        add_typedef_node(c, full_type_name, create_symbol_node(c, "u8"));
        add_alias(c, buf_ptr(bare_name), buf_ptr(full_type_name));
        return;
    }

    AstNode *node = create_node(c, NodeTypeStructDecl);
    buf_init_from_buf(&node->data.struct_decl.name, full_type_name);

    node->data.struct_decl.kind = ContainerKindStruct;
    node->data.struct_decl.visib_mod = VisibModExport;
    node->data.struct_decl.directives = create_empty_directives(c);

    for (auto it = record_def->field_begin(),
              it_end = record_def->field_end();
              it != it_end; ++it)
    {
        const FieldDecl *field_decl = *it;

        if (field_decl->isBitField()) {
            emit_warning(c, field_decl, "skipping struct %s - has bitfield\n", buf_ptr(bare_name));
            return;
        }

        AstNode *type_node = make_qual_type_node(c, field_decl->getType(), field_decl);
        if (!type_node) {
            emit_warning(c, field_decl, "skipping struct %s - unhandled type\n", buf_ptr(bare_name));
            return;
        }

        AstNode *field_node = create_struct_field_node(c, decl_name(field_decl), type_node);
        node->data.struct_decl.fields.append(field_node);
    }

    c->struct_type_table.put(bare_name, true);
    normalize_parent_ptrs(node);
    c->root->data.root.top_level_decls.append(node);

    // make an alias without the "struct_" prefix. this will get emitted at the
    // end if it doesn't conflict with anything else
    add_alias(c, buf_ptr(bare_name), buf_ptr(full_type_name));
}

static bool decl_visitor(void *context, const Decl *decl) {
    Context *c = (Context*)context;

    switch (decl->getKind()) {
        case Decl::Function:
            visit_fn_decl(c, static_cast<const FunctionDecl*>(decl));
            break;
        case Decl::Typedef:
            visit_typedef_decl(c, static_cast<const TypedefNameDecl *>(decl));
            break;
        case Decl::Enum:
            visit_enum_decl(c, static_cast<const EnumDecl *>(decl));
            break;
        case Decl::Record:
            visit_record_decl(c, static_cast<const RecordDecl *>(decl));
            break;
        default:
            emit_warning(c, decl, "ignoring %s decl\n", decl->getDeclKindName());
    }

    return true;
}

static void render_aliases(Context *c) {
    for (int i = 0; i < c->aliases.length; i += 1) {
        AstNode *alias_node = c->aliases.at(i);
        assert(alias_node->type == NodeTypeVariableDeclaration);
        Buf *name = &alias_node->data.variable_declaration.symbol;
        if (c->root_type_table.maybe_get(name)) {
            continue;
        }
        if (c->fn_table.maybe_get(name)) {
            continue;
        }
        c->root->data.root.top_level_decls.append(alias_node);
    }
}

int parse_h_buf(ImportTableEntry *import, ZigList<ErrorMsg *> *errors, Buf *source,
        const char **args, int args_len, const char *libc_include_path, bool warnings_on)
{
    int err;
    Buf tmp_file_path = BUF_INIT;
    if ((err = os_buf_to_tmp_file(source, buf_create_from_str(".h"), &tmp_file_path))) {
        return err;
    }
    ZigList<const char *> clang_argv = {0};
    clang_argv.append(buf_ptr(&tmp_file_path));

    clang_argv.append("-isystem");
    clang_argv.append(libc_include_path);

    for (int i = 0; i < args_len; i += 1) {
        clang_argv.append(args[i]);
    }

    err = parse_h_file(import, errors, &clang_argv, warnings_on);

    os_delete_file(&tmp_file_path);

    return err;
}

int parse_h_file(ImportTableEntry *import, ZigList<ErrorMsg *> *errors,
        ZigList<const char *> *clang_argv, bool warnings_on)
{
    Context context = {0};
    Context *c = &context;
    c->warnings_on = warnings_on;
    c->import = import;
    c->errors = errors;
    c->visib_mod = VisibModPub;
    c->root_type_table.init(16);
    c->enum_type_table.init(16);
    c->struct_type_table.init(16);
    c->fn_table.init(16);

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

    // we don't need spell checking and it slows things down
    clang_argv->append("-fno-spell-checking");
    // to make the end argument work
    clang_argv->append(nullptr);

    IntrusiveRefCntPtr<DiagnosticsEngine> diags(CompilerInstance::createDiagnostics(new DiagnosticOptions));

    std::shared_ptr<PCHContainerOperations> pch_container_ops = std::make_shared<PCHContainerOperations>();

    bool skip_function_bodies = true;
    bool only_local_decls = true;
    bool capture_diagnostics = true;
    bool user_files_are_volatile = true;
    bool allow_pch_with_compiler_errors = false;
    const char *resources_path = ZIG_HEADERS_DIR;
    std::unique_ptr<ASTUnit> err_unit;
    std::unique_ptr<ASTUnit> ast_unit(ASTUnit::LoadFromCommandLine(
            &clang_argv->at(0), &clang_argv->last(),
            pch_container_ops, diags, resources_path,
            only_local_decls, capture_diagnostics, None, true, false, TU_Complete,
            false, false, allow_pch_with_compiler_errors, skip_function_bodies,
            user_files_are_volatile, false, &err_unit));


    // Early failures in LoadFromCommandLine may return with ErrUnit unset.
    if (!ast_unit && !err_unit) {
        return ErrorFileSystem;
    }

    if (diags->getClient()->getNumErrors() > 0) {
        if (ast_unit) {
            err_unit = std::move(ast_unit);
        }

        for (ASTUnit::stored_diag_iterator it = err_unit->stored_diag_begin(), 
                it_end = err_unit->stored_diag_end();
                it != it_end; ++it)
        {
            switch (it->getLevel()) {
                case DiagnosticsEngine::Ignored:
                case DiagnosticsEngine::Note:
                case DiagnosticsEngine::Remark:
                case DiagnosticsEngine::Warning:
                    continue;
                case DiagnosticsEngine::Error:
                case DiagnosticsEngine::Fatal:
                    break;
            }
            StringRef msg_str_ref = it->getMessage();
            FullSourceLoc fsl = it->getLocation();
            FileID file_id = fsl.getFileID();
            StringRef filename = fsl.getManager().getFilename(fsl);
            unsigned line = fsl.getSpellingLineNumber() - 1;
            unsigned column = fsl.getSpellingColumnNumber() - 1;
            unsigned offset = fsl.getManager().getFileOffset(fsl);
            const char *source = (const char *)fsl.getManager().getBufferData(file_id).bytes_begin();
            Buf *msg = buf_create_from_str((const char *)msg_str_ref.bytes_begin());
            Buf *path = buf_create_from_str((const char *)filename.bytes_begin());

            ErrorMsg *err_msg = err_msg_create_with_offset(path, line, column, offset, source, msg);

            c->errors->append(err_msg);
        }

        return 0;
    }

    c->source_manager = &ast_unit->getSourceManager();

    c->root = create_node(c, NodeTypeRoot);
    ast_unit->visitLocalTopLevelDecls(c, decl_visitor);

    render_aliases(c);

    normalize_parent_ptrs(c->root);
    import->root = c->root;

    return 0;
}
