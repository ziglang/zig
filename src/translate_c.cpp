/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "all_types.hpp"
#include "analyze.hpp"
#include "c_tokenizer.hpp"
#include "error.hpp"
#include "ir.hpp"
#include "os.hpp"
#include "translate_c.hpp"
#include "parser.hpp"


#include <clang/Frontend/ASTUnit.h>
#include <clang/Frontend/CompilerInstance.h>
#include <clang/AST/Expr.h>

#include <string.h>

using namespace clang;

struct Alias {
    Buf *new_name;
    Buf *canon_name;
};

enum TransScopeId {
    TransScopeIdSwitch,
    TransScopeIdVar,
    TransScopeIdBlock,
    TransScopeIdRoot,
    TransScopeIdWhile,
};

struct TransScope {
    TransScopeId id;
    TransScope *parent;
};

struct TransScopeSwitch {
    TransScope base;
    AstNode *switch_node;
    uint32_t case_index;
    bool found_default;
    Buf *end_label_name;
};

struct TransScopeVar {
    TransScope base;
    Buf *c_name;
    Buf *zig_name;
};

struct TransScopeBlock {
    TransScope base;
    AstNode *node;
};

struct TransScopeRoot {
    TransScope base;
};

struct TransScopeWhile {
    TransScope base;
    AstNode *node;
};

struct Context {
    ImportTableEntry *import;
    ZigList<ErrorMsg *> *errors;
    VisibMod visib_mod;
    bool want_export;
    AstNode *root;
    HashMap<const void *, AstNode *, ptr_hash, ptr_eq> decl_table;
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> macro_table;
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> global_table;
    SourceManager *source_manager;
    ZigList<Alias> aliases;
    AstNode *source_node;
    bool warnings_on;

    CodeGen *codegen;
    ASTContext *ctx;

    TransScopeRoot *global_scope;
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> ptr_params;
};

enum ResultUsed {
    ResultUsedNo,
    ResultUsedYes,
};

enum TransLRValue {
    TransLValue,
    TransRValue,
};

static TransScopeRoot *trans_scope_root_create(Context *c);
static TransScopeWhile *trans_scope_while_create(Context *c, TransScope *parent_scope);
static TransScopeBlock *trans_scope_block_create(Context *c, TransScope *parent_scope);
static TransScopeVar *trans_scope_var_create(Context *c, TransScope *parent_scope, Buf *wanted_name);
static TransScopeSwitch *trans_scope_switch_create(Context *c, TransScope *parent_scope);

static TransScopeBlock *trans_scope_block_find(TransScope *scope);

static AstNode *resolve_record_decl(Context *c, const RecordDecl *record_decl);
static AstNode *resolve_enum_decl(Context *c, const EnumDecl *enum_decl);
static AstNode *resolve_typedef_decl(Context *c, const TypedefNameDecl *typedef_decl);

static int trans_stmt_extra(Context *c, TransScope *scope, const Stmt *stmt,
        ResultUsed result_used, TransLRValue lrval,
        AstNode **out_node, TransScope **out_child_scope,
        TransScope **out_node_scope);
static TransScope *trans_stmt(Context *c, TransScope *scope, const Stmt *stmt, AstNode **out_node);
static AstNode *trans_expr(Context *c, ResultUsed result_used, TransScope *scope, const Expr *expr, TransLRValue lrval);
static AstNode *trans_qual_type(Context *c, QualType qt, const SourceLocation &source_loc);
static AstNode *trans_bool_expr(Context *c, ResultUsed result_used, TransScope *scope, const Expr *expr, TransLRValue lrval);

