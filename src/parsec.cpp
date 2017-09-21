/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "all_types.hpp"
#include "analyze.hpp"
#include "c_tokenizer.hpp"
#include "config.h"
#include "error.hpp"
#include "ir.hpp"
#include "os.hpp"
#include "parsec.hpp"
#include "parser.hpp"


#include <clang/Frontend/ASTUnit.h>
#include <clang/Frontend/CompilerInstance.h>
#include <clang/AST/Expr.h>

#include <string.h>

using namespace clang;

struct MacroSymbol {
    Buf *name;
    Buf *value;
};

struct Alias {
    Buf *new_name;
    Buf *canon_name;
};

struct Context {
    ImportTableEntry *import;
    ZigList<ErrorMsg *> *errors;
    bool warnings_on;
    VisibMod visib_mod;
    AstNode *root;
    HashMap<const void *, AstNode *, ptr_hash, ptr_eq> decl_table;
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> macro_table;
    SourceManager *source_manager;
    ZigList<Alias> aliases;
    ZigList<MacroSymbol> macro_symbols;
    AstNode *source_node;

    CodeGen *codegen;
    ASTContext *ctx;

    HashMap<Buf *, bool, buf_hash, buf_eql_buf> ptr_params;
};

static AstNode *resolve_record_decl(Context *c, const RecordDecl *record_decl);
static AstNode *resolve_enum_decl(Context *c, const EnumDecl *enum_decl);
static AstNode *resolve_typedef_decl(Context *c, const TypedefNameDecl *typedef_decl);


