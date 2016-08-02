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
#include "c_tokenizer.hpp"
#include "analyze.hpp"

#include <clang/Frontend/ASTUnit.h>
#include <clang/Frontend/CompilerInstance.h>

#include <string.h>

using namespace clang;

struct MacroSymbol {
    Buf *name;
    Buf *value;
};

struct GlobalValue {
    TypeTableEntry *type;
    bool is_const;
};

struct Context {
    ImportTableEntry *import;
    ZigList<ErrorMsg *> *errors;
    bool warnings_on;
    VisibMod visib_mod;
    AstNode *root;
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> global_type_table;
    HashMap<Buf *, GlobalValue, buf_hash, buf_eql_buf> global_value_table;
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> struct_type_table;
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> struct_decl_table;
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> enum_type_table;
    HashMap<const void *, TypeTableEntry *, ptr_hash, ptr_eq> decl_table;
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> fn_table;
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> macro_table;
    SourceManager *source_manager;
    ZigList<AstNode *> aliases;
    ZigList<MacroSymbol> macro_symbols;
    AstNode *source_node;

    CodeGen *codegen;
    bool transform_extern_fn_ptr;
};

static TypeTableEntry *resolve_qual_type_with_table(Context *c, QualType qt, const Decl *decl,
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> *type_table);

static TypeTableEntry *resolve_qual_type(Context *c, QualType qt, const Decl *decl);
static TypeTableEntry *resolve_record_decl(Context *c, const RecordDecl *record_decl);
static TypeTableEntry *resolve_enum_decl(Context *c, const EnumDecl *enum_decl);


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

static uint32_t get_next_node_index(Context *c) {
    uint32_t result = c->codegen->next_node_index;
    c->codegen->next_node_index += 1;
    return result;
}

static AstNode *create_node(Context *c, NodeType type) {
    AstNode *node = allocate<AstNode>(1);
    node->type = type;
    node->owner = c->import;
    node->create_index = get_next_node_index(c);
    return node;
}

static AstNode *create_symbol_node(Context *c, const char *type_name) {
    AstNode *node = create_node(c, NodeTypeSymbol);
    node->data.symbol_expr.symbol = buf_create_from_str(type_name);
    return node;
}

static AstNode *create_field_access_node(Context *c, const char *lhs, const char *rhs) {
    AstNode *node = create_node(c, NodeTypeFieldAccessExpr);
    node->data.field_access_expr.struct_expr = create_symbol_node(c, lhs);
    node->data.field_access_expr.field_name = buf_create_from_str(rhs);
    normalize_parent_ptrs(node);
    return node;
}

static AstNode *create_typed_var_decl_node(Context *c, bool is_const, const char *var_name,
        AstNode *type_node, AstNode *init_node)
{
    AstNode *node = create_node(c, NodeTypeVariableDeclaration);
    node->data.variable_declaration.symbol = buf_create_from_str(var_name);
    node->data.variable_declaration.is_const = is_const;
    node->data.variable_declaration.top_level_decl.visib_mod = c->visib_mod;
    node->data.variable_declaration.expr = init_node;
    node->data.variable_declaration.top_level_decl.directives = nullptr;
    node->data.variable_declaration.type = type_node;
    normalize_parent_ptrs(node);
    return node;
}

static AstNode *create_var_decl_node(Context *c, const char *var_name, AstNode *expr_node) {
    return create_typed_var_decl_node(c, true, var_name, nullptr, expr_node);
}

static AstNode *create_prefix_node(Context *c, PrefixOp op, AstNode *child_node) {
    assert(child_node);
    AstNode *node = create_node(c, NodeTypePrefixOpExpr);
    node->data.prefix_op_expr.prefix_op = op;
    node->data.prefix_op_expr.primary_expr = child_node;
    normalize_parent_ptrs(node);
    return node;
}

static AstNode *create_struct_field_node(Context *c, const char *name, AstNode *type_node) {
    assert(type_node);
    AstNode *node = create_node(c, NodeTypeStructField);
    node->data.struct_field.name = buf_create_from_str(name);
    node->data.struct_field.top_level_decl.visib_mod = VisibModPub;
    node->data.struct_field.type = type_node;

    normalize_parent_ptrs(node);
    return node;
}

static AstNode *create_param_decl_node(Context *c, const char *name, AstNode *type_node, bool is_noalias) {
    assert(type_node);
    AstNode *node = create_node(c, NodeTypeParamDecl);
    node->data.param_decl.name = buf_create_from_str(name);
    node->data.param_decl.type = type_node;
    node->data.param_decl.is_noalias = is_noalias;

    normalize_parent_ptrs(node);
    return node;
}

static AstNode *create_char_lit_node(Context *c, uint8_t value) {
    AstNode *node = create_node(c, NodeTypeCharLiteral);
    node->data.char_literal.value = value;
    return node;
}

// accepts ownership of buf
static AstNode *create_str_lit_node(Context *c, Buf *buf) {
    AstNode *node = create_node(c, NodeTypeStringLiteral);
    node->data.string_literal.buf = buf;
    node->data.string_literal.c = true;
    return node;
}

static AstNode *create_num_lit_float(Context *c, double x) {
    AstNode *node = create_node(c, NodeTypeNumberLiteral);
    node->data.number_literal.bignum = allocate_nonzero<BigNum>(1);
    bignum_init_float(node->data.number_literal.bignum, x);
    return node;
}

static AstNode *create_num_lit_float_negative(Context *c, double x, bool negative) {
    AstNode *num_lit_node = create_num_lit_float(c, x);
    if (!negative) return num_lit_node;
    return create_prefix_node(c, PrefixOpNegation, num_lit_node);
}

static AstNode *create_num_lit_unsigned(Context *c, uint64_t x) {
    AstNode *node = create_node(c, NodeTypeNumberLiteral);
    node->data.number_literal.bignum = allocate_nonzero<BigNum>(1);
    bignum_init_unsigned(node->data.number_literal.bignum, x);
    return node;
}

static AstNode *create_num_lit_unsigned_negative(Context *c, uint64_t x, bool negative) {
    AstNode *num_lit_node = create_num_lit_unsigned(c, x);
    if (!negative) return num_lit_node;
    return create_prefix_node(c, PrefixOpNegation, num_lit_node);
}

static AstNode *create_num_lit_signed(Context *c, int64_t x) {
    if (x >= 0) {
        return create_num_lit_unsigned(c, x);
    }
    BigNum bn_orig;
    bignum_init_signed(&bn_orig, x);

    BigNum bn_negated;
    bignum_negate(&bn_negated, &bn_orig);

    uint64_t uint = bignum_to_twos_complement(&bn_negated);
    AstNode *num_lit_node = create_num_lit_unsigned(c, uint);
    return create_prefix_node(c, PrefixOpNegation, num_lit_node);
}

static AstNode *create_type_decl_node(Context *c, const char *name, AstNode *child_type_node) {
    AstNode *node = create_node(c, NodeTypeTypeDecl);
    node->data.type_decl.symbol = buf_create_from_str(name);
    node->data.type_decl.top_level_decl.visib_mod = c->visib_mod;
    node->data.type_decl.child_type = child_type_node;

    normalize_parent_ptrs(node);
    return node;
}