ATTRIBUTE_PRINTF(3, 4)
static void emit_warning(Context *c, const SourceLocation &sl, const char *format, ...) {
    if (!c->warnings_on) {
        return;
    }

    va_list ap;
    va_start(ap, format);
    Buf *msg = buf_vprintf(format, ap);
    va_end(ap);

    StringRef filename = c->source_manager->getFilename(c->source_manager->getSpellingLoc(sl));
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

static Buf *trans_lookup_zig_symbol(Context *c, TransScope *scope, Buf *c_symbol_name) {
    while (scope != nullptr) {
        if (scope->id == TransScopeIdVar) {
            TransScopeVar *var_scope = (TransScopeVar *)scope;
            if (buf_eql_buf(var_scope->c_name, c_symbol_name)) {
                return var_scope->zig_name;
            }
        }
        scope = scope->parent;
    }
    return c_symbol_name;
}

static AstNode * trans_create_node(Context *c, NodeType id) {
    AstNode *node = allocate<AstNode>(1);
    node->type = id;
    node->owner = c->import;
    // TODO line/column. mapping to C file??
    return node;
}

static AstNode *trans_create_node_break(Context *c, Buf *label_name, AstNode *value_node) {
    AstNode *node = trans_create_node(c, NodeTypeBreak);
    node->data.break_expr.name = label_name;
    node->data.break_expr.expr = value_node;
    return node;
}

static AstNode *trans_create_node_return(Context *c, AstNode *value_node) {
    AstNode *node = trans_create_node(c, NodeTypeReturnExpr);
    node->data.return_expr.kind = ReturnKindUnconditional;
    node->data.return_expr.expr = value_node;
    return node;
}

static AstNode *trans_create_node_if(Context *c, AstNode *cond_node, AstNode *then_node, AstNode *else_node) {
    AstNode *node = trans_create_node(c, NodeTypeIfBoolExpr);
    node->data.if_bool_expr.condition = cond_node;
    node->data.if_bool_expr.then_block = then_node;
    node->data.if_bool_expr.else_node = else_node;
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

static AstNode *trans_create_node_ptr_deref(Context *c, AstNode *child_node) {
    AstNode *node = trans_create_node(c, NodeTypePtrDeref);
    node->data.ptr_deref_expr.target = child_node;
    return node;
}

static AstNode *trans_create_node_prefix_op(Context *c, PrefixOp op, AstNode *child_node) {
    AstNode *node = trans_create_node(c, NodeTypePrefixOpExpr);
    node->data.prefix_op_expr.prefix_op = op;
    node->data.prefix_op_expr.primary_expr = child_node;
    return node;
}

static AstNode *trans_create_node_unwrap_null(Context *c, AstNode *child_node) {
    AstNode *node = trans_create_node(c, NodeTypeUnwrapOptional);
    node->data.unwrap_optional.expr = child_node;
    return node;
}

static AstNode *trans_create_node_bin_op(Context *c, AstNode *lhs_node, BinOpType op, AstNode *rhs_node) {
    AstNode *node = trans_create_node(c, NodeTypeBinOpExpr);
    node->data.bin_op_expr.op1 = lhs_node;
    node->data.bin_op_expr.bin_op = op;
    node->data.bin_op_expr.op2 = rhs_node;
    return node;
}

static AstNode *maybe_suppress_result(Context *c, ResultUsed result_used, AstNode *node) {
    if (result_used == ResultUsedYes) return node;
    return trans_create_node_bin_op(c,
        trans_create_node_symbol_str(c, "_"),
        BinOpTypeAssign,
        node);
}

static AstNode *trans_create_node_ptr_type(Context *c, bool is_const, bool is_volatile, AstNode *child_node, PtrLen ptr_len) {
    AstNode *node = trans_create_node(c, NodeTypePointerType);
    node->data.pointer_type.star_token = allocate<ZigToken>(1);
    node->data.pointer_type.star_token->id = (ptr_len == PtrLenSingle) ? TokenIdStar: TokenIdBracketStarBracket;
    node->data.pointer_type.is_const = is_const;
    node->data.pointer_type.is_const = is_const;
    node->data.pointer_type.is_volatile = is_volatile;
    node->data.pointer_type.op_expr = child_node;
    return node;
}

static AstNode *trans_create_node_addr_of(Context *c, AstNode *child_node) {
    AstNode *node = trans_create_node(c, NodeTypePrefixOpExpr);
    node->data.prefix_op_expr.prefix_op = PrefixOpAddrOf;
    node->data.prefix_op_expr.primary_expr = child_node;
    return node;
}

static AstNode *trans_create_node_bool(Context *c, bool value) {
    AstNode *bool_node = trans_create_node(c, NodeTypeBoolLiteral);
    bool_node->data.bool_literal.value = value;
    return bool_node;
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

static AstNode *trans_create_node_inline_fn(Context *c, Buf *fn_name, AstNode *ref_node, AstNode *src_proto_node) {
    AstNode *fn_def = trans_create_node(c, NodeTypeFnDef);
    AstNode *fn_proto = trans_create_node(c, NodeTypeFnProto);
    fn_proto->data.fn_proto.visib_mod = c->visib_mod;
    fn_proto->data.fn_proto.name = fn_name;
    fn_proto->data.fn_proto.is_inline = true;
    fn_proto->data.fn_proto.return_type = src_proto_node->data.fn_proto.return_type; // TODO ok for these to alias?

    fn_def->data.fn_def.fn_proto = fn_proto;
    fn_proto->data.fn_proto.fn_def_node = fn_def;

    AstNode *unwrap_node = trans_create_node_unwrap_null(c, ref_node);
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
    block->data.block.statements.items[0] = trans_create_node_return(c, fn_call_node);

    fn_def->data.fn_def.body = block;
    return fn_def;
}

static AstNode *get_global(Context *c, Buf *name) {
    {
        auto entry = c->global_table.maybe_get(name);
        if (entry) {
            return entry->value;
        }
    }
    {
        auto entry = c->macro_table.maybe_get(name);
        if (entry)
            return entry->value;
    }
    if (c->codegen->primitive_type_table.maybe_get(name) != nullptr) {
        return trans_create_node_symbol(c, name);
    }
    return nullptr;
}

static void add_top_level_decl(Context *c, Buf *name, AstNode *node) {
    c->global_table.put(name, node);
    c->root->data.root.top_level_decls.append(node);
}

static AstNode *add_global_var(Context *c, Buf *var_name, AstNode *value_node) {
    bool is_const = true;
    AstNode *type_node = nullptr;
    AstNode *node = trans_create_node_var_decl_global(c, is_const, var_name, type_node, value_node);
    add_top_level_decl(c, var_name, node);
    return node;
}

static Buf *string_ref_to_buf(StringRef string_ref) {
    return buf_create_from_mem((const char *)string_ref.bytes_begin(), string_ref.size());
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

static const Type *qual_type_canon(QualType qt) {
    return qt.getCanonicalType().getTypePtr();
}

static QualType get_expr_qual_type(Context *c, const Expr *expr) {
    // String literals in C are `char *` but they should really be `const char *`.
    if (expr->getStmtClass() == Stmt::ImplicitCastExprClass) {
        const ImplicitCastExpr *cast_expr = static_cast<const ImplicitCastExpr *>(expr);
        if (cast_expr->getCastKind() == CK_ArrayToPointerDecay) {
            const Expr *sub_expr = cast_expr->getSubExpr();
            if (sub_expr->getStmtClass() == Stmt::StringLiteralClass) {
                QualType array_qt = sub_expr->getType();
                const ArrayType *array_type = static_cast<const ArrayType *>(array_qt.getTypePtr());
                QualType pointee_qt = array_type->getElementType();
                pointee_qt.addConst();
                return c->ctx->getPointerType(pointee_qt);
            }
        }
    }
    return expr->getType();
}

static QualType get_expr_qual_type_before_implicit_cast(Context *c, const Expr *expr) {
    if (expr->getStmtClass() == Stmt::ImplicitCastExprClass) {
        const ImplicitCastExpr *cast_expr = static_cast<const ImplicitCastExpr *>(expr);
        return get_expr_qual_type(c, cast_expr->getSubExpr());
    }
    return expr->getType();
}

static AstNode *get_expr_type(Context *c, const Expr *expr) {
    return trans_qual_type(c, get_expr_qual_type(c, expr), expr->getLocStart());
}

static bool qual_types_equal(QualType t1, QualType t2) {
    if (t1.isConstQualified() != t2.isConstQualified()) {
        return false;
    }
    if (t1.isVolatileQualified() != t2.isVolatileQualified()) {
        return false;
    }
    if (t1.isRestrictQualified() != t2.isRestrictQualified()) {
        return false;
    }
    return t1.getTypePtr() == t2.getTypePtr();
}

static bool is_c_void_type(AstNode *node) {
    return (node->type == NodeTypeSymbol && buf_eql_str(node->data.symbol_expr.symbol, "c_void"));
}

static bool expr_types_equal(Context *c, const Expr *expr1, const Expr *expr2) {
    QualType t1 = get_expr_qual_type(c, expr1);
    QualType t2 = get_expr_qual_type(c, expr2);

    return qual_types_equal(t1, t2);
}

static bool qual_type_is_ptr(QualType qt) {
    const Type *ty = qual_type_canon(qt);
    return ty->getTypeClass() == Type::Pointer;
}

static const FunctionProtoType *qual_type_get_fn_proto(QualType qt, bool *is_ptr) {
    const Type *ty = qual_type_canon(qt);
    *is_ptr = false;

    if (ty->getTypeClass() == Type::Pointer) {
        *is_ptr = true;
        const PointerType *pointer_ty = static_cast<const PointerType*>(ty);
        QualType child_qt = pointer_ty->getPointeeType();
        ty = child_qt.getTypePtr();
    }

    if (ty->getTypeClass() == Type::FunctionProto) {
        return static_cast<const FunctionProtoType*>(ty);
    }

    return nullptr;
}

static bool qual_type_is_fn_ptr(QualType qt) {
    bool is_ptr;
    if (qual_type_get_fn_proto(qt, &is_ptr)) {
        return is_ptr;
    }

    return false;
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

static AstNode* trans_c_cast(Context *c, const SourceLocation &source_location, QualType dest_type,
        QualType src_type, AstNode *expr)
{
    if (qual_types_equal(dest_type, src_type)) {
        return expr;
    }
    if (qual_type_is_ptr(dest_type) && qual_type_is_ptr(src_type)) {
        AstNode *ptr_cast_node = trans_create_node_builtin_fn_call_str(c, "ptrCast");
        ptr_cast_node->data.fn_call_expr.params.append(trans_qual_type(c, dest_type, source_location));
        ptr_cast_node->data.fn_call_expr.params.append(expr);
        return ptr_cast_node;
    }
    // TODO: maybe widen to increase size
    // TODO: maybe bitcast to change sign
    // TODO: maybe truncate to reduce size
    return trans_create_node_fn_call_1(c, trans_qual_type(c, dest_type, source_location), expr);
}

static bool c_is_signed_integer(Context *c, QualType qt) {
    const Type *c_type = qual_type_canon(qt);
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
    const Type *c_type = qual_type_canon(qt);
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

static bool c_is_builtin_type(Context *c, QualType qt, BuiltinType::Kind kind) {
    const Type *c_type = qual_type_canon(qt);
    if (c_type->getTypeClass() != Type::Builtin)
        return false;
    const BuiltinType *builtin_ty = static_cast<const BuiltinType*>(c_type);
    return builtin_ty->getKind() == kind;
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

static bool type_is_opaque(Context *c, const Type *ty, const SourceLocation &source_loc) {
    switch (ty->getTypeClass()) {
        case Type::Builtin: {
            const BuiltinType *builtin_ty = static_cast<const BuiltinType*>(ty);
            return builtin_ty->getKind() == BuiltinType::Void;
        }
        case Type::Record: {
            const RecordType *record_ty = static_cast<const RecordType*>(ty);
            return record_ty->getDecl()->getDefinition() == nullptr;
        }
        case Type::Elaborated: {
            const ElaboratedType *elaborated_ty = static_cast<const ElaboratedType*>(ty);
            return type_is_opaque(c, elaborated_ty->getNamedType().getTypePtr(), source_loc);
        }
        case Type::Typedef: {
            const TypedefType *typedef_ty = static_cast<const TypedefType*>(ty);
            const TypedefNameDecl *typedef_decl = typedef_ty->getDecl();
            return type_is_opaque(c, typedef_decl->getUnderlyingType().getTypePtr(), source_loc);
        }
        default:
            return false;
    }
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
                    case BuiltinType::Float16:
                        return trans_create_node_symbol_str(c, "f16");
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
                    return trans_create_node_prefix_op(c, PrefixOpOptional, child_node);
                }

                PtrLen ptr_len = type_is_opaque(c, child_qt.getTypePtr(), source_loc) ? PtrLenSingle : PtrLenUnknown;

                AstNode *pointer_node = trans_create_node_ptr_type(c, child_qt.isConstQualified(),
                        child_qt.isVolatileQualified(), child_node, ptr_len);
                return trans_create_node_prefix_op(c, PrefixOpOptional, pointer_node);
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
                    case ETK_Enum:
                    case ETK_Union:
                        return trans_qual_type(c, elaborated_ty->getNamedType(), source_loc);
                    case ETK_Interface:
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
                    // we do want to look at the AstNode instead of QualType, because
                    // if they do something like:
                    //     typedef Foo void;
                    //     void foo(void) -> Foo;
                    // we want to keep the return type AST node.
                    if (is_c_void_type(proto_node->data.fn_proto.return_type)) {
                        proto_node->data.fn_proto.return_type = trans_create_node_symbol_str(c, "void");
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
        case Type::IncompleteArray:
            {
                const IncompleteArrayType *incomplete_array_ty = static_cast<const IncompleteArrayType *>(ty);
                QualType child_qt = incomplete_array_ty->getElementType();
                AstNode *child_type_node = trans_qual_type(c, child_qt, source_loc);
                if (child_type_node == nullptr) {
                    emit_warning(c, source_loc, "unresolved array element type");
                    return nullptr;
                }
                AstNode *pointer_node = trans_create_node_ptr_type(c, child_qt.isConstQualified(),
                        child_qt.isVolatileQualified(), child_type_node, PtrLenUnknown);
                return pointer_node;
            }
        case Type::BlockPointer:
        case Type::LValueReference:
        case Type::RValueReference:
        case Type::MemberPointer:
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
        case Type::DependentAddressSpace:
            emit_warning(c, source_loc, "unsupported type: '%s'", ty->getTypeClassName());
            return nullptr;
    }
    zig_unreachable();
}

static AstNode *trans_qual_type(Context *c, QualType qt, const SourceLocation &source_loc) {
    return trans_type(c, qt.getTypePtr(), source_loc);
}

static int trans_compound_stmt_inline(Context *c, TransScope *scope, const CompoundStmt *stmt,
        AstNode *block_node, TransScope **out_node_scope)
{
    assert(block_node->type == NodeTypeBlock);
    for (CompoundStmt::const_body_iterator it = stmt->body_begin(), end_it = stmt->body_end(); it != end_it; ++it) {
        AstNode *child_node;
        scope = trans_stmt(c, scope, *it, &child_node);
        if (scope == nullptr)
            return ErrorUnexpected;
        if (child_node != nullptr)
            block_node->data.block.statements.append(child_node);
    }
    if (out_node_scope != nullptr) {
        *out_node_scope = scope;
    }
    return ErrorNone;
}

static AstNode *trans_compound_stmt(Context *c, TransScope *scope, const CompoundStmt *stmt,
        TransScope **out_node_scope)
{
    TransScopeBlock *child_scope_block = trans_scope_block_create(c, scope);
    if (trans_compound_stmt_inline(c, &child_scope_block->base, stmt, child_scope_block->node, out_node_scope))
        return nullptr;
    return child_scope_block->node;
}

static AstNode *trans_return_stmt(Context *c, TransScope *scope, const ReturnStmt *stmt) {
    const Expr *value_expr = stmt->getRetValue();
    if (value_expr == nullptr) {
        return trans_create_node(c, NodeTypeReturnExpr);
    } else {
        AstNode *return_node = trans_create_node(c, NodeTypeReturnExpr);
        return_node->data.return_expr.expr = trans_expr(c, ResultUsedYes, scope, value_expr, TransRValue);
        if (return_node->data.return_expr.expr == nullptr)
            return nullptr;
        return return_node;
    }
}

static AstNode *trans_integer_literal(Context *c, const IntegerLiteral *stmt) {
    llvm::APSInt result;
    if (!stmt->EvaluateAsInt(result, *c->ctx)) {
        emit_warning(c, stmt->getLocStart(), "invalid integer literal");
        return nullptr;
    }
    return trans_create_node_apint(c, result);
}

static AstNode *trans_conditional_operator(Context *c, ResultUsed result_used, TransScope *scope,
        const ConditionalOperator *stmt)
{
    AstNode *node = trans_create_node(c, NodeTypeIfBoolExpr);

    Expr *cond_expr = stmt->getCond();
    Expr *true_expr = stmt->getTrueExpr();
    Expr *false_expr = stmt->getFalseExpr();

    node->data.if_bool_expr.condition = trans_expr(c, ResultUsedYes, scope, cond_expr, TransRValue);
    if (node->data.if_bool_expr.condition == nullptr)
        return nullptr;

    node->data.if_bool_expr.then_block = trans_expr(c, result_used, scope, true_expr, TransRValue);
    if (node->data.if_bool_expr.then_block == nullptr)
        return nullptr;

    node->data.if_bool_expr.else_node = trans_expr(c, result_used, scope, false_expr, TransRValue);
    if (node->data.if_bool_expr.else_node == nullptr)
        return nullptr;

    return maybe_suppress_result(c, result_used, node);
}

static AstNode *trans_create_bin_op(Context *c, TransScope *scope, Expr *lhs, BinOpType bin_op, Expr *rhs) {
    AstNode *node = trans_create_node(c, NodeTypeBinOpExpr);
    node->data.bin_op_expr.bin_op = bin_op;

    node->data.bin_op_expr.op1 = trans_expr(c, ResultUsedYes, scope, lhs, TransRValue);
    if (node->data.bin_op_expr.op1 == nullptr)
        return nullptr;

    node->data.bin_op_expr.op2 = trans_expr(c, ResultUsedYes, scope, rhs, TransRValue);
    if (node->data.bin_op_expr.op2 == nullptr)
        return nullptr;

    return node;
}

static AstNode *trans_create_bool_bin_op(Context *c, TransScope *scope, Expr *lhs, BinOpType bin_op, Expr *rhs) {
    assert(bin_op == BinOpTypeBoolAnd || bin_op == BinOpTypeBoolOr);
    AstNode *node = trans_create_node(c, NodeTypeBinOpExpr);
    node->data.bin_op_expr.bin_op = bin_op;

    node->data.bin_op_expr.op1 = trans_bool_expr(c, ResultUsedYes, scope, lhs, TransRValue);
    if (node->data.bin_op_expr.op1 == nullptr)
        return nullptr;

    node->data.bin_op_expr.op2 = trans_bool_expr(c, ResultUsedYes, scope, rhs, TransRValue);
    if (node->data.bin_op_expr.op2 == nullptr)
        return nullptr;

    return node;
}

static AstNode *trans_create_assign(Context *c, ResultUsed result_used, TransScope *scope, Expr *lhs, Expr *rhs) {
    if (result_used == ResultUsedNo) {
        // common case
        AstNode *node = trans_create_node(c, NodeTypeBinOpExpr);
        node->data.bin_op_expr.bin_op = BinOpTypeAssign;

        node->data.bin_op_expr.op1 = trans_expr(c, ResultUsedYes, scope, lhs, TransLValue);
        if (node->data.bin_op_expr.op1 == nullptr)
            return nullptr;

        node->data.bin_op_expr.op2 = trans_expr(c, ResultUsedYes, scope, rhs, TransRValue);
        if (node->data.bin_op_expr.op2 == nullptr)
            return nullptr;

        return node;
    } else {
        // worst case
        // c: lhs = rhs
        // zig: x: {
        // zig:     const _tmp = rhs;
        // zig:     lhs = _tmp;
        // zig:     break :x _tmp
        // zig: }

        TransScopeBlock *child_scope = trans_scope_block_create(c, scope);
        Buf *label_name = buf_create_from_str("x");
        child_scope->node->data.block.name = label_name;

        // const _tmp = rhs;
        AstNode *rhs_node = trans_expr(c, ResultUsedYes, &child_scope->base, rhs, TransRValue);
        if (rhs_node == nullptr) return nullptr;
        // TODO: avoid name collisions with generated variable names
        Buf* tmp_var_name = buf_create_from_str("_tmp");
        AstNode *tmp_var_decl = trans_create_node_var_decl_local(c, true, tmp_var_name, nullptr, rhs_node);
        child_scope->node->data.block.statements.append(tmp_var_decl);

        // lhs = _tmp;
        AstNode *lhs_node = trans_expr(c, ResultUsedYes, &child_scope->base, lhs, TransLValue);
        if (lhs_node == nullptr) return nullptr;
        child_scope->node->data.block.statements.append(
            trans_create_node_bin_op(c, lhs_node, BinOpTypeAssign,
                trans_create_node_symbol(c, tmp_var_name)));

        // break :x _tmp
        AstNode *tmp_symbol_node = trans_create_node_symbol(c, tmp_var_name);
        child_scope->node->data.block.statements.append(trans_create_node_break(c, label_name, tmp_symbol_node));

        return child_scope->node;
    }
}

static AstNode *trans_create_shift_op(Context *c, TransScope *scope, QualType result_type,
        Expr *lhs_expr, BinOpType bin_op, Expr *rhs_expr)
{
    const SourceLocation &rhs_location = rhs_expr->getLocStart();
    AstNode *rhs_type = qual_type_to_log2_int_ref(c, result_type, rhs_location);
    // lhs >> u5(rh)

    AstNode *lhs = trans_expr(c, ResultUsedYes, scope, lhs_expr, TransLValue);
    if (lhs == nullptr) return nullptr;

    AstNode *rhs = trans_expr(c, ResultUsedYes, scope, rhs_expr, TransRValue);
    if (rhs == nullptr) return nullptr;
    AstNode *coerced_rhs = trans_create_node_fn_call_1(c, rhs_type, rhs);

    return trans_create_node_bin_op(c, lhs, bin_op, coerced_rhs);
}

static AstNode *trans_binary_operator(Context *c, ResultUsed result_used, TransScope *scope, const BinaryOperator *stmt) {
    switch (stmt->getOpcode()) {
        case BO_PtrMemD:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_PtrMemD");
            return nullptr;
        case BO_PtrMemI:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_PtrMemI");
            return nullptr;
        case BO_Cmp:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C binary operators: BO_Cmp");
            return nullptr;
        case BO_Mul:
            return trans_create_bin_op(c, scope, stmt->getLHS(),
                qual_type_has_wrapping_overflow(c, stmt->getType()) ? BinOpTypeMultWrap : BinOpTypeMult,
                stmt->getRHS());
        case BO_Div:
            if (qual_type_has_wrapping_overflow(c, stmt->getType())) {
                // unsigned/float division uses the operator
                return trans_create_bin_op(c, scope, stmt->getLHS(), BinOpTypeDiv, stmt->getRHS());
            } else {
                // signed integer division uses @divTrunc
                AstNode *fn_call = trans_create_node_builtin_fn_call_str(c, "divTrunc");
                AstNode *lhs = trans_expr(c, ResultUsedYes, scope, stmt->getLHS(), TransLValue);
                if (lhs == nullptr) return nullptr;
                fn_call->data.fn_call_expr.params.append(lhs);
                AstNode *rhs = trans_expr(c, ResultUsedYes, scope, stmt->getRHS(), TransLValue);
                if (rhs == nullptr) return nullptr;
                fn_call->data.fn_call_expr.params.append(rhs);
                return fn_call;
            }
        case BO_Rem:
            if (qual_type_has_wrapping_overflow(c, stmt->getType())) {
                // unsigned/float division uses the operator
                return trans_create_bin_op(c, scope, stmt->getLHS(), BinOpTypeMod, stmt->getRHS());
            } else {
                // signed integer division uses @rem
                AstNode *fn_call = trans_create_node_builtin_fn_call_str(c, "rem");
                AstNode *lhs = trans_expr(c, ResultUsedYes, scope, stmt->getLHS(), TransLValue);
                if (lhs == nullptr) return nullptr;
                fn_call->data.fn_call_expr.params.append(lhs);
                AstNode *rhs = trans_expr(c, ResultUsedYes, scope, stmt->getRHS(), TransLValue);
                if (rhs == nullptr) return nullptr;
                fn_call->data.fn_call_expr.params.append(rhs);
                return fn_call;
            }
        case BO_Add:
            return trans_create_bin_op(c, scope, stmt->getLHS(),
                qual_type_has_wrapping_overflow(c, stmt->getType()) ? BinOpTypeAddWrap : BinOpTypeAdd,
                stmt->getRHS());
        case BO_Sub:
            return trans_create_bin_op(c, scope, stmt->getLHS(),
                qual_type_has_wrapping_overflow(c, stmt->getType()) ? BinOpTypeSubWrap : BinOpTypeSub,
                stmt->getRHS());
        case BO_Shl:
            return trans_create_shift_op(c, scope, stmt->getType(), stmt->getLHS(), BinOpTypeBitShiftLeft, stmt->getRHS());
        case BO_Shr:
            return trans_create_shift_op(c, scope, stmt->getType(), stmt->getLHS(), BinOpTypeBitShiftRight, stmt->getRHS());
        case BO_LT:
            return trans_create_bin_op(c, scope, stmt->getLHS(), BinOpTypeCmpLessThan, stmt->getRHS());
        case BO_GT:
            return trans_create_bin_op(c, scope, stmt->getLHS(), BinOpTypeCmpGreaterThan, stmt->getRHS());
        case BO_LE:
            return trans_create_bin_op(c, scope, stmt->getLHS(), BinOpTypeCmpLessOrEq, stmt->getRHS());
        case BO_GE:
            return trans_create_bin_op(c, scope, stmt->getLHS(), BinOpTypeCmpGreaterOrEq, stmt->getRHS());
        case BO_EQ:
            return trans_create_bin_op(c, scope, stmt->getLHS(), BinOpTypeCmpEq, stmt->getRHS());
        case BO_NE:
            return trans_create_bin_op(c, scope, stmt->getLHS(), BinOpTypeCmpNotEq, stmt->getRHS());
        case BO_And:
            return trans_create_bin_op(c, scope, stmt->getLHS(), BinOpTypeBinAnd, stmt->getRHS());
        case BO_Xor:
            return trans_create_bin_op(c, scope, stmt->getLHS(), BinOpTypeBinXor, stmt->getRHS());
        case BO_Or:
            return trans_create_bin_op(c, scope, stmt->getLHS(), BinOpTypeBinOr, stmt->getRHS());
        case BO_LAnd:
            return trans_create_bool_bin_op(c, scope, stmt->getLHS(), BinOpTypeBoolAnd, stmt->getRHS());
        case BO_LOr:
            return trans_create_bool_bin_op(c, scope, stmt->getLHS(), BinOpTypeBoolOr, stmt->getRHS());
        case BO_Assign:
            return trans_create_assign(c, result_used, scope, stmt->getLHS(), stmt->getRHS());
        case BO_Comma:
            {
                TransScopeBlock *scope_block = trans_scope_block_create(c, scope);
                Buf *label_name = buf_create_from_str("x");
                scope_block->node->data.block.name = label_name;

                AstNode *lhs = trans_expr(c, ResultUsedNo, &scope_block->base, stmt->getLHS(), TransRValue);
                if (lhs == nullptr)
                    return nullptr;
                scope_block->node->data.block.statements.append(maybe_suppress_result(c, ResultUsedNo, lhs));

                AstNode *rhs = trans_expr(c, result_used, &scope_block->base, stmt->getRHS(), TransRValue);
                if (rhs == nullptr)
                    return nullptr;
                scope_block->node->data.block.statements.append(trans_create_node_break(c, label_name, maybe_suppress_result(c, result_used, rhs)));
                return scope_block->node;
            }
        case BO_MulAssign:
        case BO_DivAssign:
        case BO_RemAssign:
        case BO_AddAssign:
        case BO_SubAssign:
        case BO_ShlAssign:
        case BO_ShrAssign:
        case BO_AndAssign:
        case BO_XorAssign:
        case BO_OrAssign:
            zig_unreachable();
    }

    zig_unreachable();
}

static AstNode *trans_create_compound_assign_shift(Context *c, ResultUsed result_used, TransScope *scope,
        const CompoundAssignOperator *stmt, BinOpType assign_op, BinOpType bin_op)
{
    const SourceLocation &rhs_location = stmt->getRHS()->getLocStart();
    AstNode *rhs_type = qual_type_to_log2_int_ref(c, stmt->getComputationLHSType(), rhs_location);

    bool use_intermediate_casts = stmt->getComputationLHSType().getTypePtr() != stmt->getComputationResultType().getTypePtr();
    if (!use_intermediate_casts && result_used == ResultUsedNo) {
        // simple common case, where the C and Zig are identical:
        // lhs >>= rhs
        AstNode *lhs = trans_expr(c, ResultUsedYes, scope, stmt->getLHS(), TransLValue);
        if (lhs == nullptr) return nullptr;

        AstNode *rhs = trans_expr(c, ResultUsedYes, scope, stmt->getRHS(), TransRValue);
        if (rhs == nullptr) return nullptr;
        AstNode *coerced_rhs = trans_create_node_fn_call_1(c, rhs_type, rhs);

        return trans_create_node_bin_op(c, lhs, assign_op, coerced_rhs);
    } else {
        // need more complexity. worst case, this looks like this:
        // c:   lhs >>= rhs
        // zig: x: {
        // zig:     const _ref = &lhs;
        // zig:     *_ref = result_type(operation_type(*_ref) >> u5(rhs));
        // zig:     break :x *_ref
        // zig: }
        // where u5 is the appropriate type

        TransScopeBlock *child_scope = trans_scope_block_create(c, scope);
        Buf *label_name = buf_create_from_str("x");
        child_scope->node->data.block.name = label_name;

        // const _ref = &lhs;
        AstNode *lhs = trans_expr(c, ResultUsedYes, &child_scope->base, stmt->getLHS(), TransLValue);
        if (lhs == nullptr) return nullptr;
        AstNode *addr_of_lhs = trans_create_node_addr_of(c, lhs);
        // TODO: avoid name collisions with generated variable names
        Buf* tmp_var_name = buf_create_from_str("_ref");
        AstNode *tmp_var_decl = trans_create_node_var_decl_local(c, true, tmp_var_name, nullptr, addr_of_lhs);
        child_scope->node->data.block.statements.append(tmp_var_decl);

        // *_ref = result_type(operation_type(*_ref) >> u5(rhs));

        AstNode *rhs = trans_expr(c, ResultUsedYes, &child_scope->base, stmt->getRHS(), TransRValue);
        if (rhs == nullptr) return nullptr;
        AstNode *coerced_rhs = trans_create_node_fn_call_1(c, rhs_type, rhs);

        // operation_type(*_ref)
        AstNode *operation_type_cast = trans_c_cast(c, rhs_location,
            stmt->getComputationLHSType(),
            stmt->getLHS()->getType(),
            trans_create_node_ptr_deref(c, trans_create_node_symbol(c, tmp_var_name)));

        // result_type(... >> u5(rhs))
        AstNode *result_type_cast = trans_c_cast(c, rhs_location,
            stmt->getComputationResultType(),
            stmt->getComputationLHSType(),
            trans_create_node_bin_op(c,
                operation_type_cast,
                bin_op,
                coerced_rhs));

        // *_ref = ...
        AstNode *assign_statement = trans_create_node_bin_op(c,
            trans_create_node_ptr_deref(c,
                trans_create_node_symbol(c, tmp_var_name)),
            BinOpTypeAssign, result_type_cast);

        child_scope->node->data.block.statements.append(assign_statement);

        if (result_used == ResultUsedYes) {
            // break :x *_ref
            child_scope->node->data.block.statements.append(
                trans_create_node_break(c, label_name,
                    trans_create_node_ptr_deref(c,
                        trans_create_node_symbol(c, tmp_var_name))));
        }

        return child_scope->node;
    }
}

static AstNode *trans_create_compound_assign(Context *c, ResultUsed result_used, TransScope *scope,
        const CompoundAssignOperator *stmt, BinOpType assign_op, BinOpType bin_op)
{
    if (result_used == ResultUsedNo) {
        // simple common case, where the C and Zig are identical:
        // lhs += rhs
        AstNode *lhs = trans_expr(c, ResultUsedYes, scope, stmt->getLHS(), TransLValue);
        if (lhs == nullptr) return nullptr;
        AstNode *rhs = trans_expr(c, ResultUsedYes, scope, stmt->getRHS(), TransRValue);
        if (rhs == nullptr) return nullptr;
        return trans_create_node_bin_op(c, lhs, assign_op, rhs);
    } else {
        // need more complexity. worst case, this looks like this:
        // c:   lhs += rhs
        // zig: x: {
        // zig:     const _ref = &lhs;
        // zig:     *_ref = *_ref + rhs;
        // zig:     break :x *_ref
        // zig: }

        TransScopeBlock *child_scope = trans_scope_block_create(c, scope);
        Buf *label_name = buf_create_from_str("x");
        child_scope->node->data.block.name = label_name;

        // const _ref = &lhs;
        AstNode *lhs = trans_expr(c, ResultUsedYes, &child_scope->base, stmt->getLHS(), TransLValue);
        if (lhs == nullptr) return nullptr;
        AstNode *addr_of_lhs = trans_create_node_addr_of(c, lhs);
        // TODO: avoid name collisions with generated variable names
        Buf* tmp_var_name = buf_create_from_str("_ref");
        AstNode *tmp_var_decl = trans_create_node_var_decl_local(c, true, tmp_var_name, nullptr, addr_of_lhs);
        child_scope->node->data.block.statements.append(tmp_var_decl);

        // *_ref = *_ref + rhs;

        AstNode *rhs = trans_expr(c, ResultUsedYes, &child_scope->base, stmt->getRHS(), TransRValue);
        if (rhs == nullptr) return nullptr;

        AstNode *assign_statement = trans_create_node_bin_op(c,
            trans_create_node_ptr_deref(c,
                trans_create_node_symbol(c, tmp_var_name)),
            BinOpTypeAssign,
            trans_create_node_bin_op(c,
                trans_create_node_ptr_deref(c,
                    trans_create_node_symbol(c, tmp_var_name)),
                bin_op,
                rhs));
        child_scope->node->data.block.statements.append(assign_statement);

        // break :x *_ref
        child_scope->node->data.block.statements.append(
            trans_create_node_break(c, label_name,
                trans_create_node_ptr_deref(c,
                    trans_create_node_symbol(c, tmp_var_name))));

        return child_scope->node;
    }
}


static AstNode *trans_compound_assign_operator(Context *c, ResultUsed result_used, TransScope *scope,
        const CompoundAssignOperator *stmt)
{
    switch (stmt->getOpcode()) {
        case BO_MulAssign:
            if (qual_type_has_wrapping_overflow(c, stmt->getType()))
                return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignTimesWrap, BinOpTypeMultWrap);
            else
                return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignTimes, BinOpTypeMult);
        case BO_DivAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C compound assign operators: BO_DivAssign");
            return nullptr;
        case BO_RemAssign:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C compound assign operators: BO_RemAssign");
            return nullptr;
        case BO_Cmp:
            emit_warning(c, stmt->getLocStart(), "TODO handle more C compound assign operators: BO_Cmp");
            return nullptr;
        case BO_AddAssign:
            if (qual_type_has_wrapping_overflow(c, stmt->getType()))
                return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignPlusWrap, BinOpTypeAddWrap);
            else
                return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignPlus, BinOpTypeAdd);
        case BO_SubAssign:
            if (qual_type_has_wrapping_overflow(c, stmt->getType()))
                return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignMinusWrap, BinOpTypeSubWrap);
            else
                return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignMinus, BinOpTypeSub);
        case BO_ShlAssign:
            return trans_create_compound_assign_shift(c, result_used, scope, stmt, BinOpTypeAssignBitShiftLeft, BinOpTypeBitShiftLeft);
        case BO_ShrAssign:
            return trans_create_compound_assign_shift(c, result_used, scope, stmt, BinOpTypeAssignBitShiftRight, BinOpTypeBitShiftRight);
        case BO_AndAssign:
            return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignBitAnd, BinOpTypeBinAnd);
        case BO_XorAssign:
            return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignBitXor, BinOpTypeBinXor);
        case BO_OrAssign:
            return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignBitOr, BinOpTypeBinOr);
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
            zig_unreachable();
    }

    zig_unreachable();
}