ATTRIBUTE_PRINTF(3, 4)
static void emit_warning(Context *c, const SourceLocation &sl, const char *format, ...) {
    if (!c->warnings_on) {
        return;
    }

    va_list ap;
    va_start(ap, format);
    Buf *msg = buf_vprintf(format, ap);
    va_end(ap);

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

static void add_global_weak_alias(Context *c, Buf *new_name, Buf *canon_name) {
    Alias *alias = c->aliases.add_one();
    alias->new_name = new_name;
    alias->canon_name = canon_name;
}

static AstNode * trans_create_node(Context *c, NodeType id) {
    AstNode *node = allocate<AstNode>(1);
    node->type = id;
    node->owner = c->import;
    // TODO line/column. mapping to C file??
    return node;
}

static AstNode *trans_create_node_float_lit(Context *c, double value) {
    AstNode *node = trans_create_node(c, NodeTypeFloatLiteral);
    node->data.float_literal.bigfloat = allocate<BigFloat>(1);
    bigfloat_init_64(node->data.float_literal.bigfloat, value);
    return node;
}

static AstNode *trans_create_node_symbol(Context *c, Buf *name) {
    AstNode *node = trans_create_node(c, NodeTypeSymbol);
    node->data.symbol_expr.symbol = name;
    return node;
}

static AstNode *trans_create_node_symbol_str(Context *c, const char *name) {
    return trans_create_node_symbol(c, buf_create_from_str(name));
}

static AstNode *trans_create_node_builtin_fn_call(Context *c, Buf *name) {
    AstNode *node = trans_create_node(c, NodeTypeFnCallExpr);
    node->data.fn_call_expr.fn_ref_expr = trans_create_node_symbol(c, name);
    node->data.fn_call_expr.is_builtin = true;
    return node;
}

static AstNode *trans_create_node_builtin_fn_call_str(Context *c, const char *name) {
    return trans_create_node_builtin_fn_call(c, buf_create_from_str(name));
}

static AstNode *trans_create_node_opaque(Context *c) {
    return trans_create_node_builtin_fn_call_str(c, "OpaqueType");
}

static AstNode *trans_create_node_fn_call_1(Context *c, AstNode *fn_ref_expr, AstNode *arg1) {
    AstNode *node = trans_create_node(c, NodeTypeFnCallExpr);
    node->data.fn_call_expr.fn_ref_expr = fn_ref_expr;
    node->data.fn_call_expr.params.append(arg1);
    return node;
}

static AstNode *trans_create_node_field_access(Context *c, AstNode *container, Buf *field_name) {
    AstNode *node = trans_create_node(c, NodeTypeFieldAccessExpr);
	if (container->type == NodeTypeSymbol) {
		assert(container->data.symbol_expr.symbol != nullptr);
	}
    node->data.field_access_expr.struct_expr = container;
    node->data.field_access_expr.field_name = field_name;
    return node;
}

static AstNode *trans_create_node_field_access_str(Context *c, AstNode *container, const char *field_name) {
    return trans_create_node_field_access(c, container, buf_create_from_str(field_name));
}

static AstNode *trans_create_node_prefix_op(Context *c, PrefixOp op, AstNode *child_node) {
    AstNode *node = trans_create_node(c, NodeTypePrefixOpExpr);
    node->data.prefix_op_expr.prefix_op = op;
    node->data.prefix_op_expr.primary_expr = child_node;
    return node;
}

static AstNode *trans_create_node_bin_op(Context *c, AstNode *lhs_node, BinOpType op, AstNode *rhs_node) {
    AstNode *node = trans_create_node(c, NodeTypeBinOpExpr);
    node->data.bin_op_expr.op1 = lhs_node;
    node->data.bin_op_expr.bin_op = op;
    node->data.bin_op_expr.op2 = rhs_node;
    return node;
}

static AstNode *maybe_suppress_result(Context *c, bool result_used, AstNode *node) {
    if (result_used) return node;
    return trans_create_node_bin_op(c,
        trans_create_node_symbol_str(c, "_"),
        BinOpTypeAssign,
        node);
}

static AstNode *trans_create_node_addr_of(Context *c, bool is_const, bool is_volatile, AstNode *child_node) {
    AstNode *node = trans_create_node(c, NodeTypeAddrOfExpr);
    node->data.addr_of_expr.is_const = is_const;
    node->data.addr_of_expr.is_volatile = is_volatile;
    node->data.addr_of_expr.op_expr = child_node;
    return node;
}

static AstNode *trans_create_node_str_lit_c(Context *c, Buf *buf) {
    AstNode *node = trans_create_node(c, NodeTypeStringLiteral);
    node->data.string_literal.buf = buf;
    node->data.string_literal.c = true;
    return node;
}

static AstNode *trans_create_node_str_lit_non_c(Context *c, Buf *buf) {
    AstNode *node = trans_create_node(c, NodeTypeStringLiteral);
    node->data.string_literal.buf = buf;
    node->data.string_literal.c = false;
    return node;
}

static AstNode *trans_create_node_unsigned_negative(Context *c, uint64_t x, bool is_negative) {
    AstNode *node = trans_create_node(c, NodeTypeIntLiteral);
    node->data.int_literal.bigint = allocate<BigInt>(1);
    bigint_init_data(node->data.int_literal.bigint, &x, 1, is_negative);
    return node;
}

static AstNode *trans_create_node_unsigned(Context *c, uint64_t x) {
    return trans_create_node_unsigned_negative(c, x, false);
}

static AstNode *trans_create_node_cast(Context *c, AstNode *dest, AstNode *src) {
    AstNode *node = trans_create_node(c, NodeTypeFnCallExpr);
    node->data.fn_call_expr.fn_ref_expr = dest;
    node->data.fn_call_expr.params.resize(1);
    node->data.fn_call_expr.params.items[0] = src;
    return node;
}

static AstNode *trans_create_node_unsigned_negative_type(Context *c, uint64_t x, bool is_negative,
        const char *type_name)
{
    AstNode *lit_node = trans_create_node_unsigned_negative(c, x, is_negative);
    return trans_create_node_cast(c, trans_create_node_symbol_str(c, type_name), lit_node);
}

static AstNode *trans_create_node_array_type(Context *c, AstNode *size_node, AstNode *child_type_node) {
    AstNode *node = trans_create_node(c, NodeTypeArrayType);
    node->data.array_type.size = size_node;
    node->data.array_type.child_type = child_type_node;
    return node;
}

static AstNode *trans_create_node_var_decl(Context *c, VisibMod visib_mod, bool is_const, Buf *var_name,
        AstNode *type_node, AstNode *init_node)
{
    AstNode *node = trans_create_node(c, NodeTypeVariableDeclaration);
    node->data.variable_declaration.visib_mod = visib_mod;
    node->data.variable_declaration.symbol = var_name;
    node->data.variable_declaration.is_const = is_const;
    node->data.variable_declaration.type = type_node;
    node->data.variable_declaration.expr = init_node;
    return node;
}

static AstNode *trans_create_node_var_decl_global(Context *c, bool is_const, Buf *var_name, AstNode *type_node,
        AstNode *init_node)
{
    return trans_create_node_var_decl(c, c->visib_mod, is_const, var_name, type_node, init_node);
}

static AstNode *trans_create_node_var_decl_local(Context *c, bool is_const, Buf *var_name, AstNode *type_node,
        AstNode *init_node)
{
    return trans_create_node_var_decl(c, VisibModPrivate, is_const, var_name, type_node, init_node);
}


static AstNode *trans_create_node_inline_fn(Context *c, Buf *fn_name, Buf *var_name, AstNode *src_proto_node) {
    AstNode *fn_def = trans_create_node(c, NodeTypeFnDef);
    AstNode *fn_proto = trans_create_node(c, NodeTypeFnProto);
    fn_proto->data.fn_proto.visib_mod = c->visib_mod;
    fn_proto->data.fn_proto.name = fn_name;
    fn_proto->data.fn_proto.is_inline = true;
    fn_proto->data.fn_proto.return_type = src_proto_node->data.fn_proto.return_type; // TODO ok for these to alias?

    fn_def->data.fn_def.fn_proto = fn_proto;
    fn_proto->data.fn_proto.fn_def_node = fn_def;

    AstNode *unwrap_node = trans_create_node_prefix_op(c, PrefixOpUnwrapMaybe, trans_create_node_symbol(c, var_name));
    AstNode *fn_call_node = trans_create_node(c, NodeTypeFnCallExpr);
    fn_call_node->data.fn_call_expr.fn_ref_expr = unwrap_node;

    for (size_t i = 0; i < src_proto_node->data.fn_proto.params.length; i += 1) {
        AstNode *src_param_node = src_proto_node->data.fn_proto.params.at(i);
        Buf *param_name = src_param_node->data.param_decl.name;
        if (!param_name) param_name = buf_sprintf("arg%" ZIG_PRI_usize "", i);

        AstNode *dest_param_node = trans_create_node(c, NodeTypeParamDecl);
        dest_param_node->data.param_decl.name = param_name;
        dest_param_node->data.param_decl.type = src_param_node->data.param_decl.type;
        dest_param_node->data.param_decl.is_noalias = src_param_node->data.param_decl.is_noalias;
        fn_proto->data.fn_proto.params.append(dest_param_node);

        fn_call_node->data.fn_call_expr.params.append(trans_create_node_symbol(c, param_name));

    }

    AstNode *block = trans_create_node(c, NodeTypeBlock);
    block->data.block.statements.resize(1);
    block->data.block.statements.items[0] = fn_call_node;
    block->data.block.last_statement_is_result_expression = true;

    fn_def->data.fn_def.body = block;
    return fn_def;
}

static AstNode *trans_create_node_unwrap_null(Context *c, AstNode *child) {
    return trans_create_node_prefix_op(c, PrefixOpUnwrapMaybe, child);
}

static AstNode *get_global(Context *c, Buf *name) {
    for (size_t i = 0; i < c->root->data.root.top_level_decls.length; i += 1) {
        AstNode *decl_node = c->root->data.root.top_level_decls.items[i];
        if (decl_node->type == NodeTypeVariableDeclaration) {
            if (buf_eql_buf(decl_node->data.variable_declaration.symbol, name)) {
                return decl_node;
            }
        } else if (decl_node->type == NodeTypeFnDef) {
            if (buf_eql_buf(decl_node->data.fn_def.fn_proto->data.fn_proto.name, name)) {
                return decl_node;
            }
        } else if (decl_node->type == NodeTypeFnProto) {
            if (buf_eql_buf(decl_node->data.fn_proto.name, name)) {
                return decl_node;
            }
        }
    }
    {
        auto entry = c->macro_table.maybe_get(name);
        if (entry)
            return entry->value;
    }
    return nullptr;
}

static AstNode *add_global_var(Context *c, Buf *var_name, AstNode *value_node) {
    bool is_const = true;
    AstNode *type_node = nullptr;
    AstNode *node = trans_create_node_var_decl_global(c, is_const, var_name, type_node, value_node);
    c->root->data.root.top_level_decls.append(node);
    return node;
}

static const char *decl_name(const Decl *decl) {
    const NamedDecl *named_decl = static_cast<const NamedDecl *>(decl);
    return (const char *)named_decl->getName().bytes_begin();
}

static AstNode *trans_create_node_apint(Context *c, const llvm::APSInt &aps_int) {
    AstNode *node = trans_create_node(c, NodeTypeIntLiteral);
    node->data.int_literal.bigint = allocate<BigInt>(1);
    bigint_init_data(node->data.int_literal.bigint, aps_int.getRawData(), aps_int.getNumWords(), aps_int.isNegative());
    return node;

}

static AstNode *trans_qual_type(Context *c, QualType qt, const SourceLocation &source_loc);

static bool is_c_void_type(AstNode *node) {
    return (node->type == NodeTypeSymbol && buf_eql_str(node->data.symbol_expr.symbol, "c_void"));
}

static AstNode* trans_c_cast(Context *c, const SourceLocation &source_location, const QualType &qt, AstNode *expr) {
    // TODO: maybe widen to increase size
    // TODO: maybe bitcast to change sign
    // TODO: maybe truncate to reduce size
    return trans_create_node_fn_call_1(c, trans_qual_type(c, qt, source_location), expr);
}

static uint32_t qual_type_int_bit_width(Context *c, const QualType &qt, const SourceLocation &source_loc) {
    const Type *ty = qt.getTypePtr();
    switch (ty->getTypeClass()) {
        case Type::Builtin:
            {
                const BuiltinType *builtin_ty = static_cast<const BuiltinType*>(ty);
                switch (builtin_ty->getKind()) {
                    case BuiltinType::Char_U:
                    case BuiltinType::UChar:
                    case BuiltinType::Char_S:
                    case BuiltinType::SChar:
                        return 8;
                    case BuiltinType::UInt128:
                    case BuiltinType::Int128:
                        return 128;
                    default:
                        return 0;
                }
                zig_unreachable();
            }
        case Type::Typedef:
            {
                const TypedefType *typedef_ty = static_cast<const TypedefType*>(ty);
                const TypedefNameDecl *typedef_decl = typedef_ty->getDecl();
                const char *type_name = decl_name(typedef_decl);
                if (strcmp(type_name, "uint8_t") == 0 || strcmp(type_name, "int8_t") == 0) {
                    return 8;
                } else if (strcmp(type_name, "uint16_t") == 0 || strcmp(type_name, "int16_t") == 0) {
                    return 16;
                } else if (strcmp(type_name, "uint32_t") == 0 || strcmp(type_name, "int32_t") == 0) {
                    return 32;
                } else if (strcmp(type_name, "uint64_t") == 0 || strcmp(type_name, "int64_t") == 0) {
                    return 64;
                } else {
                    return 0;
                }
            }
        default:
            return 0;
    }
    zig_unreachable();
}


static AstNode *qual_type_to_log2_int_ref(Context *c, const QualType &qt,
        const SourceLocation &source_loc)
{
    uint32_t int_bit_width = qual_type_int_bit_width(c, qt, source_loc);
    if (int_bit_width != 0) {
        // we can perform the log2 now.
        uint64_t cast_bit_width = log2_u64(int_bit_width);
        return trans_create_node_symbol(c, buf_sprintf("u%" ZIG_PRI_u64, cast_bit_width));
    }

    AstNode *zig_type_node = trans_qual_type(c, qt, source_loc);

//    @import("std").math.Log2Int(c_long);
//
//    FnCall
//        FieldAccess
//            FieldAccess
//                FnCall (.builtin = true)
//                    Symbol "import"
//                    StringLiteral "std"
//                Symbol "math"
//            Symbol "Log2Int"
//        zig_type_node

    AstNode *import_fn_call = trans_create_node_builtin_fn_call_str(c, "import");
    import_fn_call->data.fn_call_expr.params.append(trans_create_node_str_lit_non_c(c, buf_create_from_str("std")));
    AstNode *inner_field_access = trans_create_node_field_access_str(c, import_fn_call, "math");
    AstNode *outer_field_access = trans_create_node_field_access_str(c, inner_field_access, "Log2Int");
    AstNode *log2int_fn_call = trans_create_node_fn_call_1(c, outer_field_access, zig_type_node);

    return log2int_fn_call;
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

static QualType resolve_any_typedef(Context *c, QualType qt) {
    const Type * ty = qt.getTypePtr();
    if (ty->getTypeClass() != Type::Typedef)
        return qt;
    const TypedefType *typedef_ty = static_cast<const TypedefType*>(ty);
    const TypedefNameDecl *typedef_decl = typedef_ty->getDecl();
    return typedef_decl->getUnderlyingType();
}

static bool c_is_signed_integer(Context *c, QualType qt) {
    const Type *c_type = resolve_any_typedef(c, qt).getTypePtr();
    if (c_type->getTypeClass() != Type::Builtin)
        return false;
    const BuiltinType *builtin_ty = static_cast<const BuiltinType*>(c_type);
    switch (builtin_ty->getKind()) {
        case BuiltinType::SChar:
        case BuiltinType::Short:
        case BuiltinType::Int:
        case BuiltinType::Long:
        case BuiltinType::LongLong:
        case BuiltinType::Int128:
        case BuiltinType::WChar_S:
            return true;
        default: 
            return false;
    }
}

static bool c_is_unsigned_integer(Context *c, QualType qt) {
    const Type *c_type = resolve_any_typedef(c, qt).getTypePtr();
    if (c_type->getTypeClass() != Type::Builtin)
        return false;
    const BuiltinType *builtin_ty = static_cast<const BuiltinType*>(c_type);
    switch (builtin_ty->getKind()) {
        case BuiltinType::Char_U:
        case BuiltinType::UChar:
        case BuiltinType::Char_S:
        case BuiltinType::UShort:
        case BuiltinType::UInt:
        case BuiltinType::ULong:
        case BuiltinType::ULongLong:
        case BuiltinType::UInt128:
        case BuiltinType::WChar_U:
            return true;
        default: 
            return false;
    }
}

static bool c_is_float(Context *c, QualType qt) {
    const Type *c_type = qt.getTypePtr();
    if (c_type->getTypeClass() != Type::Builtin)
        return false;
    const BuiltinType *builtin_ty = static_cast<const BuiltinType*>(c_type);
    switch (builtin_ty->getKind()) {
        case BuiltinType::Half:
        case BuiltinType::Float:
        case BuiltinType::Double:
        case BuiltinType::Float128:
        case BuiltinType::LongDouble:
            return true;
        default: 
            return false;
    }
}

static bool qual_type_has_wrapping_overflow(Context *c, QualType qt) {
    if (c_is_signed_integer(c, qt) || c_is_float(c, qt)) {
        // float and signed integer overflow is undefined behavior.
        return false;
    } else {
        // unsigned integer overflow wraps around.
        return true;
    }
}

enum TransLRValue {
    TransLValue,
    TransRValue,
};

static AstNode *trans_stmt(Context *c, bool result_used, AstNode *block, Stmt *stmt, TransLRValue lrval);
static AstNode *const skip_add_to_block_node = (AstNode *) 0x2;

static AstNode *trans_expr(Context *c, bool result_used, AstNode *block, Expr *expr, TransLRValue lrval) {
    return trans_stmt(c, result_used, block, expr, lrval);
}

static AstNode *trans_type(Context *c, const Type *ty, const SourceLocation &source_loc) {
    switch (ty->getTypeClass()) {
        case Type::Builtin:
            {
                const BuiltinType *builtin_ty = static_cast<const BuiltinType*>(ty);
                switch (builtin_ty->getKind()) {
                    case BuiltinType::Void:
                        return trans_create_node_symbol_str(c, "c_void");
                    case BuiltinType::Bool:
                        return trans_create_node_symbol_str(c, "bool");
                    case BuiltinType::Char_U:
                    case BuiltinType::UChar:
                    case BuiltinType::Char_S:
                        return trans_create_node_symbol_str(c, "u8");
                    case BuiltinType::SChar:
                        return trans_create_node_symbol_str(c, "i8");
                    case BuiltinType::UShort:
                        return trans_create_node_symbol_str(c, "c_ushort");
                    case BuiltinType::UInt:
                        return trans_create_node_symbol_str(c, "c_uint");
                    case BuiltinType::ULong:
                        return trans_create_node_symbol_str(c, "c_ulong");
                    case BuiltinType::ULongLong:
                        return trans_create_node_symbol_str(c, "c_ulonglong");
                    case BuiltinType::Short:
                        return trans_create_node_symbol_str(c, "c_short");
                    case BuiltinType::Int:
                        return trans_create_node_symbol_str(c, "c_int");
                    case BuiltinType::Long:
                        return trans_create_node_symbol_str(c, "c_long");
                    case BuiltinType::LongLong:
                        return trans_create_node_symbol_str(c, "c_longlong");
                    case BuiltinType::UInt128:
                        return trans_create_node_symbol_str(c, "u128");
                    case BuiltinType::Int128:
                        return trans_create_node_symbol_str(c, "i128");
                    case BuiltinType::Float:
                        return trans_create_node_symbol_str(c, "f32");
                    case BuiltinType::Double:
                        return trans_create_node_symbol_str(c, "f64");
                    case BuiltinType::Float128:
                        return trans_create_node_symbol_str(c, "f128");
                    case BuiltinType::LongDouble:
                        return trans_create_node_symbol_str(c, "c_longdouble");
                    case BuiltinType::WChar_U:
                    case BuiltinType::Char16:
                    case BuiltinType::Char32:
                    case BuiltinType::WChar_S:
                    case BuiltinType::Half:
                    case BuiltinType::NullPtr:
                    case BuiltinType::ObjCId:
                    case BuiltinType::ObjCClass:
                    case BuiltinType::ObjCSel:
                    case BuiltinType::OMPArraySection:
                    case BuiltinType::Dependent:
                    case BuiltinType::Overload:
                    case BuiltinType::BoundMember:
                    case BuiltinType::PseudoObject:
                    case BuiltinType::UnknownAny:
                    case BuiltinType::BuiltinFn:
                    case BuiltinType::ARCUnbridgedCast:

                    case BuiltinType::OCLImage1dRO:
                    case BuiltinType::OCLImage1dArrayRO:
                    case BuiltinType::OCLImage1dBufferRO:
                    case BuiltinType::OCLImage2dRO:
                    case BuiltinType::OCLImage2dArrayRO:
                    case BuiltinType::OCLImage2dDepthRO:
                    case BuiltinType::OCLImage2dArrayDepthRO:
                    case BuiltinType::OCLImage2dMSAARO:
                    case BuiltinType::OCLImage2dArrayMSAARO:
                    case BuiltinType::OCLImage2dMSAADepthRO:
                    case BuiltinType::OCLImage2dArrayMSAADepthRO:
                    case BuiltinType::OCLImage3dRO:
                    case BuiltinType::OCLImage1dWO:
                    case BuiltinType::OCLImage1dArrayWO:
                    case BuiltinType::OCLImage1dBufferWO:
                    case BuiltinType::OCLImage2dWO:
                    case BuiltinType::OCLImage2dArrayWO:
                    case BuiltinType::OCLImage2dDepthWO:
                    case BuiltinType::OCLImage2dArrayDepthWO:
                    case BuiltinType::OCLImage2dMSAAWO:
                    case BuiltinType::OCLImage2dArrayMSAAWO:
                    case BuiltinType::OCLImage2dMSAADepthWO:
                    case BuiltinType::OCLImage2dArrayMSAADepthWO:
                    case BuiltinType::OCLImage3dWO:
                    case BuiltinType::OCLImage1dRW:
                    case BuiltinType::OCLImage1dArrayRW:
                    case BuiltinType::OCLImage1dBufferRW:
                    case BuiltinType::OCLImage2dRW:
                    case BuiltinType::OCLImage2dArrayRW:
                    case BuiltinType::OCLImage2dDepthRW:
                    case BuiltinType::OCLImage2dArrayDepthRW:
                    case BuiltinType::OCLImage2dMSAARW:
                    case BuiltinType::OCLImage2dArrayMSAARW:
                    case BuiltinType::OCLImage2dMSAADepthRW:
                    case BuiltinType::OCLImage2dArrayMSAADepthRW:
                    case BuiltinType::OCLImage3dRW:
                    case BuiltinType::OCLSampler:
                    case BuiltinType::OCLEvent:
                    case BuiltinType::OCLClkEvent:
                    case BuiltinType::OCLQueue:
                    case BuiltinType::OCLReserveID:
                        emit_warning(c, source_loc, "unsupported builtin type");
                        return nullptr;
                }
                break;
            }
        case Type::Pointer:
            {
                const PointerType *pointer_ty = static_cast<const PointerType*>(ty);
                QualType child_qt = pointer_ty->getPointeeType();
                AstNode *child_node = trans_qual_type(c, child_qt, source_loc);
                if (child_node == nullptr) {
                    emit_warning(c, source_loc, "pointer to unsupported type");
                    return nullptr;
                }

                if (qual_type_child_is_fn_proto(child_qt)) {
                    return trans_create_node_prefix_op(c, PrefixOpMaybe, child_node);
                }

                AstNode *pointer_node = trans_create_node_addr_of(c, child_qt.isConstQualified(),
                        child_qt.isVolatileQualified(), child_node);
                return trans_create_node_prefix_op(c, PrefixOpMaybe, pointer_node);
            }
        case Type::Typedef:
            {
                const TypedefType *typedef_ty = static_cast<const TypedefType*>(ty);
                const TypedefNameDecl *typedef_decl = typedef_ty->getDecl();
                return resolve_typedef_decl(c, typedef_decl);
            }
        case Type::Elaborated:
            {
                const ElaboratedType *elaborated_ty = static_cast<const ElaboratedType*>(ty);
                switch (elaborated_ty->getKeyword()) {
                    case ETK_Struct:
                        return trans_qual_type(c, elaborated_ty->getNamedType(), source_loc);
                    case ETK_Enum:
                        return trans_qual_type(c, elaborated_ty->getNamedType(), source_loc);
                    case ETK_Interface:
                    case ETK_Union:
                    case ETK_Class:
                    case ETK_Typename:
                    case ETK_None:
                        emit_warning(c, source_loc, "unsupported elaborated type");
                        return nullptr;
                }
            }
        case Type::FunctionProto:
            {
                const FunctionProtoType *fn_proto_ty = static_cast<const FunctionProtoType*>(ty);

                AstNode *proto_node = trans_create_node(c, NodeTypeFnProto);
                switch (fn_proto_ty->getCallConv()) {
                    case CC_C:           // __attribute__((cdecl))
                        proto_node->data.fn_proto.cc = CallingConventionC;
                        proto_node->data.fn_proto.is_extern = true;
                        break;
                    case CC_X86StdCall:  // __attribute__((stdcall))
                        proto_node->data.fn_proto.cc = CallingConventionStdcall;
                        break;
                    case CC_X86FastCall: // __attribute__((fastcall))
                        emit_warning(c, source_loc, "unsupported calling convention: x86 fastcall");
                        return nullptr;
                    case CC_X86ThisCall: // __attribute__((thiscall))
                        emit_warning(c, source_loc, "unsupported calling convention: x86 thiscall");
                        return nullptr;
                    case CC_X86VectorCall: // __attribute__((vectorcall))
                        emit_warning(c, source_loc, "unsupported calling convention: x86 vectorcall");
                        return nullptr;
                    case CC_X86Pascal:   // __attribute__((pascal))
                        emit_warning(c, source_loc, "unsupported calling convention: x86 pascal");
                        return nullptr;
                    case CC_Win64: // __attribute__((ms_abi))
                        emit_warning(c, source_loc, "unsupported calling convention: win64");
                        return nullptr;
                    case CC_X86_64SysV:  // __attribute__((sysv_abi))
                        emit_warning(c, source_loc, "unsupported calling convention: x86 64sysv");
                        return nullptr;
                    case CC_X86RegCall:
                        emit_warning(c, source_loc, "unsupported calling convention: x86 reg");
                        return nullptr;
                    case CC_AAPCS:       // __attribute__((pcs("aapcs")))
                        emit_warning(c, source_loc, "unsupported calling convention: aapcs");
                        return nullptr;
                    case CC_AAPCS_VFP:   // __attribute__((pcs("aapcs-vfp")))
                        emit_warning(c, source_loc, "unsupported calling convention: aapcs-vfp");
                        return nullptr;
                    case CC_IntelOclBicc: // __attribute__((intel_ocl_bicc))
                        emit_warning(c, source_loc, "unsupported calling convention: intel_ocl_bicc");
                        return nullptr;
                    case CC_SpirFunction: // default for OpenCL functions on SPIR target
                        emit_warning(c, source_loc, "unsupported calling convention: SPIR function");
                        return nullptr;
                    case CC_OpenCLKernel:
                        emit_warning(c, source_loc, "unsupported calling convention: OpenCLKernel");
                        return nullptr;
                    case CC_Swift:
                        emit_warning(c, source_loc, "unsupported calling convention: Swift");
                        return nullptr;
                    case CC_PreserveMost:
                        emit_warning(c, source_loc, "unsupported calling convention: PreserveMost");
                        return nullptr;
                    case CC_PreserveAll:
                        emit_warning(c, source_loc, "unsupported calling convention: PreserveAll");
                        return nullptr;
                }

                proto_node->data.fn_proto.is_var_args = fn_proto_ty->isVariadic();
                size_t param_count = fn_proto_ty->getNumParams();

                if (fn_proto_ty->getNoReturnAttr()) {
                    proto_node->data.fn_proto.return_type = trans_create_node_symbol_str(c, "noreturn");
                } else {
                    proto_node->data.fn_proto.return_type = trans_qual_type(c, fn_proto_ty->getReturnType(),
                            source_loc);
                    if (proto_node->data.fn_proto.return_type == nullptr) {
                        emit_warning(c, source_loc, "unsupported function proto return type");
                        return nullptr;
                    }
                    // convert c_void to actual void (only for return type)
                    if (is_c_void_type(proto_node->data.fn_proto.return_type)) {
                        proto_node->data.fn_proto.return_type = nullptr;
                    }
                }

                //emit_warning(c, source_loc, "TODO figure out fn prototype fn name");
                const char *fn_name = nullptr;
                if (fn_name != nullptr) {
                    proto_node->data.fn_proto.name = buf_create_from_str(fn_name);
                }

                for (size_t i = 0; i < param_count; i += 1) {
                    QualType qt = fn_proto_ty->getParamType(i);
                    AstNode *param_type_node = trans_qual_type(c, qt, source_loc);

                    if (param_type_node == nullptr) {
                        emit_warning(c, source_loc, "unresolved function proto parameter type");
                        return nullptr;
                    }

                    AstNode *param_node = trans_create_node(c, NodeTypeParamDecl);
                    //emit_warning(c, source_loc, "TODO figure out fn prototype param name");
                    const char *param_name = nullptr;
                    if (param_name != nullptr) {
                        param_node->data.param_decl.name = buf_create_from_str(param_name);
                    }
                    param_node->data.param_decl.is_noalias = qt.isRestrictQualified();
                    param_node->data.param_decl.type = param_type_node;
                    proto_node->data.fn_proto.params.append(param_node);
                }
                // TODO check for always_inline attribute
                // TODO check for align attribute

                return proto_node;
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
                AstNode *child_type_node = trans_qual_type(c, const_arr_ty->getElementType(), source_loc);
                if (child_type_node == nullptr) {
                    emit_warning(c, source_loc, "unresolved array element type");
                    return nullptr;
                }
                uint64_t size = const_arr_ty->getSize().getLimitedValue();
                AstNode *size_node = trans_create_node_unsigned(c, size);
                return trans_create_node_array_type(c, size_node, child_type_node);
            }
        case Type::Paren:
            {
                const ParenType *paren_ty = static_cast<const ParenType *>(ty);
                return trans_qual_type(c, paren_ty->getInnerType(), source_loc);
            }
        case Type::Decayed:
            {
                const DecayedType *decayed_ty = static_cast<const DecayedType *>(ty);
                return trans_qual_type(c, decayed_ty->getDecayedType(), source_loc);
            }
        case Type::Attributed:
            {
                const AttributedType *attributed_ty = static_cast<const AttributedType *>(ty);
                return trans_qual_type(c, attributed_ty->getEquivalentType(), source_loc);
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
        case Type::ObjCTypeParam:
        case Type::DeducedTemplateSpecialization:
            emit_warning(c, source_loc, "unsupported type: '%s'", ty->getTypeClassName());
            return nullptr;
    }
    zig_unreachable();
}

static AstNode *trans_qual_type(Context *c, QualType qt, const SourceLocation &source_loc) {
    return trans_type(c, qt.getTypePtr(), source_loc);
}

static AstNode *trans_compound_stmt(Context *c, AstNode *parent, CompoundStmt *stmt) {
    AstNode *child_block = trans_create_node(c, NodeTypeBlock);
    for (CompoundStmt::body_iterator it = stmt->body_begin(), end_it = stmt->body_end(); it != end_it; ++it) {
        AstNode *child_node = trans_stmt(c, false, child_block, *it, TransRValue);
        if (child_node == nullptr)
            return nullptr;
        if (child_node != skip_add_to_block_node)
            child_block->data.block.statements.append(child_node);
    }
    return child_block;
}

static AstNode *trans_return_stmt(Context *c, AstNode *block, ReturnStmt *stmt) {
    Expr *value_expr = stmt->getRetValue();
    if (value_expr == nullptr) {
        emit_warning(c, stmt->getLocStart(), "TODO handle C return void");
        return nullptr;
    } else {
        AstNode *return_node = trans_create_node(c, NodeTypeReturnExpr);
        return_node->data.return_expr.expr = trans_expr(c, true, block, value_expr, TransRValue);
        if (return_node->data.return_expr.expr == nullptr)
            return nullptr;
        return return_node;
    }
}

static AstNode *trans_integer_literal(Context *c, IntegerLiteral *stmt) {
    llvm::APSInt result;
    if (!stmt->EvaluateAsInt(result, *c->ctx)) {
        emit_warning(c, stmt->getLocStart(), "invalid integer literal");
        return nullptr;
    }
    return trans_create_node_apint(c, result);
}

static AstNode *trans_conditional_operator(Context *c, bool result_used, AstNode *block, ConditionalOperator *stmt) {
    AstNode *node = trans_create_node(c, NodeTypeIfBoolExpr);

    Expr *cond_expr = stmt->getCond();
    Expr *true_expr = stmt->getTrueExpr();
    Expr *false_expr = stmt->getFalseExpr();

    node->data.if_bool_expr.condition = trans_expr(c, true, block, cond_expr, TransRValue);
    if (node->data.if_bool_expr.condition == nullptr)
        return nullptr;

    node->data.if_bool_expr.then_block = trans_expr(c, result_used, block, true_expr, TransRValue);
    if (node->data.if_bool_expr.then_block == nullptr)
        return nullptr;

    node->data.if_bool_expr.else_node = trans_expr(c, result_used, block, false_expr, TransRValue);
    if (node->data.if_bool_expr.else_node == nullptr)
        return nullptr;

    return maybe_suppress_result(c, result_used, node);
}

static AstNode *trans_create_bin_op(Context *c, AstNode *block, Expr *lhs, BinOpType bin_op, Expr *rhs) {
    AstNode *node = trans_create_node(c, NodeTypeBinOpExpr);
    node->data.bin_op_expr.bin_op = bin_op;

    node->data.bin_op_expr.op1 = trans_expr(c, true, block, lhs, TransRValue);
    if (node->data.bin_op_expr.op1 == nullptr)
        return nullptr;

    node->data.bin_op_expr.op2 = trans_expr(c, true, block, rhs, TransRValue);
    if (node->data.bin_op_expr.op2 == nullptr)
        return nullptr;

    return node;
}

static AstNode *trans_create_assign(Context *c, bool result_used, AstNode *block, Expr *lhs, Expr *rhs) {
    if (!result_used) {
        // common case
        AstNode *node = trans_create_node(c, NodeTypeBinOpExpr);
        node->data.bin_op_expr.bin_op = BinOpTypeAssign;

        node->data.bin_op_expr.op1 = trans_expr(c, true, block, lhs, TransLValue);
        if (node->data.bin_op_expr.op1 == nullptr)
            return nullptr;

        node->data.bin_op_expr.op2 = trans_expr(c, true, block, rhs, TransRValue);
        if (node->data.bin_op_expr.op2 == nullptr)
            return nullptr;

        return node;
    } else {
        // worst case
        // c: lhs = rhs
        // zig: {
        // zig:     const _tmp = rhs;
        // zig:     lhs = _tmp;
        // zig:     _tmp
        // zig: }

        AstNode *child_block = trans_create_node(c, NodeTypeBlock);

        // const _tmp = rhs;
        AstNode *rhs_node = trans_expr(c, true, child_block, rhs, TransRValue);
        if (rhs_node == nullptr) return nullptr;
        // TODO: avoid name collisions with generated variable names
        Buf* tmp_var_name = buf_create_from_str("_tmp");
        AstNode *tmp_var_decl = trans_create_node_var_decl_local(c, true, tmp_var_name, nullptr, rhs_node);
        child_block->data.block.statements.append(tmp_var_decl);

        // lhs = _tmp;
        AstNode *lhs_node = trans_expr(c, true, child_block, lhs, TransLValue);
        if (lhs_node == nullptr) return nullptr;
        child_block->data.block.statements.append(
            trans_create_node_bin_op(c, lhs_node, BinOpTypeAssign,
                trans_create_node_symbol(c, tmp_var_name)));

        // _tmp
        child_block->data.block.statements.append(trans_create_node_symbol(c, tmp_var_name));
        child_block->data.block.last_statement_is_result_expression = true;

        return child_block;
    }
}

static AstNode *trans_binary_operator(Context *c, bool result_used, AstNode *block, BinaryOperator *stmt) {
    switch (stmt->getOpcode()) {
        case BO_PtrMemD:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_PtrMemD");
            return nullptr;
        case BO_PtrMemI:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_PtrMemI");
            return nullptr;
        case BO_Mul:
            return trans_create_bin_op(c, block, stmt->getLHS(),
                qual_type_has_wrapping_overflow(c, stmt->getType()) ? BinOpTypeMultWrap : BinOpTypeMult,
                stmt->getRHS());
        case BO_Div:
            if (qual_type_has_wrapping_overflow(c, stmt->getType())) {
                // unsigned/float division uses the operator
                return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeDiv, stmt->getRHS());
            } else {
                // signed integer division uses @divTrunc
                AstNode *fn_call = trans_create_node_builtin_fn_call_str(c, "divTrunc");
                AstNode *lhs = trans_expr(c, true, block, stmt->getLHS(), TransLValue);
                if (lhs == nullptr) return nullptr;
                fn_call->data.fn_call_expr.params.append(lhs);
                AstNode *rhs = trans_expr(c, true, block, stmt->getRHS(), TransLValue);
                if (rhs == nullptr) return nullptr;
                fn_call->data.fn_call_expr.params.append(rhs);
                return fn_call;
            }
        case BO_Rem:
            if (qual_type_has_wrapping_overflow(c, stmt->getType())) {
                // unsigned/float division uses the operator
                return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeMod, stmt->getRHS());
            } else {
                // signed integer division uses @divTrunc
                AstNode *fn_call = trans_create_node_builtin_fn_call_str(c, "rem");
                AstNode *lhs = trans_expr(c, true, block, stmt->getLHS(), TransLValue);
                if (lhs == nullptr) return nullptr;
                fn_call->data.fn_call_expr.params.append(lhs);
                AstNode *rhs = trans_expr(c, true, block, stmt->getRHS(), TransLValue);
                if (rhs == nullptr) return nullptr;
                fn_call->data.fn_call_expr.params.append(rhs);
                return fn_call;
            }
        case BO_Add:
            return trans_create_bin_op(c, block, stmt->getLHS(),
                qual_type_has_wrapping_overflow(c, stmt->getType()) ? BinOpTypeAddWrap : BinOpTypeAdd,
                stmt->getRHS());
        case BO_Sub:
            return trans_create_bin_op(c, block, stmt->getLHS(),
                qual_type_has_wrapping_overflow(c, stmt->getType()) ? BinOpTypeSubWrap : BinOpTypeSub,
                stmt->getRHS());
        case BO_Shl:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_Shl");
            return nullptr;
        case BO_Shr:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_Shr");
            return nullptr;
        case BO_LT:
            return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeCmpLessThan, stmt->getRHS());
        case BO_GT:
            return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeCmpGreaterThan, stmt->getRHS());
        case BO_LE:
            return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeCmpLessOrEq, stmt->getRHS());
        case BO_GE:
            return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeCmpGreaterOrEq, stmt->getRHS());
        case BO_EQ:
            return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeCmpEq, stmt->getRHS());
        case BO_NE:
            return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeCmpNotEq, stmt->getRHS());
        case BO_And:
            return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeBinAnd, stmt->getRHS());
        case BO_Xor:
            return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeBinXor, stmt->getRHS());
        case BO_Or:
            return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeBinOr, stmt->getRHS());
        case BO_LAnd:
            return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeBoolAnd, stmt->getRHS());
        case BO_LOr:
            // TODO: int vs bool
            return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeBoolOr, stmt->getRHS());
        case BO_Assign:
            return trans_create_assign(c, result_used, block, stmt->getLHS(), stmt->getRHS());
        case BO_MulAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_MulAssign");
            return nullptr;
        case BO_DivAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_DivAssign");
            return nullptr;
        case BO_RemAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_RemAssign");
            return nullptr;
        case BO_AddAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_AddAssign");
            return nullptr;
        case BO_SubAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_SubAssign");
            return nullptr;
        case BO_ShlAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_ShlAssign");
            return nullptr;
        case BO_ShrAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_ShrAssign");
            return nullptr;
        case BO_AndAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_AndAssign");
            return nullptr;
        case BO_XorAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_XorAssign");
            return nullptr;
        case BO_OrAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_OrAssign");
            return nullptr;
        case BO_Comma:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_Comma");
            return nullptr;
    }

    zig_unreachable();
}