static AstNode *make_type_node(Context *c, TypeTableEntry *type_entry) {
    AstNode *node = create_node(c, NodeTypeSymbol);
    node->data.symbol_expr.override_type_entry = type_entry;
    return node;
}

static AstNode *create_fn_proto_node(Context *c, Buf *name, TypeTableEntry *fn_type) {
    assert(fn_type->id == TypeTableEntryIdFn);
    AstNode *node = create_node(c, NodeTypeFnProto);
    node->data.fn_proto.is_inline = true;
    node->data.fn_proto.top_level_decl.visib_mod = c->visib_mod;
    node->data.fn_proto.name = name;
    node->data.fn_proto.return_type = make_type_node(c, fn_type->data.fn.fn_type_id.return_type);

    for (int i = 0; i < fn_type->data.fn.fn_type_id.param_count; i += 1) {
        FnTypeParamInfo *info = &fn_type->data.fn.fn_type_id.param_info[i];
        char arg_name[20];
        sprintf(arg_name, "arg_%d", i);
        node->data.fn_proto.params.append(create_param_decl_node(c, arg_name,
                    make_type_node(c, info->type), info->is_noalias));
    }

    normalize_parent_ptrs(node);
    return node;
}

static AstNode *create_one_statement_block(Context *c, AstNode *statement) {
    AstNode *node = create_node(c, NodeTypeBlock);
    node->data.block.statements.append(statement);

    normalize_parent_ptrs(node);
    return node;
}

static AstNode *create_inline_fn_node(Context *c, Buf *fn_name, Buf *var_name, TypeTableEntry *fn_type) {
    AstNode *node = create_node(c, NodeTypeFnDef);
    node->data.fn_def.fn_proto = create_fn_proto_node(c, fn_name, fn_type);

    AstNode *unwrap_node = create_prefix_node(c, PrefixOpUnwrapMaybe, create_symbol_node(c, buf_ptr(var_name)));

    AstNode *fn_call_node = create_node(c, NodeTypeFnCallExpr);
    fn_call_node->data.fn_call_expr.fn_ref_expr = unwrap_node;
    for (int i = 0; i < fn_type->data.fn.fn_type_id.param_count; i += 1) {
        AstNode *decl_node = node->data.fn_def.fn_proto->data.fn_proto.params.at(i);
        Buf *param_name = decl_node->data.param_decl.name;
        fn_call_node->data.fn_call_expr.params.append(create_symbol_node(c, buf_ptr(param_name)));
    }

    normalize_parent_ptrs(fn_call_node);

    node->data.fn_def.body = create_one_statement_block(c, fn_call_node);

    normalize_parent_ptrs(node);
    return node;
}



static const char *decl_name(const Decl *decl) {
    const NamedDecl *named_decl = static_cast<const NamedDecl *>(decl);
    return (const char *)named_decl->getName().bytes_begin();
}

static AstNode *add_typedef_node(Context *c, TypeTableEntry *type_decl) {
    assert(type_decl);
    assert(type_decl->id == TypeTableEntryIdTypeDecl);

    AstNode *node = create_type_decl_node(c, buf_ptr(&type_decl->name),
            make_type_node(c, type_decl->data.type_decl.child_type));
    node->data.type_decl.override_type = type_decl;

    c->global_type_table.put(&type_decl->name, type_decl);
    c->root->data.root.top_level_decls.append(node);
    return node;
}

static AstNode *add_const_var_node(Context *c, Buf *name, TypeTableEntry *type_entry) {
    AstNode *node = create_var_decl_node(c, buf_ptr(name), make_type_node(c, type_entry));

    c->global_type_table.put(name, type_entry);
    c->root->data.root.top_level_decls.append(node);
    return node;
}

static AstNode *create_ap_num_lit_node(Context *c, const Decl *source_decl,
        const llvm::APSInt &aps_int)
{
    if (aps_int.isSigned()) {
        if (aps_int > INT64_MAX || aps_int < INT64_MIN) {
            emit_warning(c, source_decl, "integer overflow\n");
            return nullptr;
        } else {
            return create_num_lit_signed(c, aps_int.getExtValue());
        }
    } else {
        if (aps_int > INT64_MAX) {
            emit_warning(c, source_decl, "integer overflow\n");
            return nullptr;
        } else {
            return create_num_lit_unsigned(c, aps_int.getExtValue());
        }
    }
}

static bool is_c_void_type(Context *c, TypeTableEntry *type_entry) {
    while (type_entry->id == TypeTableEntryIdTypeDecl) {
        if (type_entry == c->codegen->builtin_types.entry_c_void) {
            return true;
        }
        type_entry = type_entry->data.type_decl.child_type;
    }
    return false;
}

static bool qual_type_child_is_fn_proto(const QualType &qt) {
    if (qt.getTypePtr()->getTypeClass() == Type::Paren) {
        const ParenType *paren_type = static_cast<const ParenType *>(qt.getTypePtr());
        if (paren_type->getInnerType()->getTypeClass() == Type::FunctionProto) {
            return true;
        }
    } else if (qt.getTypePtr()->getTypeClass() == Type::Attributed) {
        const AttributedType *attr_type = static_cast<const AttributedType *>(qt.getTypePtr());
        return qual_type_child_is_fn_proto(attr_type->getEquivalentType());
    }
    return false;
}