static AstNode *trans_implicit_cast_expr(Context *c, TransScope *scope, const ImplicitCastExpr *stmt) {
    switch (stmt->getCastKind()) {
        case CK_LValueToRValue:
            return trans_expr(c, ResultUsedYes, scope, stmt->getSubExpr(), TransRValue);
        case CK_IntegralCast:
            {
                AstNode *target_node = trans_expr(c, ResultUsedYes, scope, stmt->getSubExpr(), TransRValue);
                if (target_node == nullptr)
                    return nullptr;
                return trans_c_cast(c, stmt->getExprLoc(), stmt->getType(),
                        stmt->getSubExpr()->getType(), target_node);
            }
        case CK_FunctionToPointerDecay:
        case CK_ArrayToPointerDecay:
            {
                AstNode *target_node = trans_expr(c, ResultUsedYes, scope, stmt->getSubExpr(), TransRValue);
                if (target_node == nullptr)
                    return nullptr;
                return target_node;
            }
        case CK_BitCast:
            {
                AstNode *target_node = trans_expr(c, ResultUsedYes, scope, stmt->getSubExpr(), TransRValue);
                if (target_node == nullptr)
                    return nullptr;

                if (expr_types_equal(c, stmt, stmt->getSubExpr())) {
                    return target_node;
                }

                AstNode *dest_type_node = get_expr_type(c, stmt);

                AstNode *node = trans_create_node_builtin_fn_call_str(c, "ptrCast");
                node->data.fn_call_expr.params.append(dest_type_node);
                node->data.fn_call_expr.params.append(target_node);
                return node;
            }
        case CK_NullToPointer:
            return trans_create_node(c, NodeTypeNullLiteral);
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

static AstNode *trans_decl_ref_expr(Context *c, TransScope *scope, const DeclRefExpr *stmt, TransLRValue lrval) {
    const ValueDecl *value_decl = stmt->getDecl();
    Buf *c_symbol_name = buf_create_from_str(decl_name(value_decl));
    Buf *zig_symbol_name = trans_lookup_zig_symbol(c, scope, c_symbol_name);
    if (lrval == TransLValue) {
        c->ptr_params.put(zig_symbol_name, true);
    }
    return trans_create_node_symbol(c, zig_symbol_name);
}

static AstNode *trans_create_post_crement(Context *c, ResultUsed result_used, TransScope *scope,
        const UnaryOperator *stmt, BinOpType assign_op)
{
    Expr *op_expr = stmt->getSubExpr();

    if (result_used == ResultUsedNo) {
        // common case
        // c: expr++
        // zig: expr += 1
        return trans_create_node_bin_op(c,
            trans_expr(c, ResultUsedYes, scope, op_expr, TransLValue),
            assign_op,
            trans_create_node_unsigned(c, 1));
    }
    // worst case
    // c: expr++
    // zig: x: {
    // zig:     const _ref = &expr;
    // zig:     const _tmp = *_ref;
    // zig:     *_ref += 1;
    // zig:     break :x _tmp
    // zig: }
    TransScopeBlock *child_scope = trans_scope_block_create(c, scope);
    Buf *label_name = buf_create_from_str("x");
    child_scope->node->data.block.name = label_name;

    // const _ref = &expr;
    AstNode *expr = trans_expr(c, ResultUsedYes, &child_scope->base, op_expr, TransLValue);
    if (expr == nullptr) return nullptr;
    AstNode *addr_of_expr = trans_create_node_addr_of(c, expr);
    // TODO: avoid name collisions with generated variable names
    Buf* ref_var_name = buf_create_from_str("_ref");
    AstNode *ref_var_decl = trans_create_node_var_decl_local(c, true, ref_var_name, nullptr, addr_of_expr);
    child_scope->node->data.block.statements.append(ref_var_decl);

    // const _tmp = *_ref;
    Buf* tmp_var_name = buf_create_from_str("_tmp");
    AstNode *tmp_var_decl = trans_create_node_var_decl_local(c, true, tmp_var_name, nullptr,
        trans_create_node_ptr_deref(c,
            trans_create_node_symbol(c, ref_var_name)));
    child_scope->node->data.block.statements.append(tmp_var_decl);

    // *_ref += 1;
    AstNode *assign_statement = trans_create_node_bin_op(c,
        trans_create_node_ptr_deref(c,
            trans_create_node_symbol(c, ref_var_name)),
        assign_op,
        trans_create_node_unsigned(c, 1));
    child_scope->node->data.block.statements.append(assign_statement);

    // break :x _tmp
    child_scope->node->data.block.statements.append(trans_create_node_break(c, label_name, trans_create_node_symbol(c, tmp_var_name)));

    return child_scope->node;
}

static AstNode *trans_create_pre_crement(Context *c, ResultUsed result_used, TransScope *scope,
        const UnaryOperator *stmt, BinOpType assign_op)
{
    Expr *op_expr = stmt->getSubExpr();

    if (result_used == ResultUsedNo) {
        // common case
        // c: ++expr
        // zig: expr += 1
        return trans_create_node_bin_op(c,
            trans_expr(c, ResultUsedYes, scope, op_expr, TransLValue),
            assign_op,
            trans_create_node_unsigned(c, 1));
    }
    // worst case
    // c: ++expr
    // zig: x: {
    // zig:     const _ref = &expr;
    // zig:     *_ref += 1;
    // zig:     break :x *_ref
    // zig: }
    TransScopeBlock *child_scope = trans_scope_block_create(c, scope);
    Buf *label_name = buf_create_from_str("x");
    child_scope->node->data.block.name = label_name;

    // const _ref = &expr;
    AstNode *expr = trans_expr(c, ResultUsedYes, &child_scope->base, op_expr, TransLValue);
    if (expr == nullptr) return nullptr;
    AstNode *addr_of_expr = trans_create_node_addr_of(c, expr);
    // TODO: avoid name collisions with generated variable names
    Buf* ref_var_name = buf_create_from_str("_ref");
    AstNode *ref_var_decl = trans_create_node_var_decl_local(c, true, ref_var_name, nullptr, addr_of_expr);
    child_scope->node->data.block.statements.append(ref_var_decl);

    // *_ref += 1;
    AstNode *assign_statement = trans_create_node_bin_op(c,
        trans_create_node_ptr_deref(c,
            trans_create_node_symbol(c, ref_var_name)),
        assign_op,
        trans_create_node_unsigned(c, 1));
    child_scope->node->data.block.statements.append(assign_statement);

    // break :x *_ref
    AstNode *deref_expr = trans_create_node_ptr_deref(c,
            trans_create_node_symbol(c, ref_var_name));
    child_scope->node->data.block.statements.append(trans_create_node_break(c, label_name, deref_expr));

    return child_scope->node;
}

static AstNode *trans_unary_operator(Context *c, ResultUsed result_used, TransScope *scope, const UnaryOperator *stmt) {
    switch (stmt->getOpcode()) {
        case UO_PostInc:
            if (qual_type_has_wrapping_overflow(c, stmt->getType()))
                return trans_create_post_crement(c, result_used, scope, stmt, BinOpTypeAssignPlusWrap);
            else
                return trans_create_post_crement(c, result_used, scope, stmt, BinOpTypeAssignPlus);
        case UO_PostDec:
            if (qual_type_has_wrapping_overflow(c, stmt->getType()))
                return trans_create_post_crement(c, result_used, scope, stmt, BinOpTypeAssignMinusWrap);
            else
                return trans_create_post_crement(c, result_used, scope, stmt, BinOpTypeAssignMinus);
        case UO_PreInc:
            if (qual_type_has_wrapping_overflow(c, stmt->getType()))
                return trans_create_pre_crement(c, result_used, scope, stmt, BinOpTypeAssignPlusWrap);
            else
                return trans_create_pre_crement(c, result_used, scope, stmt, BinOpTypeAssignPlus);
        case UO_PreDec:
            if (qual_type_has_wrapping_overflow(c, stmt->getType()))
                return trans_create_pre_crement(c, result_used, scope, stmt, BinOpTypeAssignMinusWrap);
            else
                return trans_create_pre_crement(c, result_used, scope, stmt, BinOpTypeAssignMinus);
        case UO_AddrOf:
            {
                AstNode *value_node = trans_expr(c, result_used, scope, stmt->getSubExpr(), TransLValue);
                if (value_node == nullptr)
                    return value_node;
                return trans_create_node_addr_of(c, value_node);
            }
        case UO_Deref:
            {
                AstNode *value_node = trans_expr(c, result_used, scope, stmt->getSubExpr(), TransRValue);
                if (value_node == nullptr)
                    return nullptr;
                bool is_fn_ptr = qual_type_is_fn_ptr(stmt->getSubExpr()->getType());
                if (is_fn_ptr)
                    return value_node;
                AstNode *unwrapped = trans_create_node_unwrap_null(c, value_node);
                return trans_create_node_ptr_deref(c, unwrapped);
            }
        case UO_Plus:
            emit_warning(c, stmt->getLocStart(), "TODO handle C translation UO_Plus");
            return nullptr;
        case UO_Minus:
            {
                Expr *op_expr = stmt->getSubExpr();
                if (!qual_type_has_wrapping_overflow(c, op_expr->getType())) {
                    AstNode *node = trans_create_node(c, NodeTypePrefixOpExpr);
                    node->data.prefix_op_expr.prefix_op = PrefixOpNegation;

                    node->data.prefix_op_expr.primary_expr = trans_expr(c, ResultUsedYes, scope, op_expr, TransRValue);
                    if (node->data.prefix_op_expr.primary_expr == nullptr)
                        return nullptr;

                    return node;
                } else if (c_is_unsigned_integer(c, op_expr->getType())) {
                    // we gotta emit 0 -% x
                    AstNode *node = trans_create_node(c, NodeTypeBinOpExpr);
                    node->data.bin_op_expr.op1 = trans_create_node_unsigned(c, 0);

                    node->data.bin_op_expr.op2 = trans_expr(c, ResultUsedYes, scope, op_expr, TransRValue);
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
            {
                Expr *op_expr = stmt->getSubExpr();
                AstNode *sub_node = trans_expr(c, ResultUsedYes, scope, op_expr, TransRValue);
                if (sub_node == nullptr)
                    return nullptr;

                return trans_create_node_prefix_op(c, PrefixOpBinNot, sub_node);
            }
        case UO_LNot:
            {
                Expr *op_expr = stmt->getSubExpr();
                AstNode *sub_node = trans_bool_expr(c, ResultUsedYes, scope, op_expr, TransRValue);
                if (sub_node == nullptr)
                    return nullptr;

                return trans_create_node_prefix_op(c, PrefixOpBoolNot, sub_node);
            }
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

static int trans_local_declaration(Context *c, TransScope *scope, const DeclStmt *stmt,
        AstNode **out_node, TransScope **out_scope)
{
    // declarations are added via the scope
    *out_node = nullptr;

    TransScopeBlock *scope_block = trans_scope_block_find(scope);
    assert(scope_block != nullptr);

    for (auto iter = stmt->decl_begin(); iter != stmt->decl_end(); iter++) {
        Decl *decl = *iter;
        switch (decl->getKind()) {
            case Decl::Var: {
                VarDecl *var_decl = (VarDecl *)decl;
                QualType qual_type = var_decl->getTypeSourceInfo()->getType();
                AstNode *init_node = nullptr;
                if (var_decl->hasInit()) {
                    init_node = trans_expr(c, ResultUsedYes, scope, var_decl->getInit(), TransRValue);
                    if (init_node == nullptr)
                        return ErrorUnexpected;

                } else {
                    init_node = trans_create_node(c, NodeTypeUndefinedLiteral);
                }
                AstNode *type_node = trans_qual_type(c, qual_type, stmt->getLocStart());
                if (type_node == nullptr)
                    return ErrorUnexpected;

                Buf *c_symbol_name = buf_create_from_str(decl_name(var_decl));

                TransScopeVar *var_scope = trans_scope_var_create(c, scope, c_symbol_name);
                scope = &var_scope->base;

                AstNode *node = trans_create_node_var_decl_local(c, qual_type.isConstQualified(),
                        var_scope->zig_name, type_node, init_node);

                scope_block->node->data.block.statements.append(node);
                continue;
            }
            case Decl::AccessSpec:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind AccessSpec");
                return ErrorUnexpected;
            case Decl::Block:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Block");
                return ErrorUnexpected;
            case Decl::Captured:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Captured");
                return ErrorUnexpected;
            case Decl::ClassScopeFunctionSpecialization:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ClassScopeFunctionSpecialization");
                return ErrorUnexpected;
            case Decl::Empty:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Empty");
                return ErrorUnexpected;
            case Decl::Export:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Export");
                return ErrorUnexpected;
            case Decl::ExternCContext:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ExternCContext");
                return ErrorUnexpected;
            case Decl::FileScopeAsm:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind FileScopeAsm");
                return ErrorUnexpected;
            case Decl::Friend:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Friend");
                return ErrorUnexpected;
            case Decl::FriendTemplate:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind FriendTemplate");
                return ErrorUnexpected;
            case Decl::Import:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Import");
                return ErrorUnexpected;
            case Decl::LinkageSpec:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind LinkageSpec");
                return ErrorUnexpected;
            case Decl::Label:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Label");
                return ErrorUnexpected;
            case Decl::Namespace:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Namespace");
                return ErrorUnexpected;
            case Decl::NamespaceAlias:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind NamespaceAlias");
                return ErrorUnexpected;
            case Decl::ObjCCompatibleAlias:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCCompatibleAlias");
                return ErrorUnexpected;
            case Decl::ObjCCategory:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCCategory");
                return ErrorUnexpected;
            case Decl::ObjCCategoryImpl:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCCategoryImpl");
                return ErrorUnexpected;
            case Decl::ObjCImplementation:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCImplementation");
                return ErrorUnexpected;
            case Decl::ObjCInterface:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCInterface");
                return ErrorUnexpected;
            case Decl::ObjCProtocol:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCProtocol");
                return ErrorUnexpected;
            case Decl::ObjCMethod:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCMethod");
                return ErrorUnexpected;
            case Decl::ObjCProperty:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCProperty");
                return ErrorUnexpected;
            case Decl::BuiltinTemplate:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind BuiltinTemplate");
                return ErrorUnexpected;
            case Decl::ClassTemplate:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ClassTemplate");
                return ErrorUnexpected;
            case Decl::FunctionTemplate:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind FunctionTemplate");
                return ErrorUnexpected;
            case Decl::TypeAliasTemplate:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind TypeAliasTemplate");
                return ErrorUnexpected;
            case Decl::VarTemplate:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind VarTemplate");
                return ErrorUnexpected;
            case Decl::TemplateTemplateParm:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind TemplateTemplateParm");
                return ErrorUnexpected;
            case Decl::Enum:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Enum");
                return ErrorUnexpected;
            case Decl::Record:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Record");
                return ErrorUnexpected;
            case Decl::CXXRecord:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind CXXRecord");
                return ErrorUnexpected;
            case Decl::ClassTemplateSpecialization:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ClassTemplateSpecialization");
                return ErrorUnexpected;
            case Decl::ClassTemplatePartialSpecialization:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ClassTemplatePartialSpecialization");
                return ErrorUnexpected;
            case Decl::TemplateTypeParm:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind TemplateTypeParm");
                return ErrorUnexpected;
            case Decl::ObjCTypeParam:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCTypeParam");
                return ErrorUnexpected;
            case Decl::TypeAlias:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind TypeAlias");
                return ErrorUnexpected;
            case Decl::Typedef:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Typedef");
                return ErrorUnexpected;
            case Decl::UnresolvedUsingTypename:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind UnresolvedUsingTypename");
                return ErrorUnexpected;
            case Decl::Using:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Using");
                return ErrorUnexpected;
            case Decl::UsingDirective:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind UsingDirective");
                return ErrorUnexpected;
            case Decl::UsingPack:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind UsingPack");
                return ErrorUnexpected;
            case Decl::UsingShadow:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind UsingShadow");
                return ErrorUnexpected;
            case Decl::ConstructorUsingShadow:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ConstructorUsingShadow");
                return ErrorUnexpected;
            case Decl::Binding:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Binding");
                return ErrorUnexpected;
            case Decl::Field:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Field");
                return ErrorUnexpected;
            case Decl::ObjCAtDefsField:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCAtDefsField");
                return ErrorUnexpected;
            case Decl::ObjCIvar:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCIvar");
                return ErrorUnexpected;
            case Decl::Function:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Function");
                return ErrorUnexpected;
            case Decl::CXXDeductionGuide:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind CXXDeductionGuide");
                return ErrorUnexpected;
            case Decl::CXXMethod:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind CXXMethod");
                return ErrorUnexpected;
            case Decl::CXXConstructor:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind CXXConstructor");
                return ErrorUnexpected;
            case Decl::CXXConversion:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind CXXConversion");
                return ErrorUnexpected;
            case Decl::CXXDestructor:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind CXXDestructor");
                return ErrorUnexpected;
            case Decl::MSProperty:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind MSProperty");
                return ErrorUnexpected;
            case Decl::NonTypeTemplateParm:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind NonTypeTemplateParm");
                return ErrorUnexpected;
            case Decl::Decomposition:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind Decomposition");
                return ErrorUnexpected;
            case Decl::ImplicitParam:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ImplicitParam");
                return ErrorUnexpected;
            case Decl::OMPCapturedExpr:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind OMPCapturedExpr");
                return ErrorUnexpected;
            case Decl::ParmVar:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ParmVar");
                return ErrorUnexpected;
            case Decl::VarTemplateSpecialization:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind VarTemplateSpecialization");
                return ErrorUnexpected;
            case Decl::VarTemplatePartialSpecialization:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind VarTemplatePartialSpecialization");
                return ErrorUnexpected;
            case Decl::EnumConstant:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind EnumConstant");
                return ErrorUnexpected;
            case Decl::IndirectField:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind IndirectField");
                return ErrorUnexpected;
            case Decl::OMPDeclareReduction:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind OMPDeclareReduction");
                return ErrorUnexpected;
            case Decl::UnresolvedUsingValue:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind UnresolvedUsingValue");
                return ErrorUnexpected;
            case Decl::OMPThreadPrivate:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind OMPThreadPrivate");
                return ErrorUnexpected;
            case Decl::ObjCPropertyImpl:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind ObjCPropertyImpl");
                return ErrorUnexpected;
            case Decl::PragmaComment:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind PragmaComment");
                return ErrorUnexpected;
            case Decl::PragmaDetectMismatch:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind PragmaDetectMismatch");
                return ErrorUnexpected;
            case Decl::StaticAssert:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind StaticAssert");
                return ErrorUnexpected;
            case Decl::TranslationUnit:
                emit_warning(c, stmt->getLocStart(), "TODO handle decl kind TranslationUnit");
                return ErrorUnexpected;
        }
        zig_unreachable();
    }

    *out_scope = scope;
    return ErrorNone;
}

static AstNode *to_enum_zero_cmp(Context *c, AstNode *expr, AstNode *enum_type) {
    AstNode *tag_type = trans_create_node_builtin_fn_call_str(c, "TagType");
    tag_type->data.fn_call_expr.params.append(enum_type);

    // @TagType(Enum)(0)
    AstNode *zero = trans_create_node_unsigned_negative(c, 0, false);
    AstNode *casted_zero = trans_create_node_fn_call_1(c, tag_type, zero);

    // @bitCast(Enum, @TagType(Enum)(0))
    AstNode *bitcast = trans_create_node_builtin_fn_call_str(c, "bitCast");
    bitcast->data.fn_call_expr.params.append(enum_type);
    bitcast->data.fn_call_expr.params.append(casted_zero);

    return trans_create_node_bin_op(c, expr, BinOpTypeCmpNotEq, bitcast);
}

static AstNode *trans_bool_expr(Context *c, ResultUsed result_used, TransScope *scope, const Expr *expr, TransLRValue lrval) {
    AstNode *res = trans_expr(c, result_used, scope, expr, lrval);
    if (res == nullptr)
        return nullptr;

    switch (res->type) {
        case NodeTypeBinOpExpr:
            switch (res->data.bin_op_expr.bin_op) {
                case BinOpTypeBoolOr:
                case BinOpTypeBoolAnd:
                case BinOpTypeCmpEq:
                case BinOpTypeCmpNotEq:
                case BinOpTypeCmpLessThan:
                case BinOpTypeCmpGreaterThan:
                case BinOpTypeCmpLessOrEq:
                case BinOpTypeCmpGreaterOrEq:
                    return res;
                default:
                    break;
            }

        case NodeTypePrefixOpExpr:
            switch (res->data.prefix_op_expr.prefix_op) {
                case PrefixOpBoolNot:
                    return res;
                default:
                    break;
            }

        case NodeTypeBoolLiteral:
            return res;

        default:
            break;
    }


    const Type *ty = get_expr_qual_type_before_implicit_cast(c, expr).getTypePtr();
    auto classs = ty->getTypeClass();
    switch (classs) {
        case Type::Builtin:
        {
            const BuiltinType *builtin_ty = static_cast<const BuiltinType*>(ty);
            switch (builtin_ty->getKind()) {
                case BuiltinType::Bool:
                case BuiltinType::Char_U:
                case BuiltinType::UChar:
                case BuiltinType::Char_S:
                case BuiltinType::SChar:
                case BuiltinType::UShort:
                case BuiltinType::UInt:
                case BuiltinType::ULong:
                case BuiltinType::ULongLong:
                case BuiltinType::Short:
                case BuiltinType::Int:
                case BuiltinType::Long:
                case BuiltinType::LongLong:
                case BuiltinType::UInt128:
                case BuiltinType::Int128:
                case BuiltinType::Float:
                case BuiltinType::Double:
                case BuiltinType::Float128:
                case BuiltinType::LongDouble:
                case BuiltinType::WChar_U:
                case BuiltinType::Char16:
                case BuiltinType::Char32:
                case BuiltinType::WChar_S:
                case BuiltinType::Float16:
                    return trans_create_node_bin_op(c, res, BinOpTypeCmpNotEq, trans_create_node_unsigned_negative(c, 0, false));
                case BuiltinType::NullPtr:
                    return trans_create_node_bin_op(c, res, BinOpTypeCmpNotEq, trans_create_node(c, NodeTypeNullLiteral));

                case BuiltinType::Void:
                case BuiltinType::Half:
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
                    return res;
            }
            break;
        }
        case Type::Pointer:
            return trans_create_node_bin_op(c, res, BinOpTypeCmpNotEq, trans_create_node(c, NodeTypeNullLiteral));

        case Type::Typedef:
        {
            const TypedefType *typedef_ty = static_cast<const TypedefType*>(ty);
            const TypedefNameDecl *typedef_decl = typedef_ty->getDecl();
            auto existing_entry = c->decl_table.maybe_get((void*)typedef_decl->getCanonicalDecl());
            if (existing_entry) {
                return existing_entry->value;
            }

            return res;
        }

        case Type::Enum:
        {
            const EnumType *enum_ty = static_cast<const EnumType*>(ty);
            AstNode *enum_type = resolve_enum_decl(c, enum_ty->getDecl());
            return to_enum_zero_cmp(c, res, enum_type);
        }

        case Type::Elaborated:
        {
            const ElaboratedType *elaborated_ty = static_cast<const ElaboratedType*>(ty);
            switch (elaborated_ty->getKeyword()) {
                case ETK_Enum: {
                    AstNode *enum_type = trans_qual_type(c, elaborated_ty->getNamedType(), expr->getLocStart());
                    return to_enum_zero_cmp(c, res, enum_type);
                }
                case ETK_Struct:
                case ETK_Union:
                case ETK_Interface:
                case ETK_Class:
                case ETK_Typename:
                case ETK_None:
                    return res;
            }
        }

        case Type::FunctionProto:
        case Type::Record:
        case Type::ConstantArray:
        case Type::Paren:
        case Type::Decayed:
        case Type::Attributed:
        case Type::IncompleteArray:
        case Type::BlockPointer:
        case Type::LValueReference:
        case Type::RValueReference:
        case Type::MemberPointer:
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
        case Type::DependentAddressSpace:
            return res;
    }
    zig_unreachable();
}

static AstNode *trans_while_loop(Context *c, TransScope *scope, const WhileStmt *stmt) {
    TransScopeWhile *while_scope = trans_scope_while_create(c, scope);

    while_scope->node->data.while_expr.condition = trans_bool_expr(c, ResultUsedYes, scope, stmt->getCond(), TransRValue);
    if (while_scope->node->data.while_expr.condition == nullptr)
        return nullptr;

    TransScope *body_scope = trans_stmt(c, &while_scope->base, stmt->getBody(),
            &while_scope->node->data.while_expr.body);
    if (body_scope == nullptr)
        return nullptr;

    return while_scope->node;
}

static AstNode *trans_if_statement(Context *c, TransScope *scope, const IfStmt *stmt) {
    // if (c) t
    // if (c) t else e
    AstNode *if_node = trans_create_node(c, NodeTypeIfBoolExpr);

    TransScope *then_scope = trans_stmt(c, scope, stmt->getThen(), &if_node->data.if_bool_expr.then_block);
    if (then_scope == nullptr)
        return nullptr;

    if (stmt->getElse() != nullptr) {
        TransScope *else_scope = trans_stmt(c, scope, stmt->getElse(), &if_node->data.if_bool_expr.else_node);
        if (else_scope == nullptr)
            return nullptr;
    }

    if_node->data.if_bool_expr.condition = trans_bool_expr(c, ResultUsedYes, scope, stmt->getCond(), TransRValue);
    if (if_node->data.if_bool_expr.condition == nullptr)
        return nullptr;

    return if_node;
}

static AstNode *trans_call_expr(Context *c, ResultUsed result_used, TransScope *scope, const CallExpr *stmt) {
    AstNode *node = trans_create_node(c, NodeTypeFnCallExpr);

    AstNode *callee_raw_node = trans_expr(c, ResultUsedYes, scope, stmt->getCallee(), TransRValue);
    if (callee_raw_node == nullptr)
        return nullptr;

    bool is_ptr = false;
    const FunctionProtoType *fn_ty = qual_type_get_fn_proto(stmt->getCallee()->getType(), &is_ptr);
    AstNode *callee_node = nullptr;
    if (is_ptr && fn_ty) {
        if (stmt->getCallee()->getStmtClass() == Stmt::ImplicitCastExprClass) {
            const ImplicitCastExpr *implicit_cast = static_cast<const ImplicitCastExpr *>(stmt->getCallee());
            if (implicit_cast->getCastKind() == CK_FunctionToPointerDecay) {
                if (implicit_cast->getSubExpr()->getStmtClass() == Stmt::DeclRefExprClass) {
                    const DeclRefExpr *decl_ref = static_cast<const DeclRefExpr *>(implicit_cast->getSubExpr());
                    const Decl *decl = decl_ref->getFoundDecl();
                    if (decl->getKind() == Decl::Function) {
                        callee_node = callee_raw_node;
                    }
                }
            }
        }
        if (callee_node == nullptr) {
            callee_node = trans_create_node_unwrap_null(c, callee_raw_node);
        }
    } else {
        callee_node = callee_raw_node;
    }

    node->data.fn_call_expr.fn_ref_expr = callee_node;

    unsigned num_args = stmt->getNumArgs();
    const Expr * const* args = stmt->getArgs();
    for (unsigned i = 0; i < num_args; i += 1) {
        AstNode *arg_node = trans_expr(c, ResultUsedYes, scope, args[i], TransRValue);
        if (arg_node == nullptr)
            return nullptr;

        node->data.fn_call_expr.params.append(arg_node);
    }

    if (result_used == ResultUsedNo && fn_ty && !qual_type_canon(fn_ty->getReturnType())->isVoidType()) {
        node = trans_create_node_bin_op(c, trans_create_node_symbol_str(c, "_"), BinOpTypeAssign, node);
    }

    return node;
}

static AstNode *trans_member_expr(Context *c, TransScope *scope, const MemberExpr *stmt) {
    AstNode *container_node = trans_expr(c, ResultUsedYes, scope, stmt->getBase(), TransRValue);
    if (container_node == nullptr)
        return nullptr;

    if (stmt->isArrow()) {
        container_node = trans_create_node_unwrap_null(c, container_node);
    }

    const char *name = decl_name(stmt->getMemberDecl());

    AstNode *node = trans_create_node_field_access_str(c, container_node, name);
    return node;
}

static AstNode *trans_array_subscript_expr(Context *c, TransScope *scope, const ArraySubscriptExpr *stmt) {
    AstNode *container_node = trans_expr(c, ResultUsedYes, scope, stmt->getBase(), TransRValue);
    if (container_node == nullptr)
        return nullptr;

    AstNode *idx_node = trans_expr(c, ResultUsedYes, scope, stmt->getIdx(), TransRValue);
    if (idx_node == nullptr)
        return nullptr;


    AstNode *node = trans_create_node(c, NodeTypeArrayAccessExpr);
    node->data.array_access_expr.array_ref_expr = container_node;
    node->data.array_access_expr.subscript = idx_node;
    return node;
}

static AstNode *trans_c_style_cast_expr(Context *c, ResultUsed result_used, TransScope *scope,
        const CStyleCastExpr *stmt, TransLRValue lrvalue)
{
    AstNode *sub_expr_node = trans_expr(c, result_used, scope, stmt->getSubExpr(), lrvalue);
    if (sub_expr_node == nullptr)
        return nullptr;

    return trans_c_cast(c, stmt->getLocStart(), stmt->getType(), stmt->getSubExpr()->getType(), sub_expr_node);
}

static AstNode *trans_unary_expr_or_type_trait_expr(Context *c, TransScope *scope,
        const UnaryExprOrTypeTraitExpr *stmt)
{
    AstNode *type_node = trans_qual_type(c, stmt->getTypeOfArgument(), stmt->getLocStart());
    if (type_node == nullptr)
        return nullptr;

    AstNode *node = trans_create_node_builtin_fn_call_str(c, "sizeOf");
    node->data.fn_call_expr.params.append(type_node);
    return node;
}

static AstNode *trans_do_loop(Context *c, TransScope *parent_scope, const DoStmt *stmt) {
    TransScopeWhile *while_scope = trans_scope_while_create(c, parent_scope);

    while_scope->node->data.while_expr.condition = trans_create_node_bool(c, true);

    AstNode *body_node;
    TransScope *child_scope;
    if (stmt->getBody()->getStmtClass() == Stmt::CompoundStmtClass) {
        // there's already a block in C, so we'll append our condition to it.
        // c: do {
        // c:   a;
        // c:   b;
        // c: } while(c);
        // zig: while (true) {
        // zig:   a;
        // zig:   b;
        // zig:   if (!cond) break;
        // zig: }

        // We call the low level function so that we can set child_scope to the scope of the generated block.
        if (trans_stmt_extra(c, &while_scope->base, stmt->getBody(), ResultUsedNo, TransRValue, &body_node,
            nullptr, &child_scope))
        {
            return nullptr;
        }
        assert(body_node->type == NodeTypeBlock);
    } else {
        // the C statement is without a block, so we need to create a block to contain it.
        // c: do
        // c:   a;
        // c: while(c);
        // zig: while (true) {
        // zig:   a;
        // zig:   if (!cond) break;
        // zig: }
        TransScopeBlock *child_block_scope = trans_scope_block_create(c, &while_scope->base);
        body_node = child_block_scope->node;
        AstNode *child_statement;
        child_scope = trans_stmt(c, &child_block_scope->base, stmt->getBody(), &child_statement);
        if (child_scope == nullptr) return nullptr;
        body_node->data.block.statements.append(child_statement);
    }

    // if (!cond) break;
    AstNode *condition_node = trans_expr(c, ResultUsedYes, child_scope, stmt->getCond(), TransRValue);
    if (condition_node == nullptr) return nullptr;
    AstNode *terminator_node = trans_create_node(c, NodeTypeIfBoolExpr);
    terminator_node->data.if_bool_expr.condition = trans_create_node_prefix_op(c, PrefixOpBoolNot, condition_node);
    terminator_node->data.if_bool_expr.then_block = trans_create_node(c, NodeTypeBreak);

    body_node->data.block.statements.append(terminator_node);

    while_scope->node->data.while_expr.body = body_node;

    return while_scope->node;
}

static AstNode *trans_for_loop(Context *c, TransScope *parent_scope, const ForStmt *stmt) {
    AstNode *loop_block_node;
    TransScopeWhile *while_scope;
    TransScope *cond_scope;
    const Stmt *init_stmt = stmt->getInit();
    if (init_stmt == nullptr) {
        while_scope = trans_scope_while_create(c, parent_scope);
        loop_block_node = while_scope->node;
        cond_scope = parent_scope;
    } else {
        TransScopeBlock *child_scope = trans_scope_block_create(c, parent_scope);
        loop_block_node = child_scope->node;

        AstNode *vars_node;
        cond_scope = trans_stmt(c, &child_scope->base, init_stmt, &vars_node);
        if (cond_scope == nullptr)
            return nullptr;
        if (vars_node != nullptr)
            child_scope->node->data.block.statements.append(vars_node);

        while_scope = trans_scope_while_create(c, cond_scope);

        child_scope->node->data.block.statements.append(while_scope->node);
    }

    const Stmt *cond_stmt = stmt->getCond();
    if (cond_stmt == nullptr) {
        while_scope->node->data.while_expr.condition = trans_create_node_bool(c, true);
    } else {
        if (Expr::classof(cond_stmt)) {
            const Expr *cond_expr = static_cast<const Expr*>(cond_stmt);
            while_scope->node->data.while_expr.condition = trans_bool_expr(c, ResultUsedYes, cond_scope, cond_expr, TransRValue);

            if (while_scope->node->data.while_expr.condition == nullptr)
                return nullptr;
        } else {
            TransScope *end_cond_scope = trans_stmt(c, cond_scope, cond_stmt,
                                                    &while_scope->node->data.while_expr.condition);
            if (end_cond_scope == nullptr)
                return nullptr;
        }
    }

    const Stmt *inc_stmt = stmt->getInc();
    if (inc_stmt != nullptr) {
        AstNode *inc_node;
        TransScope *inc_scope = trans_stmt(c, cond_scope, inc_stmt, &inc_node);
        if (inc_scope == nullptr)
            return nullptr;
        while_scope->node->data.while_expr.continue_expr = inc_node;
    }

    AstNode *body_statement;
    TransScope *body_scope = trans_stmt(c, &while_scope->base, stmt->getBody(), &body_statement);
    if (body_scope == nullptr)
        return nullptr;
    while_scope->node->data.while_expr.body = body_statement;

    return loop_block_node;
}

static AstNode *trans_switch_stmt(Context *c, TransScope *parent_scope, const SwitchStmt *stmt) {
    TransScopeBlock *block_scope = trans_scope_block_create(c, parent_scope);

    TransScopeSwitch *switch_scope;

    const DeclStmt *var_decl_stmt = stmt->getConditionVariableDeclStmt();
    if (var_decl_stmt == nullptr) {
        switch_scope = trans_scope_switch_create(c, &block_scope->base);
    } else {
        AstNode *vars_node;
        TransScope *var_scope = trans_stmt(c, &block_scope->base, var_decl_stmt, &vars_node);
        if (var_scope == nullptr)
            return nullptr;
        if (vars_node != nullptr)
            block_scope->node->data.block.statements.append(vars_node);
        switch_scope = trans_scope_switch_create(c, var_scope);
    }
    block_scope->node->data.block.statements.append(switch_scope->switch_node);

    // TODO avoid name collisions
    Buf *end_label_name = buf_create_from_str("__switch");
    switch_scope->end_label_name = end_label_name;
    block_scope->node->data.block.name = end_label_name;

    const Expr *cond_expr = stmt->getCond();
    assert(cond_expr != nullptr);

    AstNode *expr_node = trans_expr(c, ResultUsedYes, &block_scope->base, cond_expr, TransRValue);
    if (expr_node == nullptr)
        return nullptr;
    switch_scope->switch_node->data.switch_expr.expr = expr_node;

    AstNode *body_node;
    const Stmt *body_stmt = stmt->getBody();
    if (body_stmt->getStmtClass() == Stmt::CompoundStmtClass) {
        if (trans_compound_stmt_inline(c, &switch_scope->base, (const CompoundStmt *)body_stmt,
                                       block_scope->node, nullptr))
        {
            return nullptr;
        }
    } else {
        TransScope *body_scope = trans_stmt(c, &switch_scope->base, body_stmt, &body_node);
        if (body_scope == nullptr)
            return nullptr;
        if (body_node != nullptr)
            block_scope->node->data.block.statements.append(body_node);
    }

    if (!switch_scope->found_default && !stmt->isAllEnumCasesCovered()) {
        AstNode *prong_node = trans_create_node(c, NodeTypeSwitchProng);
        prong_node->data.switch_prong.expr = trans_create_node_break(c, end_label_name, nullptr);
        switch_scope->switch_node->data.switch_expr.prongs.append(prong_node);
    }

    return block_scope->node;
}

static TransScopeSwitch *trans_scope_switch_find(TransScope *scope) {
    while (scope != nullptr) {
        if (scope->id == TransScopeIdSwitch) {
            return (TransScopeSwitch *)scope;
        }
        scope = scope->parent;
    }
    return nullptr;
}

static int trans_switch_case(Context *c, TransScope *parent_scope, const CaseStmt *stmt, AstNode **out_node,
                             TransScope **out_scope) {
    *out_node = nullptr;

    if (stmt->getRHS() != nullptr) {
        emit_warning(c, stmt->getLocStart(), "TODO support GNU switch case a ... b extension");
        return ErrorUnexpected;
    }

    TransScopeSwitch *switch_scope = trans_scope_switch_find(parent_scope);
    assert(switch_scope != nullptr);

    Buf *label_name = buf_sprintf("__case_%" PRIu32, switch_scope->case_index);
    switch_scope->case_index += 1;

    {
        // Add the prong
        AstNode *prong_node = trans_create_node(c, NodeTypeSwitchProng);
        AstNode *item_node = trans_expr(c, ResultUsedYes, &switch_scope->base, stmt->getLHS(), TransRValue);
        if (item_node == nullptr)
            return ErrorUnexpected;
        prong_node->data.switch_prong.items.append(item_node);
        prong_node->data.switch_prong.expr = trans_create_node_break(c, label_name, nullptr);
        switch_scope->switch_node->data.switch_expr.prongs.append(prong_node);
    }

    TransScopeBlock *scope_block = trans_scope_block_find(parent_scope);

    AstNode *case_block = trans_create_node(c, NodeTypeBlock);
    case_block->data.block.name = label_name;
    case_block->data.block.statements = scope_block->node->data.block.statements;
    scope_block->node->data.block.statements = {0};
    scope_block->node->data.block.statements.append(case_block);

    AstNode *sub_stmt_node;
    TransScope *new_scope = trans_stmt(c, parent_scope, stmt->getSubStmt(), &sub_stmt_node);
    if (new_scope == nullptr)
        return ErrorUnexpected;
    if (sub_stmt_node != nullptr)
        scope_block->node->data.block.statements.append(sub_stmt_node);

    *out_scope = new_scope;
    return ErrorNone;
}

static int trans_switch_default(Context *c, TransScope *parent_scope, const DefaultStmt *stmt, AstNode **out_node,
                                TransScope **out_scope)
{
    *out_node = nullptr;

    TransScopeSwitch *switch_scope = trans_scope_switch_find(parent_scope);
    assert(switch_scope != nullptr);

    Buf *label_name = buf_sprintf("__default");

    {
        // Add the prong
        AstNode *prong_node = trans_create_node(c, NodeTypeSwitchProng);
        prong_node->data.switch_prong.expr = trans_create_node_break(c, label_name, nullptr);
        switch_scope->switch_node->data.switch_expr.prongs.append(prong_node);
        switch_scope->found_default = true;
    }

    TransScopeBlock *scope_block = trans_scope_block_find(parent_scope);

    AstNode *case_block = trans_create_node(c, NodeTypeBlock);
    case_block->data.block.name = label_name;
    case_block->data.block.statements = scope_block->node->data.block.statements;
    scope_block->node->data.block.statements = {0};
    scope_block->node->data.block.statements.append(case_block);

    AstNode *sub_stmt_node;
    TransScope *new_scope = trans_stmt(c, parent_scope, stmt->getSubStmt(), &sub_stmt_node);
    if (new_scope == nullptr)
        return ErrorUnexpected;
    if (sub_stmt_node != nullptr)
        scope_block->node->data.block.statements.append(sub_stmt_node);

    *out_scope = new_scope;
    return ErrorNone;
}

static AstNode *trans_string_literal(Context *c, TransScope *scope, const StringLiteral *stmt) {
    switch (stmt->getKind()) {
        case StringLiteral::Ascii:
        case StringLiteral::UTF8:
            return trans_create_node_str_lit_c(c, string_ref_to_buf(stmt->getString()));
        case StringLiteral::UTF16:
            emit_warning(c, stmt->getLocStart(), "TODO support UTF16 string literals");
            return nullptr;
        case StringLiteral::UTF32:
            emit_warning(c, stmt->getLocStart(), "TODO support UTF32 string literals");
            return nullptr;
        case StringLiteral::Wide:
            emit_warning(c, stmt->getLocStart(), "TODO support wide string literals");
            return nullptr;
    }
    zig_unreachable();
}

static AstNode *trans_break_stmt(Context *c, TransScope *scope, const BreakStmt *stmt) {
    TransScope *cur_scope = scope;
    while (cur_scope != nullptr) {
        if (cur_scope->id == TransScopeIdWhile) {
            return trans_create_node(c, NodeTypeBreak);
        } else if (cur_scope->id == TransScopeIdSwitch) {
            TransScopeSwitch *switch_scope = (TransScopeSwitch *)cur_scope;
            return trans_create_node_break(c, switch_scope->end_label_name, nullptr);
        }
        cur_scope = cur_scope->parent;
    }
    zig_unreachable();
}

static AstNode *trans_continue_stmt(Context *c, TransScope *scope, const ContinueStmt *stmt) {
    return trans_create_node(c, NodeTypeContinue);
}

static int wrap_stmt(AstNode **out_node, TransScope **out_scope, TransScope *in_scope, AstNode *result_node) {
    if (result_node == nullptr)
        return ErrorUnexpected;
    *out_node = result_node;
    if (out_scope != nullptr)
        *out_scope = in_scope;
    return ErrorNone;
}

static int trans_stmt_extra(Context *c, TransScope *scope, const Stmt *stmt,
        ResultUsed result_used, TransLRValue lrvalue,
        AstNode **out_node, TransScope **out_child_scope,
        TransScope **out_node_scope)
{
    Stmt::StmtClass sc = stmt->getStmtClass();
    switch (sc) {
        case Stmt::ReturnStmtClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_return_stmt(c, scope, (const ReturnStmt *)stmt));
        case Stmt::CompoundStmtClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_compound_stmt(c, scope, (const CompoundStmt *)stmt, out_node_scope));
        case Stmt::IntegerLiteralClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_integer_literal(c, (const IntegerLiteral *)stmt));
        case Stmt::ConditionalOperatorClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_conditional_operator(c, result_used, scope, (const ConditionalOperator *)stmt));
        case Stmt::BinaryOperatorClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_binary_operator(c, result_used, scope, (const BinaryOperator *)stmt));
        case Stmt::CompoundAssignOperatorClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_compound_assign_operator(c, result_used, scope, (const CompoundAssignOperator *)stmt));
        case Stmt::ImplicitCastExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_implicit_cast_expr(c, scope, (const ImplicitCastExpr *)stmt));
        case Stmt::DeclRefExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_decl_ref_expr(c, scope, (const DeclRefExpr *)stmt, lrvalue));
        case Stmt::UnaryOperatorClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_unary_operator(c, result_used, scope, (const UnaryOperator *)stmt));
        case Stmt::DeclStmtClass:
            return trans_local_declaration(c, scope, (const DeclStmt *)stmt, out_node, out_child_scope);
        case Stmt::WhileStmtClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_while_loop(c, scope, (const WhileStmt *)stmt));
        case Stmt::IfStmtClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_if_statement(c, scope, (const IfStmt *)stmt));
        case Stmt::CallExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_call_expr(c, result_used, scope, (const CallExpr *)stmt));
        case Stmt::NullStmtClass:
            *out_node = nullptr;
            *out_child_scope = scope;
            return ErrorNone;
        case Stmt::MemberExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_member_expr(c, scope, (const MemberExpr *)stmt));
        case Stmt::ArraySubscriptExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_array_subscript_expr(c, scope, (const ArraySubscriptExpr *)stmt));
        case Stmt::CStyleCastExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_c_style_cast_expr(c, result_used, scope, (const CStyleCastExpr *)stmt, lrvalue));
        case Stmt::UnaryExprOrTypeTraitExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_unary_expr_or_type_trait_expr(c, scope, (const UnaryExprOrTypeTraitExpr *)stmt));
        case Stmt::DoStmtClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_do_loop(c, scope, (const DoStmt *)stmt));
        case Stmt::ForStmtClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_for_loop(c, scope, (const ForStmt *)stmt));
        case Stmt::StringLiteralClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_string_literal(c, scope, (const StringLiteral *)stmt));
        case Stmt::BreakStmtClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_break_stmt(c, scope, (const BreakStmt *)stmt));
        case Stmt::ContinueStmtClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_continue_stmt(c, scope, (const ContinueStmt *)stmt));
        case Stmt::ParenExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_expr(c, result_used, scope, ((const ParenExpr*)stmt)->getSubExpr(), lrvalue));
        case Stmt::SwitchStmtClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                             trans_switch_stmt(c, scope, (const SwitchStmt *)stmt));
        case Stmt::CaseStmtClass:
            return trans_switch_case(c, scope, (const CaseStmt *)stmt, out_node, out_child_scope);
        case Stmt::DefaultStmtClass:
            return trans_switch_default(c, scope, (const DefaultStmt *)stmt, out_node, out_child_scope);
        case Stmt::NoStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C NoStmtClass");
            return ErrorUnexpected;
        case Stmt::GCCAsmStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C GCCAsmStmtClass");
            return ErrorUnexpected;
        case Stmt::MSAsmStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C MSAsmStmtClass");
            return ErrorUnexpected;
        case Stmt::AttributedStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C AttributedStmtClass");
            return ErrorUnexpected;
        case Stmt::CXXCatchStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXCatchStmtClass");
            return ErrorUnexpected;
        case Stmt::CXXForRangeStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXForRangeStmtClass");
            return ErrorUnexpected;
        case Stmt::CXXTryStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXTryStmtClass");
            return ErrorUnexpected;
        case Stmt::CapturedStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CapturedStmtClass");
            return ErrorUnexpected;
        case Stmt::CoreturnStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CoreturnStmtClass");
            return ErrorUnexpected;
        case Stmt::CoroutineBodyStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CoroutineBodyStmtClass");
            return ErrorUnexpected;
        case Stmt::BinaryConditionalOperatorClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C BinaryConditionalOperatorClass");
            return ErrorUnexpected;
        case Stmt::AddrLabelExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C AddrLabelExprClass");
            return ErrorUnexpected;
        case Stmt::ArrayInitIndexExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ArrayInitIndexExprClass");
            return ErrorUnexpected;
        case Stmt::ArrayInitLoopExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ArrayInitLoopExprClass");
            return ErrorUnexpected;
        case Stmt::ArrayTypeTraitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ArrayTypeTraitExprClass");
            return ErrorUnexpected;
        case Stmt::AsTypeExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C AsTypeExprClass");
            return ErrorUnexpected;
        case Stmt::AtomicExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C AtomicExprClass");
            return ErrorUnexpected;
        case Stmt::BlockExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C BlockExprClass");
            return ErrorUnexpected;
        case Stmt::CXXBindTemporaryExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXBindTemporaryExprClass");
            return ErrorUnexpected;
        case Stmt::CXXBoolLiteralExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXBoolLiteralExprClass");
            return ErrorUnexpected;
        case Stmt::CXXConstructExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXConstructExprClass");
            return ErrorUnexpected;
        case Stmt::CXXTemporaryObjectExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXTemporaryObjectExprClass");
            return ErrorUnexpected;
        case Stmt::CXXDefaultArgExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXDefaultArgExprClass");
            return ErrorUnexpected;
        case Stmt::CXXDefaultInitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXDefaultInitExprClass");
            return ErrorUnexpected;
        case Stmt::CXXDeleteExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXDeleteExprClass");
            return ErrorUnexpected;
        case Stmt::CXXDependentScopeMemberExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXDependentScopeMemberExprClass");
            return ErrorUnexpected;
        case Stmt::CXXFoldExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXFoldExprClass");
            return ErrorUnexpected;
        case Stmt::CXXInheritedCtorInitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXInheritedCtorInitExprClass");
            return ErrorUnexpected;
        case Stmt::CXXNewExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXNewExprClass");
            return ErrorUnexpected;
        case Stmt::CXXNoexceptExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXNoexceptExprClass");
            return ErrorUnexpected;
        case Stmt::CXXNullPtrLiteralExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXNullPtrLiteralExprClass");
            return ErrorUnexpected;
        case Stmt::CXXPseudoDestructorExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXPseudoDestructorExprClass");
            return ErrorUnexpected;
        case Stmt::CXXScalarValueInitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXScalarValueInitExprClass");
            return ErrorUnexpected;
        case Stmt::CXXStdInitializerListExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXStdInitializerListExprClass");
            return ErrorUnexpected;
        case Stmt::CXXThisExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXThisExprClass");
            return ErrorUnexpected;
        case Stmt::CXXThrowExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXThrowExprClass");
            return ErrorUnexpected;
        case Stmt::CXXTypeidExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXTypeidExprClass");
            return ErrorUnexpected;
        case Stmt::CXXUnresolvedConstructExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXUnresolvedConstructExprClass");
            return ErrorUnexpected;
        case Stmt::CXXUuidofExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXUuidofExprClass");
            return ErrorUnexpected;
        case Stmt::CUDAKernelCallExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CUDAKernelCallExprClass");
            return ErrorUnexpected;
        case Stmt::CXXMemberCallExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXMemberCallExprClass");
            return ErrorUnexpected;
        case Stmt::CXXOperatorCallExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXOperatorCallExprClass");
            return ErrorUnexpected;
        case Stmt::UserDefinedLiteralClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C UserDefinedLiteralClass");
            return ErrorUnexpected;
        case Stmt::CXXFunctionalCastExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXFunctionalCastExprClass");
            return ErrorUnexpected;
        case Stmt::CXXConstCastExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXConstCastExprClass");
            return ErrorUnexpected;
        case Stmt::CXXDynamicCastExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXDynamicCastExprClass");
            return ErrorUnexpected;
        case Stmt::CXXReinterpretCastExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXReinterpretCastExprClass");
            return ErrorUnexpected;
        case Stmt::CXXStaticCastExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CXXStaticCastExprClass");
            return ErrorUnexpected;
        case Stmt::ObjCBridgedCastExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCBridgedCastExprClass");
            return ErrorUnexpected;
        case Stmt::CharacterLiteralClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CharacterLiteralClass");
            return ErrorUnexpected;
        case Stmt::ChooseExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ChooseExprClass");
            return ErrorUnexpected;
        case Stmt::CompoundLiteralExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CompoundLiteralExprClass");
            return ErrorUnexpected;
        case Stmt::ConvertVectorExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ConvertVectorExprClass");
            return ErrorUnexpected;
        case Stmt::CoawaitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CoawaitExprClass");
            return ErrorUnexpected;
        case Stmt::CoyieldExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C CoyieldExprClass");
            return ErrorUnexpected;
        case Stmt::DependentCoawaitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C DependentCoawaitExprClass");
            return ErrorUnexpected;
        case Stmt::DependentScopeDeclRefExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C DependentScopeDeclRefExprClass");
            return ErrorUnexpected;
        case Stmt::DesignatedInitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C DesignatedInitExprClass");
            return ErrorUnexpected;
        case Stmt::DesignatedInitUpdateExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C DesignatedInitUpdateExprClass");
            return ErrorUnexpected;
        case Stmt::ExprWithCleanupsClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ExprWithCleanupsClass");
            return ErrorUnexpected;
        case Stmt::ExpressionTraitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ExpressionTraitExprClass");
            return ErrorUnexpected;
        case Stmt::ExtVectorElementExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ExtVectorElementExprClass");
            return ErrorUnexpected;
        case Stmt::FloatingLiteralClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C FloatingLiteralClass");
            return ErrorUnexpected;
        case Stmt::FunctionParmPackExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C FunctionParmPackExprClass");
            return ErrorUnexpected;
        case Stmt::GNUNullExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C GNUNullExprClass");
            return ErrorUnexpected;
        case Stmt::GenericSelectionExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C GenericSelectionExprClass");
            return ErrorUnexpected;
        case Stmt::ImaginaryLiteralClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ImaginaryLiteralClass");
            return ErrorUnexpected;
        case Stmt::ImplicitValueInitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ImplicitValueInitExprClass");
            return ErrorUnexpected;
        case Stmt::InitListExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C InitListExprClass");
            return ErrorUnexpected;
        case Stmt::LambdaExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C LambdaExprClass");
            return ErrorUnexpected;
        case Stmt::MSPropertyRefExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C MSPropertyRefExprClass");
            return ErrorUnexpected;
        case Stmt::MSPropertySubscriptExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C MSPropertySubscriptExprClass");
            return ErrorUnexpected;
        case Stmt::MaterializeTemporaryExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C MaterializeTemporaryExprClass");
            return ErrorUnexpected;
        case Stmt::NoInitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C NoInitExprClass");
            return ErrorUnexpected;
        case Stmt::OMPArraySectionExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPArraySectionExprClass");
            return ErrorUnexpected;
        case Stmt::ObjCArrayLiteralClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCArrayLiteralClass");
            return ErrorUnexpected;
        case Stmt::ObjCAvailabilityCheckExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCAvailabilityCheckExprClass");
            return ErrorUnexpected;
        case Stmt::ObjCBoolLiteralExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCBoolLiteralExprClass");
            return ErrorUnexpected;
        case Stmt::ObjCBoxedExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCBoxedExprClass");
            return ErrorUnexpected;
        case Stmt::ObjCDictionaryLiteralClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCDictionaryLiteralClass");
            return ErrorUnexpected;
        case Stmt::ObjCEncodeExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCEncodeExprClass");
            return ErrorUnexpected;
        case Stmt::ObjCIndirectCopyRestoreExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCIndirectCopyRestoreExprClass");
            return ErrorUnexpected;
        case Stmt::ObjCIsaExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCIsaExprClass");
            return ErrorUnexpected;
        case Stmt::ObjCIvarRefExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCIvarRefExprClass");
            return ErrorUnexpected;
        case Stmt::ObjCMessageExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCMessageExprClass");
            return ErrorUnexpected;
        case Stmt::ObjCPropertyRefExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCPropertyRefExprClass");
            return ErrorUnexpected;
        case Stmt::ObjCProtocolExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCProtocolExprClass");
            return ErrorUnexpected;
        case Stmt::ObjCSelectorExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCSelectorExprClass");
            return ErrorUnexpected;
        case Stmt::ObjCStringLiteralClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCStringLiteralClass");
            return ErrorUnexpected;
        case Stmt::ObjCSubscriptRefExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCSubscriptRefExprClass");
            return ErrorUnexpected;
        case Stmt::OffsetOfExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OffsetOfExprClass");
            return ErrorUnexpected;
        case Stmt::OpaqueValueExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OpaqueValueExprClass");
            return ErrorUnexpected;
        case Stmt::UnresolvedLookupExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C UnresolvedLookupExprClass");
            return ErrorUnexpected;
        case Stmt::UnresolvedMemberExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C UnresolvedMemberExprClass");
            return ErrorUnexpected;
        case Stmt::PackExpansionExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C PackExpansionExprClass");
            return ErrorUnexpected;
        case Stmt::ParenListExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ParenListExprClass");
            return ErrorUnexpected;
        case Stmt::PredefinedExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C PredefinedExprClass");
            return ErrorUnexpected;
        case Stmt::PseudoObjectExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C PseudoObjectExprClass");
            return ErrorUnexpected;
        case Stmt::ShuffleVectorExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ShuffleVectorExprClass");
            return ErrorUnexpected;
        case Stmt::SizeOfPackExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C SizeOfPackExprClass");
            return ErrorUnexpected;
        case Stmt::StmtExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C StmtExprClass");
            return ErrorUnexpected;
        case Stmt::SubstNonTypeTemplateParmExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C SubstNonTypeTemplateParmExprClass");
            return ErrorUnexpected;
        case Stmt::SubstNonTypeTemplateParmPackExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C SubstNonTypeTemplateParmPackExprClass");
            return ErrorUnexpected;
        case Stmt::TypeTraitExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C TypeTraitExprClass");
            return ErrorUnexpected;
        case Stmt::TypoExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C TypoExprClass");
            return ErrorUnexpected;
        case Stmt::VAArgExprClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C VAArgExprClass");
            return ErrorUnexpected;
        case Stmt::GotoStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C GotoStmtClass");
            return ErrorUnexpected;
        case Stmt::IndirectGotoStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C IndirectGotoStmtClass");
            return ErrorUnexpected;
        case Stmt::LabelStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C LabelStmtClass");
            return ErrorUnexpected;
        case Stmt::MSDependentExistsStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C MSDependentExistsStmtClass");
            return ErrorUnexpected;
        case Stmt::OMPAtomicDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPAtomicDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPBarrierDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPBarrierDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPCancelDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPCancelDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPCancellationPointDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPCancellationPointDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPCriticalDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPCriticalDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPFlushDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPFlushDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPDistributeDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPDistributeDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPDistributeParallelForDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPDistributeParallelForDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPDistributeParallelForSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPDistributeParallelForSimdDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPDistributeSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPDistributeSimdDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPForDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPForDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPForSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPForSimdDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPParallelForDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPParallelForDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPParallelForSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPParallelForSimdDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPSimdDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTargetParallelForSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetParallelForSimdDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTargetSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetSimdDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTargetTeamsDistributeDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetTeamsDistributeDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTargetTeamsDistributeParallelForDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetTeamsDistributeParallelForDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTargetTeamsDistributeParallelForSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetTeamsDistributeParallelForSimdDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTargetTeamsDistributeSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetTeamsDistributeSimdDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTaskLoopDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTaskLoopDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTaskLoopSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTaskLoopSimdDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTeamsDistributeDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTeamsDistributeDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTeamsDistributeParallelForDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTeamsDistributeParallelForDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTeamsDistributeParallelForSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTeamsDistributeParallelForSimdDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTeamsDistributeSimdDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTeamsDistributeSimdDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPMasterDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPMasterDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPOrderedDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPOrderedDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPParallelDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPParallelDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPParallelSectionsDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPParallelSectionsDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPSectionDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPSectionDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPSectionsDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPSectionsDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPSingleDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPSingleDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTargetDataDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetDataDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTargetDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTargetEnterDataDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetEnterDataDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTargetExitDataDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetExitDataDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTargetParallelDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetParallelDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTargetParallelForDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetParallelForDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTargetTeamsDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetTeamsDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTargetUpdateDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTargetUpdateDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTaskDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTaskDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTaskgroupDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTaskgroupDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTaskwaitDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTaskwaitDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTaskyieldDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTaskyieldDirectiveClass");
            return ErrorUnexpected;
        case Stmt::OMPTeamsDirectiveClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C OMPTeamsDirectiveClass");
            return ErrorUnexpected;
        case Stmt::ObjCAtCatchStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCAtCatchStmtClass");
            return ErrorUnexpected;
        case Stmt::ObjCAtFinallyStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCAtFinallyStmtClass");
            return ErrorUnexpected;
        case Stmt::ObjCAtSynchronizedStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCAtSynchronizedStmtClass");
            return ErrorUnexpected;
        case Stmt::ObjCAtThrowStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCAtThrowStmtClass");
            return ErrorUnexpected;
        case Stmt::ObjCAtTryStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCAtTryStmtClass");
            return ErrorUnexpected;
        case Stmt::ObjCAutoreleasePoolStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCAutoreleasePoolStmtClass");
            return ErrorUnexpected;
        case Stmt::ObjCForCollectionStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C ObjCForCollectionStmtClass");
            return ErrorUnexpected;
        case Stmt::SEHExceptStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C SEHExceptStmtClass");
            return ErrorUnexpected;
        case Stmt::SEHFinallyStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C SEHFinallyStmtClass");
            return ErrorUnexpected;
        case Stmt::SEHLeaveStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C SEHLeaveStmtClass");
            return ErrorUnexpected;
        case Stmt::SEHTryStmtClass:
            emit_warning(c, stmt->getLocStart(), "TODO handle C SEHTryStmtClass");
            return ErrorUnexpected;
    }
    zig_unreachable();
}