static AstNode *trans_compound_assign_operator(Context *c, bool result_used, AstNode *block, CompoundAssignOperator *stmt) {
    switch (stmt->getOpcode()) {
        case BO_MulAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C compound assign operators: BO_MulAssign");
            return nullptr;
        case BO_DivAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C compound assign operators: BO_DivAssign");
            return nullptr;
        case BO_RemAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C compound assign operators: BO_RemAssign");
            return nullptr;
        case BO_AddAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C compound assign operators: BO_AddAssign");
            return nullptr;
        case BO_SubAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C compound assign operators: BO_SubAssign");
            return nullptr;
        case BO_ShlAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C compound assign operators: BO_ShlAssign");
            return nullptr;
        case BO_ShrAssign: {
            BinOpType bin_op = BinOpTypeBitShiftRight;

            const SourceLocation &rhs_location = stmt->getRHS()->getLocStart();
            AstNode *rhs_type = qual_type_to_log2_int_ref(c, stmt->getComputationLHSType(), rhs_location);

            bool use_intermediate_casts = stmt->getComputationLHSType().getTypePtr() != stmt->getComputationResultType().getTypePtr();
            if (!use_intermediate_casts && !result_used) {
                // simple common case, where the C and Zig are identical:
                // lhs >>= rh* s
                AstNode *lhs = trans_expr(c, true, block, stmt->getLHS(), TransLValue);
                if (lhs == nullptr) return nullptr;

                AstNode *rhs = trans_expr(c, true, block, stmt->getRHS(), TransRValue);
                if (rhs == nullptr) return nullptr;
                AstNode *coerced_rhs = trans_create_node_fn_call_1(c, rhs_type, rhs);

                return trans_create_node_bin_op(c, lhs, BinOpTypeAssignBitShiftRight, coerced_rhs);
            } else {
                // need more complexity. worst case, this looks like this:
                // c:   lhs >>= rhs
                // zig: {
                // zig:     const _ref = &lhs;
                // zig:     *_ref = result_type(operation_type(*_ref) >> u5(rhs));
                // zig:     *_ref
                // zig: }
                // where u5 is the appropriate type

                // TODO: avoid mess when we don't need the assignment value for chained assignments or anything.
                AstNode *child_block = trans_create_node(c, NodeTypeBlock);

                // const _ref = &lhs;
                AstNode *lhs = trans_expr(c, true, child_block, stmt->getLHS(), TransLValue);
                if (lhs == nullptr) return nullptr;
                AstNode *addr_of_lhs = trans_create_node_addr_of(c, false, false, lhs);
                // TODO: avoid name collisions with generated variable names
                Buf* tmp_var_name = buf_create_from_str("_ref");
                AstNode *tmp_var_decl = trans_create_node_var_decl_local(c, true, tmp_var_name, nullptr, addr_of_lhs);
                child_block->data.block.statements.append(tmp_var_decl);

                // *_ref = result_type(operation_type(*_ref) >> u5(rhs));

                AstNode *rhs = trans_expr(c, true, child_block, stmt->getRHS(), TransRValue);
                if (rhs == nullptr) return nullptr;
                AstNode *coerced_rhs = trans_create_node_fn_call_1(c, rhs_type, rhs);

                AstNode *assign_statement = trans_create_node_bin_op(c,
                    trans_create_node_prefix_op(c, PrefixOpDereference,
                        trans_create_node_symbol(c, tmp_var_name)),
                    BinOpTypeAssign,
                    trans_c_cast(c, rhs_location,
                        stmt->getComputationResultType(),
                        trans_create_node_bin_op(c,
                            trans_c_cast(c, rhs_location,
                                stmt->getComputationLHSType(),
                                trans_create_node_prefix_op(c, PrefixOpDereference,
                                    trans_create_node_symbol(c, tmp_var_name))),
                            bin_op,
                            coerced_rhs)));
                child_block->data.block.statements.append(assign_statement);

                if (result_used) {
                    // *_ref
                    child_block->data.block.statements.append(
                        trans_create_node_prefix_op(c, PrefixOpDereference,
                            trans_create_node_symbol(c, tmp_var_name)));
                    child_block->data.block.last_statement_is_result_expression = true;
                }

                return child_block;
            }
        }
        case BO_AndAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C compound assign operators: BO_AndAssign");
            return nullptr;
        case BO_XorAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C compound assign operators: BO_XorAssign");
            return nullptr;
        case BO_OrAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C compound assign operators: BO_OrAssign");
            return nullptr;
        case BO_PtrMemD:
        case BO_PtrMemI:
        case BO_Assign:
        case BO_Mul:
        case BO_Div:
        case BO_Rem:
        case BO_Add:
        case BO_Sub:
        case BO_Shl:
        case BO_Shr:
        case BO_LT:
        case BO_GT:
        case BO_LE:
        case BO_GE:
        case BO_EQ:
        case BO_NE:
        case BO_And:
        case BO_Xor:
        case BO_Or:
        case BO_LAnd:
        case BO_LOr:
        case BO_Comma:
            zig_panic("compound assign expected to be handled by binary operator");
    }

    zig_unreachable();
}