static TypeTableEntry *resolve_type_with_table(Context *c, const Type *ty, const Decl *decl,
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> *type_table)
{
    switch (ty->getTypeClass()) {
        case Type::Builtin:
            {
                const BuiltinType *builtin_ty = static_cast<const BuiltinType*>(ty);
                switch (builtin_ty->getKind()) {
                    case BuiltinType::Void:
                        return c->codegen->builtin_types.entry_c_void;
                    case BuiltinType::Bool:
                        return c->codegen->builtin_types.entry_bool;
                    case BuiltinType::Char_U:
                    case BuiltinType::UChar:
                    case BuiltinType::Char_S:
                        return c->codegen->builtin_types.entry_u8;
                    case BuiltinType::SChar:
                        return c->codegen->builtin_types.entry_i8;
                    case BuiltinType::UShort:
                        return get_c_int_type(c->codegen, CIntTypeUShort);
                    case BuiltinType::UInt:
                        return get_c_int_type(c->codegen, CIntTypeUInt);
                    case BuiltinType::ULong:
                        return get_c_int_type(c->codegen, CIntTypeULong);
                    case BuiltinType::ULongLong:
                        return get_c_int_type(c->codegen, CIntTypeULongLong);
                    case BuiltinType::Short:
                        return get_c_int_type(c->codegen, CIntTypeShort);
                    case BuiltinType::Int:
                        return get_c_int_type(c->codegen, CIntTypeInt);
                    case BuiltinType::Long:
                        return get_c_int_type(c->codegen, CIntTypeLong);
                    case BuiltinType::LongLong:
                        return get_c_int_type(c->codegen, CIntTypeLongLong);
                    case BuiltinType::Float:
                        return c->codegen->builtin_types.entry_f32;
                    case BuiltinType::Double:
                        return c->codegen->builtin_types.entry_f64;
                    case BuiltinType::LongDouble:
                        return c->codegen->builtin_types.entry_c_long_double;
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
                    case BuiltinType::OCLImage2dArrayDepth:
                    case BuiltinType::OCLImage2dDepth:
                    case BuiltinType::OCLImage2dMSAA:
                    case BuiltinType::OCLImage2dArrayMSAA:
                    case BuiltinType::OCLImage2dMSAADepth:
                    case BuiltinType::OCLImage2dArrayMSAADepth:
                    case BuiltinType::OCLClkEvent:
                    case BuiltinType::OCLQueue:
                    case BuiltinType::OCLNDRange:
                    case BuiltinType::OCLReserveID:
                    case BuiltinType::OMPArraySection:
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
                        return c->codegen->builtin_types.entry_invalid;
                }
                break;
            }
        case Type::Pointer:
            {
                const PointerType *pointer_ty = static_cast<const PointerType*>(ty);
                QualType child_qt = pointer_ty->getPointeeType();
                TypeTableEntry *child_type = resolve_qual_type(c, child_qt, decl);
                if (get_underlying_type(child_type)->id == TypeTableEntryIdInvalid) {
                    emit_warning(c, decl, "pointer to unresolved type");
                    return c->codegen->builtin_types.entry_invalid;
                }

                if (qual_type_child_is_fn_proto(child_qt)) {
                    return get_maybe_type(c->codegen, child_type);
                }
                bool is_const = child_qt.isConstQualified();

                TypeTableEntry *non_null_pointer_type = get_pointer_to_type(c->codegen, child_type, is_const);
                return get_maybe_type(c->codegen, non_null_pointer_type);
            }
        case Type::Typedef:
            {
                const TypedefType *typedef_ty = static_cast<const TypedefType*>(ty);
                const TypedefNameDecl *typedef_decl = typedef_ty->getDecl();
                Buf *type_name = buf_create_from_str(decl_name(typedef_decl));
                if (buf_eql_str(type_name, "uint8_t")) {
                    return c->codegen->builtin_types.entry_u8;
                } else if (buf_eql_str(type_name, "int8_t")) {
                    return c->codegen->builtin_types.entry_i8;
                } else if (buf_eql_str(type_name, "uint16_t")) {
                    return c->codegen->builtin_types.entry_u16;
                } else if (buf_eql_str(type_name, "int16_t")) {
                    return c->codegen->builtin_types.entry_i16;
                } else if (buf_eql_str(type_name, "uint32_t")) {
                    return c->codegen->builtin_types.entry_u32;
                } else if (buf_eql_str(type_name, "int32_t")) {
                    return c->codegen->builtin_types.entry_i32;
                } else if (buf_eql_str(type_name, "uint64_t")) {
                    return c->codegen->builtin_types.entry_u64;
                } else if (buf_eql_str(type_name, "int64_t")) {
                    return c->codegen->builtin_types.entry_i64;
                } else if (buf_eql_str(type_name, "intptr_t")) {
                    return c->codegen->builtin_types.entry_isize;
                } else if (buf_eql_str(type_name, "uintptr_t")) {
                    return c->codegen->builtin_types.entry_usize;
                } else {
                    auto entry = type_table->maybe_get(type_name);
                    if (entry) {
                        if (get_underlying_type(entry->value)->id == TypeTableEntryIdInvalid) {
                            return c->codegen->builtin_types.entry_invalid;
                        } else {
                            return entry->value;
                        }
                    } else {
                        return c->codegen->builtin_types.entry_invalid;
                    }
                }
            }
        case Type::Elaborated:
            {
                const ElaboratedType *elaborated_ty = static_cast<const ElaboratedType*>(ty);
                switch (elaborated_ty->getKeyword()) {
                    case ETK_Struct:
                        return resolve_qual_type_with_table(c, elaborated_ty->getNamedType(),
                                decl, &c->struct_type_table);
                    case ETK_Enum:
                        return resolve_qual_type_with_table(c, elaborated_ty->getNamedType(),
                                decl, &c->enum_type_table);
                    case ETK_Interface:
                    case ETK_Union:
                    case ETK_Class:
                    case ETK_Typename:
                    case ETK_None:
                        emit_warning(c, decl, "unsupported elaborated type");
                        return c->codegen->builtin_types.entry_invalid;
                }
            }
        case Type::FunctionProto:
            {
                const FunctionProtoType *fn_proto_ty = static_cast<const FunctionProtoType*>(ty);

                switch (fn_proto_ty->getCallConv()) {
                    case CC_C:           // __attribute__((cdecl))
                        break;
                    case CC_X86StdCall:  // __attribute__((stdcall))
                        emit_warning(c, decl, "function type has x86 stdcall calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_X86FastCall: // __attribute__((fastcall))
                        emit_warning(c, decl, "function type has x86 fastcall calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_X86ThisCall: // __attribute__((thiscall))
                        emit_warning(c, decl, "function type has x86 thiscall calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_X86VectorCall: // __attribute__((vectorcall))
                        emit_warning(c, decl, "function type has x86 vectorcall calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_X86Pascal:   // __attribute__((pascal))
                        emit_warning(c, decl, "function type has x86 pascal calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_X86_64Win64: // __attribute__((ms_abi))
                        emit_warning(c, decl, "function type has x86 64win64 calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_X86_64SysV:  // __attribute__((sysv_abi))
                        emit_warning(c, decl, "function type has x86 64sysv calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_AAPCS:       // __attribute__((pcs("aapcs")))
                        emit_warning(c, decl, "function type has aapcs calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_AAPCS_VFP:   // __attribute__((pcs("aapcs-vfp")))
                        emit_warning(c, decl, "function type has aapcs-vfp calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_IntelOclBicc: // __attribute__((intel_ocl_bicc))
                        emit_warning(c, decl, "function type has intel_ocl_bicc calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_SpirFunction: // default for OpenCL functions on SPIR target
                        emit_warning(c, decl, "function type has SPIR function calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_SpirKernel:    // inferred for OpenCL kernels on SPIR target
                        emit_warning(c, decl, "function type has SPIR kernel calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                }

                FnTypeId fn_type_id = {0};
                fn_type_id.is_naked = false;
                fn_type_id.is_extern = true;
                fn_type_id.is_var_args = fn_proto_ty->isVariadic();
                fn_type_id.param_count = fn_proto_ty->getNumParams();


                if (fn_proto_ty->getNoReturnAttr()) {
                    fn_type_id.return_type = c->codegen->builtin_types.entry_unreachable;
                } else {
                    fn_type_id.return_type = resolve_qual_type(c, fn_proto_ty->getReturnType(), decl);
                    if (get_underlying_type(fn_type_id.return_type)->id == TypeTableEntryIdInvalid) {
                        emit_warning(c, decl, "unresolved function proto return type");
                        return c->codegen->builtin_types.entry_invalid;
                    }
                    // convert c_void to actual void (only for return type)
                    if (is_c_void_type(c, fn_type_id.return_type)) {
                        fn_type_id.return_type = c->codegen->builtin_types.entry_void;
                    }
                }

                if (fn_type_id.param_count > fn_type_id_prealloc_param_info_count) {
                    fn_type_id.param_info = allocate_nonzero<FnTypeParamInfo>(fn_type_id.param_count);
                } else {
                    fn_type_id.param_info = &fn_type_id.prealloc_param_info[0];
                }

                for (int i = 0; i < fn_type_id.param_count; i += 1) {
                    QualType qt = fn_proto_ty->getParamType(i);
                    TypeTableEntry *param_type = resolve_qual_type(c, qt, decl);

                    if (get_underlying_type(param_type)->id == TypeTableEntryIdInvalid) {
                        emit_warning(c, decl, "unresolved function proto parameter type");
                        return c->codegen->builtin_types.entry_invalid;
                    }

                    FnTypeParamInfo *param_info = &fn_type_id.param_info[i];
                    param_info->type = param_type;
                    param_info->is_noalias = qt.isRestrictQualified();
                }

                return get_fn_type(c->codegen, &fn_type_id);
            }
        case Type::Record:
            {
                const RecordType *record_ty = static_cast<const RecordType*>(ty);
                return resolve_record_decl(c, record_ty->getDecl());
            }
        case Type::Enum:
            {
                const EnumType *enum_ty = static_cast<const EnumType*>(ty);
                return resolve_enum_decl(c, enum_ty->getDecl());
            }
        case Type::ConstantArray:
            {
                const ConstantArrayType *const_arr_ty = static_cast<const ConstantArrayType *>(ty);
                TypeTableEntry *child_type = resolve_qual_type(c, const_arr_ty->getElementType(), decl);
                if (child_type->id == TypeTableEntryIdInvalid) {
                    emit_warning(c, decl, "unresolved array element type");
                    return child_type;
                }
                uint64_t size = const_arr_ty->getSize().getLimitedValue();
                return get_array_type(c->codegen, child_type, size);
            }
        case Type::Paren:
            {
                const ParenType *paren_ty = static_cast<const ParenType *>(ty);
                return resolve_qual_type(c, paren_ty->getInnerType(), decl);
            }
        case Type::Decayed:
            {
                const DecayedType *decayed_ty = static_cast<const DecayedType *>(ty);
                return resolve_qual_type(c, decayed_ty->getDecayedType(), decl);
            }
        case Type::Attributed:
            {
                const AttributedType *attributed_ty = static_cast<const AttributedType *>(ty);
                return resolve_qual_type(c, attributed_ty->getEquivalentType(), decl);
            }
        case Type::BlockPointer:
        case Type::LValueReference:
        case Type::RValueReference:
        case Type::MemberPointer:
        case Type::IncompleteArray:
        case Type::VariableArray:
        case Type::DependentSizedArray:
        case Type::DependentSizedExtVector:
        case Type::Vector:
        case Type::ExtVector:
        case Type::FunctionNoProto:
        case Type::UnresolvedUsing:
        case Type::Adjusted:
        case Type::TypeOfExpr:
        case Type::TypeOf:
        case Type::Decltype:
        case Type::UnaryTransform:
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
        case Type::Pipe:
            emit_warning(c, decl, "missed a '%s' type", ty->getTypeClassName());
            return c->codegen->builtin_types.entry_invalid;
    }
    zig_unreachable();
}

static TypeTableEntry *resolve_qual_type_with_table(Context *c, QualType qt, const Decl *decl,
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> *type_table)
{
    return resolve_type_with_table(c, qt.getTypePtr(), decl, type_table);
}

static TypeTableEntry *resolve_qual_type(Context *c, QualType qt, const Decl *decl) {
    return resolve_qual_type_with_table(c, qt, decl, &c->global_type_table);
}

static void visit_fn_decl(Context *c, const FunctionDecl *fn_decl) {
    Buf *fn_name = buf_create_from_str(decl_name(fn_decl));

    if (c->fn_table.maybe_get(fn_name)) {
        // we already saw this function
        return;
    }

    TypeTableEntry *fn_type = resolve_qual_type(c, fn_decl->getType(), fn_decl);

    if (fn_type->id == TypeTableEntryIdInvalid) {
        emit_warning(c, fn_decl, "ignoring function '%s' - unable to resolve type", buf_ptr(fn_name));
        return;
    }
    assert(fn_type->id == TypeTableEntryIdFn);


    AstNode *node = create_node(c, NodeTypeFnProto);
    node->data.fn_proto.name = fn_name;

    node->data.fn_proto.is_extern = fn_type->data.fn.fn_type_id.is_extern;
    node->data.fn_proto.top_level_decl.visib_mod = c->visib_mod;
    node->data.fn_proto.is_var_args = fn_type->data.fn.fn_type_id.is_var_args;
    node->data.fn_proto.return_type = make_type_node(c, fn_type->data.fn.fn_type_id.return_type);

    assert(!fn_type->data.fn.fn_type_id.is_naked);

    int arg_count = fn_type->data.fn.fn_type_id.param_count;
    Buf name_buf = BUF_INIT;
    for (int i = 0; i < arg_count; i += 1) {
        FnTypeParamInfo *param_info = &fn_type->data.fn.fn_type_id.param_info[i];
        AstNode *type_node = make_type_node(c, param_info->type);
        const ParmVarDecl *param = fn_decl->getParamDecl(i);
        const char *name = decl_name(param);
        if (strlen(name) == 0) {
            buf_resize(&name_buf, 0);
            buf_appendf(&name_buf, "arg%d", i);
            name = buf_ptr(&name_buf);
        }

        node->data.fn_proto.params.append(create_param_decl_node(c, name, type_node, param_info->is_noalias));
    }

    normalize_parent_ptrs(node);

    c->fn_table.put(buf_create_from_buf(fn_name), true);
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

    // if the underlying type is anonymous, we can special case it to just
    // use the name of this typedef
    // TODO

    TypeTableEntry *child_type = resolve_qual_type(c, child_qt, typedef_decl);
    if (child_type->id == TypeTableEntryIdInvalid) {
        emit_warning(c, typedef_decl, "typedef %s - unresolved child type", buf_ptr(type_name));
        return;
    }
    add_const_var_node(c, type_name, child_type);
}

static void add_alias(Context *c, const char *new_name, const char *target_name) {
    AstNode *alias_node = create_var_decl_node(c, new_name, create_symbol_node(c, target_name));
    c->aliases.append(alias_node);
}

static void replace_with_fwd_decl(Context *c, TypeTableEntry *struct_type, Buf *full_type_name) {
    unsigned line = c->source_node ? c->source_node->line : 0;
    LLVMZigDIType *replacement_di_type = LLVMZigCreateDebugForwardDeclType(c->codegen->dbuilder,
        LLVMZigTag_DW_structure_type(), buf_ptr(full_type_name), 
        LLVMZigFileToScope(c->import->di_file), c->import->di_file, line);

    LLVMZigReplaceTemporary(c->codegen->dbuilder, struct_type->di_type, replacement_di_type);
    struct_type->di_type = replacement_di_type;
}

static TypeTableEntry *resolve_enum_decl(Context *c, const EnumDecl *enum_decl) {
    auto existing_entry = c->decl_table.maybe_get((void*)enum_decl);
    if (existing_entry) {
        return existing_entry->value;
    }

    const char *raw_name = decl_name(enum_decl);

    Buf *bare_name;
    if (raw_name[0] == 0) {
        bare_name = buf_sprintf("anon_$%" PRIu32, get_next_node_index(c));
    } else {
        bare_name = buf_create_from_str(raw_name);
    }

    Buf *full_type_name = buf_sprintf("enum_%s", buf_ptr(bare_name));

    const EnumDecl *enum_def = enum_decl->getDefinition();
    if (!enum_def) {
        TypeTableEntry *enum_type = get_partial_container_type(c->codegen, c->import,
                c->import->block_context,
                ContainerKindEnum, c->source_node, buf_ptr(full_type_name));
        c->enum_type_table.put(bare_name, enum_type);
        c->decl_table.put(enum_decl, enum_type);
        replace_with_fwd_decl(c, enum_type, full_type_name);

        return enum_type;
    }

    bool pure_enum = true;
    uint32_t field_count = 0;
    for (auto it = enum_def->enumerator_begin(),
              it_end = enum_def->enumerator_end();
              it != it_end; ++it, field_count += 1)
    {
        const EnumConstantDecl *enum_const = *it;
        if (enum_const->getInitExpr()) {
            pure_enum = false;
        }
    }

    TypeTableEntry *tag_type_entry = resolve_qual_type(c, enum_decl->getIntegerType(), enum_decl);

    if (pure_enum) {
        TypeTableEntry *enum_type = get_partial_container_type(c->codegen, c->import,
                c->import->block_context,
                ContainerKindEnum, c->source_node, buf_ptr(full_type_name));
        c->enum_type_table.put(bare_name, enum_type);
        c->decl_table.put(enum_decl, enum_type);

        enum_type->data.enumeration.gen_field_count = 0;
        enum_type->data.enumeration.complete = true;
        enum_type->data.enumeration.tag_type = tag_type_entry;

        enum_type->data.enumeration.field_count = field_count;
        enum_type->data.enumeration.fields = allocate<TypeEnumField>(field_count);
        LLVMZigDIEnumerator **di_enumerators = allocate<LLVMZigDIEnumerator*>(field_count);

        uint32_t i = 0;
        for (auto it = enum_def->enumerator_begin(),
                it_end = enum_def->enumerator_end();
                it != it_end; ++it, i += 1)
        {
            const EnumConstantDecl *enum_const = *it;

            Buf *enum_val_name = buf_create_from_str(decl_name(enum_const));
            Buf *field_name;
            if (buf_starts_with_buf(enum_val_name, bare_name)) {
                field_name = buf_slice(enum_val_name, buf_len(bare_name), buf_len(enum_val_name));
            } else {
                field_name = enum_val_name;
            }

            TypeEnumField *type_enum_field = &enum_type->data.enumeration.fields[i];
            type_enum_field->name = field_name;
            type_enum_field->type_entry = c->codegen->builtin_types.entry_void;
            type_enum_field->value = i;

            di_enumerators[i] = LLVMZigCreateDebugEnumerator(c->codegen->dbuilder, buf_ptr(type_enum_field->name), i);


            // in C each enum value is in the global namespace. so we put them there too.
            // at this point we can rely on the enum emitting successfully
            AstNode *field_access_node = create_field_access_node(c, buf_ptr(full_type_name), buf_ptr(field_name));
            AstNode *var_node = create_var_decl_node(c, buf_ptr(enum_val_name), field_access_node);
            c->root->data.root.top_level_decls.append(var_node);

            c->global_value_table.put(enum_val_name, {enum_type, true});
        }

        // create llvm type for root struct
        enum_type->type_ref = tag_type_entry->type_ref;

        // create debug type for tag
        unsigned line = c->source_node ? (c->source_node->line + 1) : 0;
        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(c->codegen->target_data_ref, enum_type->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(c->codegen->target_data_ref, enum_type->type_ref);
        LLVMZigDIType *tag_di_type = LLVMZigCreateDebugEnumerationType(c->codegen->dbuilder,
                LLVMZigFileToScope(c->import->di_file), buf_ptr(bare_name),
                c->import->di_file, line,
                debug_size_in_bits,
                debug_align_in_bits,
                di_enumerators, field_count, tag_type_entry->di_type, "");

        LLVMZigReplaceTemporary(c->codegen->dbuilder, enum_type->di_type, tag_di_type);
        enum_type->di_type = tag_di_type;

        return enum_type;
    } else {
        TypeTableEntry *enum_type = get_typedecl_type(c->codegen, buf_ptr(full_type_name), tag_type_entry);
        c->enum_type_table.put(bare_name, enum_type);
        c->decl_table.put(enum_decl, enum_type);

        // add variables for all the values with enum_type
        for (auto it = enum_def->enumerator_begin(),
                it_end = enum_def->enumerator_end();
                it != it_end; ++it)
        {
            const EnumConstantDecl *enum_const = *it;
            AstNode *num_lit_node = create_ap_num_lit_node(c, enum_decl, enum_const->getInitVal());
            if (!num_lit_node) {
                return c->codegen->builtin_types.entry_invalid;
            }

            Buf *enum_val_name = buf_create_from_str(decl_name(enum_const));

            AstNode *type_node = make_type_node(c, enum_type);
            AstNode *var_decl_node = create_typed_var_decl_node(c, true, buf_ptr(enum_val_name),
                    type_node, num_lit_node);

            c->root->data.root.top_level_decls.append(var_decl_node);
            c->global_value_table.put(enum_val_name, {enum_type, true});

        }

        return enum_type;
    }
}

static void visit_enum_decl(Context *c, const EnumDecl *enum_decl) {
    TypeTableEntry *enum_type = resolve_enum_decl(c, enum_decl);

    if (enum_type->id == TypeTableEntryIdInvalid) {
        return;
    }

    // make an alias without the "enum_" prefix. this will get emitted at the
    // end if it doesn't conflict with anything else
    if (decl_name(enum_decl)[0] != 0) {
        add_alias(c, decl_name(enum_decl), buf_ptr(&enum_type->name));
    }

    if (enum_type->id == TypeTableEntryIdEnum) {
        if (enum_type->data.enumeration.complete) {
            // now create top level decl for the type
            AstNode *enum_node = create_node(c, NodeTypeContainerDecl);
            enum_node->data.struct_decl.name = &enum_type->name;
            enum_node->data.struct_decl.kind = ContainerKindEnum;
            enum_node->data.struct_decl.top_level_decl.visib_mod = VisibModExport;
            enum_node->data.struct_decl.type_entry = enum_type;

            for (uint32_t i = 0; i < enum_type->data.enumeration.field_count; i += 1) {
                TypeEnumField *type_enum_field = &enum_type->data.enumeration.fields[i];
                AstNode *type_node = make_type_node(c, type_enum_field->type_entry);
                AstNode *field_node = create_struct_field_node(c, buf_ptr(type_enum_field->name), type_node);
                enum_node->data.struct_decl.fields.append(field_node);
            }

            normalize_parent_ptrs(enum_node);
            c->root->data.root.top_level_decls.append(enum_node);
        } else {
            TypeTableEntry *typedecl_type = get_typedecl_type(c->codegen, buf_ptr(&enum_type->name),
                    c->codegen->builtin_types.entry_u8);
            add_typedef_node(c, typedecl_type);
        }
    } else if (enum_type->id == TypeTableEntryIdTypeDecl) {
        add_typedef_node(c, enum_type);
    } else {
        zig_unreachable();
    }
}

static TypeTableEntry *resolve_record_decl(Context *c, const RecordDecl *record_decl) {
    auto existing_entry = c->decl_table.maybe_get((void*)record_decl);
    if (existing_entry) {
        return existing_entry->value;
    }

    const char *raw_name = decl_name(record_decl);

    if (!record_decl->isStruct()) {
        emit_warning(c, record_decl, "skipping record %s, not a struct", raw_name);
        return c->codegen->builtin_types.entry_invalid;
    }

    Buf *bare_name;
    if (record_decl->isAnonymousStructOrUnion() || raw_name[0] == 0) {
        bare_name = buf_sprintf("anon_$%" PRIu32, get_next_node_index(c));
    } else {
        bare_name = buf_create_from_str(raw_name);
    }

    Buf *full_type_name = buf_sprintf("struct_%s", buf_ptr(bare_name));


    TypeTableEntry *struct_type = get_partial_container_type(c->codegen, c->import,
            c->import->block_context, ContainerKindStruct, c->source_node, buf_ptr(full_type_name));

    c->struct_type_table.put(bare_name, struct_type);
    c->decl_table.put(record_decl, struct_type);

    RecordDecl *record_def = record_decl->getDefinition();
    unsigned line = c->source_node ? c->source_node->line : 0;
    if (!record_def) {
        replace_with_fwd_decl(c, struct_type, full_type_name);
        return struct_type;
    }


    // count fields and validate
    uint32_t field_count = 0;
    for (auto it = record_def->field_begin(),
              it_end = record_def->field_end();
              it != it_end; ++it, field_count += 1)
    {
        const FieldDecl *field_decl = *it;

        if (field_decl->isBitField()) {
            emit_warning(c, field_decl, "struct %s demoted to typedef - has bitfield\n", buf_ptr(bare_name));
            replace_with_fwd_decl(c, struct_type, full_type_name);
            return struct_type;
        }
    }

    struct_type->data.structure.src_field_count = field_count;
    struct_type->data.structure.fields = allocate<TypeStructField>(field_count);
    LLVMTypeRef *element_types = allocate<LLVMTypeRef>(field_count);
    LLVMZigDIType **di_element_types = allocate<LLVMZigDIType*>(field_count);

    // next, populate element_types as its needed for LLVMStructSetBody which is needed for LLVMOffsetOfElement
    uint32_t i = 0;
    for (auto it = record_def->field_begin(),
              it_end = record_def->field_end();
              it != it_end; ++it, i += 1)
    {
        const FieldDecl *field_decl = *it;

        TypeStructField *type_struct_field = &struct_type->data.structure.fields[i];
        type_struct_field->name = buf_create_from_str(decl_name(field_decl));
        type_struct_field->src_index = i;
        type_struct_field->gen_index = i;
        TypeTableEntry *field_type = resolve_qual_type(c, field_decl->getType(), field_decl);
        type_struct_field->type_entry = field_type;

        if (field_type->id == TypeTableEntryIdInvalid) {
            emit_warning(c, field_decl, "struct %s demoted to typedef - unresolved type\n", buf_ptr(bare_name));
            replace_with_fwd_decl(c, struct_type, full_type_name);
            return struct_type;
        }

        element_types[i] = field_type->type_ref;
        assert(element_types[i]);
    }

    LLVMStructSetBody(struct_type->type_ref, element_types, field_count, false);

    // finally populate debug info
    i = 0;
    for (auto it = record_def->field_begin(),
              it_end = record_def->field_end();
              it != it_end; ++it, i += 1)
    {
        TypeStructField *type_struct_field = &struct_type->data.structure.fields[i];
        TypeTableEntry *field_type = type_struct_field->type_entry;

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(c->codegen->target_data_ref, field_type->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(c->codegen->target_data_ref, field_type->type_ref);
        uint64_t debug_offset_in_bits = 8*LLVMOffsetOfElement(c->codegen->target_data_ref, struct_type->type_ref, i);
        di_element_types[i] = LLVMZigCreateDebugMemberType(c->codegen->dbuilder,
                LLVMZigTypeToScope(struct_type->di_type), buf_ptr(type_struct_field->name),
                c->import->di_file, line + 1,
                debug_size_in_bits,
                debug_align_in_bits,
                debug_offset_in_bits,
                0, field_type->di_type);

        assert(di_element_types[i]);

    }
    struct_type->data.structure.embedded_in_current = false;

    struct_type->data.structure.gen_field_count = field_count;
    struct_type->data.structure.complete = true;

    uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(c->codegen->target_data_ref, struct_type->type_ref);
    uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(c->codegen->target_data_ref, struct_type->type_ref);
    LLVMZigDIType *replacement_di_type = LLVMZigCreateDebugStructType(c->codegen->dbuilder,
            LLVMZigFileToScope(c->import->di_file),
            buf_ptr(full_type_name), c->import->di_file, line + 1,
            debug_size_in_bits,
            debug_align_in_bits,
            0,
            nullptr, di_element_types, field_count, 0, nullptr, "");

    LLVMZigReplaceTemporary(c->codegen->dbuilder, struct_type->di_type, replacement_di_type);
    struct_type->di_type = replacement_di_type;

    return struct_type;
}

static void visit_record_decl(Context *c, const RecordDecl *record_decl) {
    TypeTableEntry *struct_type = resolve_record_decl(c, record_decl);

    if (struct_type->id == TypeTableEntryIdInvalid) {
        return;
    }

    assert(struct_type->id == TypeTableEntryIdStruct);

    if (c->struct_decl_table.maybe_get(&struct_type->name)) {
        return;
    }
    c->struct_decl_table.put(&struct_type->name, struct_type);

    // make an alias without the "struct_" prefix. this will get emitted at the
    // end if it doesn't conflict with anything else
    if (decl_name(record_decl)[0] != 0) {
        add_alias(c, decl_name(record_decl), buf_ptr(&struct_type->name));
    }

    if (struct_type->data.structure.complete) {
        // now create a top level decl node for the type
        AstNode *struct_node = create_node(c, NodeTypeContainerDecl);
        struct_node->data.struct_decl.name = &struct_type->name;
        struct_node->data.struct_decl.kind = ContainerKindStruct;
        struct_node->data.struct_decl.top_level_decl.visib_mod = VisibModExport;
        struct_node->data.struct_decl.type_entry = struct_type;

        for (uint32_t i = 0; i < struct_type->data.structure.src_field_count; i += 1) {
            TypeStructField *type_struct_field = &struct_type->data.structure.fields[i];
            AstNode *type_node = make_type_node(c, type_struct_field->type_entry);
            AstNode *field_node = create_struct_field_node(c, buf_ptr(type_struct_field->name), type_node);
            struct_node->data.struct_decl.fields.append(field_node);
        }

        normalize_parent_ptrs(struct_node);
        c->root->data.root.top_level_decls.append(struct_node);
    } else {
        TypeTableEntry *typedecl_type = get_typedecl_type(c->codegen, buf_ptr(&struct_type->name),
                c->codegen->builtin_types.entry_u8);
        add_typedef_node(c, typedecl_type);
    }
}

static void visit_var_decl(Context *c, const VarDecl *var_decl) {
    Buf *name = buf_create_from_str(decl_name(var_decl));

    switch (var_decl->getTLSKind()) {
        case VarDecl::TLS_None:
            break;
        case VarDecl::TLS_Static:
            emit_warning(c, var_decl, "ignoring variable '%s' - static thread local storage\n", buf_ptr(name));
            return;
        case VarDecl::TLS_Dynamic:
            emit_warning(c, var_decl, "ignoring variable '%s' - dynamic thread local storage\n", buf_ptr(name));
            return;
    }

    QualType qt = var_decl->getType();
    TypeTableEntry *var_type = resolve_qual_type(c, qt, var_decl);
    if (var_type->id == TypeTableEntryIdInvalid) {
        emit_warning(c, var_decl, "ignoring variable '%s' - unresolved type\n", buf_ptr(name));
        return;
    }

    bool is_extern = var_decl->hasExternalStorage();
    bool is_static = var_decl->isFileVarDecl();
    bool is_const = qt.isConstQualified();

    if (is_static && !is_extern) {
        if (!var_decl->hasInit()) {
            emit_warning(c, var_decl, "ignoring variable '%s' - no initializer\n", buf_ptr(name));
            return;
        }
        APValue *ap_value = var_decl->evaluateValue();
        if (!ap_value) {
            emit_warning(c, var_decl, "ignoring variable '%s' - unable to evaluate initializer\n", buf_ptr(name));
            return;
        }
        AstNode *init_node;
        switch (ap_value->getKind()) {
            case APValue::Int:
                {
                    TypeTableEntry *canon_type = get_underlying_type(var_type);
                    if (canon_type->id != TypeTableEntryIdInt) {
                        emit_warning(c, var_decl,
                            "ignoring variable '%s' - int initializer for non int type\n", buf_ptr(name));
                        return;
                    }
                    init_node = create_ap_num_lit_node(c, var_decl, ap_value->getInt());
                    if (!init_node) {
                        return;
                    }
                    break;
                }
            case APValue::Uninitialized:
            case APValue::Float:
            case APValue::ComplexInt:
            case APValue::ComplexFloat:
            case APValue::LValue:
            case APValue::Vector:
            case APValue::Array:
            case APValue::Struct:
            case APValue::Union:
            case APValue::MemberPointer:
            case APValue::AddrLabelDiff:
                emit_warning(c, var_decl,
                        "ignoring variable '%s' - unrecognized initializer value kind\n", buf_ptr(name));
                return;
        }

        AstNode *type_node = make_type_node(c, var_type);
        AstNode *var_node = create_typed_var_decl_node(c, true, buf_ptr(name), type_node, init_node);
        c->root->data.root.top_level_decls.append(var_node);
        c->global_value_table.put(name, {var_type, true});
        return;
    }

    if (is_extern) {
        AstNode *type_node = make_type_node(c, var_type);
        AstNode *var_node = create_typed_var_decl_node(c, is_const, buf_ptr(name), type_node, nullptr);
        var_node->data.variable_declaration.is_extern = true;
        c->root->data.root.top_level_decls.append(var_node);
        c->global_value_table.put(name, {var_type, is_const});
        return;
    }

    emit_warning(c, var_decl, "ignoring variable '%s' - non-extern, non-static variable\n", buf_ptr(name));
    return;
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
        case Decl::Var:
            visit_var_decl(c, static_cast<const VarDecl *>(decl));
            break;
        default:
            emit_warning(c, decl, "ignoring %s decl\n", decl->getDeclKindName());
    }

    return true;
}

static bool name_exists(Context *c, Buf *name) {
    if (c->global_type_table.maybe_get(name)) {
        return true;
    }
    if (c->global_value_table.maybe_get(name)) {
        return true;
    }
    if (c->fn_table.maybe_get(name)) {
        return true;
    }
    if (c->macro_table.maybe_get(name)) {
        return true;
    }
    return false;
}

static bool name_exists_and_const(Context *c, Buf *name) {
    if (c->global_type_table.maybe_get(name)) {
        return true;
    }
    if (c->fn_table.maybe_get(name)) {
        return true;
    }
    if (c->macro_table.maybe_get(name)) {
        return true;
    }
    if (auto entry = c->global_value_table.maybe_get(name)) {
        return entry->value.is_const;
    }
    return false;
}

static void render_aliases(Context *c) {
    for (int i = 0; i < c->aliases.length; i += 1) {
        AstNode *alias_node = c->aliases.at(i);
        assert(alias_node->type == NodeTypeVariableDeclaration);
        Buf *name = alias_node->data.variable_declaration.symbol;
        if (name_exists(c, name)) {
            continue;
        }
        c->root->data.root.top_level_decls.append(alias_node);
    }
}

static void render_macros(Context *c) {
    auto it = c->macro_table.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        AstNode *var_node = entry->value;
        c->root->data.root.top_level_decls.append(var_node);
    }
}

static void process_macro(Context *c, CTokenize *ctok, Buf *name, const char *char_ptr) {
    tokenize_c_macro(ctok, (const uint8_t *)char_ptr);

    if (ctok->error) {
        return;
    }

    bool negate = false;
    for (int i = 0; i < ctok->tokens.length; i += 1) {
        bool is_first = (i == 0);
        bool is_last = (i == ctok->tokens.length - 1);
        CTok *tok = &ctok->tokens.at(i);
        switch (tok->id) {
            case CTokIdCharLit:
                if (is_last && is_first) {
                    AstNode *var_node = create_var_decl_node(c, buf_ptr(name),
                            create_char_lit_node(c, tok->data.char_lit));
                    c->macro_table.put(name, var_node);
                }
                return;
            case CTokIdStrLit:
                if (is_last && is_first) {
                    AstNode *var_node = create_var_decl_node(c, buf_ptr(name),
                            create_str_lit_node(c, buf_create_from_buf(&tok->data.str_lit)));
                    c->macro_table.put(name, var_node);
                }
                return;
            case CTokIdNumLitInt:
                if (is_last) {
                    AstNode *var_node = create_var_decl_node(c, buf_ptr(name),
                            create_num_lit_unsigned_negative(c, tok->data.num_lit_int, negate));
                    c->macro_table.put(name, var_node);
                }
                return;
            case CTokIdNumLitFloat:
                if (is_last) {
                    AstNode *var_node = create_var_decl_node(c, buf_ptr(name),
                            create_num_lit_float_negative(c, tok->data.num_lit_float, negate));
                    c->macro_table.put(name, var_node);
                }
                return;
            case CTokIdSymbol:
                if (is_last && is_first) {
                    // if it equals itself, ignore. for example, from stdio.h:
                    // #define stdin stdin
                    Buf *symbol_name = buf_create_from_buf(&tok->data.symbol);
                    if (buf_eql_buf(name, symbol_name)) {
                        return;
                    }
                    c->macro_symbols.append({name, symbol_name});
                    return;
                }
            case CTokIdMinus:
                if (is_first) {
                    negate = true;
                    break;
                } else {
                    return;
                }
        }
    }
}

static void process_symbol_macros(Context *c) {
    for (int i = 0; i < c->macro_symbols.length; i += 1) {
        MacroSymbol ms = c->macro_symbols.at(i);
        if (name_exists_and_const(c, ms.value)) {
            AstNode *var_node = create_var_decl_node(c, buf_ptr(ms.name),
                    create_symbol_node(c, buf_ptr(ms.value)));
            c->macro_table.put(ms.name, var_node);
        } else if (c->transform_extern_fn_ptr || true) { // TODO take off the || true
            if (auto entry = c->global_value_table.maybe_get(ms.value)) {
                TypeTableEntry *maybe_type = entry->value.type;
                if (maybe_type->id == TypeTableEntryIdMaybe) {
                    TypeTableEntry *fn_type = maybe_type->data.maybe.child_type;
                    if (fn_type->id == TypeTableEntryIdFn) {
                        AstNode *fn_node = create_inline_fn_node(c, ms.name, ms.value, fn_type);
                        c->macro_table.put(ms.name, fn_node);
                    }
                }
            }
        }
    }
}

static void process_preprocessor_entities(Context *c, ASTUnit &unit) {
    CTokenize ctok = {{0}};

    for (PreprocessedEntity *entity : unit.getLocalPreprocessingEntities()) {
        switch (entity->getKind()) {
            case PreprocessedEntity::InvalidKind:
            case PreprocessedEntity::InclusionDirectiveKind:
            case PreprocessedEntity::MacroExpansionKind:
                continue;
            case PreprocessedEntity::MacroDefinitionKind:
                {
                    MacroDefinitionRecord *macro = static_cast<MacroDefinitionRecord *>(entity);
                    const char *raw_name = macro->getName()->getNameStart();
                    SourceRange range = macro->getSourceRange();
                    SourceLocation begin_loc = range.getBegin();
                    SourceLocation end_loc = range.getEnd();

                    if (begin_loc == end_loc) {
                        // this means it is a macro without a value
                        // we don't care about such things
                        continue;
                    }
                    Buf *name = buf_create_from_str(raw_name);
                    if (name_exists(c, name)) {
                        continue;
                    }

                    const char *end_c = c->source_manager->getCharacterData(end_loc);
                    process_macro(c, &ctok, name, end_c);
                }
        }
    }
}

int parse_h_buf(ImportTableEntry *import, ZigList<ErrorMsg *> *errors, Buf *source,
        CodeGen *codegen, AstNode *source_node)
{
    int err;
    Buf tmp_file_path = BUF_INIT;
    if ((err = os_buf_to_tmp_file(source, buf_create_from_str(".h"), &tmp_file_path))) {
        return err;
    }

    err = parse_h_file(import, errors, buf_ptr(&tmp_file_path), codegen, source_node);

    os_delete_file(&tmp_file_path);

    return err;
}

int parse_h_file(ImportTableEntry *import, ZigList<ErrorMsg *> *errors, const char *target_file,
        CodeGen *codegen, AstNode *source_node)
{
    Context context = {0};
    Context *c = &context;
    c->warnings_on = codegen->verbose;
    c->import = import;
    c->errors = errors;
    c->visib_mod = VisibModPub;
    c->global_type_table.init(8);
    c->global_value_table.init(8);
    c->enum_type_table.init(8);
    c->struct_type_table.init(8);
    c->struct_decl_table.init(8);
    c->decl_table.init(8);
    c->fn_table.init(8);
    c->macro_table.init(8);
    c->codegen = codegen;
    c->source_node = source_node;

    ZigList<const char *> clang_argv = {0};

    clang_argv.append("-x");
    clang_argv.append("c");

    if (c->codegen->is_native_target) {
        char *ZIG_PARSEH_CFLAGS = getenv("ZIG_NATIVE_PARSEH_CFLAGS");
        if (ZIG_PARSEH_CFLAGS) {
            Buf tmp_buf = BUF_INIT;
            char *start = ZIG_PARSEH_CFLAGS;
            char *space = strstr(start, " ");
            while (space) {
                if (space - start > 0) {
                    buf_init_from_mem(&tmp_buf, start, space - start);
                    clang_argv.append(buf_ptr(buf_create_from_buf(&tmp_buf)));
                }
                start = space + 1;
                space = strstr(start, " ");
            }
            buf_init_from_str(&tmp_buf, start);
            clang_argv.append(buf_ptr(buf_create_from_buf(&tmp_buf)));
        }
    }

    clang_argv.append("-isystem");
    clang_argv.append(ZIG_HEADERS_DIR);

    clang_argv.append("-isystem");
    clang_argv.append(buf_ptr(codegen->libc_include_dir));

    for (int i = 0; i < codegen->clang_argv_len; i += 1) {
        clang_argv.append(codegen->clang_argv[i]);
    }

    // we don't need spell checking and it slows things down
    clang_argv.append("-fno-spell-checking");

    // this gives us access to preprocessing entities, presumably at
    // the cost of performance
    clang_argv.append("-Xclang");
    clang_argv.append("-detailed-preprocessing-record");

    if (!c->codegen->is_native_target) {
        clang_argv.append("-target");
        clang_argv.append(buf_ptr(&c->codegen->triple_str));
    }

    clang_argv.append(target_file);

    // to make the [start...end] argument work
    clang_argv.append(nullptr);

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
            &clang_argv.at(0), &clang_argv.last(),
            pch_container_ops, diags, resources_path,
            only_local_decls, capture_diagnostics, None, true, 0, TU_Complete,
            false, false, allow_pch_with_compiler_errors, skip_function_bodies,
            user_files_are_volatile, false, None, &err_unit));


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
            Buf *path;
            if (filename.empty()) {
                path = buf_alloc();
            } else {
                path = buf_create_from_mem((const char *)filename.bytes_begin(), filename.size());
            }

            ErrorMsg *err_msg = err_msg_create_with_offset(path, line, column, offset, source, msg);

            c->errors->append(err_msg);
        }

        return 0;
    }

    c->source_manager = &ast_unit->getSourceManager();

    c->root = create_node(c, NodeTypeRoot);
    ast_unit->visitLocalTopLevelDecls(c, decl_visitor);

    process_preprocessor_entities(c, *ast_unit);

    process_symbol_macros(c);

    render_macros(c);
    render_aliases(c);

    normalize_parent_ptrs(c->root);
    import->root = c->root;

    return 0;
}