// Returns null if there was an error
static AstNode *trans_expr(Context *c, ResultUsed result_used, TransScope *scope, const Expr *expr,
        TransLRValue lrval)
{
    AstNode *result_node;
    TransScope *result_scope;
    if (trans_stmt_extra(c, scope, expr, result_used, lrval, &result_node, &result_scope, nullptr)) {
        return nullptr;
    }
    return result_node;
}

// Statements have no result and no concept of L or R value.
// Returns child scope, or null if there was an error
static TransScope *trans_stmt(Context *c, TransScope *scope, const Stmt *stmt, AstNode **out_node) {
    TransScope *child_scope;
    if (trans_stmt_extra(c, scope, stmt, ResultUsedNo, TransRValue, out_node, &child_scope, nullptr)) {
        return nullptr;
    }
    return child_scope;
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
        proto_node->data.fn_proto.visib_mod = c->visib_mod;
        proto_node->data.fn_proto.is_export = fn_decl->hasBody() ? c->want_export : false;
    } else if (sc == SC_Extern || sc == SC_Static) {
        proto_node->data.fn_proto.visib_mod = c->visib_mod;
    } else if (sc == SC_PrivateExtern) {
        emit_warning(c, fn_decl->getLocation(), "unsupported storage class: private extern");
        return;
    } else {
        emit_warning(c, fn_decl->getLocation(), "unsupported storage class: unknown");
        return;
    }

    TransScope *scope = &c->global_scope->base;

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

        TransScopeVar *scope_var = trans_scope_var_create(c, scope, proto_param_name);
        scope = &scope_var->base;

        param_node->data.param_decl.name = scope_var->zig_name;
    }

    if (!fn_decl->hasBody()) {
        // just a prototype
        add_top_level_decl(c, proto_node->data.fn_proto.name, proto_node);
        return;
    }

    // actual function definition with body
    c->ptr_params.clear();
    Stmt *body = fn_decl->getBody();
    AstNode *actual_body_node;
    TransScope *result_scope = trans_stmt(c, scope, body, &actual_body_node);
    if (result_scope == nullptr) {
        emit_warning(c, fn_decl->getLocation(), "unable to translate function");
        return;
    }
    assert(actual_body_node != nullptr);
    assert(actual_body_node->type == NodeTypeBlock);

    // it worked

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
    add_top_level_decl(c, fn_def_node->data.fn_def.fn_proto->data.fn_proto.name, fn_def_node);
}