static AstNode *trans_implicit_cast_expr(Context *c, AstNode *block, ImplicitCastExpr *stmt) {
    switch (stmt->getCastKind()) {
        case CK_LValueToRValue:
            return trans_expr(c, true, block, stmt->getSubExpr(), TransRValue);
        case CK_IntegralCast:
            {
                AstNode *target_node = trans_expr(c, true, block, stmt->getSubExpr(), TransRValue);
                if (target_node == nullptr)
                    return nullptr;
                return trans_c_cast(c, stmt->getExprLoc(), stmt->getType(), target_node);
            }
        case CK_FunctionToPointerDecay:
        case CK_ArrayToPointerDecay:
            {
                AstNode *target_node = trans_expr(c, true, block, stmt->getSubExpr(), TransRValue);
                if (target_node == nullptr)
                    return nullptr;
                return target_node;
            }
        case CK_BitCast:
            {
                AstNode *target_node = trans_expr(c, true, block, stmt->getSubExpr(), TransRValue);
                if (target_node == nullptr)
                    return nullptr;

                AstNode *dest_type_node = trans_qual_type(c, stmt->getType(), stmt->getLocStart());

                AstNode *node = trans_create_node_builtin_fn_call_str(c, "ptrCast");
                node->data.fn_call_expr.params.append(dest_type_node);
                node->data.fn_call_expr.params.append(target_node);
                return node;
            }
        case CK_Dependent:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_Dependent");
            return nullptr;
        case CK_LValueBitCast:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_LValueBitCast");
            return nullptr;
        case CK_NoOp:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_NoOp");
            return nullptr;
        case CK_BaseToDerived:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_BaseToDerived");
            return nullptr;
        case CK_DerivedToBase:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_DerivedToBase");
            return nullptr;
        case CK_UncheckedDerivedToBase:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_UncheckedDerivedToBase");
            return nullptr;
        case CK_Dynamic:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_Dynamic");
            return nullptr;
        case CK_ToUnion:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_ToUnion");
            return nullptr;
        case CK_NullToPointer:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_NullToPointer");
            return nullptr;
        case CK_NullToMemberPointer:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_NullToMemberPointer");
            return nullptr;
        case CK_BaseToDerivedMemberPointer:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_BaseToDerivedMemberPointer");
            return nullptr;
        case CK_DerivedToBaseMemberPointer:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_DerivedToBaseMemberPointer");
            return nullptr;
        case CK_MemberPointerToBoolean:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_MemberPointerToBoolean");
            return nullptr;
        case CK_ReinterpretMemberPointer:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_ReinterpretMemberPointer");
            return nullptr;
        case CK_UserDefinedConversion:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_UserDefinedConversion");
            return nullptr;
        case CK_ConstructorConversion:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_ConstructorConversion");
            return nullptr;
        case CK_IntegralToPointer:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_IntegralToPointer");
            return nullptr;
        case CK_PointerToIntegral:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_PointerToIntegral");
            return nullptr;
        case CK_PointerToBoolean:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_PointerToBoolean");
            return nullptr;
        case CK_ToVoid:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_ToVoid");
            return nullptr;
        case CK_VectorSplat:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_VectorSplat");
            return nullptr;
        case CK_IntegralToBoolean:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_IntegralToBoolean");
            return nullptr;
        case CK_IntegralToFloating:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_IntegralToFloating");
            return nullptr;
        case CK_FloatingToIntegral:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_FloatingToIntegral");
            return nullptr;
        case CK_FloatingToBoolean:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_FloatingToBoolean");
            return nullptr;
        case CK_BooleanToSignedIntegral:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_BooleanToSignedIntegral");
            return nullptr;
        case CK_FloatingCast:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_FloatingCast");
            return nullptr;
        case CK_CPointerToObjCPointerCast:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_CPointerToObjCPointerCast");
            return nullptr;
        case CK_BlockPointerToObjCPointerCast:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_BlockPointerToObjCPointerCast");
            return nullptr;
        case CK_AnyPointerToBlockPointerCast:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_AnyPointerToBlockPointerCast");
            return nullptr;
        case CK_ObjCObjectLValueCast:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_ObjCObjectLValueCast");
            return nullptr;
        case CK_FloatingRealToComplex:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_FloatingRealToComplex");
            return nullptr;
        case CK_FloatingComplexToReal:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_FloatingComplexToReal");
            return nullptr;
        case CK_FloatingComplexToBoolean:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_FloatingComplexToBoolean");
            return nullptr;
        case CK_FloatingComplexCast:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_FloatingComplexCast");
            return nullptr;
        case CK_FloatingComplexToIntegralComplex:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_FloatingComplexToIntegralComplex");
            return nullptr;
        case CK_IntegralRealToComplex:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_IntegralRealToComplex");
            return nullptr;
        case CK_IntegralComplexToReal:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_IntegralComplexToReal");
            return nullptr;
        case CK_IntegralComplexToBoolean:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_IntegralComplexToBoolean");
            return nullptr;
        case CK_IntegralComplexCast:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_IntegralComplexCast");
            return nullptr;
        case CK_IntegralComplexToFloatingComplex:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_IntegralComplexToFloatingComplex");
            return nullptr;
        case CK_ARCProduceObject:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_ARCProduceObject");
            return nullptr;
        case CK_ARCConsumeObject:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_ARCConsumeObject");
            return nullptr;
        case CK_ARCReclaimReturnedObject:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_ARCReclaimReturnedObject");
            return nullptr;
        case CK_ARCExtendBlockObject:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_ARCExtendBlockObject");
            return nullptr;
        case CK_AtomicToNonAtomic:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_AtomicToNonAtomic");
            return nullptr;
        case CK_NonAtomicToAtomic:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_NonAtomicToAtomic");
            return nullptr;
        case CK_CopyAndAutoreleaseBlockObject:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_CopyAndAutoreleaseBlockObject");
            return nullptr;
        case CK_BuiltinFnToFnPtr:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_BuiltinFnToFnPtr");
            return nullptr;
        case CK_ZeroToOCLEvent:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_ZeroToOCLEvent");
            return nullptr;
        case CK_ZeroToOCLQueue:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_ZeroToOCLQueue");
            return nullptr;
        case CK_AddressSpaceConversion:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_AddressSpaceConversion");
            return nullptr;
        case CK_IntToOCLSampler:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation cast CK_IntToOCLSampler");
            return nullptr;
    }
    zig_unreachable();
}

static AstNode *trans_decl_ref_expr(Context *c, DeclRefExpr *stmt, TransLRValue lrval) {
    ValueDecl *value_decl = stmt->getDecl();
    Buf *symbol_name = buf_create_from_str(decl_name(value_decl));
    if (lrval == TransLValue) {
        c->ptr_params.put(symbol_name, true);
    }
    return trans_create_node_symbol(c, symbol_name);
}

static AstNode *trans_unary_operator(Context *c, bool result_used, AstNode *block, UnaryOperator *stmt) {
    switch (stmt->getOpcode()) {
        case UO_PostInc: {
            Expr *op_expr = stmt->getSubExpr();
            BinOpType bin_op = qual_type_has_wrapping_overflow(c, op_expr->getType())
                ? BinOpTypeAssignPlusWrap
                : BinOpTypeAssignPlus;

            if (!result_used) {
                // common case
                // c: expr++
                // zig: expr += 1
                return trans_create_node_bin_op(c,
                    trans_expr(c, true, block, op_expr, TransLValue),
                    bin_op,
                    trans_create_node_unsigned(c, 1));
            } else {
                // worst case
                // c: expr++
                // zig: {
                // zig:     const _ref = &expr;
                // zig:     const _tmp = *_ref;
                // zig:     *_ref += 1;
                // zig:     _tmp
                // zig: }
                emit_warning(c, stmt->getLocStart(), "TODO handle C translation UO_PostInc with result_used");
                return nullptr;
            }
        }
        case UO_PostDec:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation UO_PostDec");
            return nullptr;
        case UO_PreInc:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation UO_PreInc");
            return nullptr;
        case UO_PreDec:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation UO_PreDec");
            return nullptr;
        case UO_AddrOf:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation UO_AddrOf");
            return nullptr;
        case UO_Deref:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation UO_Deref");
            return nullptr;
        case UO_Plus:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation UO_Plus");
            return nullptr;
        case UO_Minus:
            {
                Expr *op_expr = stmt->getSubExpr();
                if (!qual_type_has_wrapping_overflow(c, op_expr->getType())) {
                    AstNode *node = trans_create_node(c, NodeTypePrefixOpExpr);
                    node->data.prefix_op_expr.prefix_op = PrefixOpNegation;

                    node->data.prefix_op_expr.primary_expr = trans_expr(c, true, block, op_expr, TransRValue);
                    if (node->data.prefix_op_expr.primary_expr == nullptr)
                        return nullptr;

                    return node;
                } else if (c_is_unsigned_integer(c, op_expr->getType())) {
                    // we gotta emit 0 -% x
                    AstNode *node = trans_create_node(c, NodeTypeBinOpExpr);
                    node->data.bin_op_expr.op1 = trans_create_node_unsigned(c, 0);

                    node->data.bin_op_expr.op2 = trans_expr(c, true, block, op_expr, TransRValue);
                    if (node->data.bin_op_expr.op2 == nullptr)
                        return nullptr;

                    node->data.bin_op_expr.bin_op = BinOpTypeSubWrap;
                    return node;
                } else {
                    emit_warning(c, stmt->getLocStart(), "C negation with non float non integer");
                    return nullptr;
                }
            }
        case UO_Not:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation UO_Not");
            return nullptr;
        case UO_LNot:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation UO_LNot");
            return nullptr;
        case UO_Real:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation UO_Real");
            return nullptr;
        case UO_Imag:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation UO_Imag");
            return nullptr;
        case UO_Extension:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation UO_Extension");
            return nullptr;
        case UO_Coawait:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation UO_Coawait");
            return nullptr;
    }
    zig_unreachable();
}

