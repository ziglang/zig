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

#include <clang/Frontend/ASTUnit.h>
#include <clang/Frontend/CompilerInstance.h>

#include <string.h>

using namespace clang;

struct Context {
    ParseH *parse_h;
    bool warnings_on;
    VisibMod visib_mod;
    AstNode *c_void_decl_node;
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> type_table;
};

static AstNode *make_qual_type_node(Context *c, QualType qt);

static AstNode *create_node(Context *c, NodeType type) {
    AstNode *node = allocate<AstNode>(1);
    node->type = type;
    return node;
}

static AstNode *simple_type_node(Context *c, const char *type_name) {
    AstNode *node = create_node(c, NodeTypeSymbol);
    buf_init_from_str(&node->data.symbol_expr.symbol, type_name);
    return node;
}

static const char *decl_name(const Decl *decl) {
    const NamedDecl *named_decl = static_cast<const NamedDecl *>(decl);
    return (const char *)named_decl->getName().bytes_begin();
}

static AstNode *create_typedef_node(Context *c, Buf *new_name, AstNode *target_node) {
    if (!target_node) {
        return nullptr;
    }
    AstNode *node = create_node(c, NodeTypeVariableDeclaration);
    buf_init_from_buf(&node->data.variable_declaration.symbol, new_name);
    node->data.variable_declaration.is_const = true;
    node->data.variable_declaration.visib_mod = c->visib_mod;
    node->data.variable_declaration.expr = target_node;
    c->parse_h->var_list.append(node);
    return node;
}

static AstNode *convert_to_c_void(Context *c, AstNode *type_node) {
    if (type_node->type == NodeTypeSymbol &&
        buf_eql_str(&type_node->data.symbol_expr.symbol, "void"))
    {
        if (!c->c_void_decl_node) {
            c->c_void_decl_node = create_typedef_node(c, buf_create_from_str("c_void"),
                    simple_type_node(c, "u8"));
            assert(c->c_void_decl_node);
        }
        return simple_type_node(c, "c_void");
    } else {
        return type_node;
    }
}

static AstNode *pointer_to_type(Context *c, AstNode *type_node, bool is_const) {
    if (!type_node) {
        return nullptr;
    }
    AstNode *node = create_node(c, NodeTypePrefixOpExpr);
    node->data.prefix_op_expr.prefix_op = is_const ? PrefixOpConstAddressOf : PrefixOpAddressOf;
    node->data.prefix_op_expr.primary_expr = convert_to_c_void(c, type_node);
    return node;
}

static AstNode *make_type_node(Context *c, const Type *ty) {
    switch (ty->getTypeClass()) {
        case Type::Builtin:
            {
                const BuiltinType *builtin_ty = static_cast<const BuiltinType*>(ty);
                switch (builtin_ty->getKind()) {
                    case BuiltinType::Void:
                        return simple_type_node(c, "void");
                    case BuiltinType::Bool:
                        return simple_type_node(c, "bool");
                    case BuiltinType::Char_U:
                    case BuiltinType::UChar:
                        return simple_type_node(c, "u8");
                    case BuiltinType::Char_S:
                    case BuiltinType::SChar:
                        return simple_type_node(c, "i8");
                    case BuiltinType::UShort:
                        return simple_type_node(c, "c_ushort");
                    case BuiltinType::UInt:
                        return simple_type_node(c, "c_uint");
                    case BuiltinType::ULong:
                        return simple_type_node(c, "c_ulong");
                    case BuiltinType::ULongLong:
                        return simple_type_node(c, "c_ulonglong");
                    case BuiltinType::Short:
                        return simple_type_node(c, "c_short");
                    case BuiltinType::Int:
                        return simple_type_node(c, "c_int");
                    case BuiltinType::Long:
                        return simple_type_node(c, "c_long");
                    case BuiltinType::LongLong:
                        return simple_type_node(c, "c_longlong");
                    case BuiltinType::Float:
                        return simple_type_node(c, "f32");
                    case BuiltinType::Double:
                        return simple_type_node(c, "f64");
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
                        if (c->warnings_on) {
                            fprintf(stderr, "missed a builtin type\n");
                        }
                        return nullptr;
                }
                break;
            }
        case Type::Pointer:
            {
                const PointerType *pointer_ty = static_cast<const PointerType*>(ty);
                QualType child_qt = pointer_ty->getPointeeType();
                AstNode *type_node = make_qual_type_node(c, child_qt);
                return pointer_to_type(c, type_node, child_qt.isConstQualified());
            }
        case Type::Typedef:
            {
                const TypedefType *typedef_ty = static_cast<const TypedefType*>(ty);
                const TypedefNameDecl *typedef_decl = typedef_ty->getDecl();
                Buf *type_name = buf_create_from_str(decl_name(typedef_decl));
                if (buf_eql_str(type_name, "uint8_t")) {
                    return simple_type_node(c, "u8");
                } else if (buf_eql_str(type_name, "int8_t")) {
                    return simple_type_node(c, "i8");
                } else if (buf_eql_str(type_name, "uint16_t")) {
                    return simple_type_node(c, "u16");
                } else if (buf_eql_str(type_name, "int16_t")) {
                    return simple_type_node(c, "i16");
                } else if (buf_eql_str(type_name, "uint32_t")) {
                    return simple_type_node(c, "u32");
                } else if (buf_eql_str(type_name, "int32_t")) {
                    return simple_type_node(c, "i32");
                } else if (buf_eql_str(type_name, "uint64_t")) {
                    return simple_type_node(c, "u64");
                } else if (buf_eql_str(type_name, "int64_t")) {
                    return simple_type_node(c, "i64");
                } else if (buf_eql_str(type_name, "intptr_t")) {
                    return simple_type_node(c, "isize");
                } else if (buf_eql_str(type_name, "uintptr_t")) {
                    return simple_type_node(c, "usize");
                } else {
                    auto entry = c->type_table.maybe_get(type_name);
                    if (entry) {
                        return simple_type_node(c, buf_ptr(type_name));
                    } else {
                        return nullptr;
                    }
                }
            }
        case Type::Elaborated:
            if (c->warnings_on) {
                fprintf(stderr, "ignoring elaborated type\n");
            }
            return nullptr;
        case Type::FunctionProto:
            if (c->warnings_on) {
                fprintf(stderr, "ignoring function type\n");
            }
            return nullptr;
        case Type::Record:
        case Type::Enum:
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
            if (c->warnings_on) {
                fprintf(stderr, "missed a '%s' type\n", ty->getTypeClassName());
            }
            return nullptr;
    }
}