static AstNode *resolve_typdef_as_builtin(Context *c, const TypedefNameDecl *typedef_decl, const char *primitive_name) {
    AstNode *node = trans_create_node_symbol_str(c, primitive_name);
    c->decl_table.put(typedef_decl, node);
    return node;
}

static AstNode *resolve_typedef_decl(Context *c, const TypedefNameDecl *typedef_decl) {
    auto existing_entry = c->decl_table.maybe_get((void*)typedef_decl->getCanonicalDecl());
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

    // trans_qual_type here might cause us to look at this typedef again so we put the item in the map first
    AstNode *symbol_node = trans_create_node_symbol(c, type_name);
    c->decl_table.put(typedef_decl->getCanonicalDecl(), symbol_node);

    AstNode *type_node = trans_qual_type(c, child_qt, typedef_decl->getLocation());
    if (type_node == nullptr) {
        emit_warning(c, typedef_decl->getLocation(), "typedef %s - unresolved child type", buf_ptr(type_name));
        c->decl_table.put(typedef_decl, nullptr);
        // TODO add global var with type_name equal to @compileError("unable to resolve C type") 
        return nullptr;
    }
    add_global_var(c, type_name, type_node);

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

    AstNode *enum_node = trans_create_node(c, NodeTypeContainerDecl);
    enum_node->data.container_decl.kind = ContainerKindEnum;
    enum_node->data.container_decl.layout = ContainerLayoutExtern;
    // TODO only emit this tag type if the enum tag type is not the default.
    // I don't know what the default is, need to figure out how clang is deciding.
    // it appears to at least be different across gcc/msvc
    if (!c_is_builtin_type(c, enum_decl->getIntegerType(), BuiltinType::UInt) &&
        !c_is_builtin_type(c, enum_decl->getIntegerType(), BuiltinType::Int))
    {
        enum_node->data.container_decl.init_arg_expr = tag_int_type;
    }
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

        AstNode *int_node = pure_enum && !is_anonymous ? nullptr : trans_create_node_apint(c, enum_const->getInitVal());
        AstNode *field_node = trans_create_node(c, NodeTypeStructField);
        field_node->data.struct_field.name = field_name;
        field_node->data.struct_field.type = nullptr;
        field_node->data.struct_field.value = int_node;
        enum_node->data.container_decl.fields.items[i] = field_node;

        // in C each enum value is in the global namespace. so we put them there too.
        // at this point we can rely on the enum emitting successfully
        if (is_anonymous) {
            Buf *enum_val_name = buf_create_from_str(decl_name(enum_const));
            add_global_var(c, enum_val_name, int_node);
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
    const char *container_kind_name;
    ContainerKind container_kind;
    if (record_decl->isUnion()) {
        container_kind_name = "union";
        container_kind = ContainerKindUnion;
    } else if (record_decl->isStruct()) {
        container_kind_name = "struct";
        container_kind = ContainerKindStruct;
    } else {
        emit_warning(c, record_decl->getLocation(), "skipping record %s, not a struct or union", raw_name);
        c->decl_table.put(record_decl->getCanonicalDecl(), nullptr);
        return nullptr;
    }

    bool is_anonymous = record_decl->isAnonymousStructOrUnion() || raw_name[0] == 0;
    Buf *bare_name = is_anonymous ? nullptr : buf_create_from_str(raw_name);
    Buf *full_type_name = (bare_name == nullptr) ?
        nullptr : buf_sprintf("%s_%s", container_kind_name, buf_ptr(bare_name));

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
            emit_warning(c, field_decl->getLocation(), "%s %s demoted to opaque type - has bitfield",
                    container_kind_name,
                    is_anonymous ? "(anon)" : buf_ptr(bare_name));
            return demote_struct_to_opaque(c, record_decl, full_type_name, bare_name);
        }
    }

    AstNode *struct_node = trans_create_node(c, NodeTypeContainerDecl);
    struct_node->data.container_decl.kind = container_kind;
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
                    "%s %s demoted to opaque type - unresolved type",
                    container_kind_name,
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