static AstNode *trans_local_declaration(Context *c, AstNode *block, DeclStmt *stmt) {
    for (auto iter = stmt->decl_begin(); iter != stmt->decl_end(); iter++) {
        Decl *decl = *iter;
        switch (decl->getKind()) {
            case Decl::Var: {
                VarDecl *var_decl = (VarDecl *)decl;
                QualType qual_type = var_decl->getTypeSourceInfo()->getType();
                AstNode *init_node = nullptr;
                if (var_decl->hasInit()) {
                    init_node = trans_expr(c, true, block, var_decl->getInit(), TransRValue);
                    if (init_node == nullptr)
                        return nullptr;

                }
                AstNode *type_node = trans_qual_type(c, qual_type, stmt->getLocStart());
                if (type_node == nullptr)
                    return nullptr;

                Buf *symbol_name = buf_create_from_str(decl_name(var_decl));

                AstNode *node = trans_create_node_var_decl_local(c, qual_type.isConstQualified(),
                        symbol_name, type_node, init_node);
                block->data.block.statements.append(node);
                continue;
            }
            case Decl::AccessSpec:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind AccessSpec");
                return nullptr;
            case Decl::Block:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Block");
                return nullptr;
            case Decl::Captured:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Captured");
                return nullptr;
            case Decl::ClassScopeFunctionSpecialization:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ClassScopeFunctionSpecialization");
                return nullptr;
            case Decl::Empty:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Empty");
                return nullptr;
            case Decl::Export:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Export");
                return nullptr;
            case Decl::ExternCContext:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ExternCContext");
                return nullptr;
            case Decl::FileScopeAsm:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind FileScopeAsm");
                return nullptr;
            case Decl::Friend:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Friend");
                return nullptr;
            case Decl::FriendTemplate:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind FriendTemplate");
                return nullptr;
            case Decl::Import:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Import");
                return nullptr;
            case Decl::LinkageSpec:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind LinkageSpec");
                return nullptr;
            case Decl::Label:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Label");
                return nullptr;
            case Decl::Namespace:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Namespace");
                return nullptr;
            case Decl::NamespaceAlias:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind NamespaceAlias");
                return nullptr;
            case Decl::ObjCCompatibleAlias:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCCompatibleAlias");
                return nullptr;
            case Decl::ObjCCategory:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCCategory");
                return nullptr;
            case Decl::ObjCCategoryImpl:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCCategoryImpl");
                return nullptr;
            case Decl::ObjCImplementation:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCImplementation");
                return nullptr;
            case Decl::ObjCInterface:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCInterface");
                return nullptr;
            case Decl::ObjCProtocol:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCProtocol");
                return nullptr;
            case Decl::ObjCMethod:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCMethod");
                return nullptr;
            case Decl::ObjCProperty:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCProperty");
                return nullptr;
            case Decl::BuiltinTemplate:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind BuiltinTemplate");
                return nullptr;
            case Decl::ClassTemplate:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ClassTemplate");
                return nullptr;
            case Decl::FunctionTemplate:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind FunctionTemplate");
                return nullptr;
            case Decl::TypeAliasTemplate:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind TypeAliasTemplate");
                return nullptr;
            case Decl::VarTemplate:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind VarTemplate");
                return nullptr;
            case Decl::TemplateTemplateParm:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind TemplateTemplateParm");
                return nullptr;
            case Decl::Enum:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Enum");
                return nullptr;
            case Decl::Record:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Record");
                return nullptr;
            case Decl::CXXRecord:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind CXXRecord");
                return nullptr;
            case Decl::ClassTemplateSpecialization:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ClassTemplateSpecialization");
                return nullptr;
            case Decl::ClassTemplatePartialSpecialization:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ClassTemplatePartialSpecialization");
                return nullptr;
            case Decl::TemplateTypeParm:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind TemplateTypeParm");
                return nullptr;
            case Decl::ObjCTypeParam:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCTypeParam");
                return nullptr;
            case Decl::TypeAlias:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind TypeAlias");
                return nullptr;
            case Decl::Typedef:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Typedef");
                return nullptr;
            case Decl::UnresolvedUsingTypename:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind UnresolvedUsingTypename");
                return nullptr;
            case Decl::Using:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Using");
                return nullptr;
            case Decl::UsingDirective:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind UsingDirective");
                return nullptr;
            case Decl::UsingPack:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind UsingPack");
                return nullptr;
            case Decl::UsingShadow:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind UsingShadow");
                return nullptr;
            case Decl::ConstructorUsingShadow:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ConstructorUsingShadow");
                return nullptr;
            case Decl::Binding:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Binding");
                return nullptr;
            case Decl::Field:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Field");
                return nullptr;
            case Decl::ObjCAtDefsField:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCAtDefsField");
                return nullptr;
            case Decl::ObjCIvar:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCIvar");
                return nullptr;
            case Decl::Function:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Function");
                return nullptr;
            case Decl::CXXDeductionGuide:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind CXXDeductionGuide");
                return nullptr;
            case Decl::CXXMethod:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind CXXMethod");
                return nullptr;
            case Decl::CXXConstructor:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind CXXConstructor");
                return nullptr;
            case Decl::CXXConversion:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind CXXConversion");
                return nullptr;
            case Decl::CXXDestructor:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind CXXDestructor");
                return nullptr;
            case Decl::MSProperty:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind MSProperty");
                return nullptr;
            case Decl::NonTypeTemplateParm:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind NonTypeTemplateParm");
                return nullptr;
            case Decl::Decomposition:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Decomposition");
                return nullptr;
            case Decl::ImplicitParam:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ImplicitParam");
                return nullptr;
            case Decl::OMPCapturedExpr:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind OMPCapturedExpr");
                return nullptr;
            case Decl::ParmVar:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ParmVar");
                return nullptr;
            case Decl::VarTemplateSpecialization:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind VarTemplateSpecialization");
                return nullptr;
            case Decl::VarTemplatePartialSpecialization:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind VarTemplatePartialSpecialization");
                return nullptr;
            case Decl::EnumConstant:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind EnumConstant");
                return nullptr;
            case Decl::IndirectField:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind IndirectField");
                return nullptr;
            case Decl::OMPDeclareReduction:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind OMPDeclareReduction");
                return nullptr;
            case Decl::UnresolvedUsingValue:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind UnresolvedUsingValue");
                return nullptr;
            case Decl::OMPThreadPrivate:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind OMPThreadPrivate");
                return nullptr;
            case Decl::ObjCPropertyImpl:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCPropertyImpl");
                return nullptr;
            case Decl::PragmaComment:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind PragmaComment");
                return nullptr;
            case Decl::PragmaDetectMismatch:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind PragmaDetectMismatch");
                return nullptr;
            case Decl::StaticAssert:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind StaticAssert");
                return nullptr;
            case Decl::TranslationUnit:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind TranslationUnit");
                return nullptr;
        }
        zig_unreachable();
    }

    // declarations were already added
    return skip_add_to_block_node;
}

static AstNode *trans_while_loop(Context *c, AstNode *block, WhileStmt *stmt) {
    AstNode *while_node = trans_create_node(c, NodeTypeWhileExpr);

    while_node->data.while_expr.condition = trans_expr(c, true, block, stmt->getCond(), TransRValue);
    if (while_node->data.while_expr.condition == nullptr)
        return nullptr;

    while_node->data.while_expr.body = trans_stmt(c, false, block, stmt->getBody(), TransRValue);
    if (while_node->data.while_expr.body == nullptr)
        return nullptr;

    return while_node;
}

static AstNode *trans_if_statement(Context *c, AstNode *block, IfStmt *stmt) {
    // if (c) t
    // if (c) t else e
    AstNode *if_node = trans_create_node(c, NodeTypeIfBoolExpr);

    // TODO: condition != 0
    AstNode *condition_node = trans_expr(c, true, block, stmt->getCond(), TransRValue);
    if (condition_node == nullptr)
        return nullptr;
    if_node->data.if_bool_expr.condition = condition_node;

    if_node->data.if_bool_expr.then_block = trans_stmt(c, false, block, stmt->getThen(), TransRValue);
    if (if_node->data.if_bool_expr.then_block == nullptr)
        return nullptr;

    if (stmt->getElse() != nullptr) {
        if_node->data.if_bool_expr.else_node = trans_stmt(c, false, block, stmt->getElse(), TransRValue);
        if (if_node->data.if_bool_expr.else_node == nullptr)
            return nullptr;
    }

    return if_node;
}

static AstNode *trans_call_expr(Context *c, bool result_used, AstNode *block, CallExpr *stmt) {
    AstNode *node = trans_create_node(c, NodeTypeFnCallExpr);
    node->data.fn_call_expr.fn_ref_expr = trans_expr(c, true, block, stmt->getCallee(), TransRValue);
    if (node->data.fn_call_expr.fn_ref_expr == nullptr)
        return nullptr;

    unsigned num_args = stmt->getNumArgs();
    Expr **args = stmt->getArgs();
    for (unsigned i = 0; i < num_args; i += 1) {
        AstNode *arg_node = trans_expr(c, true, block, args[i], TransRValue);
        if (arg_node == nullptr)
            return nullptr;

        node->data.fn_call_expr.params.append(arg_node);
    }

    return node;
}

static AstNode *trans_member_expr(Context *c, AstNode *block, MemberExpr *stmt) {
    AstNode *container_node = trans_expr(c, true, block, stmt->getBase(), TransRValue);
    if (container_node == nullptr)
        return nullptr;

    if (stmt->isArrow()) {
        container_node = trans_create_node_unwrap_null(c, container_node);
    }

    const char *name = decl_name(stmt->getMemberDecl());

    AstNode *node = trans_create_node_field_access_str(c, container_node, name);
    return node;
}

static AstNode *trans_array_subscript_expr(Context *c, AstNode *block, ArraySubscriptExpr *stmt) {
    AstNode *container_node = trans_expr(c, true, block, stmt->getBase(), TransRValue);
    if (container_node == nullptr)
        return nullptr;

    AstNode *idx_node = trans_expr(c, true, block, stmt->getIdx(), TransRValue);
    if (idx_node == nullptr)
        return nullptr;


    AstNode *node = trans_create_node(c, NodeTypeArrayAccessExpr);
    node->data.array_access_expr.array_ref_expr = container_node;
    node->data.array_access_expr.subscript = idx_node;
    return node;
}

static AstNode *trans_c_style_cast_expr(Context *c, bool result_used, AstNode *block,
        CStyleCastExpr *stmt, TransLRValue lrvalue)
{
    AstNode *sub_expr_node = trans_expr(c, result_used, block, stmt->getSubExpr(), lrvalue);
    if (sub_expr_node == nullptr)
        return nullptr;

    return trans_c_cast(c, stmt->getLocStart(), stmt->getType(), sub_expr_node);
}

static AstNode *trans_unary_expr_or_type_trait_expr(Context *c, AstNode *block, UnaryExprOrTypeTraitExpr *stmt) {
    AstNode *type_node = trans_qual_type(c, stmt->getTypeOfArgument(), stmt->getLocStart());
    if (type_node == nullptr)
        return nullptr;

    AstNode *node = trans_create_node_builtin_fn_call_str(c, "sizeOf");
    node->data.fn_call_expr.params.append(type_node);
    return node;
}