static AstNode *make_qual_type_node(Context *c, QualType qt) {
    return make_type_node(c, qt.getTypePtr());
}

static void visit_fn_decl(Context *c, const FunctionDecl *fn_decl) {
    AstNode *node = create_node(c, NodeTypeFnProto);
    node->data.fn_proto.is_extern = true;
    node->data.fn_proto.visib_mod = c->visib_mod;
    node->data.fn_proto.is_var_args = fn_decl->isVariadic();
    buf_init_from_str(&node->data.fn_proto.name, decl_name(fn_decl));

    int arg_count = fn_decl->getNumParams();
    bool all_ok = true;
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
        param_decl_node->data.param_decl.type = make_qual_type_node(c, qt);
        if (!param_decl_node->data.param_decl.type) {
            all_ok = false;
            break;
        }

        node->data.fn_proto.params.append(param_decl_node);
    }

    if (fn_decl->isNoReturn()) {
        node->data.fn_proto.return_type = simple_type_node(c, "unreachable");
    } else {
        node->data.fn_proto.return_type = make_qual_type_node(c, fn_decl->getReturnType());
    }

    if (!node->data.fn_proto.return_type) {
        all_ok = false;
    }
    if (!all_ok) {
        // not all the types could be resolved, so we give up on the function decl
        if (c->warnings_on) {
            fprintf(stderr, "skipping function %s", buf_ptr(&node->data.fn_proto.name));
        }
        return;
    }

    c->parse_h->fn_list.append(node);

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

    AstNode *node = create_typedef_node(c, type_name, make_qual_type_node(c, child_qt));

    if (node) {
        c->type_table.put(type_name, true);
    }
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
        default:
            if (c->warnings_on) {
                fprintf(stderr, "ignoring %s\n", decl->getDeclKindName());
            }
    }

    return true;
}

int parse_h_buf(ParseH *parse_h, Buf *source, const char *libc_include_path) {
    int err;
    Buf tmp_file_path = BUF_INIT;
    if ((err = os_buf_to_tmp_file(source, buf_create_from_str(".h"), &tmp_file_path))) {
        return err;
    }
    ZigList<const char *> clang_argv = {0};
    clang_argv.append(buf_ptr(&tmp_file_path));

    clang_argv.append("-isystem");
    clang_argv.append(libc_include_path);

    err = parse_h_file(parse_h, &clang_argv);

    os_delete_file(&tmp_file_path);

    return err;
}

int parse_h_file(ParseH *parse_h, ZigList<const char *> *clang_argv) {
    Context context = {0};
    Context *c = &context;
    c->parse_h = parse_h;
    c->type_table.init(64);

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

            parse_h->errors.append(err_msg);
        }

        return 0;
    }

    ast_unit->visitLocalTopLevelDecls(c, decl_visitor);

    return 0;
}