static AstNode *trans_ap_value(Context *c, APValue *ap_value, QualType qt, const SourceLocation &source_loc) {
    switch (ap_value->getKind()) {
        case APValue::Int:
            return trans_create_node_apint(c, ap_value->getInt());
        case APValue::Uninitialized:
            return trans_create_node(c, NodeTypeUndefinedLiteral);
        case APValue::Array: {
            emit_warning(c, source_loc, "TODO add a test case for this code");

            unsigned init_count = ap_value->getArrayInitializedElts();
            unsigned all_count = ap_value->getArraySize();
            unsigned leftover_count = all_count - init_count;
            AstNode *init_node = trans_create_node(c, NodeTypeContainerInitExpr);
            AstNode *arr_type_node = trans_qual_type(c, qt, source_loc);
            init_node->data.container_init_expr.type = arr_type_node;
            init_node->data.container_init_expr.kind = ContainerInitKindArray;

            QualType child_qt = qt.getTypePtr()->getLocallyUnqualifiedSingleStepDesugaredType();

            for (size_t i = 0; i < init_count; i += 1) {
                APValue &elem_ap_val = ap_value->getArrayInitializedElt(i);
                AstNode *elem_node = trans_ap_value(c, &elem_ap_val, child_qt, source_loc);
                if (elem_node == nullptr)
                    return nullptr;
                init_node->data.container_init_expr.entries.append(elem_node);
            }
            if (leftover_count == 0) {
                return init_node;
            }

            APValue &filler_ap_val = ap_value->getArrayFiller();
            AstNode *filler_node = trans_ap_value(c, &filler_ap_val, child_qt, source_loc);
            if (filler_node == nullptr)
                return nullptr;

            AstNode *filler_arr_1 = trans_create_node(c, NodeTypeContainerInitExpr);
            init_node->data.container_init_expr.type = arr_type_node;
            init_node->data.container_init_expr.kind = ContainerInitKindArray;
            init_node->data.container_init_expr.entries.append(filler_node);

            AstNode *rhs_node;
            if (leftover_count == 1) {
                rhs_node = filler_arr_1;
            } else {
                AstNode *amt_node = trans_create_node_unsigned(c, leftover_count);
                rhs_node = trans_create_node_bin_op(c, filler_arr_1, BinOpTypeArrayMult, amt_node);
            }

            return trans_create_node_bin_op(c, init_node, BinOpTypeArrayCat, rhs_node);
        }
        case APValue::LValue: {
            const APValue::LValueBase lval_base = ap_value->getLValueBase();
            if (const Expr *expr = lval_base.dyn_cast<const Expr *>()) {
                return trans_expr(c, ResultUsedYes, &c->global_scope->base, expr, TransRValue);
            }
            //const ValueDecl *value_decl = lval_base.get<const ValueDecl *>();
            emit_warning(c, source_loc, "TODO handle initializer LValue ValueDecl");
            return nullptr;
        }
        case APValue::Float:
            emit_warning(c, source_loc, "unsupported initializer value kind: Float");
            return nullptr;
        case APValue::ComplexInt:
            emit_warning(c, source_loc, "unsupported initializer value kind: ComplexInt");
            return nullptr;
        case APValue::ComplexFloat:
            emit_warning(c, source_loc, "unsupported initializer value kind: ComplexFloat");
            return nullptr;
        case APValue::Vector:
            emit_warning(c, source_loc, "unsupported initializer value kind: Vector");
            return nullptr;
        case APValue::Struct:
            emit_warning(c, source_loc, "unsupported initializer value kind: Struct");
            return nullptr;
        case APValue::Union:
            emit_warning(c, source_loc, "unsupported initializer value kind: Union");
            return nullptr;
        case APValue::MemberPointer:
            emit_warning(c, source_loc, "unsupported initializer value kind: MemberPointer");
            return nullptr;
        case APValue::AddrLabelDiff:
            emit_warning(c, source_loc, "unsupported initializer value kind: AddrLabelDiff");
            return nullptr;
    }
    zig_unreachable();
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
            init_node = trans_ap_value(c, ap_value, qt, var_decl->getLocation());
            if (init_node == nullptr)
                return;
        } else {
            init_node = trans_create_node(c, NodeTypeUndefinedLiteral);
        }

        AstNode *var_node = trans_create_node_var_decl_global(c, is_const, name, var_type, init_node);
        add_top_level_decl(c, name, var_node);
        return;
    }

    if (is_extern) {
        AstNode *var_node = trans_create_node_var_decl_global(c, is_const, name, var_type, nullptr);
        var_node->data.variable_declaration.is_extern = true;
        add_top_level_decl(c, name, var_node);
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

static bool name_exists_global(Context *c, Buf *name) {
    return get_global(c, name) != nullptr;
}

static bool name_exists_scope(Context *c, Buf *name, TransScope *scope) {
    while (scope != nullptr) {
        if (scope->id == TransScopeIdVar) {
            TransScopeVar *var_scope = (TransScopeVar *)scope;
            if (buf_eql_buf(name, var_scope->zig_name)) {
                return true;
            }
        }
        scope = scope->parent;
    }
    return name_exists_global(c, name);
}

static Buf *get_unique_name(Context *c, Buf *name, TransScope *scope) {
    Buf *proposed_name = name;
    int count = 0;
    while (name_exists_scope(c, proposed_name, scope)) {
        if (proposed_name == name) {
            proposed_name = buf_alloc();
        }
        buf_resize(proposed_name, 0);
        buf_appendf(proposed_name, "%s_%d", buf_ptr(name), count);
        count += 1;
    }
    return proposed_name;
}

static TransScopeRoot *trans_scope_root_create(Context *c) {
    TransScopeRoot *result = allocate<TransScopeRoot>(1);
    result->base.id = TransScopeIdRoot;
    return result;
}

static TransScopeWhile *trans_scope_while_create(Context *c, TransScope *parent_scope) {
    TransScopeWhile *result = allocate<TransScopeWhile>(1);
    result->base.id = TransScopeIdWhile;
    result->base.parent = parent_scope;
    result->node = trans_create_node(c, NodeTypeWhileExpr);
    return result;
}

static TransScopeBlock *trans_scope_block_create(Context *c, TransScope *parent_scope) {
    TransScopeBlock *result = allocate<TransScopeBlock>(1);
    result->base.id = TransScopeIdBlock;
    result->base.parent = parent_scope;
    result->node = trans_create_node(c, NodeTypeBlock);
    return result;
}

static TransScopeVar *trans_scope_var_create(Context *c, TransScope *parent_scope, Buf *wanted_name) {
    TransScopeVar *result = allocate<TransScopeVar>(1);
    result->base.id = TransScopeIdVar;
    result->base.parent = parent_scope;
    result->c_name = wanted_name;
    result->zig_name = get_unique_name(c, wanted_name, parent_scope);
    return result;
}

static TransScopeSwitch *trans_scope_switch_create(Context *c, TransScope *parent_scope) {
    TransScopeSwitch *result = allocate<TransScopeSwitch>(1);
    result->base.id = TransScopeIdSwitch;
    result->base.parent = parent_scope;
    result->switch_node = trans_create_node(c, NodeTypeSwitchExpr);
    return result;
}

static TransScopeBlock *trans_scope_block_find(TransScope *scope) {
    while (scope != nullptr) {
        if (scope->id == TransScopeIdBlock) {
            return (TransScopeBlock *)scope;
        }
        scope = scope->parent;
    }
    return nullptr;
}

static void render_aliases(Context *c) {
    for (size_t i = 0; i < c->aliases.length; i += 1) {
        Alias *alias = &c->aliases.at(i);
        if (name_exists_global(c, alias->new_name))
            continue;

        add_global_var(c, alias->new_name, trans_create_node_symbol(c, alias->canon_name));
    }
}

static AstNode *trans_lookup_ast_container_typeof(Context *c, AstNode *ref_node);

static AstNode *trans_lookup_ast_container(Context *c, AstNode *type_node) {
    if (type_node == nullptr) {
        return nullptr;
    } else if (type_node->type == NodeTypeContainerDecl) {
        return type_node;
    } else if (type_node->type == NodeTypePrefixOpExpr) {
        return type_node;
    } else if (type_node->type == NodeTypeSymbol) {
        AstNode *existing_node = get_global(c, type_node->data.symbol_expr.symbol);
        if (existing_node == nullptr)
            return nullptr;
        if (existing_node->type != NodeTypeVariableDeclaration)
            return nullptr;
        return trans_lookup_ast_container(c, existing_node->data.variable_declaration.expr);
    } else if (type_node->type == NodeTypeFieldAccessExpr) {
        AstNode *container_node = trans_lookup_ast_container_typeof(c, type_node->data.field_access_expr.struct_expr);
        if (container_node == nullptr)
            return nullptr;
        if (container_node->type != NodeTypeContainerDecl)
            return container_node;

        for (size_t i = 0; i < container_node->data.container_decl.fields.length; i += 1) {
            AstNode *field_node = container_node->data.container_decl.fields.items[i];
            if (buf_eql_buf(field_node->data.struct_field.name, type_node->data.field_access_expr.field_name)) {
                return trans_lookup_ast_container(c, field_node->data.struct_field.type);
            }
        }
        return nullptr;
    } else {
        return nullptr;
    }
}

static AstNode *trans_lookup_ast_container_typeof(Context *c, AstNode *ref_node) {
    if (ref_node->type == NodeTypeSymbol) {
        AstNode *existing_node = get_global(c, ref_node->data.symbol_expr.symbol);
        if (existing_node == nullptr)
            return nullptr;
        if (existing_node->type != NodeTypeVariableDeclaration)
            return nullptr;
        return trans_lookup_ast_container(c, existing_node->data.variable_declaration.type);
    } else if (ref_node->type == NodeTypeFieldAccessExpr) {
        AstNode *container_node = trans_lookup_ast_container_typeof(c, ref_node->data.field_access_expr.struct_expr);
        if (container_node == nullptr)
            return nullptr;
        if (container_node->type != NodeTypeContainerDecl)
            return container_node;
        for (size_t i = 0; i < container_node->data.container_decl.fields.length; i += 1) {
            AstNode *field_node = container_node->data.container_decl.fields.items[i];
            if (buf_eql_buf(field_node->data.struct_field.name, ref_node->data.field_access_expr.field_name)) {
                return trans_lookup_ast_container(c, field_node->data.struct_field.type);
            }
        }
        return nullptr;
    } else {
        return nullptr;
    }
}

static AstNode *trans_lookup_ast_maybe_fn(Context *c, AstNode *ref_node) {
    AstNode *prefix_node = trans_lookup_ast_container_typeof(c, ref_node);
    if (prefix_node == nullptr)
        return nullptr;
    if (prefix_node->type != NodeTypePrefixOpExpr)
        return nullptr;
    if (prefix_node->data.prefix_op_expr.prefix_op != PrefixOpOptional)
        return nullptr;

    AstNode *fn_proto_node = prefix_node->data.prefix_op_expr.primary_expr;
    if (fn_proto_node->type != NodeTypeFnProto)
        return nullptr;

    return fn_proto_node;
}

static void render_macros(Context *c) {
    auto it = c->macro_table.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        AstNode *proto_node;
        AstNode *value_node = entry->value;
        if (value_node->type == NodeTypeFnDef) {
            add_top_level_decl(c, value_node->data.fn_def.fn_proto->data.fn_proto.name, value_node);
        } else if ((proto_node = trans_lookup_ast_maybe_fn(c, value_node))) {
            // If a macro aliases a global variable which is a function pointer, we conclude that
            // the macro is intended to represent a function that assumes the function pointer
            // variable is non-null and calls it.
            AstNode *inline_fn_node = trans_create_node_inline_fn(c, entry->key, value_node, proto_node);
            add_top_level_decl(c, entry->key, inline_fn_node);
        } else {
            add_global_var(c, entry->key, value_node);
        }
    }
}