static AstNode *trans_stmt(Context *c, bool result_used, AstNode *block, Stmt *stmt, TransLRValue lrvalue) {
    Stmt::StmtClass sc = stmt->getStmtClass();
    switch (sc) {
        case Stmt::ReturnStmtClass:
            return trans_return_stmt(c, block, (ReturnStmt *)stmt);
        case Stmt::CompoundStmtClass:
            return trans_compound_stmt(c, block, (CompoundStmt *)stmt);
        case Stmt::IntegerLiteralClass:
            return trans_integer_literal(c, (IntegerLiteral *)stmt);
        case Stmt::ConditionalOperatorClass:
            return trans_conditional_operator(c, result_used, block, (ConditionalOperator *)stmt);
        case Stmt::BinaryOperatorClass:
            return trans_binary_operator(c, result_used, block, (BinaryOperator *)stmt);
        case Stmt::CompoundAssignOperatorClass:
            return trans_compound_assign_operator(c, result_used, block, (CompoundAssignOperator *)stmt);
        case Stmt::ImplicitCastExprClass:
            return trans_implicit_cast_expr(c, block, (ImplicitCastExpr *)stmt);
        case Stmt::DeclRefExprClass:
            return trans_decl_ref_expr(c, (DeclRefExpr *)stmt, lrvalue);
        case Stmt::UnaryOperatorClass:
            return trans_unary_operator(c, result_used, block, (UnaryOperator *)stmt);
        case Stmt::DeclStmtClass:
            return trans_local_declaration(c, block, (DeclStmt *)stmt);
        case Stmt::WhileStmtClass:
            return trans_while_loop(c, block, (WhileStmt *)stmt);
        case Stmt::IfStmtClass:
            return trans_if_statement(c, block, (IfStmt *)stmt);
        case Stmt::CallExprClass:
            return trans_call_expr(c, result_used, block, (CallExpr *)stmt);
        case Stmt::NullStmtClass:
            return skip_add_to_block_node;
        case Stmt::MemberExprClass:
            return trans_member_expr(c, block, (MemberExpr *)stmt);
        case Stmt::ArraySubscriptExprClass:
            return trans_array_subscript_expr(c, block, (ArraySubscriptExpr *)stmt);
        case Stmt::CStyleCastExprClass:
            return trans_c_style_cast_expr(c, result_used, block, (CStyleCastExpr *)stmt, lrvalue);
        case Stmt::UnaryExprOrTypeTraitExprClass:
            return trans_unary_expr_or_type_trait_expr(c, block, (UnaryExprOrTypeTraitExpr *)stmt);
        case Stmt::CaseStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CaseStmtClass");
            return nullptr;
        case Stmt::DefaultStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C DefaultStmtClass");
            return nullptr;
        case Stmt::SwitchStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C SwitchStmtClass");
            return nullptr;
        case Stmt::NoStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C NoStmtClass");
            return nullptr;
        case Stmt::GCCAsmStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C GCCAsmStmtClass");
            return nullptr;
        case Stmt::MSAsmStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C MSAsmStmtClass");
            return nullptr;
        case Stmt::AttributedStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C AttributedStmtClass");
            return nullptr;
        case Stmt::BreakStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C BreakStmtClass");
            return nullptr;
        case Stmt::CXXCatchStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXCatchStmtClass");
            return nullptr;
        case Stmt::CXXForRangeStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXForRangeStmtClass");
            return nullptr;
        case Stmt::CXXTryStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXTryStmtClass");
            return nullptr;
        case Stmt::CapturedStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CapturedStmtClass");
            return nullptr;
        case Stmt::ContinueStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ContinueStmtClass");
            return nullptr;
        case Stmt::CoreturnStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CoreturnStmtClass");
            return nullptr;
        case Stmt::CoroutineBodyStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CoroutineBodyStmtClass");
            return nullptr;
        case Stmt::DoStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C DoStmtClass");
            return nullptr;
        case Stmt::BinaryConditionalOperatorClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C BinaryConditionalOperatorClass");
            return nullptr;
        case Stmt::AddrLabelExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C AddrLabelExprClass");
            return nullptr;
        case Stmt::ArrayInitIndexExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ArrayInitIndexExprClass");
            return nullptr;
        case Stmt::ArrayInitLoopExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ArrayInitLoopExprClass");
            return nullptr;
        case Stmt::ArrayTypeTraitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ArrayTypeTraitExprClass");
            return nullptr;
        case Stmt::AsTypeExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C AsTypeExprClass");
            return nullptr;
        case Stmt::AtomicExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C AtomicExprClass");
            return nullptr;
        case Stmt::BlockExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C BlockExprClass");
            return nullptr;
        case Stmt::CXXBindTemporaryExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXBindTemporaryExprClass");
            return nullptr;
        case Stmt::CXXBoolLiteralExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXBoolLiteralExprClass");
            return nullptr;
        case Stmt::CXXConstructExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXConstructExprClass");
            return nullptr;
        case Stmt::CXXTemporaryObjectExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXTemporaryObjectExprClass");
            return nullptr;
        case Stmt::CXXDefaultArgExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXDefaultArgExprClass");
            return nullptr;
        case Stmt::CXXDefaultInitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXDefaultInitExprClass");
            return nullptr;
        case Stmt::CXXDeleteExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXDeleteExprClass");
            return nullptr;
        case Stmt::CXXDependentScopeMemberExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXDependentScopeMemberExprClass");
            return nullptr;
        case Stmt::CXXFoldExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXFoldExprClass");
            return nullptr;
        case Stmt::CXXInheritedCtorInitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXInheritedCtorInitExprClass");
            return nullptr;
        case Stmt::CXXNewExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXNewExprClass");
            return nullptr;
        case Stmt::CXXNoexceptExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXNoexceptExprClass");
            return nullptr;
        case Stmt::CXXNullPtrLiteralExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXNullPtrLiteralExprClass");
            return nullptr;
        case Stmt::CXXPseudoDestructorExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXPseudoDestructorExprClass");
            return nullptr;
        case Stmt::CXXScalarValueInitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXScalarValueInitExprClass");
            return nullptr;
        case Stmt::CXXStdInitializerListExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXStdInitializerListExprClass");
            return nullptr;
        case Stmt::CXXThisExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXThisExprClass");
            return nullptr;
        case Stmt::CXXThrowExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXThrowExprClass");
            return nullptr;
        case Stmt::CXXTypeidExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXTypeidExprClass");
            return nullptr;
        case Stmt::CXXUnresolvedConstructExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXUnresolvedConstructExprClass");
            return nullptr;
        case Stmt::CXXUuidofExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXUuidofExprClass");
            return nullptr;
        case Stmt::CUDAKernelCallExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CUDAKernelCallExprClass");
            return nullptr;
        case Stmt::CXXMemberCallExprClass:
            (void)result_used;
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXMemberCallExprClass");
            return nullptr;
        case Stmt::CXXOperatorCallExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXOperatorCallExprClass");
            return nullptr;
        case Stmt::UserDefinedLiteralClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C UserDefinedLiteralClass");
            return nullptr;
        case Stmt::CXXFunctionalCastExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXFunctionalCastExprClass");
            return nullptr;
        case Stmt::CXXConstCastExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXConstCastExprClass");
            return nullptr;
        case Stmt::CXXDynamicCastExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXDynamicCastExprClass");
            return nullptr;
        case Stmt::CXXReinterpretCastExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXReinterpretCastExprClass");
            return nullptr;
        case Stmt::CXXStaticCastExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXStaticCastExprClass");
            return nullptr;
        case Stmt::ObjCBridgedCastExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCBridgedCastExprClass");
            return nullptr;
        case Stmt::CharacterLiteralClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CharacterLiteralClass");
            return nullptr;
        case Stmt::ChooseExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ChooseExprClass");
            return nullptr;
        case Stmt::CompoundLiteralExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CompoundLiteralExprClass");
            return nullptr;
        case Stmt::ConvertVectorExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ConvertVectorExprClass");
            return nullptr;
        case Stmt::CoawaitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CoawaitExprClass");
            return nullptr;
        case Stmt::CoyieldExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CoyieldExprClass");
            return nullptr;
        case Stmt::DependentCoawaitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C DependentCoawaitExprClass");
            return nullptr;
        case Stmt::DependentScopeDeclRefExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C DependentScopeDeclRefExprClass");
            return nullptr;
        case Stmt::DesignatedInitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C DesignatedInitExprClass");
            return nullptr;
        case Stmt::DesignatedInitUpdateExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C DesignatedInitUpdateExprClass");
            return nullptr;
        case Stmt::ExprWithCleanupsClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ExprWithCleanupsClass");
            return nullptr;
        case Stmt::ExpressionTraitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ExpressionTraitExprClass");
            return nullptr;
        case Stmt::ExtVectorElementExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ExtVectorElementExprClass");
            return nullptr;
        case Stmt::FloatingLiteralClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C FloatingLiteralClass");
            return nullptr;
        case Stmt::FunctionParmPackExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C FunctionParmPackExprClass");
            return nullptr;
        case Stmt::GNUNullExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C GNUNullExprClass");
            return nullptr;
        case Stmt::GenericSelectionExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C GenericSelectionExprClass");
            return nullptr;
        case Stmt::ImaginaryLiteralClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ImaginaryLiteralClass");
            return nullptr;
        case Stmt::ImplicitValueInitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ImplicitValueInitExprClass");
            return nullptr;
        case Stmt::InitListExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C InitListExprClass");
            return nullptr;
        case Stmt::LambdaExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C LambdaExprClass");
            return nullptr;
        case Stmt::MSPropertyRefExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C MSPropertyRefExprClass");
            return nullptr;
        case Stmt::MSPropertySubscriptExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C MSPropertySubscriptExprClass");
            return nullptr;
        case Stmt::MaterializeTemporaryExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C MaterializeTemporaryExprClass");
            return nullptr;
        case Stmt::NoInitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C NoInitExprClass");
            return nullptr;
        case Stmt::OMPArraySectionExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPArraySectionExprClass");
            return nullptr;
        case Stmt::ObjCArrayLiteralClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCArrayLiteralClass");
            return nullptr;
        case Stmt::ObjCAvailabilityCheckExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCAvailabilityCheckExprClass");
            return nullptr;
        case Stmt::ObjCBoolLiteralExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCBoolLiteralExprClass");
            return nullptr;
        case Stmt::ObjCBoxedExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCBoxedExprClass");
            return nullptr;
        case Stmt::ObjCDictionaryLiteralClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCDictionaryLiteralClass");
            return nullptr;
        case Stmt::ObjCEncodeExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCEncodeExprClass");
            return nullptr;
        case Stmt::ObjCIndirectCopyRestoreExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCIndirectCopyRestoreExprClass");
            return nullptr;
        case Stmt::ObjCIsaExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCIsaExprClass");
            return nullptr;
        case Stmt::ObjCIvarRefExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCIvarRefExprClass");
            return nullptr;
        case Stmt::ObjCMessageExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCMessageExprClass");
            return nullptr;
        case Stmt::ObjCPropertyRefExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCPropertyRefExprClass");
            return nullptr;
        case Stmt::ObjCProtocolExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCProtocolExprClass");
            return nullptr;
        case Stmt::ObjCSelectorExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCSelectorExprClass");
            return nullptr;
        case Stmt::ObjCStringLiteralClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCStringLiteralClass");
            return nullptr;
        case Stmt::ObjCSubscriptRefExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCSubscriptRefExprClass");
            return nullptr;
        case Stmt::OffsetOfExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OffsetOfExprClass");
            return nullptr;
        case Stmt::OpaqueValueExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OpaqueValueExprClass");
            return nullptr;
        case Stmt::UnresolvedLookupExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C UnresolvedLookupExprClass");
            return nullptr;
        case Stmt::UnresolvedMemberExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C UnresolvedMemberExprClass");
            return nullptr;
        case Stmt::PackExpansionExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C PackExpansionExprClass");
            return nullptr;
        case Stmt::ParenExprClass:
            return trans_expr(c, result_used, block, ((ParenExpr*)stmt)->getSubExpr(), lrvalue);
        case Stmt::ParenListExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ParenListExprClass");
            return nullptr;
        case Stmt::PredefinedExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C PredefinedExprClass");
            return nullptr;
        case Stmt::PseudoObjectExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C PseudoObjectExprClass");
            return nullptr;
        case Stmt::ShuffleVectorExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ShuffleVectorExprClass");
            return nullptr;
        case Stmt::SizeOfPackExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C SizeOfPackExprClass");
            return nullptr;
        case Stmt::StmtExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C StmtExprClass");
            return nullptr;
        case Stmt::StringLiteralClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C StringLiteralClass");
            return nullptr;
        case Stmt::SubstNonTypeTemplateParmExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C SubstNonTypeTemplateParmExprClass");
            return nullptr;
        case Stmt::SubstNonTypeTemplateParmPackExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C SubstNonTypeTemplateParmPackExprClass");
            return nullptr;
        case Stmt::TypeTraitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C TypeTraitExprClass");
            return nullptr;
        case Stmt::TypoExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C TypoExprClass");
            return nullptr;
        case Stmt::VAArgExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C VAArgExprClass");
            return nullptr;
        case Stmt::ForStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ForStmtClass");
            return nullptr;
        case Stmt::GotoStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C GotoStmtClass");
            return nullptr;
        case Stmt::IndirectGotoStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C IndirectGotoStmtClass");
            return nullptr;
        case Stmt::LabelStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C LabelStmtClass");
            return nullptr;
        case Stmt::MSDependentExistsStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C MSDependentExistsStmtClass");
            return nullptr;
        case Stmt::OMPAtomicDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPAtomicDirectiveClass");
            return nullptr;
        case Stmt::OMPBarrierDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPBarrierDirectiveClass");
            return nullptr;
        case Stmt::OMPCancelDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPCancelDirectiveClass");
            return nullptr;
        case Stmt::OMPCancellationPointDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPCancellationPointDirectiveClass");
            return nullptr;
        case Stmt::OMPCriticalDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPCriticalDirectiveClass");
            return nullptr;
        case Stmt::OMPFlushDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPFlushDirectiveClass");
            return nullptr;
        case Stmt::OMPDistributeDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPDistributeDirectiveClass");
            return nullptr;
        case Stmt::OMPDistributeParallelForDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPDistributeParallelForDirectiveClass");
            return nullptr;
        case Stmt::OMPDistributeParallelForSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPDistributeParallelForSimdDirectiveClass");
            return nullptr;
        case Stmt::OMPDistributeSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPDistributeSimdDirectiveClass");
            return nullptr;
        case Stmt::OMPForDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPForDirectiveClass");
            return nullptr;
        case Stmt::OMPForSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPForSimdDirectiveClass");
            return nullptr;
        case Stmt::OMPParallelForDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPParallelForDirectiveClass");
            return nullptr;
        case Stmt::OMPParallelForSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPParallelForSimdDirectiveClass");
            return nullptr;
        case Stmt::OMPSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPSimdDirectiveClass");
            return nullptr;
        case Stmt::OMPTargetParallelForSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetParallelForSimdDirectiveClass");
            return nullptr;
        case Stmt::OMPTargetSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetSimdDirectiveClass");
            return nullptr;
        case Stmt::OMPTargetTeamsDistributeDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetTeamsDistributeDirectiveClass");
            return nullptr;
        case Stmt::OMPTargetTeamsDistributeParallelForDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetTeamsDistributeParallelForDirectiveClass");
            return nullptr;
        case Stmt::OMPTargetTeamsDistributeParallelForSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetTeamsDistributeParallelForSimdDirectiveClass");
            return nullptr;
        case Stmt::OMPTargetTeamsDistributeSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetTeamsDistributeSimdDirectiveClass");
            return nullptr;
        case Stmt::OMPTaskLoopDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTaskLoopDirectiveClass");
            return nullptr;
        case Stmt::OMPTaskLoopSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTaskLoopSimdDirectiveClass");
            return nullptr;
        case Stmt::OMPTeamsDistributeDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTeamsDistributeDirectiveClass");
            return nullptr;
        case Stmt::OMPTeamsDistributeParallelForDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTeamsDistributeParallelForDirectiveClass");
            return nullptr;
        case Stmt::OMPTeamsDistributeParallelForSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTeamsDistributeParallelForSimdDirectiveClass");
            return nullptr;
        case Stmt::OMPTeamsDistributeSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTeamsDistributeSimdDirectiveClass");
            return nullptr;
        case Stmt::OMPMasterDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPMasterDirectiveClass");
            return nullptr;
        case Stmt::OMPOrderedDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPOrderedDirectiveClass");
            return nullptr;
        case Stmt::OMPParallelDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPParallelDirectiveClass");
            return nullptr;
        case Stmt::OMPParallelSectionsDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPParallelSectionsDirectiveClass");
            return nullptr;
        case Stmt::OMPSectionDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPSectionDirectiveClass");
            return nullptr;
        case Stmt::OMPSectionsDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPSectionsDirectiveClass");
            return nullptr;
        case Stmt::OMPSingleDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPSingleDirectiveClass");
            return nullptr;
        case Stmt::OMPTargetDataDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetDataDirectiveClass");
            return nullptr;
        case Stmt::OMPTargetDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetDirectiveClass");
            return nullptr;
        case Stmt::OMPTargetEnterDataDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetEnterDataDirectiveClass");
            return nullptr;
        case Stmt::OMPTargetExitDataDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetExitDataDirectiveClass");
            return nullptr;
        case Stmt::OMPTargetParallelDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetParallelDirectiveClass");
            return nullptr;
        case Stmt::OMPTargetParallelForDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetParallelForDirectiveClass");
            return nullptr;
        case Stmt::OMPTargetTeamsDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetTeamsDirectiveClass");
            return nullptr;
        case Stmt::OMPTargetUpdateDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetUpdateDirectiveClass");
            return nullptr;
        case Stmt::OMPTaskDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTaskDirectiveClass");
            return nullptr;
        case Stmt::OMPTaskgroupDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTaskgroupDirectiveClass");
            return nullptr;
        case Stmt::OMPTaskwaitDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTaskwaitDirectiveClass");
            return nullptr;
        case Stmt::OMPTaskyieldDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTaskyieldDirectiveClass");
            return nullptr;
        case Stmt::OMPTeamsDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTeamsDirectiveClass");
            return nullptr;
        case Stmt::ObjCAtCatchStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCAtCatchStmtClass");
            return nullptr;
        case Stmt::ObjCAtFinallyStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCAtFinallyStmtClass");
            return nullptr;
        case Stmt::ObjCAtSynchronizedStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCAtSynchronizedStmtClass");
            return nullptr;
        case Stmt::ObjCAtThrowStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCAtThrowStmtClass");
            return nullptr;
        case Stmt::ObjCAtTryStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCAtTryStmtClass");
            return nullptr;
        case Stmt::ObjCAutoreleasePoolStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCAutoreleasePoolStmtClass");
            return nullptr;
        case Stmt::ObjCForCollectionStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCForCollectionStmtClass");
            return nullptr;
        case Stmt::SEHExceptStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C SEHExceptStmtClass");
            return nullptr;
        case Stmt::SEHFinallyStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C SEHFinallyStmtClass");
            return nullptr;
        case Stmt::SEHLeaveStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C SEHLeaveStmtClass");
            return nullptr;
        case Stmt::SEHTryStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C SEHTryStmtClass");
            return nullptr;
    }
    zig_unreachable();
}

static void visit_fn_decl(Context *c, const FunctionDecl *fn_decl) {
    Buf *fn_name = buf_create_from_str(decl_name(fn_decl));

    if (get_global(c, fn_name)) {
        // we already saw this function
        return;
    }

    AstNode *proto_node = trans_qual_type(c, fn_decl->getType(), fn_decl->getLocation());
    if (proto_node == nullptr) {
        emit_warning(c, fn_decl->getLocation(), "unable to resolve prototype of function '%s'", buf_ptr(fn_name));
        return;
    }

    proto_node->data.fn_proto.name = fn_name;
    proto_node->data.fn_proto.is_extern = !fn_decl->hasBody();

    StorageClass sc = fn_decl->getStorageClass();
    if (sc == SC_None) {
        proto_node->data.fn_proto.visib_mod = fn_decl->hasBody() ? VisibModExport : c->visib_mod;
    } else if (sc == SC_Extern || sc == SC_Static) {
        proto_node->data.fn_proto.visib_mod = c->visib_mod;
    } else if (sc == SC_PrivateExtern) {
        emit_warning(c, fn_decl->getLocation(), "unsupported storage class: private extern");
        return;
    } else {
        emit_warning(c, fn_decl->getLocation(), "unsupported storage class: unknown");
        return;
    }

    for (size_t i = 0; i < proto_node->data.fn_proto.params.length; i += 1) {
        AstNode *param_node = proto_node->data.fn_proto.params.at(i);
        const ParmVarDecl *param = fn_decl->getParamDecl(i);
        const char *name = decl_name(param);
        Buf *proto_param_name;
        if (strlen(name) != 0) {
            proto_param_name = buf_create_from_str(name);
        } else {
            proto_param_name = param_node->data.param_decl.name;
            if (proto_param_name == nullptr) {
                proto_param_name = buf_sprintf("arg%" ZIG_PRI_usize "", i);
            }
        }
        param_node->data.param_decl.name = proto_param_name;
    }

    if (!fn_decl->hasBody()) {
        // just a prototype
        c->root->data.root.top_level_decls.append(proto_node);
        return;
    }

    // actual function definition with body
    c->ptr_params.clear();
    Stmt *body = fn_decl->getBody();
    AstNode *actual_body_node = trans_stmt(c, false, nullptr, body, TransRValue);
    assert(actual_body_node != skip_add_to_block_node);
    if (actual_body_node == nullptr) {
        emit_warning(c, fn_decl->getLocation(), "unable to translate function");
        return;
    }

    // it worked

    assert(actual_body_node->type == NodeTypeBlock);
    AstNode *body_node_with_param_inits = trans_create_node(c, NodeTypeBlock);

    for (size_t i = 0; i < proto_node->data.fn_proto.params.length; i += 1) {
        AstNode *param_node = proto_node->data.fn_proto.params.at(i);
        Buf *good_name = param_node->data.param_decl.name;

        if (c->ptr_params.maybe_get(good_name) != nullptr) {
            // TODO: avoid name collisions
            Buf *mangled_name = buf_sprintf("_arg_%s", buf_ptr(good_name));
            param_node->data.param_decl.name = mangled_name;

            // var c_name = _mangled_name;
            AstNode *parameter_init = trans_create_node_var_decl_local(c, false, good_name, nullptr, trans_create_node_symbol(c, mangled_name));

            body_node_with_param_inits->data.block.statements.append(parameter_init);
        }
    }

    for (size_t i = 0; i < actual_body_node->data.block.statements.length; i += 1) {
        body_node_with_param_inits->data.block.statements.append(actual_body_node->data.block.statements.at(i));
    }

    AstNode *fn_def_node = trans_create_node(c, NodeTypeFnDef);
    fn_def_node->data.fn_def.fn_proto = proto_node;
    fn_def_node->data.fn_def.body = body_node_with_param_inits;

    proto_node->data.fn_proto.fn_def_node = fn_def_node;
    c->root->data.root.top_level_decls.append(fn_def_node);
}

static AstNode *resolve_typdef_as_builtin(Context *c, const TypedefNameDecl *typedef_decl, const char *primitive_name) {
    AstNode *node = trans_create_node_symbol_str(c, primitive_name);
    c->decl_table.put(typedef_decl, node);
    return node;
}

static AstNode *resolve_typedef_decl(Context *c, const TypedefNameDecl *typedef_decl) {
    auto existing_entry = c->decl_table.maybe_get((void*)typedef_decl);
    if (existing_entry) {
        return existing_entry->value;
    }

    QualType child_qt = typedef_decl->getUnderlyingType();
    Buf *type_name = buf_create_from_str(decl_name(typedef_decl));

    if (buf_eql_str(type_name, "uint8_t")) {
        return resolve_typdef_as_builtin(c, typedef_decl, "u8");
    } else if (buf_eql_str(type_name, "int8_t")) {
        return resolve_typdef_as_builtin(c, typedef_decl, "i8");
    } else if (buf_eql_str(type_name, "uint16_t")) {
        return resolve_typdef_as_builtin(c, typedef_decl, "u16");
    } else if (buf_eql_str(type_name, "int16_t")) {
        return resolve_typdef_as_builtin(c, typedef_decl, "i16");
    } else if (buf_eql_str(type_name, "uint32_t")) {
        return resolve_typdef_as_builtin(c, typedef_decl, "u32");
    } else if (buf_eql_str(type_name, "int32_t")) {
        return resolve_typdef_as_builtin(c, typedef_decl, "i32");
    } else if (buf_eql_str(type_name, "uint64_t")) {
        return resolve_typdef_as_builtin(c, typedef_decl, "u64");
    } else if (buf_eql_str(type_name, "int64_t")) {
        return resolve_typdef_as_builtin(c, typedef_decl, "i64");
    } else if (buf_eql_str(type_name, "intptr_t")) {
        return resolve_typdef_as_builtin(c, typedef_decl, "isize");
    } else if (buf_eql_str(type_name, "uintptr_t")) {
        return resolve_typdef_as_builtin(c, typedef_decl, "usize");
    } else if (buf_eql_str(type_name, "ssize_t")) {
        return resolve_typdef_as_builtin(c, typedef_decl, "isize");
    } else if (buf_eql_str(type_name, "size_t")) {
        return resolve_typdef_as_builtin(c, typedef_decl, "usize");
    }

    // if the underlying type is anonymous, we can special case it to just
    // use the name of this typedef
    // TODO

    AstNode *type_node = trans_qual_type(c, child_qt, typedef_decl->getLocation());
    if (type_node == nullptr) {
        emit_warning(c, typedef_decl->getLocation(), "typedef %s - unresolved child type", buf_ptr(type_name));
        c->decl_table.put(typedef_decl, nullptr);
        return nullptr;
    }
    add_global_var(c, type_name, type_node);

    AstNode *symbol_node = trans_create_node_symbol(c, type_name);
    c->decl_table.put(typedef_decl, symbol_node);
    return symbol_node;
}

struct AstNode *demote_enum_to_opaque(Context *c, const EnumDecl *enum_decl,
        Buf *full_type_name, Buf *bare_name)
{
    AstNode *opaque_node = trans_create_node_opaque(c);
    if (full_type_name == nullptr) {
        c->decl_table.put(enum_decl->getCanonicalDecl(), opaque_node);
        return opaque_node;
    }
    AstNode *symbol_node = trans_create_node_symbol(c, full_type_name);
    add_global_weak_alias(c, bare_name, full_type_name);
    add_global_var(c, full_type_name, opaque_node);
    c->decl_table.put(enum_decl->getCanonicalDecl(), symbol_node);
    return symbol_node;
}

static AstNode *resolve_enum_decl(Context *c, const EnumDecl *enum_decl) {
    auto existing_entry = c->decl_table.maybe_get((void*)enum_decl->getCanonicalDecl());
    if (existing_entry) {
        return existing_entry->value;
    }

    const char *raw_name = decl_name(enum_decl);
    bool is_anonymous = (raw_name[0] == 0);
    Buf *bare_name = is_anonymous ? nullptr : buf_create_from_str(raw_name);
    Buf *full_type_name = is_anonymous ? nullptr : buf_sprintf("enum_%s", buf_ptr(bare_name));

    const EnumDecl *enum_def = enum_decl->getDefinition();
    if (!enum_def) {
        return demote_enum_to_opaque(c, enum_decl, full_type_name, bare_name);
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

    AstNode *tag_int_type = trans_qual_type(c, enum_decl->getIntegerType(), enum_decl->getLocation());
    assert(tag_int_type);

    if (pure_enum) {
        AstNode *enum_node = trans_create_node(c, NodeTypeContainerDecl);
        enum_node->data.container_decl.kind = ContainerKindEnum;
        enum_node->data.container_decl.layout = ContainerLayoutExtern;
        enum_node->data.container_decl.init_arg_expr = tag_int_type;

        enum_node->data.container_decl.fields.resize(field_count);
        uint32_t i = 0;
        for (auto it = enum_def->enumerator_begin(),
                it_end = enum_def->enumerator_end();
                it != it_end; ++it, i += 1)
        {
            const EnumConstantDecl *enum_const = *it;

            Buf *enum_val_name = buf_create_from_str(decl_name(enum_const));
            Buf *field_name;
            if (bare_name != nullptr && buf_starts_with_buf(enum_val_name, bare_name)) {
                field_name = buf_slice(enum_val_name, buf_len(bare_name), buf_len(enum_val_name));
            } else {
                field_name = enum_val_name;
            }

            AstNode *field_node = trans_create_node(c, NodeTypeStructField);
            field_node->data.struct_field.name = field_name;
            field_node->data.struct_field.type = nullptr;
            enum_node->data.container_decl.fields.items[i] = field_node;

            // in C each enum value is in the global namespace. so we put them there too.
            // at this point we can rely on the enum emitting successfully
            if (is_anonymous) {
                AstNode *lit_node = trans_create_node_unsigned(c, i);
                add_global_var(c, enum_val_name, lit_node);
            } else {
                AstNode *field_access_node = trans_create_node_field_access(c,
                        trans_create_node_symbol(c, full_type_name), field_name);
                add_global_var(c, enum_val_name, field_access_node);
            }
        }

        if (is_anonymous) {
            c->decl_table.put(enum_decl->getCanonicalDecl(), enum_node);
            return enum_node;
        } else {
            AstNode *symbol_node = trans_create_node_symbol(c, full_type_name);
            add_global_weak_alias(c, bare_name, full_type_name);
            add_global_var(c, full_type_name, enum_node);
            c->decl_table.put(enum_decl->getCanonicalDecl(), symbol_node);
            return enum_node;
        }
    }

    // TODO after issue #305 is solved, make this be an enum with tag_int_type
    // as the integer type and set the custom enum values
    AstNode *enum_node = tag_int_type;


    // add variables for all the values with enum_node
    for (auto it = enum_def->enumerator_begin(),
            it_end = enum_def->enumerator_end();
            it != it_end; ++it)
    {
        const EnumConstantDecl *enum_const = *it;

        Buf *enum_val_name = buf_create_from_str(decl_name(enum_const));
        AstNode *int_node = trans_create_node_apint(c, enum_const->getInitVal());
        AstNode *var_node = add_global_var(c, enum_val_name, int_node);
        var_node->data.variable_declaration.type = tag_int_type;
    }

    if (is_anonymous) {
        c->decl_table.put(enum_decl->getCanonicalDecl(), enum_node);
        return enum_node;
    } else {
        AstNode *symbol_node = trans_create_node_symbol(c, full_type_name);
        add_global_weak_alias(c, bare_name, full_type_name);
        add_global_var(c, full_type_name, enum_node);
        return symbol_node;
    }
}

static AstNode *demote_struct_to_opaque(Context *c, const RecordDecl *record_decl,
        Buf *full_type_name, Buf *bare_name)
{
    AstNode *opaque_node = trans_create_node_opaque(c);
    if (full_type_name == nullptr) {
        c->decl_table.put(record_decl->getCanonicalDecl(), opaque_node);
        return opaque_node;
    }
    AstNode *symbol_node = trans_create_node_symbol(c, full_type_name);
    add_global_weak_alias(c, bare_name, full_type_name);
    add_global_var(c, full_type_name, opaque_node);
    c->decl_table.put(record_decl->getCanonicalDecl(), symbol_node);
    return symbol_node;
}

static AstNode *resolve_record_decl(Context *c, const RecordDecl *record_decl) {
    auto existing_entry = c->decl_table.maybe_get((void*)record_decl->getCanonicalDecl());
    if (existing_entry) {
        return existing_entry->value;
    }

    const char *raw_name = decl_name(record_decl);

    if (!record_decl->isStruct()) {
        emit_warning(c, record_decl->getLocation(), "skipping record %s, not a struct", raw_name);
        c->decl_table.put(record_decl->getCanonicalDecl(), nullptr);
        return nullptr;
    }

    bool is_anonymous = record_decl->isAnonymousStructOrUnion() || raw_name[0] == 0;
    Buf *bare_name = is_anonymous ? nullptr : buf_create_from_str(raw_name);
    Buf *full_type_name = (bare_name == nullptr) ? nullptr : buf_sprintf("struct_%s", buf_ptr(bare_name));

    RecordDecl *record_def = record_decl->getDefinition();
    if (record_def == nullptr) {
        return demote_struct_to_opaque(c, record_decl, full_type_name, bare_name);
    }

    // count fields and validate
    uint32_t field_count = 0;
    for (auto it = record_def->field_begin(),
              it_end = record_def->field_end();
              it != it_end; ++it, field_count += 1)
    {
        const FieldDecl *field_decl = *it;

        if (field_decl->isBitField()) {
            emit_warning(c, field_decl->getLocation(), "struct %s demoted to opaque type - has bitfield",
                    is_anonymous ? "(anon)" : buf_ptr(bare_name));
            return demote_struct_to_opaque(c, record_decl, full_type_name, bare_name);
        }
    }

    AstNode *struct_node = trans_create_node(c, NodeTypeContainerDecl);
    struct_node->data.container_decl.kind = ContainerKindStruct;
    struct_node->data.container_decl.layout = ContainerLayoutExtern;

    // TODO handle attribute packed

    struct_node->data.container_decl.fields.resize(field_count);

    // must be before fields in case a circular reference happens
    if (is_anonymous) {
        c->decl_table.put(record_decl->getCanonicalDecl(), struct_node);
    } else {
        c->decl_table.put(record_decl->getCanonicalDecl(), trans_create_node_symbol(c, full_type_name));
    }

    uint32_t i = 0;
    for (auto it = record_def->field_begin(),
              it_end = record_def->field_end();
              it != it_end; ++it, i += 1)
    {
        const FieldDecl *field_decl = *it;

        AstNode *field_node = trans_create_node(c, NodeTypeStructField);
        field_node->data.struct_field.name = buf_create_from_str(decl_name(field_decl));
        field_node->data.struct_field.type = trans_qual_type(c, field_decl->getType(), field_decl->getLocation());

        if (field_node->data.struct_field.type == nullptr) {
            emit_warning(c, field_decl->getLocation(),
                    "struct %s demoted to opaque type - unresolved type",
                    is_anonymous ? "(anon)" : buf_ptr(bare_name));

            return demote_struct_to_opaque(c, record_decl, full_type_name, bare_name);
        }

        struct_node->data.container_decl.fields.items[i] = field_node;
    }

    if (is_anonymous) {
        return struct_node;
    } else {
        add_global_weak_alias(c, bare_name, full_type_name);
        add_global_var(c, full_type_name, struct_node);
        return trans_create_node_symbol(c, full_type_name);
    }
}

static void visit_var_decl(Context *c, const VarDecl *var_decl) {
    Buf *name = buf_create_from_str(decl_name(var_decl));

    switch (var_decl->getTLSKind()) {
        case VarDecl::TLS_None:
            break;
        case VarDecl::TLS_Static:
            emit_warning(c, var_decl->getLocation(),
                    "ignoring variable '%s' - static thread local storage", buf_ptr(name));
            return;
        case VarDecl::TLS_Dynamic:
            emit_warning(c, var_decl->getLocation(),
                    "ignoring variable '%s' - dynamic thread local storage", buf_ptr(name));
            return;
    }

    QualType qt = var_decl->getType();
    AstNode *var_type = trans_qual_type(c, qt, var_decl->getLocation());
    if (var_type == nullptr) {
        emit_warning(c, var_decl->getLocation(), "ignoring variable '%s' - unresolved type", buf_ptr(name));
        return;
    }

    bool is_extern = var_decl->hasExternalStorage();
    bool is_static = var_decl->isFileVarDecl();
    bool is_const = qt.isConstQualified();

    if (is_static && !is_extern) {
        AstNode *init_node;
        if (var_decl->hasInit()) {
            APValue *ap_value = var_decl->evaluateValue();
            if (ap_value == nullptr) {
                emit_warning(c, var_decl->getLocation(),
                        "ignoring variable '%s' - unable to evaluate initializer", buf_ptr(name));
                return;
            }
            switch (ap_value->getKind()) {
                case APValue::Int:
                    init_node = trans_create_node_apint(c, ap_value->getInt());
                    break;
                case APValue::Uninitialized:
                    init_node = trans_create_node(c, NodeTypeUndefinedLiteral);
                    break;
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
                    emit_warning(c, var_decl->getLocation(),
                            "ignoring variable '%s' - unrecognized initializer value kind", buf_ptr(name));
                    return;
            }
        } else {
            init_node = trans_create_node(c, NodeTypeUndefinedLiteral);
        }

        AstNode *var_node = trans_create_node_var_decl_global(c, is_const, name, var_type, init_node);
        c->root->data.root.top_level_decls.append(var_node);
        return;
    }

    if (is_extern) {
        AstNode *var_node = trans_create_node_var_decl_global(c, is_const, name, var_type, nullptr);
        var_node->data.variable_declaration.is_extern = true;
        c->root->data.root.top_level_decls.append(var_node);
        return;
    }

    emit_warning(c, var_decl->getLocation(),
        "ignoring variable '%s' - non-extern, non-static variable", buf_ptr(name));
    return;
}

static bool decl_visitor(void *context, const Decl *decl) {
    Context *c = (Context*)context;

    switch (decl->getKind()) {
        case Decl::Function:
            visit_fn_decl(c, static_cast<const FunctionDecl*>(decl));
            break;
        case Decl::Typedef:
            resolve_typedef_decl(c, static_cast<const TypedefNameDecl *>(decl));
            break;
        case Decl::Enum:
            resolve_enum_decl(c, static_cast<const EnumDecl *>(decl));
            break;
        case Decl::Record:
            resolve_record_decl(c, static_cast<const RecordDecl *>(decl));
            break;
        case Decl::Var:
            visit_var_decl(c, static_cast<const VarDecl *>(decl));
            break;
        default:
            emit_warning(c, decl->getLocation(), "ignoring %s decl", decl->getDeclKindName());
    }

    return true;
}

static bool name_exists(Context *c, Buf *name) {
    return get_global(c, name) != nullptr;
}

static void render_aliases(Context *c) {
    for (size_t i = 0; i < c->aliases.length; i += 1) {
        Alias *alias = &c->aliases.at(i);
        if (name_exists(c, alias->new_name))
            continue;

        add_global_var(c, alias->new_name, trans_create_node_symbol(c, alias->canon_name));
    }
}

static void render_macros(Context *c) {
    auto it = c->macro_table.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        AstNode *value_node = entry->value;
        if (value_node->type == NodeTypeFnDef) {
            c->root->data.root.top_level_decls.append(value_node);
        } else {
            add_global_var(c, entry->key, value_node);
        }
    }
}