static AstNode *parse_ctok_primary_expr(Context *c, CTokenize *ctok, size_t *tok_i);
static AstNode *parse_ctok_expr(Context *c, CTokenize *ctok, size_t *tok_i);
static AstNode *parse_ctok_prefix_op_expr(Context *c, CTokenize *ctok, size_t *tok_i);

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

static AstNode *parse_ctok_primary_expr(Context *c, CTokenize *ctok, size_t *tok_i) {
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
                AstNode *inner_node = parse_ctok_expr(c, ctok, tok_i);
                if (inner_node == nullptr) {
                    return nullptr;
                }

                CTok *next_tok = &ctok->tokens.at(*tok_i);
                if (next_tok->id == CTokIdRParen) {
                    *tok_i += 1;
                    return inner_node;
                }

                AstNode *node_to_cast = parse_ctok_expr(c, ctok, tok_i);
                if (node_to_cast == nullptr) {
                    return nullptr;
                }

                CTok *next_tok2 = &ctok->tokens.at(*tok_i);
                if (next_tok2->id != CTokIdRParen) {
                    return nullptr;
                }
                *tok_i += 1;


                //if (@typeId(@typeOf(x)) == @import("builtin").TypeId.Pointer)
                //    @ptrCast(dest, x)
                //else if (@typeId(@typeOf(x)) == @import("builtin").TypeId.Integer)
                //    @intToPtr(dest, x)
                //else
                //    (dest)(x)

                AstNode *import_builtin = trans_create_node_builtin_fn_call_str(c, "import");
                import_builtin->data.fn_call_expr.params.append(trans_create_node_str_lit_non_c(c, buf_create_from_str("builtin")));
                AstNode *typeid_type = trans_create_node_field_access_str(c, import_builtin, "TypeId");
                AstNode *typeid_pointer = trans_create_node_field_access_str(c, typeid_type, "Pointer");
                AstNode *typeid_integer = trans_create_node_field_access_str(c, typeid_type, "Int");
                AstNode *typeof_x = trans_create_node_builtin_fn_call_str(c, "typeOf");
                typeof_x->data.fn_call_expr.params.append(node_to_cast);
                AstNode *typeid_value = trans_create_node_builtin_fn_call_str(c, "typeId");
                typeid_value->data.fn_call_expr.params.append(typeof_x);

                AstNode *outer_if_cond = trans_create_node_bin_op(c, typeid_value, BinOpTypeCmpEq, typeid_pointer);
                AstNode *inner_if_cond = trans_create_node_bin_op(c, typeid_value, BinOpTypeCmpEq, typeid_integer);
                AstNode *inner_if_then = trans_create_node_builtin_fn_call_str(c, "intToPtr");
                inner_if_then->data.fn_call_expr.params.append(inner_node);
                inner_if_then->data.fn_call_expr.params.append(node_to_cast);
                AstNode *inner_if_else = trans_create_node_cast(c, inner_node, node_to_cast);
                AstNode *inner_if = trans_create_node_if(c, inner_if_cond, inner_if_then, inner_if_else);
                AstNode *outer_if_then = trans_create_node_builtin_fn_call_str(c, "ptrCast");
                outer_if_then->data.fn_call_expr.params.append(inner_node);
                outer_if_then->data.fn_call_expr.params.append(node_to_cast);
                return trans_create_node_if(c, outer_if_cond, outer_if_then, inner_if);
            }
        case CTokIdDot:
        case CTokIdEOF:
        case CTokIdRParen:
        case CTokIdAsterisk:
        case CTokIdBang:
        case CTokIdTilde:
            // not able to make sense of this
            return nullptr;
    }
    zig_unreachable();
}