static AstNode *parse_ctok_num_lit(Context *c, CTokenize *ctok, size_t *tok_i, bool negate) {
    CTok *tok = &ctok->tokens.at(*tok_i);
    if (tok->id == CTokIdNumLitInt) {
        *tok_i += 1;
        switch (tok->data.num_lit_int.suffix) {
            case CNumLitSuffixNone:
                return trans_create_node_unsigned_negative(c, tok->data.num_lit_int.x, negate);
            case CNumLitSuffixL:
                return trans_create_node_unsigned_negative_type(c, tok->data.num_lit_int.x, negate, "c_long");
            case CNumLitSuffixU:
                return trans_create_node_unsigned_negative_type(c, tok->data.num_lit_int.x, negate, "c_uint");
            case CNumLitSuffixLU:
                return trans_create_node_unsigned_negative_type(c, tok->data.num_lit_int.x, negate, "c_ulong");
            case CNumLitSuffixLL:
                return trans_create_node_unsigned_negative_type(c, tok->data.num_lit_int.x, negate, "c_longlong");
            case CNumLitSuffixLLU:
                return trans_create_node_unsigned_negative_type(c, tok->data.num_lit_int.x, negate, "c_ulonglong");
        }
        zig_unreachable();
    } else if (tok->id == CTokIdNumLitFloat) {
        *tok_i += 1;
        double value = negate ? -tok->data.num_lit_float : tok->data.num_lit_float;
        return trans_create_node_float_lit(c, value);
    }
    return nullptr;
}

static AstNode *parse_ctok(Context *c, CTokenize *ctok, size_t *tok_i) {
    CTok *tok = &ctok->tokens.at(*tok_i);
    switch (tok->id) {
        case CTokIdCharLit:
            *tok_i += 1;
            return trans_create_node_unsigned(c, tok->data.char_lit);
        case CTokIdStrLit:
            *tok_i += 1;
            return trans_create_node_str_lit_c(c, buf_create_from_buf(&tok->data.str_lit));
        case CTokIdMinus:
            *tok_i += 1;
            return parse_ctok_num_lit(c, ctok, tok_i, true);
        case CTokIdNumLitInt:
        case CTokIdNumLitFloat:
            return parse_ctok_num_lit(c, ctok, tok_i, false);
        case CTokIdSymbol:
            {
                *tok_i += 1;
                Buf *symbol_name = buf_create_from_buf(&tok->data.symbol);
                return trans_create_node_symbol(c, symbol_name);
            }
        case CTokIdLParen:
            {
                *tok_i += 1;
                AstNode *inner_node = parse_ctok(c, ctok, tok_i);

                CTok *next_tok = &ctok->tokens.at(*tok_i);
                if (next_tok->id != CTokIdRParen) {
                    return nullptr;
                }
                *tok_i += 1;
                return inner_node;
            }
        case CTokIdEOF:
        case CTokIdRParen:
            // not able to make sense of this
            return nullptr;
    }
    zig_unreachable();
}

static void process_macro(Context *c, CTokenize *ctok, Buf *name, const char *char_ptr) {
    tokenize_c_macro(ctok, (const uint8_t *)char_ptr);

    if (ctok->error) {
        return;
    }

    size_t tok_i = 0;
    CTok *name_tok = &ctok->tokens.at(tok_i);
    assert(name_tok->id == CTokIdSymbol && buf_eql_buf(&name_tok->data.symbol, name));
    tok_i += 1;

    AstNode *result_node = parse_ctok(c, ctok, &tok_i);
    if (result_node == nullptr) {
        return;
    }
    CTok *eof_tok = &ctok->tokens.at(tok_i);
    if (eof_tok->id != CTokIdEOF) {
        return;
    }
    if (result_node->type == NodeTypeSymbol) {
        // if it equals itself, ignore. for example, from stdio.h:
        // #define stdin stdin
        Buf *symbol_name = result_node->data.symbol_expr.symbol;
        if (buf_eql_buf(name, symbol_name)) {
            return;
        }
        c->macro_symbols.append({name, symbol_name});
    } else {
        c->macro_table.put(name, result_node);
    }
}

static void process_symbol_macros(Context *c) {
    for (size_t i = 0; i < c->macro_symbols.length; i += 1) {
        MacroSymbol ms = c->macro_symbols.at(i);

        // Check if this macro aliases another top level declaration
        AstNode *existing_node = get_global(c, ms.value);
        if (!existing_node || name_exists(c, ms.name))
            continue;

        // If a macro aliases a global variable which is a function pointer, we conclude that
        // the macro is intended to represent a function that assumes the function pointer
        // variable is non-null and calls it.
        if (existing_node->type == NodeTypeVariableDeclaration) {
            AstNode *var_type = existing_node->data.variable_declaration.type;
            if (var_type != nullptr && var_type->type == NodeTypePrefixOpExpr &&
                var_type->data.prefix_op_expr.prefix_op == PrefixOpMaybe)
            {
                AstNode *fn_proto_node = var_type->data.prefix_op_expr.primary_expr;
                if (fn_proto_node->type == NodeTypeFnProto) {
                    AstNode *inline_fn_node = trans_create_node_inline_fn(c, ms.name, ms.value, fn_proto_node);
                    c->macro_table.put(ms.name, inline_fn_node);
                    continue;
                }
            }
        }

        add_global_var(c, ms.name, trans_create_node_symbol(c, ms.value));
    }
}

static void process_preprocessor_entities(Context *c, ASTUnit &unit) {
    CTokenize ctok = {{0}};

    // TODO if we see #undef, delete it from the table

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

                    const char *begin_c = c->source_manager->getCharacterData(begin_loc);
                    process_macro(c, &ctok, name, begin_c);
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
    c->decl_table.init(8);
    c->macro_table.init(8);
    c->ptr_params.init(8);
    c->codegen = codegen;
    c->source_node = source_node;

    ZigList<const char *> clang_argv = {0};

    clang_argv.append("-x");
    clang_argv.append("c");

    if (c->codegen->is_native_target) {
        char *ZIG_PARSEC_CFLAGS = getenv("ZIG_NATIVE_PARSEC_CFLAGS");
        if (ZIG_PARSEC_CFLAGS) {
            Buf tmp_buf = BUF_INIT;
            char *start = ZIG_PARSEC_CFLAGS;
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

    for (size_t i = 0; i < codegen->clang_argv_len; i += 1) {
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

    bool skip_function_bodies = false;
    bool only_local_decls = true;
    bool capture_diagnostics = true;
    bool user_files_are_volatile = true;
    bool allow_pch_with_compiler_errors = false;
    bool single_file_parse = false;
    bool for_serialization = false;
    const char *resources_path = ZIG_HEADERS_DIR;
    std::unique_ptr<ASTUnit> err_unit;
    std::unique_ptr<ASTUnit> ast_unit(ASTUnit::LoadFromCommandLine(
            &clang_argv.at(0), &clang_argv.last(),
            pch_container_ops, diags, resources_path,
            only_local_decls, capture_diagnostics, None, true, 0, TU_Complete,
            false, false, allow_pch_with_compiler_errors, skip_function_bodies,
            single_file_parse, user_files_are_volatile, for_serialization, None, &err_unit,
            nullptr));

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
            Buf *msg = buf_create_from_str((const char *)msg_str_ref.bytes_begin());
            FullSourceLoc fsl = it->getLocation();
            if (fsl.hasManager()) {
                FileID file_id = fsl.getFileID();
                StringRef filename = fsl.getManager().getFilename(fsl);
                unsigned line = fsl.getSpellingLineNumber() - 1;
                unsigned column = fsl.getSpellingColumnNumber() - 1;
                unsigned offset = fsl.getManager().getFileOffset(fsl);
                const char *source = (const char *)fsl.getManager().getBufferData(file_id).bytes_begin();
                Buf *path;
                if (filename.empty()) {
                    path = buf_alloc();
                } else {
                    path = buf_create_from_mem((const char *)filename.bytes_begin(), filename.size());
                }

                ErrorMsg *err_msg = err_msg_create_with_offset(path, line, column, offset, source, msg);

                c->errors->append(err_msg);
            } else {
                // NOTE the only known way this gets triggered right now is if you have a lot of errors
                // clang emits "too many errors emitted, stopping now"
                fprintf(stderr, "unexpected error from clang: %s\n", buf_ptr(msg));
            }
        }

        return 0;
    }

    c->ctx = &ast_unit->getASTContext();
    c->source_manager = &ast_unit->getSourceManager();
    c->root = trans_create_node(c, NodeTypeRoot);

    ast_unit->visitLocalTopLevelDecls(c, decl_visitor);

    process_preprocessor_entities(c, *ast_unit);

    process_symbol_macros(c);
    render_macros(c);
    render_aliases(c);

    import->root = c->root;

    return 0;
}