static AstNode *parse_ctok_expr(Context *c, CTokenize *ctok, size_t *tok_i) {
    return parse_ctok_prefix_op_expr(c, ctok, tok_i);
}

static AstNode *parse_ctok_suffix_op_expr(Context *c, CTokenize *ctok, size_t *tok_i) {
    AstNode *node = parse_ctok_primary_expr(c, ctok, tok_i);
    if (node == nullptr)
        return nullptr;

    while (true) {
        CTok *first_tok = &ctok->tokens.at(*tok_i);
        if (first_tok->id == CTokIdDot) {
            *tok_i += 1;

            CTok *name_tok = &ctok->tokens.at(*tok_i);
            if (name_tok->id != CTokIdSymbol) {
                return nullptr;
            }
            *tok_i += 1;

            node = trans_create_node_field_access(c, node, buf_create_from_buf(&name_tok->data.symbol));
        } else if (first_tok->id == CTokIdAsterisk) {
            *tok_i += 1;

            node = trans_create_node_ptr_type(c, false, false, node, PtrLenUnknown);
        } else {
            return node;
        }
    }
}

static AstNode *parse_ctok_prefix_op_expr(Context *c, CTokenize *ctok, size_t *tok_i) {
    CTok *op_tok = &ctok->tokens.at(*tok_i);

    switch (op_tok->id) {
        case CTokIdBang:
            {
                *tok_i += 1;
                AstNode *prefix_op_expr = parse_ctok_prefix_op_expr(c, ctok, tok_i);
                if (prefix_op_expr == nullptr)
                    return nullptr;
                return trans_create_node_prefix_op(c, PrefixOpBoolNot, prefix_op_expr);
            }
        case CTokIdMinus:
            {
                *tok_i += 1;
                AstNode *prefix_op_expr = parse_ctok_prefix_op_expr(c, ctok, tok_i);
                if (prefix_op_expr == nullptr)
                    return nullptr;
                return trans_create_node_prefix_op(c, PrefixOpNegation, prefix_op_expr);
            }
        case CTokIdTilde:
            {
                *tok_i += 1;
                AstNode *prefix_op_expr = parse_ctok_prefix_op_expr(c, ctok, tok_i);
                if (prefix_op_expr == nullptr)
                    return nullptr;
                return trans_create_node_prefix_op(c, PrefixOpBinNot, prefix_op_expr);
            }
        case CTokIdAsterisk:
            {
                *tok_i += 1;
                AstNode *prefix_op_expr = parse_ctok_prefix_op_expr(c, ctok, tok_i);
                if (prefix_op_expr == nullptr)
                    return nullptr;
                return trans_create_node_ptr_deref(c, prefix_op_expr);
            }
        default:
            return parse_ctok_suffix_op_expr(c, ctok, tok_i);
    }
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

    AstNode *result_node = parse_ctok_suffix_op_expr(c, ctok, &tok_i);
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
    }
    c->macro_table.put(name, result_node);
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
                    if (name_exists_global(c, name)) {
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
    c->warnings_on = codegen->verbose_cimport;
    c->import = import;
    c->errors = errors;
    if (buf_ends_with_str(buf_create_from_str(target_file), ".h")) {
        c->visib_mod = VisibModPub;
        c->want_export = false;
    } else {
        c->visib_mod = VisibModPub;
        c->want_export = true;
    }
    c->decl_table.init(8);
    c->macro_table.init(8);
    c->global_table.init(8);
    c->ptr_params.init(8);
    c->codegen = codegen;
    c->source_node = source_node;
    c->global_scope = trans_scope_root_create(c);

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
    clang_argv.append(buf_ptr(codegen->zig_c_headers_dir));

    clang_argv.append("-isystem");
    clang_argv.append(buf_ptr(codegen->libc_include_dir));

    // windows c runtime requires -D_DEBUG if using debug libraries
    if (codegen->build_mode == BuildModeDebug) {
        clang_argv.append("-D_DEBUG");
    }

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
    const char *resources_path = buf_ptr(codegen->zig_c_headers_dir);
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
            Buf *msg = string_ref_to_buf(msg_str_ref);
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
                    path = string_ref_to_buf(filename);
                }

                ErrorMsg *err_msg = err_msg_create_with_offset(path, line, column, offset, source, msg);

                c->errors->append(err_msg);
            } else {
                // NOTE the only known way this gets triggered right now is if you have a lot of errors
                // clang emits "too many errors emitted, stopping now"
                fprintf(stderr, "unexpected error from clang: %s\n", buf_ptr(msg));
            }
        }

        return ErrorCCompileErrors;
    }

    c->ctx = &ast_unit->getASTContext();
    c->source_manager = &ast_unit->getSourceManager();
    c->root = trans_create_node(c, NodeTypeRoot);

    ast_unit->visitLocalTopLevelDecls(c, decl_visitor);

    process_preprocessor_entities(c, *ast_unit);

    render_macros(c);
    render_aliases(c);

    import->root = c->root;

    return 0;
}
