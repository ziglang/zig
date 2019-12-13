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
#include "zig_clang.h"

#include <string.h>

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
    AstNode *root;
    bool want_export;
    HashMap<const void *, AstNode *, ptr_hash, ptr_eq> decl_table;
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> macro_table;
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> global_table;
    ZigClangSourceManager *source_manager;
    ZigList<Alias> aliases;
    bool warnings_on;

    CodeGen *codegen;
    ZigClangASTContext *ctx;

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

static AstNode *resolve_record_decl(Context *c, const ZigClangRecordDecl *record_decl);
static AstNode *resolve_enum_decl(Context *c, const ZigClangEnumDecl *enum_decl);
static AstNode *resolve_typedef_decl(Context *c, const ZigClangTypedefNameDecl *typedef_decl);

static int trans_stmt_extra(Context *c, TransScope *scope, const ZigClangStmt *stmt,
        ResultUsed result_used, TransLRValue lrval,
        AstNode **out_node, TransScope **out_child_scope,
        TransScope **out_node_scope);
static TransScope *trans_stmt(Context *c, TransScope *scope, const ZigClangStmt *stmt, AstNode **out_node);
static AstNode *trans_expr(Context *c, ResultUsed result_used, TransScope *scope, const ZigClangExpr *expr, TransLRValue lrval);
static AstNode *trans_type(Context *c, const ZigClangType *ty, ZigClangSourceLocation source_loc);
static AstNode *trans_qual_type(Context *c, ZigClangQualType qt, ZigClangSourceLocation source_loc);
static AstNode *trans_bool_expr(Context *c, ResultUsed result_used, TransScope *scope,
        const ZigClangExpr *expr, TransLRValue lrval);
static AstNode *trans_ap_value(Context *c, const ZigClangAPValue *ap_value, ZigClangQualType qt,
        ZigClangSourceLocation source_loc);
static bool c_is_unsigned_integer(Context *c, ZigClangQualType qt);


ATTRIBUTE_PRINTF(3, 4)
static void emit_warning(Context *c, ZigClangSourceLocation sl, const char *format, ...) {
    if (!c->warnings_on) {
        return;
    }

    va_list ap;
    va_start(ap, format);
    Buf *msg = buf_vprintf(format, ap);
    va_end(ap);

    const char *filename_bytes = ZigClangSourceManager_getFilename(c->source_manager,
            ZigClangSourceManager_getSpellingLoc(c->source_manager, sl));
    Buf *path;
    if (filename_bytes) {
        path = buf_create_from_str(filename_bytes);
    } else {
        path = buf_sprintf("(no file)");
    }
    unsigned line = ZigClangSourceManager_getSpellingLineNumber(c->source_manager, sl);
    unsigned column = ZigClangSourceManager_getSpellingColumnNumber(c->source_manager, sl);
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
    node->data.fn_call_expr.modifier = CallModifierBuiltin;
    return node;
}

static AstNode *trans_create_node_builtin_fn_call_str(Context *c, const char *name) {
    return trans_create_node_builtin_fn_call(c, buf_create_from_str(name));
}

static AstNode *trans_create_node_opaque(Context *c) {
    return trans_create_node_builtin_fn_call_str(c, "OpaqueType");
}

static AstNode *trans_create_node_cast(Context *c, AstNode *dest_type, AstNode *operand) {
    AstNode *node = trans_create_node(c, NodeTypeFnCallExpr);
    node->data.fn_call_expr.fn_ref_expr = trans_create_node_symbol(c, buf_create_from_str("as"));
    node->data.fn_call_expr.modifier = CallModifierBuiltin;
    node->data.fn_call_expr.params.append(dest_type);
    node->data.fn_call_expr.params.append(operand);
    return node;
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

static TokenId ptr_len_to_token_id(PtrLen ptr_len) {
    switch (ptr_len) {
        case PtrLenSingle:
            return TokenIdStar;
        case PtrLenUnknown:
            return TokenIdLBracket;
        case PtrLenC:
            return TokenIdSymbol;
    }
    zig_unreachable();
}

static AstNode *trans_create_node_ptr_type(Context *c, bool is_const, bool is_volatile, AstNode *child_node, PtrLen ptr_len) {
    AstNode *node = trans_create_node(c, NodeTypePointerType);
    node->data.pointer_type.star_token = allocate<ZigToken>(1);
    node->data.pointer_type.star_token->id = ptr_len_to_token_id(ptr_len);
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

static AstNode *trans_create_node_str_lit(Context *c, Buf *buf) {
    AstNode *node = trans_create_node(c, NodeTypeStringLiteral);
    node->data.string_literal.buf = buf;
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
    return trans_create_node_var_decl(c, VisibModPub, is_const, var_name, type_node, init_node);
}

static AstNode *trans_create_node_var_decl_local(Context *c, bool is_const, Buf *var_name, AstNode *type_node,
        AstNode *init_node)
{
    return trans_create_node_var_decl(c, VisibModPrivate, is_const, var_name, type_node, init_node);
}

static AstNode *trans_create_node_inline_fn(Context *c, Buf *fn_name, AstNode *ref_node, AstNode *src_proto_node) {
    AstNode *fn_def = trans_create_node(c, NodeTypeFnDef);
    AstNode *fn_proto = trans_create_node(c, NodeTypeFnProto);
    fn_proto->data.fn_proto.visib_mod = VisibModPub;
    fn_proto->data.fn_proto.name = fn_name;
    fn_proto->data.fn_proto.fn_inline = FnInlineAlways;
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

static AstNode *trans_create_node_grouped_expr(Context *c, AstNode *child) {
	AstNode *node = trans_create_node(c, NodeTypeGroupedExpr);
	node->data.grouped_expr = child;
	return node;
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
    ZigType *type;
    if (get_primitive_type(c->codegen, name, &type) != ErrorPrimitiveTypeNotFound) {
        return trans_create_node_symbol(c, name);
    }
    return nullptr;
}

static void add_top_level_decl(Context *c, Buf *name, AstNode *node) {
    c->global_table.put(name, node);
    c->root->data.container_decl.decls.append(node);
}

static AstNode *add_global_var(Context *c, Buf *var_name, AstNode *value_node) {
    bool is_const = true;
    AstNode *type_node = nullptr;
    AstNode *node = trans_create_node_var_decl_global(c, is_const, var_name, type_node, value_node);
    add_top_level_decl(c, var_name, node);
    return node;
}

static AstNode *trans_create_node_apint(Context *c, const ZigClangAPSInt *aps_int) {
    AstNode *node = trans_create_node(c, NodeTypeIntLiteral);
    node->data.int_literal.bigint = allocate<BigInt>(1);
    bool is_negative = ZigClangAPSInt_isSigned(aps_int) && ZigClangAPSInt_isNegative(aps_int);
    if (!is_negative) {
        bigint_init_data(node->data.int_literal.bigint,
                ZigClangAPSInt_getRawData(aps_int),
                ZigClangAPSInt_getNumWords(aps_int),
                false);
        return node;
    }
    const ZigClangAPSInt *negated = ZigClangAPSInt_negate(aps_int);
    bigint_init_data(node->data.int_literal.bigint, ZigClangAPSInt_getRawData(negated),
            ZigClangAPSInt_getNumWords(negated), true);
    ZigClangAPSInt_free(negated);
    return node;
}

static AstNode *trans_create_node_apfloat(Context *c, const ZigClangAPFloat *ap_float) {
    uint8_t buf[128];
    size_t written = ZigClangAPFloat_convertToHexString(ap_float, (char *)buf, 0, false,
            ZigClangAPFloat_roundingMode_NearestTiesToEven);
    AstNode *node = trans_create_node(c, NodeTypeFloatLiteral);
    node->data.float_literal.bigfloat = allocate<BigFloat>(1);
    if (bigfloat_init_buf(node->data.float_literal.bigfloat, buf, written)) {
        node->data.float_literal.overflow = true;
    }
    return node;
}

static const ZigClangType *qual_type_canon(ZigClangQualType qt) {
    ZigClangQualType canon = ZigClangQualType_getCanonicalType(qt);
    return ZigClangQualType_getTypePtr(canon);
}

static ZigClangQualType get_expr_qual_type(Context *c, const ZigClangExpr *expr) {
    // String literals in C are `char *` but they should really be `const char *`.
    if (ZigClangExpr_getStmtClass(expr) == ZigClangStmt_ImplicitCastExprClass) {
        const ZigClangImplicitCastExpr *cast_expr = reinterpret_cast<const ZigClangImplicitCastExpr *>(expr);
        if (ZigClangImplicitCastExpr_getCastKind(cast_expr) == ZigClangCK_ArrayToPointerDecay) {
            const ZigClangExpr *sub_expr = ZigClangImplicitCastExpr_getSubExpr(cast_expr);
            if (ZigClangExpr_getStmtClass(sub_expr) == ZigClangStmt_StringLiteralClass) {
                ZigClangQualType array_qt = ZigClangExpr_getType(sub_expr);
                const ZigClangArrayType *array_type = reinterpret_cast<const ZigClangArrayType *>(
                        ZigClangQualType_getTypePtr(array_qt));
                ZigClangQualType pointee_qt = ZigClangArrayType_getElementType(array_type);
                ZigClangQualType_addConst(&pointee_qt);
                return ZigClangASTContext_getPointerType(c->ctx, pointee_qt);
            }
        }
    }
    return ZigClangExpr_getType(expr);
}

static ZigClangQualType get_expr_qual_type_before_implicit_cast(Context *c, const ZigClangExpr *expr) {
    if (ZigClangExpr_getStmtClass(expr) == ZigClangStmt_ImplicitCastExprClass) {
        const ZigClangImplicitCastExpr *cast_expr = reinterpret_cast<const ZigClangImplicitCastExpr *>(expr);
        return get_expr_qual_type(c, ZigClangImplicitCastExpr_getSubExpr(cast_expr));
    }
    return ZigClangExpr_getType(expr);
}

static AstNode *get_expr_type(Context *c, const ZigClangExpr *expr) {
    return trans_qual_type(c, get_expr_qual_type(c, expr), ZigClangExpr_getBeginLoc(expr));
}

static bool is_c_void_type(AstNode *node) {
    return (node->type == NodeTypeSymbol && buf_eql_str(node->data.symbol_expr.symbol, "c_void"));
}

static bool qual_type_is_ptr(ZigClangQualType qt) {
    const ZigClangType *ty = qual_type_canon(qt);
    return ZigClangType_getTypeClass(ty) == ZigClangType_Pointer;
}

static const ZigClangFunctionProtoType *qual_type_get_fn_proto(ZigClangQualType qt, bool *is_ptr) {
    const ZigClangType *ty = qual_type_canon(qt);
    *is_ptr = false;

    if (ZigClangType_getTypeClass(ty) == ZigClangType_Pointer) {
        *is_ptr = true;
        ZigClangQualType child_qt = ZigClangType_getPointeeType(ty);
        ty = ZigClangQualType_getTypePtr(child_qt);
    }

    if (ZigClangType_getTypeClass(ty) == ZigClangType_FunctionProto) {
        return reinterpret_cast<const ZigClangFunctionProtoType*>(ty);
    }

    return nullptr;
}

static bool qual_type_is_fn_ptr(ZigClangQualType qt) {
    bool is_ptr;
    if (qual_type_get_fn_proto(qt, &is_ptr)) {
        return is_ptr;
    }

    return false;
}

static uint32_t qual_type_int_bit_width(Context *c, const ZigClangQualType qt, ZigClangSourceLocation source_loc) {
    const ZigClangType *ty = ZigClangQualType_getTypePtr(qt);
    switch (ZigClangType_getTypeClass(ty)) {
        case ZigClangType_Builtin:
            {
                const ZigClangBuiltinType *builtin_ty = reinterpret_cast<const ZigClangBuiltinType*>(ty);
                switch (ZigClangBuiltinType_getKind(builtin_ty)) {
                    case ZigClangBuiltinTypeChar_U:
                    case ZigClangBuiltinTypeUChar:
                    case ZigClangBuiltinTypeChar_S:
                    case ZigClangBuiltinTypeSChar:
                        return 8;
                    case ZigClangBuiltinTypeUInt128:
                    case ZigClangBuiltinTypeInt128:
                        return 128;
                    default:
                        return 0;
                }
                zig_unreachable();
            }
        case ZigClangType_Typedef:
            {
                const ZigClangTypedefType *typedef_ty = reinterpret_cast<const ZigClangTypedefType*>(ty);
                const ZigClangTypedefNameDecl *typedef_decl = ZigClangTypedefType_getDecl(typedef_ty);
                const char *type_name = ZigClangDecl_getName_bytes_begin((const ZigClangDecl *)typedef_decl);
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


static AstNode *qual_type_to_log2_int_ref(Context *c, const ZigClangQualType qt,
        ZigClangSourceLocation source_loc)
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
//                    ZigClangStringLiteral "std"
//                Symbol "math"
//            Symbol "Log2Int"
//        zig_type_node

    AstNode *import_fn_call = trans_create_node_builtin_fn_call_str(c, "import");
    import_fn_call->data.fn_call_expr.params.append(trans_create_node_str_lit(c, buf_create_from_str("std")));
    AstNode *inner_field_access = trans_create_node_field_access_str(c, import_fn_call, "math");
    AstNode *outer_field_access = trans_create_node_field_access_str(c, inner_field_access, "Log2Int");
    AstNode *log2int_fn_call = trans_create_node_fn_call_1(c, outer_field_access, zig_type_node);

    return log2int_fn_call;
}

static bool qual_type_child_is_fn_proto(ZigClangQualType qt) {
    const ZigClangType *ty = ZigClangQualType_getTypePtr(qt);
    if (ZigClangType_getTypeClass(ty) == ZigClangType_Paren) {
        const ZigClangParenType *paren_type = reinterpret_cast<const ZigClangParenType *>(ty);
        ZigClangQualType inner_type = ZigClangParenType_getInnerType(paren_type);
        if (ZigClangQualType_getTypeClass(inner_type) == ZigClangType_FunctionProto) {
            return true;
        }
    } else if (ZigClangType_getTypeClass(ty) == ZigClangType_Attributed) {
        const ZigClangAttributedType *attr_type = reinterpret_cast<const ZigClangAttributedType *>(ty);
        return qual_type_child_is_fn_proto(ZigClangAttributedType_getEquivalentType(attr_type));
    }
    return false;
}

static AstNode* trans_c_ptr_cast(Context *c, ZigClangSourceLocation source_location, ZigClangQualType dest_type,
                                 ZigClangQualType src_type, AstNode *expr)
{
    const ZigClangType *ty = ZigClangQualType_getTypePtr(dest_type);
    const ZigClangQualType child_type = ZigClangType_getPointeeType(ty);

    AstNode *dest_type_node = trans_type(c, ty, source_location);
    AstNode *child_type_node = trans_qual_type(c, child_type, source_location);

    // Implicit downcasting from higher to lower alignment values is forbidden,
    // use @alignCast to side-step this problem
    AstNode *ptrcast_node = trans_create_node_builtin_fn_call_str(c, "ptrCast");
    ptrcast_node->data.fn_call_expr.params.append(dest_type_node);

    if (ZigClangType_isVoidType(qual_type_canon(child_type))) {
        // void has 1-byte alignment
        ptrcast_node->data.fn_call_expr.params.append(expr);
    } else {
        AstNode *alignof_node = trans_create_node_builtin_fn_call_str(c, "alignOf");
        alignof_node->data.fn_call_expr.params.append(child_type_node);
        AstNode *aligncast_node = trans_create_node_builtin_fn_call_str(c, "alignCast");
        aligncast_node->data.fn_call_expr.params.append(alignof_node);
        aligncast_node->data.fn_call_expr.params.append(expr);

        ptrcast_node->data.fn_call_expr.params.append(aligncast_node);
    }

    return ptrcast_node;
}

static AstNode* trans_c_cast(Context *c, ZigClangSourceLocation source_location, ZigClangQualType dest_type,
        ZigClangQualType src_type, AstNode *expr)
{
    // The only way void pointer casts are valid C code, is if
    // the value of the expression is ignored. We therefore just
    // return the expr, and let the system that ignores values
    // translate this correctly.
    if (ZigClangType_isVoidType(qual_type_canon(dest_type))) {
        return expr;
    }
    if (ZigClangQualType_eq(dest_type, src_type)) {
        return expr;
    }
    if (qual_type_is_ptr(dest_type) && qual_type_is_ptr(src_type)) {
        return trans_c_ptr_cast(c, source_location, dest_type, src_type, expr);
    }
    if (c_is_unsigned_integer(c, dest_type) && qual_type_is_ptr(src_type)) {
        AstNode *addr_node = trans_create_node_builtin_fn_call_str(c, "ptrToInt");
        addr_node->data.fn_call_expr.params.append(expr);
        return trans_create_node_cast(c, trans_qual_type(c, dest_type, source_location), addr_node);
    }
    if (c_is_unsigned_integer(c, src_type) && qual_type_is_ptr(dest_type)) {
        AstNode *ptr_node = trans_create_node_builtin_fn_call_str(c, "intToPtr");
        ptr_node->data.fn_call_expr.params.append(trans_qual_type(c, dest_type, source_location));
        ptr_node->data.fn_call_expr.params.append(expr);
        return ptr_node;
    }
    // TODO: maybe widen to increase size
    // TODO: maybe bitcast to change sign
    // TODO: maybe truncate to reduce size
    return trans_create_node_cast(c, trans_qual_type(c, dest_type, source_location), expr);
}

static bool c_is_signed_integer(Context *c, ZigClangQualType qt) {
    const ZigClangType *c_type = qual_type_canon(qt);
    if (ZigClangType_getTypeClass(c_type) != ZigClangType_Builtin)
        return false;
    const ZigClangBuiltinType *builtin_ty = reinterpret_cast<const ZigClangBuiltinType*>(c_type);
    switch (ZigClangBuiltinType_getKind(builtin_ty)) {
        case ZigClangBuiltinTypeSChar:
        case ZigClangBuiltinTypeShort:
        case ZigClangBuiltinTypeInt:
        case ZigClangBuiltinTypeLong:
        case ZigClangBuiltinTypeLongLong:
        case ZigClangBuiltinTypeInt128:
        case ZigClangBuiltinTypeWChar_S:
            return true;
        default:
            return false;
    }
}

static bool c_is_unsigned_integer(Context *c, ZigClangQualType qt) {
    const ZigClangType *c_type = qual_type_canon(qt);
    if (ZigClangType_getTypeClass(c_type) != ZigClangType_Builtin)
        return false;
    const ZigClangBuiltinType *builtin_ty = reinterpret_cast<const ZigClangBuiltinType*>(c_type);
    switch (ZigClangBuiltinType_getKind(builtin_ty)) {
        case ZigClangBuiltinTypeChar_U:
        case ZigClangBuiltinTypeUChar:
        case ZigClangBuiltinTypeChar_S:
        case ZigClangBuiltinTypeUShort:
        case ZigClangBuiltinTypeUInt:
        case ZigClangBuiltinTypeULong:
        case ZigClangBuiltinTypeULongLong:
        case ZigClangBuiltinTypeUInt128:
        case ZigClangBuiltinTypeWChar_U:
            return true;
        default:
            return false;
    }
}

static bool c_is_builtin_type(Context *c, ZigClangQualType qt, ZigClangBuiltinTypeKind kind) {
    const ZigClangType *c_type = qual_type_canon(qt);
    if (ZigClangType_getTypeClass(c_type) != ZigClangType_Builtin)
        return false;
    const ZigClangBuiltinType *builtin_ty = reinterpret_cast<const ZigClangBuiltinType*>(c_type);
    return ZigClangBuiltinType_getKind(builtin_ty) == kind;
}

static bool c_is_float(Context *c, ZigClangQualType qt) {
    const ZigClangType *c_type = ZigClangQualType_getTypePtr(qt);
    if (ZigClangType_getTypeClass(c_type) != ZigClangType_Builtin)
        return false;
    const ZigClangBuiltinType *builtin_ty = reinterpret_cast<const ZigClangBuiltinType*>(c_type);
    switch (ZigClangBuiltinType_getKind(builtin_ty)) {
        case ZigClangBuiltinTypeHalf:
        case ZigClangBuiltinTypeFloat:
        case ZigClangBuiltinTypeDouble:
        case ZigClangBuiltinTypeFloat128:
        case ZigClangBuiltinTypeLongDouble:
            return true;
        default:
            return false;
    }
}

static bool qual_type_has_wrapping_overflow(Context *c, ZigClangQualType qt) {
    if (c_is_signed_integer(c, qt) || c_is_float(c, qt)) {
        // float and signed integer overflow is undefined behavior.
        return false;
    } else {
        // unsigned integer overflow wraps around.
        return true;
    }
}

static bool type_is_function(Context *c, const ZigClangType *ty, ZigClangSourceLocation source_loc) {
    switch (ZigClangType_getTypeClass(ty)) {
        case ZigClangType_FunctionProto:
        case ZigClangType_FunctionNoProto:
            return true;
        case ZigClangType_Elaborated: {
            const ZigClangElaboratedType *elaborated_ty = reinterpret_cast<const ZigClangElaboratedType*>(ty);
            ZigClangQualType qt = ZigClangElaboratedType_getNamedType(elaborated_ty);
            return type_is_function(c, ZigClangQualType_getTypePtr(qt), source_loc);
        }
        case ZigClangType_Typedef: {
            const ZigClangTypedefType *typedef_ty = reinterpret_cast<const ZigClangTypedefType*>(ty);
            const ZigClangTypedefNameDecl *typedef_decl = ZigClangTypedefType_getDecl(typedef_ty);
            ZigClangQualType underlying_type = ZigClangTypedefNameDecl_getUnderlyingType(typedef_decl);
            return type_is_function(c, ZigClangQualType_getTypePtr(underlying_type), source_loc);
        }
        default:
            return false;
    }
}

static bool type_is_opaque(Context *c, const ZigClangType *ty, ZigClangSourceLocation source_loc) {
    switch (ZigClangType_getTypeClass(ty)) {
        case ZigClangType_Builtin: {
            const ZigClangBuiltinType *builtin_ty = reinterpret_cast<const ZigClangBuiltinType*>(ty);
            return ZigClangBuiltinType_getKind(builtin_ty) == ZigClangBuiltinTypeVoid;
        }
        case ZigClangType_Record: {
            const ZigClangRecordType *record_ty = reinterpret_cast<const ZigClangRecordType*>(ty);
            const ZigClangRecordDecl *record_decl = ZigClangRecordType_getDecl(record_ty);
            const ZigClangRecordDecl *record_def = ZigClangRecordDecl_getDefinition(record_decl);
            if (record_def == nullptr) {
                return true;
            }
            for (ZigClangRecordDecl_field_iterator it = ZigClangRecordDecl_field_begin(record_def),
                    it_end = ZigClangRecordDecl_field_end(record_def);
                    ZigClangRecordDecl_field_iterator_neq(it, it_end);
                    it = ZigClangRecordDecl_field_iterator_next(it))
            {
                const ZigClangFieldDecl *field_decl = ZigClangRecordDecl_field_iterator_deref(it);

                if (ZigClangFieldDecl_isBitField(field_decl)) {
                    return true;
                }
            }
            return false;
        }
        case ZigClangType_Elaborated: {
            const ZigClangElaboratedType *elaborated_ty = reinterpret_cast<const ZigClangElaboratedType*>(ty);
            ZigClangQualType qt = ZigClangElaboratedType_getNamedType(elaborated_ty);
            return type_is_opaque(c, ZigClangQualType_getTypePtr(qt), source_loc);
        }
        case ZigClangType_Typedef: {
            const ZigClangTypedefType *typedef_ty = reinterpret_cast<const ZigClangTypedefType*>(ty);
            const ZigClangTypedefNameDecl *typedef_decl = ZigClangTypedefType_getDecl(typedef_ty);
            ZigClangQualType underlying_type = ZigClangTypedefNameDecl_getUnderlyingType(typedef_decl);
            return type_is_opaque(c, ZigClangQualType_getTypePtr(underlying_type), source_loc);
        }
        default:
            return false;
    }
}

static AstNode *trans_type(Context *c, const ZigClangType *ty, ZigClangSourceLocation source_loc) {
    switch (ZigClangType_getTypeClass(ty)) {
        case ZigClangType_Builtin:
            {
                const ZigClangBuiltinType *builtin_ty = reinterpret_cast<const ZigClangBuiltinType *>(ty);
                switch (ZigClangBuiltinType_getKind(builtin_ty)) {
                    case ZigClangBuiltinTypeVoid:
                        return trans_create_node_symbol_str(c, "c_void");
                    case ZigClangBuiltinTypeBool:
                        return trans_create_node_symbol_str(c, "bool");
                    case ZigClangBuiltinTypeChar_U:
                    case ZigClangBuiltinTypeUChar:
                    case ZigClangBuiltinTypeChar_S:
                    case ZigClangBuiltinTypeChar8:
                        return trans_create_node_symbol_str(c, "u8");
                    case ZigClangBuiltinTypeSChar:
                        return trans_create_node_symbol_str(c, "i8");
                    case ZigClangBuiltinTypeUShort:
                        return trans_create_node_symbol_str(c, "c_ushort");
                    case ZigClangBuiltinTypeUInt:
                        return trans_create_node_symbol_str(c, "c_uint");
                    case ZigClangBuiltinTypeULong:
                        return trans_create_node_symbol_str(c, "c_ulong");
                    case ZigClangBuiltinTypeULongLong:
                        return trans_create_node_symbol_str(c, "c_ulonglong");
                    case ZigClangBuiltinTypeShort:
                        return trans_create_node_symbol_str(c, "c_short");
                    case ZigClangBuiltinTypeInt:
                        return trans_create_node_symbol_str(c, "c_int");
                    case ZigClangBuiltinTypeLong:
                        return trans_create_node_symbol_str(c, "c_long");
                    case ZigClangBuiltinTypeLongLong:
                        return trans_create_node_symbol_str(c, "c_longlong");
                    case ZigClangBuiltinTypeUInt128:
                        return trans_create_node_symbol_str(c, "u128");
                    case ZigClangBuiltinTypeInt128:
                        return trans_create_node_symbol_str(c, "i128");
                    case ZigClangBuiltinTypeFloat:
                        return trans_create_node_symbol_str(c, "f32");
                    case ZigClangBuiltinTypeDouble:
                        return trans_create_node_symbol_str(c, "f64");
                    case ZigClangBuiltinTypeFloat128:
                        return trans_create_node_symbol_str(c, "f128");
                    case ZigClangBuiltinTypeFloat16:
                        return trans_create_node_symbol_str(c, "f16");
                    case ZigClangBuiltinTypeLongDouble:
                        return trans_create_node_symbol_str(c, "c_longdouble");
                    case ZigClangBuiltinTypeWChar_U:
                    case ZigClangBuiltinTypeChar16:
                    case ZigClangBuiltinTypeChar32:
                    case ZigClangBuiltinTypeWChar_S:
                    case ZigClangBuiltinTypeHalf:
                    case ZigClangBuiltinTypeNullPtr:
                    case ZigClangBuiltinTypeObjCId:
                    case ZigClangBuiltinTypeObjCClass:
                    case ZigClangBuiltinTypeObjCSel:
                    case ZigClangBuiltinTypeOMPArraySection:
                    case ZigClangBuiltinTypeDependent:
                    case ZigClangBuiltinTypeOverload:
                    case ZigClangBuiltinTypeBoundMember:
                    case ZigClangBuiltinTypePseudoObject:
                    case ZigClangBuiltinTypeUnknownAny:
                    case ZigClangBuiltinTypeBuiltinFn:
                    case ZigClangBuiltinTypeARCUnbridgedCast:
                    case ZigClangBuiltinTypeShortAccum:
                    case ZigClangBuiltinTypeAccum:
                    case ZigClangBuiltinTypeLongAccum:
                    case ZigClangBuiltinTypeUShortAccum:
                    case ZigClangBuiltinTypeUAccum:
                    case ZigClangBuiltinTypeULongAccum:

                    case ZigClangBuiltinTypeOCLImage1dRO:
                    case ZigClangBuiltinTypeOCLImage1dArrayRO:
                    case ZigClangBuiltinTypeOCLImage1dBufferRO:
                    case ZigClangBuiltinTypeOCLImage2dRO:
                    case ZigClangBuiltinTypeOCLImage2dArrayRO:
                    case ZigClangBuiltinTypeOCLImage2dDepthRO:
                    case ZigClangBuiltinTypeOCLImage2dArrayDepthRO:
                    case ZigClangBuiltinTypeOCLImage2dMSAARO:
                    case ZigClangBuiltinTypeOCLImage2dArrayMSAARO:
                    case ZigClangBuiltinTypeOCLImage2dMSAADepthRO:
                    case ZigClangBuiltinTypeOCLImage2dArrayMSAADepthRO:
                    case ZigClangBuiltinTypeOCLImage3dRO:
                    case ZigClangBuiltinTypeOCLImage1dWO:
                    case ZigClangBuiltinTypeOCLImage1dArrayWO:
                    case ZigClangBuiltinTypeOCLImage1dBufferWO:
                    case ZigClangBuiltinTypeOCLImage2dWO:
                    case ZigClangBuiltinTypeOCLImage2dArrayWO:
                    case ZigClangBuiltinTypeOCLImage2dDepthWO:
                    case ZigClangBuiltinTypeOCLImage2dArrayDepthWO:
                    case ZigClangBuiltinTypeOCLImage2dMSAAWO:
                    case ZigClangBuiltinTypeOCLImage2dArrayMSAAWO:
                    case ZigClangBuiltinTypeOCLImage2dMSAADepthWO:
                    case ZigClangBuiltinTypeOCLImage2dArrayMSAADepthWO:
                    case ZigClangBuiltinTypeOCLImage3dWO:
                    case ZigClangBuiltinTypeOCLImage1dRW:
                    case ZigClangBuiltinTypeOCLImage1dArrayRW:
                    case ZigClangBuiltinTypeOCLImage1dBufferRW:
                    case ZigClangBuiltinTypeOCLImage2dRW:
                    case ZigClangBuiltinTypeOCLImage2dArrayRW:
                    case ZigClangBuiltinTypeOCLImage2dDepthRW:
                    case ZigClangBuiltinTypeOCLImage2dArrayDepthRW:
                    case ZigClangBuiltinTypeOCLImage2dMSAARW:
                    case ZigClangBuiltinTypeOCLImage2dArrayMSAARW:
                    case ZigClangBuiltinTypeOCLImage2dMSAADepthRW:
                    case ZigClangBuiltinTypeOCLImage2dArrayMSAADepthRW:
                    case ZigClangBuiltinTypeOCLImage3dRW:
                    case ZigClangBuiltinTypeOCLSampler:
                    case ZigClangBuiltinTypeOCLEvent:
                    case ZigClangBuiltinTypeOCLClkEvent:
                    case ZigClangBuiltinTypeOCLQueue:
                    case ZigClangBuiltinTypeOCLReserveID:
                    case ZigClangBuiltinTypeShortFract:
                    case ZigClangBuiltinTypeFract:
                    case ZigClangBuiltinTypeLongFract:
                    case ZigClangBuiltinTypeUShortFract:
                    case ZigClangBuiltinTypeUFract:
                    case ZigClangBuiltinTypeULongFract:
                    case ZigClangBuiltinTypeSatShortAccum:
                    case ZigClangBuiltinTypeSatAccum:
                    case ZigClangBuiltinTypeSatLongAccum:
                    case ZigClangBuiltinTypeSatUShortAccum:
                    case ZigClangBuiltinTypeSatUAccum:
                    case ZigClangBuiltinTypeSatULongAccum:
                    case ZigClangBuiltinTypeSatShortFract:
                    case ZigClangBuiltinTypeSatFract:
                    case ZigClangBuiltinTypeSatLongFract:
                    case ZigClangBuiltinTypeSatUShortFract:
                    case ZigClangBuiltinTypeSatUFract:
                    case ZigClangBuiltinTypeSatULongFract:
                    case ZigClangBuiltinTypeOCLIntelSubgroupAVCMcePayload:
                    case ZigClangBuiltinTypeOCLIntelSubgroupAVCImePayload:
                    case ZigClangBuiltinTypeOCLIntelSubgroupAVCRefPayload:
                    case ZigClangBuiltinTypeOCLIntelSubgroupAVCSicPayload:
                    case ZigClangBuiltinTypeOCLIntelSubgroupAVCMceResult:
                    case ZigClangBuiltinTypeOCLIntelSubgroupAVCImeResult:
                    case ZigClangBuiltinTypeOCLIntelSubgroupAVCRefResult:
                    case ZigClangBuiltinTypeOCLIntelSubgroupAVCSicResult:
                    case ZigClangBuiltinTypeOCLIntelSubgroupAVCImeResultSingleRefStreamout:
                    case ZigClangBuiltinTypeOCLIntelSubgroupAVCImeResultDualRefStreamout:
                    case ZigClangBuiltinTypeOCLIntelSubgroupAVCImeSingleRefStreamin:
                    case ZigClangBuiltinTypeOCLIntelSubgroupAVCImeDualRefStreamin:
                        emit_warning(c, source_loc, "unsupported builtin type");
                        return nullptr;
                }
                break;
            }
        case ZigClangType_Pointer:
            {
                ZigClangQualType child_qt = ZigClangType_getPointeeType(ty);
                AstNode *child_node = trans_qual_type(c, child_qt, source_loc);
                if (child_node == nullptr) {
                    emit_warning(c, source_loc, "pointer to unsupported type");
                    return nullptr;
                }

                if (qual_type_child_is_fn_proto(child_qt)) {
                    return trans_create_node_prefix_op(c, PrefixOpOptional, child_node);
                }

                if (type_is_function(c, ZigClangQualType_getTypePtr(child_qt), source_loc)) {
                    return trans_create_node_prefix_op(c, PrefixOpOptional, child_node);
                } else if (type_is_opaque(c, ZigClangQualType_getTypePtr(child_qt), source_loc)) {
                    AstNode *pointer_node = trans_create_node_ptr_type(c,
                            ZigClangQualType_isConstQualified(child_qt),
                            ZigClangQualType_isVolatileQualified(child_qt),
                            child_node, PtrLenSingle);
                    return trans_create_node_prefix_op(c, PrefixOpOptional, pointer_node);
                } else {
                    return trans_create_node_ptr_type(c,
                            ZigClangQualType_isConstQualified(child_qt),
                            ZigClangQualType_isVolatileQualified(child_qt),
                            child_node, PtrLenC);
                }
            }
        case ZigClangType_Typedef:
            {
                const ZigClangTypedefType *typedef_ty = reinterpret_cast<const ZigClangTypedefType*>(ty);
                const ZigClangTypedefNameDecl *typedef_decl = ZigClangTypedefType_getDecl(typedef_ty);
                return resolve_typedef_decl(c, typedef_decl);
            }
        case ZigClangType_Elaborated:
            {
                const ZigClangElaboratedType *elaborated_ty = reinterpret_cast<const ZigClangElaboratedType*>(ty);
                switch (ZigClangElaboratedType_getKeyword(elaborated_ty)) {
                    case ZigClangETK_Struct:
                    case ZigClangETK_Enum:
                    case ZigClangETK_Union:
                        return trans_qual_type(c, ZigClangElaboratedType_getNamedType(elaborated_ty), source_loc);
                    case ZigClangETK_Interface:
                    case ZigClangETK_Class:
                    case ZigClangETK_Typename:
                    case ZigClangETK_None:
                        emit_warning(c, source_loc, "unsupported elaborated type");
                        return nullptr;
                }
            }
        case ZigClangType_FunctionProto:
        case ZigClangType_FunctionNoProto:
            {
                const ZigClangFunctionType *fn_ty = reinterpret_cast<const ZigClangFunctionType*>(ty);

                AstNode *proto_node = trans_create_node(c, NodeTypeFnProto);
                switch (ZigClangFunctionType_getCallConv(fn_ty)) {
                    case ZigClangCallingConv_C:           // __attribute__((cdecl))
                        proto_node->data.fn_proto.cc = CallingConventionC;
                        proto_node->data.fn_proto.is_extern = true;
                        break;
                    case ZigClangCallingConv_X86StdCall:  // __attribute__((stdcall))
                        proto_node->data.fn_proto.cc = CallingConventionStdcall;
                        break;
                    case ZigClangCallingConv_X86FastCall: // __attribute__((fastcall))
                        emit_warning(c, source_loc, "unsupported calling convention: x86 fastcall");
                        return nullptr;
                    case ZigClangCallingConv_X86ThisCall: // __attribute__((thiscall))
                        emit_warning(c, source_loc, "unsupported calling convention: x86 thiscall");
                        return nullptr;
                    case ZigClangCallingConv_X86VectorCall: // __attribute__((vectorcall))
                        emit_warning(c, source_loc, "unsupported calling convention: x86 vectorcall");
                        return nullptr;
                    case ZigClangCallingConv_X86Pascal:   // __attribute__((pascal))
                        emit_warning(c, source_loc, "unsupported calling convention: x86 pascal");
                        return nullptr;
                    case ZigClangCallingConv_Win64: // __attribute__((ms_abi))
                        emit_warning(c, source_loc, "unsupported calling convention: win64");
                        return nullptr;
                    case ZigClangCallingConv_X86_64SysV:  // __attribute__((sysv_abi))
                        emit_warning(c, source_loc, "unsupported calling convention: x86 64sysv");
                        return nullptr;
                    case ZigClangCallingConv_X86RegCall:
                        emit_warning(c, source_loc, "unsupported calling convention: x86 reg");
                        return nullptr;
                    case ZigClangCallingConv_AAPCS:       // __attribute__((pcs("aapcs")))
                        emit_warning(c, source_loc, "unsupported calling convention: aapcs");
                        return nullptr;
                    case ZigClangCallingConv_AAPCS_VFP:   // __attribute__((pcs("aapcs-vfp")))
                        emit_warning(c, source_loc, "unsupported calling convention: aapcs-vfp");
                        return nullptr;
                    case ZigClangCallingConv_IntelOclBicc: // __attribute__((intel_ocl_bicc))
                        emit_warning(c, source_loc, "unsupported calling convention: intel_ocl_bicc");
                        return nullptr;
                    case ZigClangCallingConv_SpirFunction: // default for OpenCL functions on SPIR target
                        emit_warning(c, source_loc, "unsupported calling convention: SPIR function");
                        return nullptr;
                    case ZigClangCallingConv_OpenCLKernel:
                        emit_warning(c, source_loc, "unsupported calling convention: OpenCLKernel");
                        return nullptr;
                    case ZigClangCallingConv_Swift:
                        emit_warning(c, source_loc, "unsupported calling convention: Swift");
                        return nullptr;
                    case ZigClangCallingConv_PreserveMost:
                        emit_warning(c, source_loc, "unsupported calling convention: PreserveMost");
                        return nullptr;
                    case ZigClangCallingConv_PreserveAll:
                        emit_warning(c, source_loc, "unsupported calling convention: PreserveAll");
                        return nullptr;
                    case ZigClangCallingConv_AArch64VectorCall:
                        emit_warning(c, source_loc, "unsupported calling convention: AArch64VectorCall");
                        return nullptr;
                }

                if (ZigClangFunctionType_getNoReturnAttr(fn_ty)) {
                    proto_node->data.fn_proto.return_type = trans_create_node_symbol_str(c, "noreturn");
                } else {
                    proto_node->data.fn_proto.return_type = trans_qual_type(c,
                            ZigClangFunctionType_getReturnType(fn_ty), source_loc);
                    if (proto_node->data.fn_proto.return_type == nullptr) {
                        emit_warning(c, source_loc, "unsupported function proto return type");
                        return nullptr;
                    }
                    // convert c_void to actual void (only for return type)
                    // we do want to look at the AstNode instead of ZigClangQualType, because
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

                if (ZigClangType_getTypeClass(ty) == ZigClangType_FunctionNoProto) {
                    return proto_node;
                }

                const ZigClangFunctionProtoType *fn_proto_ty = reinterpret_cast<const ZigClangFunctionProtoType*>(ty);

                proto_node->data.fn_proto.is_var_args = ZigClangFunctionProtoType_isVariadic(fn_proto_ty);
                size_t param_count = ZigClangFunctionProtoType_getNumParams(fn_proto_ty);

                for (size_t i = 0; i < param_count; i += 1) {
                    ZigClangQualType qt = ZigClangFunctionProtoType_getParamType(fn_proto_ty, i);
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
                    param_node->data.param_decl.is_noalias = ZigClangQualType_isRestrictQualified(qt);
                    param_node->data.param_decl.type = param_type_node;
                    proto_node->data.fn_proto.params.append(param_node);
                }
                // TODO check for always_inline attribute
                // TODO check for align attribute

                return proto_node;
            }
        case ZigClangType_Record:
            {
                const ZigClangRecordType *record_ty = reinterpret_cast<const ZigClangRecordType*>(ty);
                return resolve_record_decl(c, ZigClangRecordType_getDecl(record_ty));
            }
        case ZigClangType_Enum:
            {
                const ZigClangEnumType *enum_ty = reinterpret_cast<const ZigClangEnumType*>(ty);
                return resolve_enum_decl(c, ZigClangEnumType_getDecl(enum_ty));
            }
        case ZigClangType_ConstantArray:
            {
                const ZigClangConstantArrayType *const_arr_ty = reinterpret_cast<const ZigClangConstantArrayType *>(ty);
                AstNode *child_type_node = trans_qual_type(c,
                        ZigClangConstantArrayType_getElementType(const_arr_ty), source_loc);
                if (child_type_node == nullptr) {
                    emit_warning(c, source_loc, "unresolved array element type");
                    return nullptr;
                }
                const ZigClangAPInt *size_ap_int = ZigClangConstantArrayType_getSize(const_arr_ty);
                uint64_t size = ZigClangAPInt_getLimitedValue(size_ap_int, UINT64_MAX);
                AstNode *size_node = trans_create_node_unsigned(c, size);
                return trans_create_node_array_type(c, size_node, child_type_node);
            }
        case ZigClangType_Paren:
            {
                const ZigClangParenType *paren_ty = reinterpret_cast<const ZigClangParenType *>(ty);
                return trans_qual_type(c, ZigClangParenType_getInnerType(paren_ty), source_loc);
            }
        case ZigClangType_Decayed:
            {
                const ZigClangDecayedType *decayed_ty = reinterpret_cast<const ZigClangDecayedType *>(ty);
                return trans_qual_type(c, ZigClangDecayedType_getDecayedType(decayed_ty), source_loc);
            }
        case ZigClangType_Attributed:
            {
                const ZigClangAttributedType *attributed_ty = reinterpret_cast<const ZigClangAttributedType *>(ty);
                return trans_qual_type(c, ZigClangAttributedType_getEquivalentType(attributed_ty), source_loc);
            }
        case ZigClangType_MacroQualified:
            {
                const ZigClangMacroQualifiedType *macroqualified_ty = reinterpret_cast<const ZigClangMacroQualifiedType *>(ty);
                return trans_qual_type(c, ZigClangMacroQualifiedType_getModifiedType(macroqualified_ty), source_loc);
            }
        case ZigClangType_IncompleteArray:
            {
                const ZigClangIncompleteArrayType *incomplete_array_ty = reinterpret_cast<const ZigClangIncompleteArrayType *>(ty);
                ZigClangQualType child_qt = ZigClangIncompleteArrayType_getElementType(incomplete_array_ty);
                AstNode *child_type_node = trans_qual_type(c, child_qt, source_loc);
                if (child_type_node == nullptr) {
                    emit_warning(c, source_loc, "unresolved array element type");
                    return nullptr;
                }
                AstNode *pointer_node = trans_create_node_ptr_type(c,
                        ZigClangQualType_isConstQualified(child_qt),
                        ZigClangQualType_isVolatileQualified(child_qt),
                        child_type_node, PtrLenC);
                return pointer_node;
            }
        case ZigClangType_BlockPointer:
        case ZigClangType_LValueReference:
        case ZigClangType_RValueReference:
        case ZigClangType_MemberPointer:
        case ZigClangType_VariableArray:
        case ZigClangType_DependentSizedArray:
        case ZigClangType_DependentSizedExtVector:
        case ZigClangType_Vector:
        case ZigClangType_ExtVector:
        case ZigClangType_UnresolvedUsing:
        case ZigClangType_Adjusted:
        case ZigClangType_TypeOfExpr:
        case ZigClangType_TypeOf:
        case ZigClangType_Decltype:
        case ZigClangType_UnaryTransform:
        case ZigClangType_TemplateTypeParm:
        case ZigClangType_SubstTemplateTypeParm:
        case ZigClangType_SubstTemplateTypeParmPack:
        case ZigClangType_TemplateSpecialization:
        case ZigClangType_Auto:
        case ZigClangType_InjectedClassName:
        case ZigClangType_DependentName:
        case ZigClangType_DependentTemplateSpecialization:
        case ZigClangType_PackExpansion:
        case ZigClangType_ObjCObject:
        case ZigClangType_ObjCInterface:
        case ZigClangType_Complex:
        case ZigClangType_ObjCObjectPointer:
        case ZigClangType_Atomic:
        case ZigClangType_Pipe:
        case ZigClangType_ObjCTypeParam:
        case ZigClangType_DeducedTemplateSpecialization:
        case ZigClangType_DependentAddressSpace:
        case ZigClangType_DependentVector:
            emit_warning(c, source_loc, "unsupported type: '%s'", ZigClangType_getTypeClassName(ty));
            return nullptr;
    }
    zig_unreachable();
}

static AstNode *trans_qual_type(Context *c, ZigClangQualType qt, ZigClangSourceLocation source_loc) {
    return trans_type(c, ZigClangQualType_getTypePtr(qt), source_loc);
}

static int trans_compound_stmt_inline(Context *c, TransScope *scope, const ZigClangCompoundStmt *stmt,
        AstNode *block_node, TransScope **out_node_scope)
{
    assert(block_node->type == NodeTypeBlock);
    for (ZigClangCompoundStmt_const_body_iterator it = ZigClangCompoundStmt_body_begin(stmt),
        end_it = ZigClangCompoundStmt_body_end(stmt); it != end_it; ++it)
    {
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

static AstNode *trans_compound_stmt(Context *c, TransScope *scope, const ZigClangCompoundStmt *stmt,
        TransScope **out_node_scope)
{
    TransScopeBlock *child_scope_block = trans_scope_block_create(c, scope);
    if (trans_compound_stmt_inline(c, &child_scope_block->base, stmt, child_scope_block->node, out_node_scope))
        return nullptr;
    return child_scope_block->node;
}

static AstNode *trans_stmt_expr(Context *c, ResultUsed result_used, TransScope *scope,
        const ZigClangStmtExpr *stmt, TransScope **out_node_scope)
{
    AstNode *block = trans_compound_stmt(c, scope, ZigClangStmtExpr_getSubStmt(stmt), out_node_scope);
    if (block == nullptr)
        return block;
    assert(block->type == NodeTypeBlock);
    if (block->data.block.statements.length == 0)
        return block;

    Buf *label = buf_create_from_str("x");
    block->data.block.name = label;
    AstNode *return_expr = block->data.block.statements.pop();
    if (return_expr->type == NodeTypeBinOpExpr &&
        return_expr->data.bin_op_expr.bin_op == BinOpTypeAssign &&
        return_expr->data.bin_op_expr.op1->type == NodeTypeSymbol)
       {
        Buf *symbol_buf = return_expr->data.bin_op_expr.op1->data.symbol_expr.symbol;
           if (strcmp("_", buf_ptr(symbol_buf)) == 0)
               return_expr = return_expr->data.bin_op_expr.op2;
       }
    block->data.block.statements.append(trans_create_node_break(c, label, return_expr));
    return maybe_suppress_result(c, result_used, block);
}

static AstNode *trans_return_stmt(Context *c, TransScope *scope, const ZigClangReturnStmt *stmt) {
    const ZigClangExpr *value_expr = ZigClangReturnStmt_getRetValue(stmt);
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

static AstNode *trans_integer_literal(Context *c, ResultUsed result_used, const ZigClangIntegerLiteral *stmt) {
    ZigClangExprEvalResult result;
    if (!ZigClangIntegerLiteral_EvaluateAsInt(stmt, &result, c->ctx)) {
        emit_warning(c, ZigClangExpr_getBeginLoc((ZigClangExpr*)stmt), "invalid integer literal");
        return nullptr;
    }
    AstNode *node = trans_create_node_apint(c, ZigClangAPValue_getInt(&result.Val));
    return maybe_suppress_result(c, result_used, node);
}

static AstNode *trans_floating_literal(Context *c, ResultUsed result_used, const ZigClangFloatingLiteral *stmt) {
    ZigClangAPFloat *result;
    if (!ZigClangExpr_EvaluateAsFloat((const ZigClangExpr *)stmt, &result, c->ctx)) {
        emit_warning(c, ZigClangExpr_getBeginLoc((ZigClangExpr*)stmt), "invalid floating literal");
        return nullptr;
    }
    AstNode *node = trans_create_node_apfloat(c, result);
    return maybe_suppress_result(c, result_used, node);
}

static AstNode *trans_character_literal(Context *c, ResultUsed result_used, const ZigClangCharacterLiteral *stmt) {
    switch (ZigClangCharacterLiteral_getKind(stmt)) {
        case ZigClangCharacterLiteral_CharacterKind_Ascii:
            {
                unsigned val = ZigClangCharacterLiteral_getValue(stmt);
                // C has a somewhat obscure feature called multi-character character
                // constant
                if (val > 255)
                    return trans_create_node_unsigned(c, val);
            }
            // fallthrough
        case ZigClangCharacterLiteral_CharacterKind_UTF8:
            {
                AstNode *node = trans_create_node(c, NodeTypeCharLiteral);
                node->data.char_literal.value = ZigClangCharacterLiteral_getValue(stmt);
                return maybe_suppress_result(c, result_used, node);
            }
        case ZigClangCharacterLiteral_CharacterKind_UTF16:
            emit_warning(c, ZigClangCharacterLiteral_getBeginLoc(stmt), "TODO support UTF16 character literals");
            return nullptr;
        case ZigClangCharacterLiteral_CharacterKind_UTF32:
            emit_warning(c, ZigClangCharacterLiteral_getBeginLoc(stmt), "TODO support UTF32 character literals");
            return nullptr;
        case ZigClangCharacterLiteral_CharacterKind_Wide:
            emit_warning(c, ZigClangCharacterLiteral_getBeginLoc(stmt), "TODO support wide character literals");
            return nullptr;
    }
    zig_unreachable();
}

static AstNode *trans_constant_expr(Context *c, ResultUsed result_used, const ZigClangConstantExpr *expr) {
    const ZigClangExpr *as_expr = reinterpret_cast<const ZigClangExpr *>(expr);
    ZigClangExprEvalResult result;
    if (!ZigClangExpr_EvaluateAsConstantExpr((const ZigClangExpr *)expr, &result,
                ZigClangExpr_EvaluateForCodeGen, c->ctx))
    {
        emit_warning(c, ZigClangExpr_getBeginLoc(as_expr), "invalid constant expression");
        return nullptr;
    }
    AstNode *node = trans_ap_value(c, &result.Val, ZigClangExpr_getType(as_expr),
            ZigClangExpr_getBeginLoc(as_expr));
    return maybe_suppress_result(c, result_used, node);
}

static AstNode *trans_conditional_operator(Context *c, ResultUsed result_used, TransScope *scope,
        const ZigClangConditionalOperator *stmt)
{
    AstNode *node = trans_create_node(c, NodeTypeIfBoolExpr);

    const ZigClangExpr *cond_expr = ZigClangConditionalOperator_getCond(stmt);
    const ZigClangExpr *true_expr = ZigClangConditionalOperator_getTrueExpr(stmt);
    const ZigClangExpr *false_expr = ZigClangConditionalOperator_getFalseExpr(stmt);

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

static AstNode *trans_create_bin_op(Context *c, TransScope *scope, const ZigClangExpr *lhs,
        BinOpType bin_op, const ZigClangExpr *rhs)
{
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

static AstNode *trans_create_bool_bin_op(Context *c, TransScope *scope, const ZigClangExpr *lhs,
        BinOpType bin_op, const ZigClangExpr *rhs)
{
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

static AstNode *trans_create_assign(Context *c, ResultUsed result_used, TransScope *scope,
        const ZigClangExpr *lhs, const ZigClangExpr *rhs)
{
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
        // zig: (x: {
        // zig:     const _tmp = rhs;
        // zig:     lhs = _tmp;
        // zig:     break :x _tmp
        // zig: })

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

        return trans_create_node_grouped_expr(c, child_scope->node);
    }
}

static AstNode *trans_create_shift_op(Context *c, TransScope *scope, ZigClangQualType result_type,
        const ZigClangExpr *lhs_expr, BinOpType bin_op, const ZigClangExpr *rhs_expr)
{
    ZigClangSourceLocation rhs_location = ZigClangExpr_getBeginLoc(rhs_expr);
    AstNode *rhs_type = qual_type_to_log2_int_ref(c, result_type, rhs_location);
    // lhs >> u5(rh)

    AstNode *lhs = trans_expr(c, ResultUsedYes, scope, lhs_expr, TransLValue);
    if (lhs == nullptr) return nullptr;

    AstNode *rhs = trans_expr(c, ResultUsedYes, scope, rhs_expr, TransRValue);
    if (rhs == nullptr) return nullptr;
    AstNode *coerced_rhs = trans_create_node_cast(c, rhs_type, rhs);

    return trans_create_node_bin_op(c, lhs, bin_op, coerced_rhs);
}

static AstNode *trans_binary_operator(Context *c, ResultUsed result_used, TransScope *scope,
        const ZigClangBinaryOperator *stmt)
{
    switch (ZigClangBinaryOperator_getOpcode(stmt)) {
        case ZigClangBO_PtrMemD:
            emit_warning(c, ZigClangBinaryOperator_getBeginLoc(stmt), "TODO handle more C binary operators: BO_PtrMemD");
            return nullptr;
        case ZigClangBO_PtrMemI:
            emit_warning(c, ZigClangBinaryOperator_getBeginLoc(stmt), "TODO handle more C binary operators: BO_PtrMemI");
            return nullptr;
        case ZigClangBO_Cmp:
            emit_warning(c, ZigClangBinaryOperator_getBeginLoc(stmt), "TODO handle more C binary operators: BO_Cmp");
            return nullptr;
        case ZigClangBO_Mul: {
            AstNode *node = trans_create_bin_op(c, scope, ZigClangBinaryOperator_getLHS(stmt),
                qual_type_has_wrapping_overflow(c, ZigClangBinaryOperator_getType(stmt)) ? BinOpTypeMultWrap : BinOpTypeMult,
                ZigClangBinaryOperator_getRHS(stmt));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangBO_Div:
            if (qual_type_has_wrapping_overflow(c, ZigClangBinaryOperator_getType(stmt))) {
                // unsigned/float division uses the operator
                AstNode *node = trans_create_bin_op(c, scope, ZigClangBinaryOperator_getLHS(stmt), BinOpTypeDiv, ZigClangBinaryOperator_getRHS(stmt));
                return maybe_suppress_result(c, result_used, node);
            } else {
                // signed integer division uses @divTrunc
                AstNode *fn_call = trans_create_node_builtin_fn_call_str(c, "divTrunc");
                AstNode *lhs = trans_expr(c, ResultUsedYes, scope, ZigClangBinaryOperator_getLHS(stmt), TransLValue);
                if (lhs == nullptr) return nullptr;
                fn_call->data.fn_call_expr.params.append(lhs);
                AstNode *rhs = trans_expr(c, ResultUsedYes, scope, ZigClangBinaryOperator_getRHS(stmt), TransLValue);
                if (rhs == nullptr) return nullptr;
                fn_call->data.fn_call_expr.params.append(rhs);
                return maybe_suppress_result(c, result_used, fn_call);
            }
        case ZigClangBO_Rem:
            if (qual_type_has_wrapping_overflow(c, ZigClangBinaryOperator_getType(stmt))) {
                // unsigned/float division uses the operator
                AstNode *node = trans_create_bin_op(c, scope, ZigClangBinaryOperator_getLHS(stmt), BinOpTypeMod, ZigClangBinaryOperator_getRHS(stmt));
                return maybe_suppress_result(c, result_used, node);
            } else {
                // signed integer division uses @rem
                AstNode *fn_call = trans_create_node_builtin_fn_call_str(c, "rem");
                AstNode *lhs = trans_expr(c, ResultUsedYes, scope, ZigClangBinaryOperator_getLHS(stmt), TransLValue);
                if (lhs == nullptr) return nullptr;
                fn_call->data.fn_call_expr.params.append(lhs);
                AstNode *rhs = trans_expr(c, ResultUsedYes, scope, ZigClangBinaryOperator_getRHS(stmt), TransLValue);
                if (rhs == nullptr) return nullptr;
                fn_call->data.fn_call_expr.params.append(rhs);
                return maybe_suppress_result(c, result_used, fn_call);
            }
        case ZigClangBO_Add: {
            AstNode *node = trans_create_bin_op(c, scope, ZigClangBinaryOperator_getLHS(stmt),
                qual_type_has_wrapping_overflow(c, ZigClangBinaryOperator_getType(stmt)) ? BinOpTypeAddWrap : BinOpTypeAdd,
                ZigClangBinaryOperator_getRHS(stmt));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangBO_Sub: {
            AstNode *node = trans_create_bin_op(c, scope, ZigClangBinaryOperator_getLHS(stmt),
                qual_type_has_wrapping_overflow(c, ZigClangBinaryOperator_getType(stmt)) ? BinOpTypeSubWrap : BinOpTypeSub,
                ZigClangBinaryOperator_getRHS(stmt));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangBO_Shl: {
            AstNode *node = trans_create_shift_op(c, scope, ZigClangBinaryOperator_getType(stmt), ZigClangBinaryOperator_getLHS(stmt), BinOpTypeBitShiftLeft, ZigClangBinaryOperator_getRHS(stmt));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangBO_Shr: {
            AstNode *node = trans_create_shift_op(c, scope, ZigClangBinaryOperator_getType(stmt), ZigClangBinaryOperator_getLHS(stmt), BinOpTypeBitShiftRight, ZigClangBinaryOperator_getRHS(stmt));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangBO_LT: {
            AstNode *node =trans_create_bin_op(c, scope, ZigClangBinaryOperator_getLHS(stmt), BinOpTypeCmpLessThan, ZigClangBinaryOperator_getRHS(stmt));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangBO_GT: {
            AstNode *node = trans_create_bin_op(c, scope, ZigClangBinaryOperator_getLHS(stmt), BinOpTypeCmpGreaterThan, ZigClangBinaryOperator_getRHS(stmt));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangBO_LE: {
            AstNode *node = trans_create_bin_op(c, scope, ZigClangBinaryOperator_getLHS(stmt), BinOpTypeCmpLessOrEq, ZigClangBinaryOperator_getRHS(stmt));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangBO_GE: {
            AstNode *node = trans_create_bin_op(c, scope, ZigClangBinaryOperator_getLHS(stmt), BinOpTypeCmpGreaterOrEq, ZigClangBinaryOperator_getRHS(stmt));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangBO_EQ: {
            AstNode *node = trans_create_bin_op(c, scope, ZigClangBinaryOperator_getLHS(stmt), BinOpTypeCmpEq, ZigClangBinaryOperator_getRHS(stmt));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangBO_NE: {
            AstNode *node = trans_create_bin_op(c, scope, ZigClangBinaryOperator_getLHS(stmt), BinOpTypeCmpNotEq, ZigClangBinaryOperator_getRHS(stmt));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangBO_And: {
            AstNode *node = trans_create_bin_op(c, scope, ZigClangBinaryOperator_getLHS(stmt), BinOpTypeBinAnd, ZigClangBinaryOperator_getRHS(stmt));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangBO_Xor: {
            AstNode *node = trans_create_bin_op(c, scope, ZigClangBinaryOperator_getLHS(stmt), BinOpTypeBinXor, ZigClangBinaryOperator_getRHS(stmt));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangBO_Or: {
            AstNode *node = trans_create_bin_op(c, scope, ZigClangBinaryOperator_getLHS(stmt), BinOpTypeBinOr, ZigClangBinaryOperator_getRHS(stmt));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangBO_LAnd: {
            AstNode *node = trans_create_bool_bin_op(c, scope, ZigClangBinaryOperator_getLHS(stmt), BinOpTypeBoolAnd, ZigClangBinaryOperator_getRHS(stmt));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangBO_LOr: {
            AstNode *node = trans_create_bool_bin_op(c, scope, ZigClangBinaryOperator_getLHS(stmt), BinOpTypeBoolOr, ZigClangBinaryOperator_getRHS(stmt));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangBO_Assign:
            return trans_create_assign(c, result_used, scope, ZigClangBinaryOperator_getLHS(stmt), ZigClangBinaryOperator_getRHS(stmt));
        case ZigClangBO_Comma:
            {
                TransScopeBlock *scope_block = trans_scope_block_create(c, scope);
                Buf *label_name = buf_create_from_str("x");
                scope_block->node->data.block.name = label_name;

                AstNode *lhs = trans_expr(c, ResultUsedNo, &scope_block->base, ZigClangBinaryOperator_getLHS(stmt), TransRValue);
                if (lhs == nullptr)
                    return nullptr;
                scope_block->node->data.block.statements.append(lhs);

                AstNode *rhs = trans_expr(c, ResultUsedYes, &scope_block->base, ZigClangBinaryOperator_getRHS(stmt), TransRValue);
                if (rhs == nullptr)
                    return nullptr;

                rhs = trans_create_node_break(c, label_name, rhs);
                scope_block->node->data.block.statements.append(rhs);
                return maybe_suppress_result(c, result_used, scope_block->node);
            }
        case ZigClangBO_MulAssign:
        case ZigClangBO_DivAssign:
        case ZigClangBO_RemAssign:
        case ZigClangBO_AddAssign:
        case ZigClangBO_SubAssign:
        case ZigClangBO_ShlAssign:
        case ZigClangBO_ShrAssign:
        case ZigClangBO_AndAssign:
        case ZigClangBO_XorAssign:
        case ZigClangBO_OrAssign:
            zig_unreachable();
    }

    zig_unreachable();
}

static AstNode *trans_create_compound_assign_shift(Context *c, ResultUsed result_used, TransScope *scope,
        const ZigClangCompoundAssignOperator *stmt, BinOpType assign_op, BinOpType bin_op)
{
    ZigClangSourceLocation rhs_location = ZigClangExpr_getBeginLoc(ZigClangCompoundAssignOperator_getRHS(stmt));
    ZigClangQualType computation_lhs_type = ZigClangCompoundAssignOperator_getComputationLHSType(stmt);
    AstNode *rhs_type = qual_type_to_log2_int_ref(c, computation_lhs_type, rhs_location);
    ZigClangQualType computation_result_type = ZigClangCompoundAssignOperator_getComputationResultType(stmt);

    bool use_intermediate_casts = ZigClangQualType_getTypePtr(computation_lhs_type) !=
        ZigClangQualType_getTypePtr(computation_result_type);
    if (!use_intermediate_casts && result_used == ResultUsedNo) {
        // simple common case, where the C and Zig are identical:
        // lhs >>= rhs
        AstNode *lhs = trans_expr(c, ResultUsedYes, scope, ZigClangCompoundAssignOperator_getLHS(stmt), TransLValue);
        if (lhs == nullptr) return nullptr;

        AstNode *rhs = trans_expr(c, ResultUsedYes, scope, ZigClangCompoundAssignOperator_getRHS(stmt), TransRValue);
        if (rhs == nullptr) return nullptr;
        AstNode *coerced_rhs = trans_create_node_cast(c, rhs_type, rhs);

        return trans_create_node_bin_op(c, lhs, assign_op, coerced_rhs);
    } else {
        // need more complexity. worst case, this looks like this:
        // c:   lhs >>= rhs
        // zig: (x: {
        // zig:     const _ref = &lhs;
        // zig:     *_ref = result_type(operation_type(*_ref) >> u5(rhs));
        // zig:     break :x *_ref
        // zig: })
        // where u5 is the appropriate type

        TransScopeBlock *child_scope = trans_scope_block_create(c, scope);
        Buf *label_name = buf_create_from_str("x");
        child_scope->node->data.block.name = label_name;

        // const _ref = &lhs;
        AstNode *lhs = trans_expr(c, ResultUsedYes, &child_scope->base,
                ZigClangCompoundAssignOperator_getLHS(stmt), TransLValue);
        if (lhs == nullptr) return nullptr;
        AstNode *addr_of_lhs = trans_create_node_addr_of(c, lhs);
        // TODO: avoid name collisions with generated variable names
        Buf* tmp_var_name = buf_create_from_str("_ref");
        AstNode *tmp_var_decl = trans_create_node_var_decl_local(c, true, tmp_var_name, nullptr, addr_of_lhs);
        child_scope->node->data.block.statements.append(tmp_var_decl);

        // *_ref = result_type(operation_type(*_ref) >> u5(rhs));

        AstNode *rhs = trans_expr(c, ResultUsedYes, &child_scope->base, ZigClangCompoundAssignOperator_getRHS(stmt), TransRValue);
        if (rhs == nullptr) return nullptr;
        AstNode *coerced_rhs = trans_create_node_cast(c, rhs_type, rhs);

        // operation_type(*_ref)
        AstNode *operation_type_cast = trans_c_cast(c, rhs_location,
            computation_lhs_type,
            ZigClangExpr_getType(ZigClangCompoundAssignOperator_getLHS(stmt)),
            trans_create_node_ptr_deref(c, trans_create_node_symbol(c, tmp_var_name)));

        // result_type(... >> u5(rhs))
        AstNode *result_type_cast = trans_c_cast(c, rhs_location,
            computation_result_type,
            computation_lhs_type,
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

        return trans_create_node_grouped_expr(c, child_scope->node);
    }
}

static AstNode *trans_create_compound_assign(Context *c, ResultUsed result_used, TransScope *scope,
        const ZigClangCompoundAssignOperator *stmt, BinOpType assign_op, BinOpType bin_op)
{
    if (result_used == ResultUsedNo) {
        // simple common case, where the C and Zig are identical:
        // lhs += rhs
        AstNode *lhs = trans_expr(c, ResultUsedYes, scope, ZigClangCompoundAssignOperator_getLHS(stmt), TransLValue);
        if (lhs == nullptr) return nullptr;
        AstNode *rhs = trans_expr(c, ResultUsedYes, scope, ZigClangCompoundAssignOperator_getRHS(stmt), TransRValue);
        if (rhs == nullptr) return nullptr;
        return trans_create_node_bin_op(c, lhs, assign_op, rhs);
    } else {
        // need more complexity. worst case, this looks like this:
        // c:   lhs += rhs
        // zig: (x: {
        // zig:     const _ref = &lhs;
        // zig:     *_ref = *_ref + rhs;
        // zig:     break :x *_ref
        // zig: })

        TransScopeBlock *child_scope = trans_scope_block_create(c, scope);
        Buf *label_name = buf_create_from_str("x");
        child_scope->node->data.block.name = label_name;

        // const _ref = &lhs;
        AstNode *lhs = trans_expr(c, ResultUsedYes, &child_scope->base,
                ZigClangCompoundAssignOperator_getLHS(stmt), TransLValue);
        if (lhs == nullptr) return nullptr;
        AstNode *addr_of_lhs = trans_create_node_addr_of(c, lhs);
        // TODO: avoid name collisions with generated variable names
        Buf* tmp_var_name = buf_create_from_str("_ref");
        AstNode *tmp_var_decl = trans_create_node_var_decl_local(c, true, tmp_var_name, nullptr, addr_of_lhs);
        child_scope->node->data.block.statements.append(tmp_var_decl);

        // *_ref = *_ref + rhs;

        AstNode *rhs = trans_expr(c, ResultUsedYes, &child_scope->base,
                ZigClangCompoundAssignOperator_getRHS(stmt), TransRValue);
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

        return trans_create_node_grouped_expr(c, child_scope->node);
    }
}


static AstNode *trans_compound_assign_operator(Context *c, ResultUsed result_used, TransScope *scope,
        const ZigClangCompoundAssignOperator *stmt)
{
    switch (ZigClangCompoundAssignOperator_getOpcode(stmt)) {
        case ZigClangBO_MulAssign:
            if (qual_type_has_wrapping_overflow(c, ZigClangCompoundAssignOperator_getType(stmt)))
                return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignTimesWrap, BinOpTypeMultWrap);
            else
                return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignTimes, BinOpTypeMult);
        case ZigClangBO_DivAssign:
            emit_warning(c, ZigClangCompoundAssignOperator_getBeginLoc(stmt), "TODO handle more C compound assign operators: BO_DivAssign");
            return nullptr;
        case ZigClangBO_RemAssign:
            emit_warning(c, ZigClangCompoundAssignOperator_getBeginLoc(stmt), "TODO handle more C compound assign operators: BO_RemAssign");
            return nullptr;
        case ZigClangBO_Cmp:
            emit_warning(c, ZigClangCompoundAssignOperator_getBeginLoc(stmt), "TODO handle more C compound assign operators: BO_Cmp");
            return nullptr;
        case ZigClangBO_AddAssign:
            if (qual_type_has_wrapping_overflow(c, ZigClangCompoundAssignOperator_getType(stmt)))
                return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignPlusWrap, BinOpTypeAddWrap);
            else
                return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignPlus, BinOpTypeAdd);
        case ZigClangBO_SubAssign:
            if (qual_type_has_wrapping_overflow(c, ZigClangCompoundAssignOperator_getType(stmt)))
                return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignMinusWrap, BinOpTypeSubWrap);
            else
                return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignMinus, BinOpTypeSub);
        case ZigClangBO_ShlAssign:
            return trans_create_compound_assign_shift(c, result_used, scope, stmt, BinOpTypeAssignBitShiftLeft, BinOpTypeBitShiftLeft);
        case ZigClangBO_ShrAssign:
            return trans_create_compound_assign_shift(c, result_used, scope, stmt, BinOpTypeAssignBitShiftRight, BinOpTypeBitShiftRight);
        case ZigClangBO_AndAssign:
            return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignBitAnd, BinOpTypeBinAnd);
        case ZigClangBO_XorAssign:
            return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignBitXor, BinOpTypeBinXor);
        case ZigClangBO_OrAssign:
            return trans_create_compound_assign(c, result_used, scope, stmt, BinOpTypeAssignBitOr, BinOpTypeBinOr);
        case ZigClangBO_PtrMemD:
        case ZigClangBO_PtrMemI:
        case ZigClangBO_Assign:
        case ZigClangBO_Mul:
        case ZigClangBO_Div:
        case ZigClangBO_Rem:
        case ZigClangBO_Add:
        case ZigClangBO_Sub:
        case ZigClangBO_Shl:
        case ZigClangBO_Shr:
        case ZigClangBO_LT:
        case ZigClangBO_GT:
        case ZigClangBO_LE:
        case ZigClangBO_GE:
        case ZigClangBO_EQ:
        case ZigClangBO_NE:
        case ZigClangBO_And:
        case ZigClangBO_Xor:
        case ZigClangBO_Or:
        case ZigClangBO_LAnd:
        case ZigClangBO_LOr:
        case ZigClangBO_Comma:
            zig_unreachable();
    }

    zig_unreachable();
}

static AstNode *trans_implicit_cast_expr(Context *c, ResultUsed result_used, TransScope *scope,
        const ZigClangImplicitCastExpr *stmt)
{
    switch (ZigClangImplicitCastExpr_getCastKind(stmt)) {
        case ZigClangCK_LValueToRValue:
            return trans_expr(c, ResultUsedYes, scope, ZigClangImplicitCastExpr_getSubExpr(stmt), TransRValue);
        case ZigClangCK_IntegralCast:
            {
                AstNode *target_node = trans_expr(c, ResultUsedYes, scope, ZigClangImplicitCastExpr_getSubExpr(stmt), TransRValue);
                if (target_node == nullptr)
                    return nullptr;
                AstNode *node = trans_c_cast(c, ZigClangImplicitCastExpr_getBeginLoc(stmt),
                    ZigClangExpr_getType(reinterpret_cast<const ZigClangExpr *>(stmt)),
                    ZigClangExpr_getType(ZigClangImplicitCastExpr_getSubExpr(stmt)),
                    target_node);
                return maybe_suppress_result(c, result_used, node);
            }
        case ZigClangCK_FunctionToPointerDecay:
        case ZigClangCK_ArrayToPointerDecay:
            {
                AstNode *target_node = trans_expr(c, ResultUsedYes, scope, ZigClangImplicitCastExpr_getSubExpr(stmt), TransRValue);
                if (target_node == nullptr)
                    return nullptr;
                return maybe_suppress_result(c, result_used, target_node);
            }
        case ZigClangCK_BitCast:
            {
                AstNode *target_node = trans_expr(c, ResultUsedYes, scope, ZigClangImplicitCastExpr_getSubExpr(stmt), TransRValue);
                if (target_node == nullptr)
                    return nullptr;

                const ZigClangQualType dest_type = get_expr_qual_type(c, reinterpret_cast<const ZigClangExpr *>(stmt));
                const ZigClangQualType src_type = get_expr_qual_type(c, ZigClangImplicitCastExpr_getSubExpr(stmt));

                return trans_c_cast(c, ZigClangImplicitCastExpr_getBeginLoc(stmt),
                        dest_type, src_type, target_node);
            }
        case ZigClangCK_NullToPointer:
            return trans_create_node(c, NodeTypeNullLiteral);
        case ZigClangCK_NoOp:
            return trans_expr(c, ResultUsedYes, scope, ZigClangImplicitCastExpr_getSubExpr(stmt), TransRValue);
        case ZigClangCK_Dependent:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C translation cast CK_Dependent");
            return nullptr;
        case ZigClangCK_LValueBitCast:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C translation cast CK_LValueBitCast");
            return nullptr;
        case ZigClangCK_BaseToDerived:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C translation cast CK_BaseToDerived");
            return nullptr;
        case ZigClangCK_DerivedToBase:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C translation cast CK_DerivedToBase");
            return nullptr;
        case ZigClangCK_UncheckedDerivedToBase:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C translation cast CK_UncheckedDerivedToBase");
            return nullptr;
        case ZigClangCK_Dynamic:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C translation cast CK_Dynamic");
            return nullptr;
        case ZigClangCK_ToUnion:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C translation cast CK_ToUnion");
            return nullptr;
        case ZigClangCK_NullToMemberPointer:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C translation cast CK_NullToMemberPointer");
            return nullptr;
        case ZigClangCK_BaseToDerivedMemberPointer:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C translation cast CK_BaseToDerivedMemberPointer");
            return nullptr;
        case ZigClangCK_DerivedToBaseMemberPointer:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C translation cast CK_DerivedToBaseMemberPointer");
            return nullptr;
        case ZigClangCK_MemberPointerToBoolean:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C translation cast CK_MemberPointerToBoolean");
            return nullptr;
        case ZigClangCK_ReinterpretMemberPointer:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C translation cast CK_ReinterpretMemberPointer");
            return nullptr;
        case ZigClangCK_UserDefinedConversion:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C translation cast CK_UserDefinedConversion");
            return nullptr;
        case ZigClangCK_ConstructorConversion:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_ConstructorConversion");
            return nullptr;
        case ZigClangCK_PointerToBoolean:
            {
                const ZigClangExpr *expr = ZigClangImplicitCastExpr_getSubExpr(stmt);
                AstNode *val = trans_expr(c, ResultUsedYes, scope, expr, TransRValue);
                if (val == nullptr)
                    return nullptr;

                AstNode *val_ptr = trans_create_node_builtin_fn_call_str(c, "ptrToInt");
                val_ptr->data.fn_call_expr.params.append(val);

                AstNode *zero = trans_create_node_unsigned(c, 0);

                // Translate as @ptrToInt((&val) != 0)
                return trans_create_node_bin_op(c, val_ptr, BinOpTypeCmpNotEq, zero);
            }
        case ZigClangCK_ToVoid:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_ToVoid");
            return nullptr;
        case ZigClangCK_VectorSplat:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_VectorSplat");
            return nullptr;
        case ZigClangCK_IntegralToBoolean:
            {
                const ZigClangExpr *expr = ZigClangImplicitCastExpr_getSubExpr(stmt);

                bool expr_val;
                if (ZigClangExpr_EvaluateAsBooleanCondition(expr, &expr_val, c->ctx, false)) {
                    return trans_create_node_bool(c, expr_val);
                }

                AstNode *val = trans_expr(c, ResultUsedYes, scope, expr, TransRValue);
                if (val == nullptr)
                    return nullptr;

                AstNode *zero = trans_create_node_unsigned(c, 0);

                // Translate as val != 0
                return trans_create_node_bin_op(c, val, BinOpTypeCmpNotEq, zero);
            }
        case ZigClangCK_PointerToIntegral:
            {
                AstNode *target_node = trans_expr(c, ResultUsedYes, scope, ZigClangImplicitCastExpr_getSubExpr(stmt), TransRValue);
                if (target_node == nullptr)
                    return nullptr;

                AstNode *dest_type_node = get_expr_type(c, (const ZigClangExpr *)stmt);
                if (dest_type_node == nullptr)
                    return nullptr;

                AstNode *val_node = trans_create_node_builtin_fn_call_str(c, "ptrToInt");
                val_node->data.fn_call_expr.params.append(target_node);
                // @ptrToInt always returns a usize
                AstNode *node = trans_create_node_builtin_fn_call_str(c, "intCast");
                node->data.fn_call_expr.params.append(dest_type_node);
                node->data.fn_call_expr.params.append(val_node);

                return maybe_suppress_result(c, result_used, node);
            }
        case ZigClangCK_IntegralToPointer:
            {
                AstNode *target_node = trans_expr(c, ResultUsedYes, scope, ZigClangImplicitCastExpr_getSubExpr(stmt), TransRValue);
                if (target_node == nullptr)
                    return nullptr;

                AstNode *dest_type_node = get_expr_type(c, (const ZigClangExpr *)stmt);
                if (dest_type_node == nullptr)
                    return nullptr;

                AstNode *node = trans_create_node_builtin_fn_call_str(c, "intToPtr");
                node->data.fn_call_expr.params.append(dest_type_node);
                node->data.fn_call_expr.params.append(target_node);

                return maybe_suppress_result(c, result_used, node);
            }
        case ZigClangCK_IntegralToFloating:
        case ZigClangCK_FloatingToIntegral:
            {
                AstNode *target_node = trans_expr(c, ResultUsedYes, scope, ZigClangImplicitCastExpr_getSubExpr(stmt), TransRValue);
                if (target_node == nullptr)
                    return nullptr;

                AstNode *dest_type_node = get_expr_type(c, (const ZigClangExpr *)stmt);
                if (dest_type_node == nullptr)
                    return nullptr;

                char const *fn = (ZigClangImplicitCastExpr_getCastKind(stmt) == ZigClangCK_IntegralToFloating) ?
                    "intToFloat" : "floatToInt";
                AstNode *node = trans_create_node_builtin_fn_call_str(c, fn);
                node->data.fn_call_expr.params.append(dest_type_node);
                node->data.fn_call_expr.params.append(target_node);

                return maybe_suppress_result(c, result_used, node);
            }
        case ZigClangCK_FixedPointCast:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_FixedPointCast");
            return nullptr;
        case ZigClangCK_FixedPointToBoolean:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_FixedPointToBoolean");
            return nullptr;
        case ZigClangCK_FloatingToBoolean:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_FloatingToBoolean");
            return nullptr;
        case ZigClangCK_BooleanToSignedIntegral:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_BooleanToSignedIntegral");
            return nullptr;
        case ZigClangCK_FloatingCast:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_FloatingCast");
            return nullptr;
        case ZigClangCK_CPointerToObjCPointerCast:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_CPointerToObjCPointerCast");
            return nullptr;
        case ZigClangCK_BlockPointerToObjCPointerCast:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_BlockPointerToObjCPointerCast");
            return nullptr;
        case ZigClangCK_AnyPointerToBlockPointerCast:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_AnyPointerToBlockPointerCast");
            return nullptr;
        case ZigClangCK_ObjCObjectLValueCast:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_ObjCObjectLValueCast");
            return nullptr;
        case ZigClangCK_FloatingRealToComplex:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_FloatingRealToComplex");
            return nullptr;
        case ZigClangCK_FloatingComplexToReal:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_FloatingComplexToReal");
            return nullptr;
        case ZigClangCK_FloatingComplexToBoolean:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_FloatingComplexToBoolean");
            return nullptr;
        case ZigClangCK_FloatingComplexCast:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_FloatingComplexCast");
            return nullptr;
        case ZigClangCK_FloatingComplexToIntegralComplex:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_FloatingComplexToIntegralComplex");
            return nullptr;
        case ZigClangCK_IntegralRealToComplex:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_IntegralRealToComplex");
            return nullptr;
        case ZigClangCK_IntegralComplexToReal:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_IntegralComplexToReal");
            return nullptr;
        case ZigClangCK_IntegralComplexToBoolean:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_IntegralComplexToBoolean");
            return nullptr;
        case ZigClangCK_IntegralComplexCast:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_IntegralComplexCast");
            return nullptr;
        case ZigClangCK_IntegralComplexToFloatingComplex:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_IntegralComplexToFloatingComplex");
            return nullptr;
        case ZigClangCK_ARCProduceObject:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_ARCProduceObject");
            return nullptr;
        case ZigClangCK_ARCConsumeObject:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_ARCConsumeObject");
            return nullptr;
        case ZigClangCK_ARCReclaimReturnedObject:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_ARCReclaimReturnedObject");
            return nullptr;
        case ZigClangCK_ARCExtendBlockObject:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_ARCExtendBlockObject");
            return nullptr;
        case ZigClangCK_AtomicToNonAtomic:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_AtomicToNonAtomic");
            return nullptr;
        case ZigClangCK_NonAtomicToAtomic:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_NonAtomicToAtomic");
            return nullptr;
        case ZigClangCK_CopyAndAutoreleaseBlockObject:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_CopyAndAutoreleaseBlockObject");
            return nullptr;
        case ZigClangCK_BuiltinFnToFnPtr:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_BuiltinFnToFnPtr");
            return nullptr;
        case ZigClangCK_ZeroToOCLOpaqueType:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_ZeroToOCLOpaqueType");
            return nullptr;
        case ZigClangCK_AddressSpaceConversion:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_AddressSpaceConversion");
            return nullptr;
        case ZigClangCK_IntToOCLSampler:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_IntToOCLSampler");
            return nullptr;
        case ZigClangCK_LValueToRValueBitCast:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_LValueToRValueBitCast");
            return nullptr;
        case ZigClangCK_FixedPointToIntegral:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_FixedPointToIntegral");
            return nullptr;
        case ZigClangCK_IntegralToFixedPoint:
            emit_warning(c, ZigClangImplicitCastExpr_getBeginLoc(stmt), "TODO handle C CK_IntegralToFixedPointral");
            return nullptr;
    }
    zig_unreachable();
}

static AstNode *trans_decl_ref_expr(Context *c, TransScope *scope, const ZigClangDeclRefExpr *stmt, TransLRValue lrval) {
    const ZigClangValueDecl *value_decl = ZigClangDeclRefExpr_getDecl(stmt);
    Buf *c_symbol_name = buf_create_from_str(ZigClangDecl_getName_bytes_begin((const ZigClangDecl *)value_decl));
    Buf *zig_symbol_name = trans_lookup_zig_symbol(c, scope, c_symbol_name);
    if (lrval == TransLValue) {
        c->ptr_params.put(zig_symbol_name, true);
    }
    return trans_create_node_symbol(c, zig_symbol_name);
}

static AstNode *trans_create_post_crement(Context *c, ResultUsed result_used, TransScope *scope,
        const ZigClangUnaryOperator *stmt, BinOpType assign_op)
{
    const ZigClangExpr *op_expr = ZigClangUnaryOperator_getSubExpr(stmt);

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
    // zig: (x: {
    // zig:     const _ref = &expr;
    // zig:     const _tmp = *_ref;
    // zig:     *_ref += 1;
    // zig:     break :x _tmp
    // zig: })
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

    return trans_create_node_grouped_expr(c, child_scope->node);
}

static AstNode *trans_create_pre_crement(Context *c, ResultUsed result_used, TransScope *scope,
        const ZigClangUnaryOperator *stmt, BinOpType assign_op)
{
    const ZigClangExpr *op_expr = ZigClangUnaryOperator_getSubExpr(stmt);

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
    // zig: (x: {
    // zig:     const _ref = &expr;
    // zig:     *_ref += 1;
    // zig:     break :x *_ref
    // zig: })
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

    return trans_create_node_grouped_expr(c, child_scope->node);
}

static AstNode *trans_unary_operator(Context *c, ResultUsed result_used, TransScope *scope,
        const ZigClangUnaryOperator *stmt)
{
    switch (ZigClangUnaryOperator_getOpcode(stmt)) {
        case ZigClangUO_PostInc:
            if (qual_type_has_wrapping_overflow(c, ZigClangUnaryOperator_getType(stmt)))
                return trans_create_post_crement(c, result_used, scope, stmt, BinOpTypeAssignPlusWrap);
            else
                return trans_create_post_crement(c, result_used, scope, stmt, BinOpTypeAssignPlus);
        case ZigClangUO_PostDec:
            if (qual_type_has_wrapping_overflow(c, ZigClangUnaryOperator_getType(stmt)))
                return trans_create_post_crement(c, result_used, scope, stmt, BinOpTypeAssignMinusWrap);
            else
                return trans_create_post_crement(c, result_used, scope, stmt, BinOpTypeAssignMinus);
        case ZigClangUO_PreInc:
            if (qual_type_has_wrapping_overflow(c, ZigClangUnaryOperator_getType(stmt)))
                return trans_create_pre_crement(c, result_used, scope, stmt, BinOpTypeAssignPlusWrap);
            else
                return trans_create_pre_crement(c, result_used, scope, stmt, BinOpTypeAssignPlus);
        case ZigClangUO_PreDec:
            if (qual_type_has_wrapping_overflow(c, ZigClangUnaryOperator_getType(stmt)))
                return trans_create_pre_crement(c, result_used, scope, stmt, BinOpTypeAssignMinusWrap);
            else
                return trans_create_pre_crement(c, result_used, scope, stmt, BinOpTypeAssignMinus);
        case ZigClangUO_AddrOf:
            {
                AstNode *value_node = trans_expr(c, result_used, scope, ZigClangUnaryOperator_getSubExpr(stmt), TransLValue);
                if (value_node == nullptr)
                    return value_node;
                return trans_create_node_addr_of(c, value_node);
            }
        case ZigClangUO_Deref:
            {
                AstNode *value_node = trans_expr(c, result_used, scope, ZigClangUnaryOperator_getSubExpr(stmt), TransRValue);
                if (value_node == nullptr)
                    return nullptr;
                bool is_fn_ptr = qual_type_is_fn_ptr(ZigClangExpr_getType(ZigClangUnaryOperator_getSubExpr(stmt)));
                if (is_fn_ptr)
                    return value_node;
                AstNode *unwrapped = trans_create_node_unwrap_null(c, value_node);
                return trans_create_node_ptr_deref(c, unwrapped);
            }
        case ZigClangUO_Plus:
            emit_warning(c, ZigClangUnaryOperator_getBeginLoc(stmt), "TODO handle C translation UO_Plus");
            return nullptr;
        case ZigClangUO_Minus:
            {
                const ZigClangExpr *op_expr = ZigClangUnaryOperator_getSubExpr(stmt);
                if (!qual_type_has_wrapping_overflow(c, ZigClangExpr_getType(op_expr))) {
                    AstNode *node = trans_create_node(c, NodeTypePrefixOpExpr);
                    node->data.prefix_op_expr.prefix_op = PrefixOpNegation;

                    node->data.prefix_op_expr.primary_expr = trans_expr(c, ResultUsedYes, scope, op_expr, TransRValue);
                    if (node->data.prefix_op_expr.primary_expr == nullptr)
                        return nullptr;

                    return node;
                } else if (c_is_unsigned_integer(c, ZigClangExpr_getType(op_expr))) {
                    // we gotta emit 0 -% x
                    AstNode *node = trans_create_node(c, NodeTypeBinOpExpr);
                    node->data.bin_op_expr.op1 = trans_create_node_unsigned(c, 0);

                    node->data.bin_op_expr.op2 = trans_expr(c, ResultUsedYes, scope, op_expr, TransRValue);
                    if (node->data.bin_op_expr.op2 == nullptr)
                        return nullptr;

                    node->data.bin_op_expr.bin_op = BinOpTypeSubWrap;
                    return node;
                } else {
                    emit_warning(c, ZigClangUnaryOperator_getBeginLoc(stmt), "C negation with non float non integer");
                    return nullptr;
                }
            }
        case ZigClangUO_Not:
            {
                const ZigClangExpr *op_expr = ZigClangUnaryOperator_getSubExpr(stmt);
                AstNode *sub_node = trans_expr(c, ResultUsedYes, scope, op_expr, TransRValue);
                if (sub_node == nullptr)
                    return nullptr;

                return trans_create_node_prefix_op(c, PrefixOpBinNot, sub_node);
            }
        case ZigClangUO_LNot:
            {
                const ZigClangExpr *op_expr = ZigClangUnaryOperator_getSubExpr(stmt);
                AstNode *sub_node = trans_bool_expr(c, ResultUsedYes, scope, op_expr, TransRValue);
                if (sub_node == nullptr)
                    return nullptr;

                return trans_create_node_prefix_op(c, PrefixOpBoolNot, sub_node);
            }
        case ZigClangUO_Real:
            emit_warning(c, ZigClangUnaryOperator_getBeginLoc(stmt), "TODO handle C translation UO_Real");
            return nullptr;
        case ZigClangUO_Imag:
            emit_warning(c, ZigClangUnaryOperator_getBeginLoc(stmt), "TODO handle C translation UO_Imag");
            return nullptr;
        case ZigClangUO_Extension:
            return trans_expr(c, result_used, scope, ZigClangUnaryOperator_getSubExpr(stmt), TransLValue);
        case ZigClangUO_Coawait:
            emit_warning(c, ZigClangUnaryOperator_getBeginLoc(stmt), "TODO handle C translation UO_Coawait");
            return nullptr;
    }
    zig_unreachable();
}

static int trans_local_declaration(Context *c, TransScope *scope, const ZigClangDeclStmt *stmt,
        AstNode **out_node, TransScope **out_scope)
{
    // declarations are added via the scope
    *out_node = nullptr;

    TransScopeBlock *scope_block = trans_scope_block_find(scope);
    assert(scope_block != nullptr);

    for (ZigClangDeclStmt_const_decl_iterator iter = ZigClangDeclStmt_decl_begin(stmt),
            iter_end = ZigClangDeclStmt_decl_end(stmt);
        iter != iter_end; ++iter)
    {
        ZigClangDecl *decl = *iter;
        switch (ZigClangDecl_getKind(decl)) {
            case ZigClangDeclVar: {
                ZigClangVarDecl *var_decl = (ZigClangVarDecl *)decl;
                ZigClangQualType qual_type = ZigClangVarDecl_getTypeSourceInfo_getType(var_decl);
                AstNode *init_node = nullptr;
                if (ZigClangVarDecl_hasInit(var_decl)) {
                    init_node = trans_expr(c, ResultUsedYes, scope, ZigClangVarDecl_getInit(var_decl), TransRValue);
                    if (init_node == nullptr)
                        return ErrorUnexpected;

                } else {
                    init_node = trans_create_node(c, NodeTypeUndefinedLiteral);
                }
                AstNode *type_node = trans_qual_type(c, qual_type, ZigClangDeclStmt_getBeginLoc(stmt));
                if (type_node == nullptr)
                    return ErrorUnexpected;

                Buf *c_symbol_name = buf_create_from_str(ZigClangDecl_getName_bytes_begin((const ZigClangDecl *)var_decl));

                TransScopeVar *var_scope = trans_scope_var_create(c, scope, c_symbol_name);
                scope = &var_scope->base;

                AstNode *node = trans_create_node_var_decl_local(c,
                        ZigClangQualType_isConstQualified(qual_type),
                        var_scope->zig_name, type_node, init_node);

                scope_block->node->data.block.statements.append(node);
                continue;
            }
            case ZigClangDeclAccessSpec:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle decl kind AccessSpec");
                return ErrorUnexpected;
            case ZigClangDeclBlock:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Block");
                return ErrorUnexpected;
            case ZigClangDeclCaptured:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Captured");
                return ErrorUnexpected;
            case ZigClangDeclClassScopeFunctionSpecialization:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ClassScopeFunctionSpecialization");
                return ErrorUnexpected;
            case ZigClangDeclEmpty:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Empty");
                return ErrorUnexpected;
            case ZigClangDeclExport:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Export");
                return ErrorUnexpected;
            case ZigClangDeclExternCContext:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ExternCContext");
                return ErrorUnexpected;
            case ZigClangDeclFileScopeAsm:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C FileScopeAsm");
                return ErrorUnexpected;
            case ZigClangDeclFriend:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Friend");
                return ErrorUnexpected;
            case ZigClangDeclFriendTemplate:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C FriendTemplate");
                return ErrorUnexpected;
            case ZigClangDeclImport:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Import");
                return ErrorUnexpected;
            case ZigClangDeclLinkageSpec:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C LinkageSpec");
                return ErrorUnexpected;
            case ZigClangDeclLabel:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Label");
                return ErrorUnexpected;
            case ZigClangDeclNamespace:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Namespace");
                return ErrorUnexpected;
            case ZigClangDeclNamespaceAlias:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C NamespaceAlias");
                return ErrorUnexpected;
            case ZigClangDeclObjCCompatibleAlias:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ObjCCompatibleAlias");
                return ErrorUnexpected;
            case ZigClangDeclObjCCategory:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ObjCCategory");
                return ErrorUnexpected;
            case ZigClangDeclObjCCategoryImpl:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ObjCCategoryImpl");
                return ErrorUnexpected;
            case ZigClangDeclObjCImplementation:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ObjCImplementation");
                return ErrorUnexpected;
            case ZigClangDeclObjCInterface:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ObjCInterface");
                return ErrorUnexpected;
            case ZigClangDeclObjCProtocol:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ObjCProtocol");
                return ErrorUnexpected;
            case ZigClangDeclObjCMethod:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ObjCMethod");
                return ErrorUnexpected;
            case ZigClangDeclObjCProperty:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ObjCProperty");
                return ErrorUnexpected;
            case ZigClangDeclBuiltinTemplate:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C BuiltinTemplate");
                return ErrorUnexpected;
            case ZigClangDeclClassTemplate:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ClassTemplate");
                return ErrorUnexpected;
            case ZigClangDeclFunctionTemplate:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C FunctionTemplate");
                return ErrorUnexpected;
            case ZigClangDeclTypeAliasTemplate:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C TypeAliasTemplate");
                return ErrorUnexpected;
            case ZigClangDeclVarTemplate:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C VarTemplate");
                return ErrorUnexpected;
            case ZigClangDeclTemplateTemplateParm:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C TemplateTemplateParm");
                return ErrorUnexpected;
            case ZigClangDeclEnum:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Enum");
                return ErrorUnexpected;
            case ZigClangDeclRecord:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Record");
                return ErrorUnexpected;
            case ZigClangDeclCXXRecord:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C CXXRecord");
                return ErrorUnexpected;
            case ZigClangDeclClassTemplateSpecialization:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ClassTemplateSpecialization");
                return ErrorUnexpected;
            case ZigClangDeclClassTemplatePartialSpecialization:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ClassTemplatePartialSpecialization");
                return ErrorUnexpected;
            case ZigClangDeclTemplateTypeParm:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C TemplateTypeParm");
                return ErrorUnexpected;
            case ZigClangDeclObjCTypeParam:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ObjCTypeParam");
                return ErrorUnexpected;
            case ZigClangDeclTypeAlias:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C TypeAlias");
                return ErrorUnexpected;
            case ZigClangDeclTypedef:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Typedef");
                return ErrorUnexpected;
            case ZigClangDeclUnresolvedUsingTypename:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C UnresolvedUsingTypename");
                return ErrorUnexpected;
            case ZigClangDeclUsing:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Using");
                return ErrorUnexpected;
            case ZigClangDeclUsingDirective:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C UsingDirective");
                return ErrorUnexpected;
            case ZigClangDeclUsingPack:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C UsingPack");
                return ErrorUnexpected;
            case ZigClangDeclUsingShadow:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C UsingShadow");
                return ErrorUnexpected;
            case ZigClangDeclConstructorUsingShadow:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ConstructorUsingShadow");
                return ErrorUnexpected;
            case ZigClangDeclBinding:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Binding");
                return ErrorUnexpected;
            case ZigClangDeclField:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Field");
                return ErrorUnexpected;
            case ZigClangDeclObjCAtDefsField:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ObjCAtDefsField");
                return ErrorUnexpected;
            case ZigClangDeclObjCIvar:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ObjCIvar");
                return ErrorUnexpected;
            case ZigClangDeclFunction:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Function");
                return ErrorUnexpected;
            case ZigClangDeclCXXDeductionGuide:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C CXXDeductionGuide");
                return ErrorUnexpected;
            case ZigClangDeclCXXMethod:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C CXXMethod");
                return ErrorUnexpected;
            case ZigClangDeclCXXConstructor:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C CXXConstructor");
                return ErrorUnexpected;
            case ZigClangDeclCXXConversion:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C CXXConversion");
                return ErrorUnexpected;
            case ZigClangDeclCXXDestructor:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C CXXDestructor");
                return ErrorUnexpected;
            case ZigClangDeclMSProperty:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C MSProperty");
                return ErrorUnexpected;
            case ZigClangDeclNonTypeTemplateParm:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C NonTypeTemplateParm");
                return ErrorUnexpected;
            case ZigClangDeclDecomposition:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Decomposition");
                return ErrorUnexpected;
            case ZigClangDeclImplicitParam:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ImplicitParam");
                return ErrorUnexpected;
            case ZigClangDeclOMPCapturedExpr:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C OMPCapturedExpr");
                return ErrorUnexpected;
            case ZigClangDeclParmVar:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ParmVar");
                return ErrorUnexpected;
            case ZigClangDeclVarTemplateSpecialization:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C VarTemplateSpecialization");
                return ErrorUnexpected;
            case ZigClangDeclVarTemplatePartialSpecialization:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C VarTemplatePartialSpecialization");
                return ErrorUnexpected;
            case ZigClangDeclEnumConstant:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C EnumConstant");
                return ErrorUnexpected;
            case ZigClangDeclIndirectField:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C IndirectField");
                return ErrorUnexpected;
            case ZigClangDeclOMPDeclareReduction:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C OMPDeclareReduction");
                return ErrorUnexpected;
            case ZigClangDeclUnresolvedUsingValue:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C UnresolvedUsingValue");
                return ErrorUnexpected;
            case ZigClangDeclOMPRequires:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C OMPRequires");
                return ErrorUnexpected;
            case ZigClangDeclOMPThreadPrivate:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C OMPThreadPrivate");
                return ErrorUnexpected;
            case ZigClangDeclObjCPropertyImpl:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C ObjCPropertyImpl");
                return ErrorUnexpected;
            case ZigClangDeclPragmaComment:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C PragmaComment");
                return ErrorUnexpected;
            case ZigClangDeclPragmaDetectMismatch:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C PragmaDetectMismatch");
                return ErrorUnexpected;
            case ZigClangDeclStaticAssert:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C StaticAssert");
                return ErrorUnexpected;
            case ZigClangDeclTranslationUnit:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C TranslationUnit");
                return ErrorUnexpected;
            case ZigClangDeclConcept:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C Concept");
                return ErrorUnexpected;
            case ZigClangDeclOMPDeclareMapper:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C OMPDeclareMapper");
                return ErrorUnexpected;
            case ZigClangDeclOMPAllocate:
                emit_warning(c, ZigClangDeclStmt_getBeginLoc(stmt), "TODO handle C OMPAllocate");
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
    AstNode *casted_zero = trans_create_node_cast(c, tag_type, zero);

    // @bitCast(Enum, @TagType(Enum)(0))
    AstNode *bitcast = trans_create_node_builtin_fn_call_str(c, "bitCast");
    bitcast->data.fn_call_expr.params.append(enum_type);
    bitcast->data.fn_call_expr.params.append(casted_zero);

    return trans_create_node_bin_op(c, expr, BinOpTypeCmpNotEq, bitcast);
}

static AstNode *trans_bool_expr(Context *c, ResultUsed result_used, TransScope *scope, const ZigClangExpr *expr, TransLRValue lrval) {
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


    const ZigClangType *ty = ZigClangQualType_getTypePtr(get_expr_qual_type_before_implicit_cast(c, expr));
    auto classs = ZigClangType_getTypeClass(ty);
    switch (classs) {
        case ZigClangType_Builtin:
        {
            const ZigClangBuiltinType *builtin_ty = reinterpret_cast<const ZigClangBuiltinType*>(ty);
            switch (ZigClangBuiltinType_getKind(builtin_ty)) {
                case ZigClangBuiltinTypeBool:
                case ZigClangBuiltinTypeChar_U:
                case ZigClangBuiltinTypeUChar:
                case ZigClangBuiltinTypeChar_S:
                case ZigClangBuiltinTypeSChar:
                case ZigClangBuiltinTypeUShort:
                case ZigClangBuiltinTypeUInt:
                case ZigClangBuiltinTypeULong:
                case ZigClangBuiltinTypeULongLong:
                case ZigClangBuiltinTypeShort:
                case ZigClangBuiltinTypeInt:
                case ZigClangBuiltinTypeLong:
                case ZigClangBuiltinTypeLongLong:
                case ZigClangBuiltinTypeUInt128:
                case ZigClangBuiltinTypeInt128:
                case ZigClangBuiltinTypeFloat:
                case ZigClangBuiltinTypeDouble:
                case ZigClangBuiltinTypeFloat128:
                case ZigClangBuiltinTypeLongDouble:
                case ZigClangBuiltinTypeWChar_U:
                case ZigClangBuiltinTypeChar8:
                case ZigClangBuiltinTypeChar16:
                case ZigClangBuiltinTypeChar32:
                case ZigClangBuiltinTypeWChar_S:
                case ZigClangBuiltinTypeFloat16:
                    return trans_create_node_bin_op(c, res, BinOpTypeCmpNotEq, trans_create_node_unsigned_negative(c, 0, false));
                case ZigClangBuiltinTypeNullPtr:
                    return trans_create_node_bin_op(c, res, BinOpTypeCmpNotEq,
                            trans_create_node(c, NodeTypeNullLiteral));

                case ZigClangBuiltinTypeVoid:
                case ZigClangBuiltinTypeHalf:
                case ZigClangBuiltinTypeObjCId:
                case ZigClangBuiltinTypeObjCClass:
                case ZigClangBuiltinTypeObjCSel:
                case ZigClangBuiltinTypeOMPArraySection:
                case ZigClangBuiltinTypeDependent:
                case ZigClangBuiltinTypeOverload:
                case ZigClangBuiltinTypeBoundMember:
                case ZigClangBuiltinTypePseudoObject:
                case ZigClangBuiltinTypeUnknownAny:
                case ZigClangBuiltinTypeBuiltinFn:
                case ZigClangBuiltinTypeARCUnbridgedCast:
                case ZigClangBuiltinTypeOCLImage1dRO:
                case ZigClangBuiltinTypeOCLImage1dArrayRO:
                case ZigClangBuiltinTypeOCLImage1dBufferRO:
                case ZigClangBuiltinTypeOCLImage2dRO:
                case ZigClangBuiltinTypeOCLImage2dArrayRO:
                case ZigClangBuiltinTypeOCLImage2dDepthRO:
                case ZigClangBuiltinTypeOCLImage2dArrayDepthRO:
                case ZigClangBuiltinTypeOCLImage2dMSAARO:
                case ZigClangBuiltinTypeOCLImage2dArrayMSAARO:
                case ZigClangBuiltinTypeOCLImage2dMSAADepthRO:
                case ZigClangBuiltinTypeOCLImage2dArrayMSAADepthRO:
                case ZigClangBuiltinTypeOCLImage3dRO:
                case ZigClangBuiltinTypeOCLImage1dWO:
                case ZigClangBuiltinTypeOCLImage1dArrayWO:
                case ZigClangBuiltinTypeOCLImage1dBufferWO:
                case ZigClangBuiltinTypeOCLImage2dWO:
                case ZigClangBuiltinTypeOCLImage2dArrayWO:
                case ZigClangBuiltinTypeOCLImage2dDepthWO:
                case ZigClangBuiltinTypeOCLImage2dArrayDepthWO:
                case ZigClangBuiltinTypeOCLImage2dMSAAWO:
                case ZigClangBuiltinTypeOCLImage2dArrayMSAAWO:
                case ZigClangBuiltinTypeOCLImage2dMSAADepthWO:
                case ZigClangBuiltinTypeOCLImage2dArrayMSAADepthWO:
                case ZigClangBuiltinTypeOCLImage3dWO:
                case ZigClangBuiltinTypeOCLImage1dRW:
                case ZigClangBuiltinTypeOCLImage1dArrayRW:
                case ZigClangBuiltinTypeOCLImage1dBufferRW:
                case ZigClangBuiltinTypeOCLImage2dRW:
                case ZigClangBuiltinTypeOCLImage2dArrayRW:
                case ZigClangBuiltinTypeOCLImage2dDepthRW:
                case ZigClangBuiltinTypeOCLImage2dArrayDepthRW:
                case ZigClangBuiltinTypeOCLImage2dMSAARW:
                case ZigClangBuiltinTypeOCLImage2dArrayMSAARW:
                case ZigClangBuiltinTypeOCLImage2dMSAADepthRW:
                case ZigClangBuiltinTypeOCLImage2dArrayMSAADepthRW:
                case ZigClangBuiltinTypeOCLImage3dRW:
                case ZigClangBuiltinTypeOCLSampler:
                case ZigClangBuiltinTypeOCLEvent:
                case ZigClangBuiltinTypeOCLClkEvent:
                case ZigClangBuiltinTypeOCLQueue:
                case ZigClangBuiltinTypeOCLReserveID:
                case ZigClangBuiltinTypeShortAccum:
                case ZigClangBuiltinTypeAccum:
                case ZigClangBuiltinTypeLongAccum:
                case ZigClangBuiltinTypeUShortAccum:
                case ZigClangBuiltinTypeUAccum:
                case ZigClangBuiltinTypeULongAccum:
                case ZigClangBuiltinTypeShortFract:
                case ZigClangBuiltinTypeFract:
                case ZigClangBuiltinTypeLongFract:
                case ZigClangBuiltinTypeUShortFract:
                case ZigClangBuiltinTypeUFract:
                case ZigClangBuiltinTypeULongFract:
                case ZigClangBuiltinTypeSatShortAccum:
                case ZigClangBuiltinTypeSatAccum:
                case ZigClangBuiltinTypeSatLongAccum:
                case ZigClangBuiltinTypeSatUShortAccum:
                case ZigClangBuiltinTypeSatUAccum:
                case ZigClangBuiltinTypeSatULongAccum:
                case ZigClangBuiltinTypeSatShortFract:
                case ZigClangBuiltinTypeSatFract:
                case ZigClangBuiltinTypeSatLongFract:
                case ZigClangBuiltinTypeSatUShortFract:
                case ZigClangBuiltinTypeSatUFract:
                case ZigClangBuiltinTypeSatULongFract:
                case ZigClangBuiltinTypeOCLIntelSubgroupAVCMcePayload:
                case ZigClangBuiltinTypeOCLIntelSubgroupAVCImePayload:
                case ZigClangBuiltinTypeOCLIntelSubgroupAVCRefPayload:
                case ZigClangBuiltinTypeOCLIntelSubgroupAVCSicPayload:
                case ZigClangBuiltinTypeOCLIntelSubgroupAVCMceResult:
                case ZigClangBuiltinTypeOCLIntelSubgroupAVCImeResult:
                case ZigClangBuiltinTypeOCLIntelSubgroupAVCRefResult:
                case ZigClangBuiltinTypeOCLIntelSubgroupAVCSicResult:
                case ZigClangBuiltinTypeOCLIntelSubgroupAVCImeResultSingleRefStreamout:
                case ZigClangBuiltinTypeOCLIntelSubgroupAVCImeResultDualRefStreamout:
                case ZigClangBuiltinTypeOCLIntelSubgroupAVCImeSingleRefStreamin:
                case ZigClangBuiltinTypeOCLIntelSubgroupAVCImeDualRefStreamin:
                    return res;
            }
            break;
        }
        case ZigClangType_Pointer:
            return trans_create_node_bin_op(c, res, BinOpTypeCmpNotEq, trans_create_node(c, NodeTypeNullLiteral));

        case ZigClangType_Typedef:
        {
            const ZigClangTypedefType *typedef_ty = reinterpret_cast<const ZigClangTypedefType*>(ty);
            const ZigClangTypedefNameDecl *typedef_decl = ZigClangTypedefType_getDecl(typedef_ty);
            auto existing_entry = c->decl_table.maybe_get((void*)ZigClangTypedefNameDecl_getCanonicalDecl(typedef_decl));
            if (existing_entry) {
                return existing_entry->value;
            }

            return res;
        }

        case ZigClangType_Enum:
        {
            const ZigClangEnumType *enum_ty = reinterpret_cast<const ZigClangEnumType *>(ty);
            AstNode *enum_type = resolve_enum_decl(c, ZigClangEnumType_getDecl(enum_ty));
            return to_enum_zero_cmp(c, res, enum_type);
        }

        case ZigClangType_Elaborated:
        {
            const ZigClangElaboratedType *elaborated_ty = reinterpret_cast<const ZigClangElaboratedType*>(ty);
            switch (ZigClangElaboratedType_getKeyword(elaborated_ty)) {
                case ZigClangETK_Enum: {
                    AstNode *enum_type = trans_qual_type(c, ZigClangElaboratedType_getNamedType(elaborated_ty),
                            ZigClangExpr_getBeginLoc(expr));
                    return to_enum_zero_cmp(c, res, enum_type);
                }
                case ZigClangETK_Struct:
                case ZigClangETK_Union:
                case ZigClangETK_Interface:
                case ZigClangETK_Class:
                case ZigClangETK_Typename:
                case ZigClangETK_None:
                    return res;
            }
        }

        case ZigClangType_FunctionProto:
        case ZigClangType_Record:
        case ZigClangType_ConstantArray:
        case ZigClangType_Paren:
        case ZigClangType_Decayed:
        case ZigClangType_Attributed:
        case ZigClangType_IncompleteArray:
        case ZigClangType_BlockPointer:
        case ZigClangType_LValueReference:
        case ZigClangType_RValueReference:
        case ZigClangType_MemberPointer:
        case ZigClangType_VariableArray:
        case ZigClangType_DependentSizedArray:
        case ZigClangType_DependentSizedExtVector:
        case ZigClangType_Vector:
        case ZigClangType_ExtVector:
        case ZigClangType_FunctionNoProto:
        case ZigClangType_UnresolvedUsing:
        case ZigClangType_Adjusted:
        case ZigClangType_TypeOfExpr:
        case ZigClangType_TypeOf:
        case ZigClangType_Decltype:
        case ZigClangType_UnaryTransform:
        case ZigClangType_TemplateTypeParm:
        case ZigClangType_SubstTemplateTypeParm:
        case ZigClangType_SubstTemplateTypeParmPack:
        case ZigClangType_TemplateSpecialization:
        case ZigClangType_Auto:
        case ZigClangType_InjectedClassName:
        case ZigClangType_DependentName:
        case ZigClangType_DependentTemplateSpecialization:
        case ZigClangType_PackExpansion:
        case ZigClangType_ObjCObject:
        case ZigClangType_ObjCInterface:
        case ZigClangType_Complex:
        case ZigClangType_ObjCObjectPointer:
        case ZigClangType_Atomic:
        case ZigClangType_Pipe:
        case ZigClangType_ObjCTypeParam:
        case ZigClangType_DeducedTemplateSpecialization:
        case ZigClangType_DependentAddressSpace:
        case ZigClangType_DependentVector:
        case ZigClangType_MacroQualified:
            return res;
    }
    zig_unreachable();
}

static AstNode *trans_while_loop(Context *c, TransScope *scope, const ZigClangWhileStmt *stmt) {
    TransScopeWhile *while_scope = trans_scope_while_create(c, scope);

    while_scope->node->data.while_expr.condition = trans_bool_expr(c, ResultUsedYes, scope,
            ZigClangWhileStmt_getCond(stmt), TransRValue);
    if (while_scope->node->data.while_expr.condition == nullptr)
        return nullptr;

    TransScope *body_scope = trans_stmt(c, &while_scope->base, ZigClangWhileStmt_getBody(stmt),
            &while_scope->node->data.while_expr.body);
    if (body_scope == nullptr)
        return nullptr;

    return while_scope->node;
}

static AstNode *trans_if_statement(Context *c, TransScope *scope, const ZigClangIfStmt *stmt) {
    // if (c) t
    // if (c) t else e
    AstNode *if_node = trans_create_node(c, NodeTypeIfBoolExpr);

    TransScope *then_scope = trans_stmt(c, scope, ZigClangIfStmt_getThen(stmt), &if_node->data.if_bool_expr.then_block);
    if (then_scope == nullptr)
        return nullptr;

    if (ZigClangIfStmt_getElse(stmt) != nullptr) {
        TransScope *else_scope = trans_stmt(c, scope, ZigClangIfStmt_getElse(stmt), &if_node->data.if_bool_expr.else_node);
        if (else_scope == nullptr)
            return nullptr;
    }

    if_node->data.if_bool_expr.condition = trans_bool_expr(c, ResultUsedYes, scope, ZigClangIfStmt_getCond(stmt),
            TransRValue);
    if (if_node->data.if_bool_expr.condition == nullptr)
        return nullptr;

    return if_node;
}

static AstNode *trans_call_expr(Context *c, ResultUsed result_used, TransScope *scope, const ZigClangCallExpr *stmt) {
    AstNode *node = trans_create_node(c, NodeTypeFnCallExpr);

    AstNode *callee_raw_node = trans_expr(c, ResultUsedYes, scope, ZigClangCallExpr_getCallee(stmt), TransRValue);
    if (callee_raw_node == nullptr)
        return nullptr;

    bool is_ptr = false;
    const ZigClangFunctionProtoType *fn_ty = qual_type_get_fn_proto(
            ZigClangExpr_getType(ZigClangCallExpr_getCallee(stmt)), &is_ptr);
    AstNode *callee_node = nullptr;
    if (is_ptr && fn_ty) {
        if (ZigClangExpr_getStmtClass(ZigClangCallExpr_getCallee(stmt)) == ZigClangStmt_ImplicitCastExprClass) {
            const ZigClangImplicitCastExpr *implicit_cast = reinterpret_cast<const ZigClangImplicitCastExpr *>(
                    ZigClangCallExpr_getCallee(stmt));
            if (ZigClangImplicitCastExpr_getCastKind(implicit_cast) == ZigClangCK_FunctionToPointerDecay) {
                const ZigClangExpr *subexpr = ZigClangImplicitCastExpr_getSubExpr(implicit_cast);
                if (ZigClangExpr_getStmtClass(subexpr) == ZigClangStmt_DeclRefExprClass) {
                    const ZigClangDeclRefExpr *decl_ref = reinterpret_cast<const ZigClangDeclRefExpr *>(subexpr);
                    const ZigClangNamedDecl *named_decl = ZigClangDeclRefExpr_getFoundDecl(decl_ref);
                    if (ZigClangDecl_getKind((const ZigClangDecl *)named_decl) == ZigClangDeclFunction) {
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

    unsigned num_args = ZigClangCallExpr_getNumArgs(stmt);
    const ZigClangExpr * const* args = ZigClangCallExpr_getArgs(stmt);
    for (unsigned i = 0; i < num_args; i += 1) {
        AstNode *arg_node = trans_expr(c, ResultUsedYes, scope, args[i], TransRValue);
        if (arg_node == nullptr)
            return nullptr;

        node->data.fn_call_expr.params.append(arg_node);
    }

    if (result_used == ResultUsedNo && fn_ty &&
        !ZigClangType_isVoidType(qual_type_canon(ZigClangFunctionProtoType_getReturnType(fn_ty))))
    {
        node = trans_create_node_bin_op(c, trans_create_node_symbol_str(c, "_"), BinOpTypeAssign, node);
    }

    return node;
}

static AstNode *trans_member_expr(Context *c, ResultUsed result_used, TransScope *scope,
    const ZigClangMemberExpr *stmt)
{
    AstNode *container_node = trans_expr(c, ResultUsedYes, scope, ZigClangMemberExpr_getBase(stmt), TransRValue);
    if (container_node == nullptr)
        return nullptr;

    if (ZigClangMemberExpr_isArrow(stmt)) {
        container_node = trans_create_node_ptr_deref(c, container_node);
    }

    const char *name = ZigClangDecl_getName_bytes_begin((const ZigClangDecl *)ZigClangMemberExpr_getMemberDecl(stmt));

    AstNode *node = trans_create_node_field_access_str(c, container_node, name);
    return maybe_suppress_result(c, result_used, node);
}

static AstNode *trans_array_subscript_expr(Context *c, ResultUsed result_used, TransScope *scope,
        const ZigClangArraySubscriptExpr *stmt)
{
    AstNode *container_node = trans_expr(c, ResultUsedYes, scope, ZigClangArraySubscriptExpr_getBase(stmt),
            TransRValue);
    if (container_node == nullptr)
        return nullptr;

    AstNode *idx_node = trans_expr(c, ResultUsedYes, scope, ZigClangArraySubscriptExpr_getIdx(stmt), TransRValue);
    if (idx_node == nullptr)
        return nullptr;


    AstNode *node = trans_create_node(c, NodeTypeArrayAccessExpr);
    node->data.array_access_expr.array_ref_expr = container_node;
    node->data.array_access_expr.subscript = idx_node;
    return maybe_suppress_result(c, result_used, node);
}

static AstNode *trans_c_style_cast_expr(Context *c, ResultUsed result_used, TransScope *scope,
        const ZigClangCStyleCastExpr *stmt, TransLRValue lrvalue)
{
    AstNode *sub_expr_node = trans_expr(c, ResultUsedYes, scope, ZigClangCStyleCastExpr_getSubExpr(stmt), lrvalue);
    if (sub_expr_node == nullptr)
        return nullptr;

    AstNode *cast = trans_c_cast(c, ZigClangCStyleCastExpr_getBeginLoc(stmt), ZigClangCStyleCastExpr_getType(stmt),
            ZigClangExpr_getType(ZigClangCStyleCastExpr_getSubExpr(stmt)), sub_expr_node);
    if (cast == nullptr)
        return nullptr;

    return maybe_suppress_result(c, result_used, cast);
}

static AstNode *trans_unary_expr_or_type_trait_expr(Context *c, ResultUsed result_used,
        TransScope *scope, const ZigClangUnaryExprOrTypeTraitExpr *stmt)
{
    AstNode *type_node = trans_qual_type(c, ZigClangUnaryExprOrTypeTraitExpr_getTypeOfArgument(stmt),
            ZigClangUnaryExprOrTypeTraitExpr_getBeginLoc(stmt));
    if (type_node == nullptr)
        return nullptr;

    AstNode *node = trans_create_node_builtin_fn_call_str(c, "sizeOf");
    node->data.fn_call_expr.params.append(type_node);
    return maybe_suppress_result(c, result_used, node);
}

static AstNode *trans_do_loop(Context *c, TransScope *parent_scope, const ZigClangDoStmt *stmt) {
    TransScopeWhile *while_scope = trans_scope_while_create(c, parent_scope);

    while_scope->node->data.while_expr.condition = trans_create_node_bool(c, true);

    AstNode *body_node;
    TransScope *child_scope;
    if (ZigClangStmt_getStmtClass(ZigClangDoStmt_getBody(stmt)) == ZigClangStmt_CompoundStmtClass) {
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
        if (trans_stmt_extra(c, &while_scope->base, ZigClangDoStmt_getBody(stmt), ResultUsedNo, TransRValue,
                    &body_node, nullptr, &child_scope))
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
        child_scope = trans_stmt(c, &child_block_scope->base, ZigClangDoStmt_getBody(stmt), &child_statement);
        if (child_scope == nullptr) return nullptr;
        if (child_statement != nullptr) {
            body_node->data.block.statements.append(child_statement);
        }
    }

    // if (!cond) break;
    AstNode *condition_node = trans_expr(c, ResultUsedYes, child_scope, ZigClangDoStmt_getCond(stmt), TransRValue);
    if (condition_node == nullptr) return nullptr;
    AstNode *terminator_node = trans_create_node(c, NodeTypeIfBoolExpr);
    terminator_node->data.if_bool_expr.condition = trans_create_node_prefix_op(c, PrefixOpBoolNot, condition_node);
    terminator_node->data.if_bool_expr.then_block = trans_create_node(c, NodeTypeBreak);

    assert(terminator_node != nullptr);
    body_node->data.block.statements.append(terminator_node);

    while_scope->node->data.while_expr.body = body_node;

    return while_scope->node;
}

static AstNode *trans_for_loop(Context *c, TransScope *parent_scope, const ZigClangForStmt *stmt) {
    AstNode *loop_block_node;
    TransScopeWhile *while_scope;
    TransScope *cond_scope;
    const ZigClangStmt *init_stmt = ZigClangForStmt_getInit(stmt);
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

    const ZigClangExpr *cond_expr = ZigClangForStmt_getCond(stmt);
    if (cond_expr == nullptr) {
        while_scope->node->data.while_expr.condition = trans_create_node_bool(c, true);
    } else {
        while_scope->node->data.while_expr.condition = trans_bool_expr(c, ResultUsedYes, cond_scope,
                cond_expr, TransRValue);

        if (while_scope->node->data.while_expr.condition == nullptr)
            return nullptr;
    }

    const ZigClangExpr *inc_expr = ZigClangForStmt_getInc(stmt);
    if (inc_expr != nullptr) {
        AstNode *inc_node = trans_expr(c, ResultUsedNo, cond_scope, inc_expr, TransRValue);
        if (inc_node == nullptr)
            return nullptr;
        while_scope->node->data.while_expr.continue_expr = inc_node;
    }

    AstNode *body_statement;
    TransScope *body_scope = trans_stmt(c, &while_scope->base, ZigClangForStmt_getBody(stmt), &body_statement);
    if (body_scope == nullptr)
        return nullptr;

    if (body_statement == nullptr) {
        while_scope->node->data.while_expr.body = trans_create_node(c, NodeTypeBlock);
    } else {
        while_scope->node->data.while_expr.body = body_statement;
    }

    return loop_block_node;
}

static AstNode *trans_switch_stmt(Context *c, TransScope *parent_scope, const ZigClangSwitchStmt *stmt) {
    TransScopeBlock *block_scope = trans_scope_block_create(c, parent_scope);

    TransScopeSwitch *switch_scope;

    const ZigClangDeclStmt *var_decl_stmt = ZigClangSwitchStmt_getConditionVariableDeclStmt(stmt);
    if (var_decl_stmt == nullptr) {
        switch_scope = trans_scope_switch_create(c, &block_scope->base);
    } else {
        AstNode *vars_node;
        TransScope *var_scope = trans_stmt(c, &block_scope->base, (const ZigClangStmt *)var_decl_stmt, &vars_node);
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

    const ZigClangExpr *cond_expr = ZigClangSwitchStmt_getCond(stmt);
    assert(cond_expr != nullptr);

    AstNode *expr_node = trans_expr(c, ResultUsedYes, &block_scope->base, cond_expr, TransRValue);
    if (expr_node == nullptr)
        return nullptr;
    switch_scope->switch_node->data.switch_expr.expr = expr_node;

    AstNode *body_node;
    const ZigClangStmt *body_stmt = ZigClangSwitchStmt_getBody(stmt);
    if (ZigClangStmt_getStmtClass(body_stmt) == ZigClangStmt_CompoundStmtClass) {
        if (trans_compound_stmt_inline(c, &switch_scope->base, (const ZigClangCompoundStmt *)body_stmt,
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

    if (!switch_scope->found_default && !ZigClangSwitchStmt_isAllEnumCasesCovered(stmt)) {
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

static int trans_switch_case(Context *c, TransScope *parent_scope, const ZigClangCaseStmt *stmt, AstNode **out_node,
                             TransScope **out_scope) {
    *out_node = nullptr;

    if (ZigClangCaseStmt_getRHS(stmt) != nullptr) {
        emit_warning(c, ZigClangCaseStmt_getBeginLoc(stmt), "TODO support GNU switch case a ... b extension");
        return ErrorUnexpected;
    }

    TransScopeSwitch *switch_scope = trans_scope_switch_find(parent_scope);
    assert(switch_scope != nullptr);

    Buf *label_name = buf_sprintf("__case_%" PRIu32, switch_scope->case_index);
    switch_scope->case_index += 1;

    {
        // Add the prong
        AstNode *prong_node = trans_create_node(c, NodeTypeSwitchProng);
        AstNode *item_node = trans_expr(c, ResultUsedYes, &switch_scope->base, ZigClangCaseStmt_getLHS(stmt),
                TransRValue);
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
    TransScope *new_scope = trans_stmt(c, parent_scope, ZigClangCaseStmt_getSubStmt(stmt), &sub_stmt_node);
    if (new_scope == nullptr)
        return ErrorUnexpected;
    if (sub_stmt_node != nullptr)
        scope_block->node->data.block.statements.append(sub_stmt_node);

    *out_scope = new_scope;
    return ErrorNone;
}

static int trans_switch_default(Context *c, TransScope *parent_scope, const ZigClangDefaultStmt *stmt,
        AstNode **out_node, TransScope **out_scope)
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
    TransScope *new_scope = trans_stmt(c, parent_scope, ZigClangDefaultStmt_getSubStmt(stmt), &sub_stmt_node);
    if (new_scope == nullptr)
        return ErrorUnexpected;
    if (sub_stmt_node != nullptr)
        scope_block->node->data.block.statements.append(sub_stmt_node);

    *out_scope = new_scope;
    return ErrorNone;
}

static AstNode *trans_string_literal(Context *c, ResultUsed result_used, TransScope *scope,
        const ZigClangStringLiteral *stmt)
{
    switch (ZigClangStringLiteral_getKind(stmt)) {
        case ZigClangStringLiteral_StringKind_Ascii:
        case ZigClangStringLiteral_StringKind_UTF8: {
            size_t str_len;
            const char *str_ptr = ZigClangStringLiteral_getString_bytes_begin_size(stmt, &str_len);
            AstNode *node = trans_create_node_str_lit(c, buf_create_from_mem(str_ptr, str_len));
            return maybe_suppress_result(c, result_used, node);
        }
        case ZigClangStringLiteral_StringKind_UTF16:
            emit_warning(c, ZigClangStmt_getBeginLoc((const ZigClangStmt *)stmt), "TODO support UTF16 string literals");
            return nullptr;
        case ZigClangStringLiteral_StringKind_UTF32:
            emit_warning(c, ZigClangStmt_getBeginLoc((const ZigClangStmt *)stmt), "TODO support UTF32 string literals");
            return nullptr;
        case ZigClangStringLiteral_StringKind_Wide:
            emit_warning(c, ZigClangStmt_getBeginLoc((const ZigClangStmt *)stmt), "TODO support wide string literals");
            return nullptr;
    }
    zig_unreachable();
}

static AstNode *trans_break_stmt(Context *c, TransScope *scope, const ZigClangBreakStmt *stmt) {
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

static AstNode *trans_continue_stmt(Context *c, TransScope *scope, const ZigClangContinueStmt *stmt) {
    return trans_create_node(c, NodeTypeContinue);
}

static AstNode *trans_predefined_expr(Context *c, ResultUsed result_used, TransScope *scope,
    const ZigClangPredefinedExpr *expr)
{
    return trans_string_literal(c, result_used, scope, ZigClangPredefinedExpr_getFunctionName(expr));
}

static int wrap_stmt(AstNode **out_node, TransScope **out_scope, TransScope *in_scope, AstNode *result_node) {
    if (result_node == nullptr)
        return ErrorUnexpected;
    *out_node = result_node;
    if (out_scope != nullptr)
        *out_scope = in_scope;
    return ErrorNone;
}

static int trans_stmt_extra(Context *c, TransScope *scope, const ZigClangStmt *stmt,
        ResultUsed result_used, TransLRValue lrvalue,
        AstNode **out_node, TransScope **out_child_scope,
        TransScope **out_node_scope)
{
    ZigClangStmtClass sc = ZigClangStmt_getStmtClass(stmt);
    switch (sc) {
        case ZigClangStmt_ReturnStmtClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_return_stmt(c, scope, (const ZigClangReturnStmt *)stmt));
        case ZigClangStmt_CompoundStmtClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_compound_stmt(c, scope, (const ZigClangCompoundStmt *)stmt, out_node_scope));
        case ZigClangStmt_IntegerLiteralClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_integer_literal(c, result_used, (const ZigClangIntegerLiteral *)stmt));
        case ZigClangStmt_ConditionalOperatorClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_conditional_operator(c, result_used, scope, (const ZigClangConditionalOperator *)stmt));
        case ZigClangStmt_BinaryOperatorClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_binary_operator(c, result_used, scope, (const ZigClangBinaryOperator *)stmt));
        case ZigClangStmt_CompoundAssignOperatorClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_compound_assign_operator(c, result_used, scope, (const ZigClangCompoundAssignOperator *)stmt));
        case ZigClangStmt_ImplicitCastExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_implicit_cast_expr(c, result_used, scope, (const ZigClangImplicitCastExpr *)stmt));
        case ZigClangStmt_DeclRefExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_decl_ref_expr(c, scope, (const ZigClangDeclRefExpr *)stmt, lrvalue));
        case ZigClangStmt_UnaryOperatorClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_unary_operator(c, result_used, scope, (const ZigClangUnaryOperator *)stmt));
        case ZigClangStmt_DeclStmtClass:
            return trans_local_declaration(c, scope, (const ZigClangDeclStmt *)stmt, out_node, out_child_scope);
        case ZigClangStmt_DoStmtClass:
        case ZigClangStmt_WhileStmtClass: {
            AstNode *while_node = sc == ZigClangStmt_DoStmtClass
                ? trans_do_loop(c, scope, (const ZigClangDoStmt *)stmt)
                : trans_while_loop(c, scope, (const ZigClangWhileStmt *)stmt);

            if (while_node == nullptr)
                return ErrorUnexpected;

            assert(while_node->type == NodeTypeWhileExpr);
            if (while_node->data.while_expr.body == nullptr)
                while_node->data.while_expr.body = trans_create_node(c, NodeTypeBlock);

            return wrap_stmt(out_node, out_child_scope, scope, while_node);
        }
        case ZigClangStmt_IfStmtClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_if_statement(c, scope, (const ZigClangIfStmt *)stmt));
        case ZigClangStmt_CallExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_call_expr(c, result_used, scope, (const ZigClangCallExpr *)stmt));
        case ZigClangStmt_NullStmtClass:
            *out_node = trans_create_node(c, NodeTypeBlock);
            *out_child_scope = scope;
            return ErrorNone;
        case ZigClangStmt_MemberExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_member_expr(c, result_used, scope, (const ZigClangMemberExpr *)stmt));
        case ZigClangStmt_ArraySubscriptExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_array_subscript_expr(c, result_used, scope, (const ZigClangArraySubscriptExpr *)stmt));
        case ZigClangStmt_CStyleCastExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_c_style_cast_expr(c, result_used, scope, (const ZigClangCStyleCastExpr *)stmt, lrvalue));
        case ZigClangStmt_UnaryExprOrTypeTraitExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_unary_expr_or_type_trait_expr(c, result_used, scope, (const ZigClangUnaryExprOrTypeTraitExpr *)stmt));
        case ZigClangStmt_ForStmtClass: {
            AstNode *node = trans_for_loop(c, scope, (const ZigClangForStmt *)stmt);
            return wrap_stmt(out_node, out_child_scope, scope, node);
        }
        case ZigClangStmt_StringLiteralClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_string_literal(c, result_used, scope, (const ZigClangStringLiteral *)stmt));
        case ZigClangStmt_BreakStmtClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_break_stmt(c, scope, (const ZigClangBreakStmt *)stmt));
        case ZigClangStmt_ContinueStmtClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_continue_stmt(c, scope, (const ZigClangContinueStmt *)stmt));
        case ZigClangStmt_ParenExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_expr(c, result_used, scope,
                        ZigClangParenExpr_getSubExpr((const ZigClangParenExpr *)stmt), lrvalue));
        case ZigClangStmt_SwitchStmtClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                             trans_switch_stmt(c, scope, (const ZigClangSwitchStmt *)stmt));
        case ZigClangStmt_CaseStmtClass:
            return trans_switch_case(c, scope, (const ZigClangCaseStmt *)stmt, out_node, out_child_scope);
        case ZigClangStmt_DefaultStmtClass:
            return trans_switch_default(c, scope, (const ZigClangDefaultStmt *)stmt, out_node, out_child_scope);
        case ZigClangStmt_ConstantExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_constant_expr(c, result_used, (const ZigClangConstantExpr *)stmt));
        case ZigClangStmt_PredefinedExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                             trans_predefined_expr(c, result_used, scope, (const ZigClangPredefinedExpr *)stmt));
        case ZigClangStmt_StmtExprClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_stmt_expr(c, result_used, scope, (const ZigClangStmtExpr *)stmt, out_node_scope));
        case ZigClangStmt_NoStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C NoStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_GCCAsmStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C GCCAsmStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_MSAsmStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C MSAsmStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_AttributedStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C AttributedStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXCatchStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXCatchStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXForRangeStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXForRangeStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXTryStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXTryStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_CapturedStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CapturedStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_CoreturnStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CoreturnStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_CoroutineBodyStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CoroutineBodyStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_BinaryConditionalOperatorClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C BinaryConditionalOperatorClass");
            return ErrorUnexpected;
        case ZigClangStmt_AddrLabelExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C AddrLabelExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ArrayInitIndexExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ArrayInitIndexExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ArrayInitLoopExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ArrayInitLoopExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ArrayTypeTraitExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ArrayTypeTraitExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_AsTypeExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C AsTypeExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_AtomicExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C AtomicExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_BlockExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C BlockExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXBindTemporaryExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXBindTemporaryExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXBoolLiteralExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXBoolLiteralExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXConstructExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXConstructExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXTemporaryObjectExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXTemporaryObjectExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXDefaultArgExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXDefaultArgExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXDefaultInitExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXDefaultInitExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXDeleteExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXDeleteExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXDependentScopeMemberExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXDependentScopeMemberExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXFoldExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXFoldExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXInheritedCtorInitExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXInheritedCtorInitExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXNewExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXNewExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXNoexceptExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXNoexceptExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXNullPtrLiteralExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXNullPtrLiteralExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXPseudoDestructorExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXPseudoDestructorExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXScalarValueInitExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXScalarValueInitExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXStdInitializerListExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXStdInitializerListExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXThisExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXThisExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXThrowExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXThrowExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXTypeidExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXTypeidExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXUnresolvedConstructExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXUnresolvedConstructExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXUuidofExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXUuidofExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CUDAKernelCallExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CUDAKernelCallExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXMemberCallExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXMemberCallExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXOperatorCallExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXOperatorCallExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_UserDefinedLiteralClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C UserDefinedLiteralClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXFunctionalCastExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXFunctionalCastExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXConstCastExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXConstCastExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXDynamicCastExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXDynamicCastExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXReinterpretCastExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXReinterpretCastExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CXXStaticCastExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CXXStaticCastExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCBridgedCastExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCBridgedCastExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CharacterLiteralClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_character_literal(c, result_used, (const ZigClangCharacterLiteral *)stmt));
            return ErrorUnexpected;
        case ZigClangStmt_ChooseExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ChooseExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CompoundLiteralExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CompoundLiteralExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ConvertVectorExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ConvertVectorExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CoawaitExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CoawaitExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_CoyieldExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C CoyieldExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_DependentCoawaitExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C DependentCoawaitExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_DependentScopeDeclRefExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C DependentScopeDeclRefExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_DesignatedInitExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C DesignatedInitExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_DesignatedInitUpdateExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C DesignatedInitUpdateExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ExpressionTraitExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ExpressionTraitExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ExtVectorElementExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ExtVectorElementExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_FixedPointLiteralClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C FixedPointLiteralClass");
            return ErrorUnexpected;
        case ZigClangStmt_FloatingLiteralClass:
            return wrap_stmt(out_node, out_child_scope, scope,
                    trans_floating_literal(c, result_used, (const ZigClangFloatingLiteral *)stmt));
        case ZigClangStmt_ExprWithCleanupsClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ExprWithCleanupsClass");
            return ErrorUnexpected;
        case ZigClangStmt_FunctionParmPackExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C FunctionParmPackExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_GNUNullExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C GNUNullExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_GenericSelectionExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C GenericSelectionExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ImaginaryLiteralClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ImaginaryLiteralClass");
            return ErrorUnexpected;
        case ZigClangStmt_ImplicitValueInitExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ImplicitValueInitExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_InitListExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C InitListExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_LambdaExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C LambdaExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_MSPropertyRefExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C MSPropertyRefExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_MSPropertySubscriptExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C MSPropertySubscriptExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_MaterializeTemporaryExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C MaterializeTemporaryExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_NoInitExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C NoInitExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPArraySectionExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPArraySectionExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCArrayLiteralClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCArrayLiteralClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCAvailabilityCheckExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCAvailabilityCheckExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCBoolLiteralExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCBoolLiteralExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCBoxedExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCBoxedExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCDictionaryLiteralClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCDictionaryLiteralClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCEncodeExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCEncodeExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCIndirectCopyRestoreExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCIndirectCopyRestoreExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCIsaExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCIsaExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCIvarRefExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCIvarRefExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCMessageExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCMessageExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCPropertyRefExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCPropertyRefExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCProtocolExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCProtocolExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCSelectorExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCSelectorExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCStringLiteralClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCStringLiteralClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCSubscriptRefExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCSubscriptRefExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_OffsetOfExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OffsetOfExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_OpaqueValueExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OpaqueValueExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_UnresolvedLookupExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C UnresolvedLookupExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_UnresolvedMemberExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C UnresolvedMemberExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_PackExpansionExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C PackExpansionExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ParenListExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ParenListExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_PseudoObjectExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C PseudoObjectExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_ShuffleVectorExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ShuffleVectorExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_SizeOfPackExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C SizeOfPackExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_SubstNonTypeTemplateParmExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C SubstNonTypeTemplateParmExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_SubstNonTypeTemplateParmPackExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C SubstNonTypeTemplateParmPackExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_TypeTraitExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C TypeTraitExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_TypoExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C TypoExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_VAArgExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C VAArgExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_GotoStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C GotoStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_IndirectGotoStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C IndirectGotoStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_LabelStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C LabelStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_MSDependentExistsStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C MSDependentExistsStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPAtomicDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPAtomicDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPBarrierDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPBarrierDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPCancelDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPCancelDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPCancellationPointDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPCancellationPointDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPCriticalDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPCriticalDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPFlushDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPFlushDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPDistributeDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPDistributeDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPDistributeParallelForDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPDistributeParallelForDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPDistributeParallelForSimdDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPDistributeParallelForSimdDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPDistributeSimdDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPDistributeSimdDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPForDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPForDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPForSimdDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPForSimdDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPParallelForDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPParallelForDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPParallelForSimdDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPParallelForSimdDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPSimdDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPSimdDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTargetParallelForSimdDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTargetParallelForSimdDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTargetSimdDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTargetSimdDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTargetTeamsDistributeDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTargetTeamsDistributeDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTargetTeamsDistributeParallelForDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTargetTeamsDistributeParallelForDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTargetTeamsDistributeParallelForSimdDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTargetTeamsDistributeParallelForSimdDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTargetTeamsDistributeSimdDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTargetTeamsDistributeSimdDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTaskLoopDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTaskLoopDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTaskLoopSimdDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTaskLoopSimdDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTeamsDistributeDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTeamsDistributeDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTeamsDistributeParallelForDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTeamsDistributeParallelForDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTeamsDistributeParallelForSimdDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTeamsDistributeParallelForSimdDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTeamsDistributeSimdDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTeamsDistributeSimdDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPMasterDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPMasterDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPOrderedDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPOrderedDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPParallelDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPParallelDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPParallelSectionsDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPParallelSectionsDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPSectionDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPSectionDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPSectionsDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPSectionsDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPSingleDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPSingleDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTargetDataDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTargetDataDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTargetDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTargetDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTargetEnterDataDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTargetEnterDataDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTargetExitDataDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTargetExitDataDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTargetParallelDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTargetParallelDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTargetParallelForDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTargetParallelForDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTargetTeamsDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTargetTeamsDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTargetUpdateDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTargetUpdateDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTaskDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTaskDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTaskgroupDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTaskgroupDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTaskwaitDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTaskwaitDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTaskyieldDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTaskyieldDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_OMPTeamsDirectiveClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C OMPTeamsDirectiveClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCAtCatchStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCAtCatchStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCAtFinallyStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCAtFinallyStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCAtSynchronizedStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCAtSynchronizedStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCAtThrowStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCAtThrowStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCAtTryStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCAtTryStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCAutoreleasePoolStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCAutoreleasePoolStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_ObjCForCollectionStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C ObjCForCollectionStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_SEHExceptStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C SEHExceptStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_SEHFinallyStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C SEHFinallyStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_SEHLeaveStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C SEHLeaveStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_SEHTryStmtClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C SEHTryStmtClass");
            return ErrorUnexpected;
        case ZigClangStmt_BuiltinBitCastExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C BuiltinBitCastExprClass");
            return ErrorUnexpected;
        case ZigClangStmt_SourceLocExprClass:
            emit_warning(c, ZigClangStmt_getBeginLoc(stmt), "TODO handle C SourceLocExprClass");
            return ErrorUnexpected;
    }
    zig_unreachable();
}

// Returns null if there was an error
static AstNode *trans_expr(Context *c, ResultUsed result_used, TransScope *scope, const ZigClangExpr *expr,
        TransLRValue lrval)
{
    AstNode *result_node;
    TransScope *result_scope;
    if (trans_stmt_extra(c, scope, (const ZigClangStmt *)expr, result_used, lrval, &result_node, &result_scope, nullptr)) {
        return nullptr;
    }
    return result_node;
}

// Statements have no result and no concept of L or R value.
// Returns child scope, or null if there was an error
static TransScope *trans_stmt(Context *c, TransScope *scope, const ZigClangStmt *stmt, AstNode **out_node) {
    TransScope *child_scope;
    if (trans_stmt_extra(c, scope, stmt, ResultUsedNo, TransRValue, out_node, &child_scope, nullptr)) {
        return nullptr;
    }
    return child_scope;
}

static void visit_fn_decl(Context *c, const ZigClangFunctionDecl *fn_decl) {
    Buf *fn_name = buf_create_from_str(ZigClangDecl_getName_bytes_begin((const ZigClangDecl *)fn_decl));

    if (get_global(c, fn_name)) {
        // we already saw this function
        return;
    }

    AstNode *proto_node = trans_qual_type(c, ZigClangFunctionDecl_getType(fn_decl),
            ZigClangFunctionDecl_getLocation(fn_decl));
    if (proto_node == nullptr) {
        emit_warning(c, ZigClangFunctionDecl_getLocation(fn_decl),
                "unable to resolve prototype of function '%s'", buf_ptr(fn_name));
        return;
    }

    proto_node->data.fn_proto.name = fn_name;
    proto_node->data.fn_proto.is_extern = !ZigClangFunctionDecl_hasBody(fn_decl);

    ZigClangStorageClass sc = ZigClangFunctionDecl_getStorageClass(fn_decl);
    if (sc == ZigClangStorageClass_None) {
        proto_node->data.fn_proto.visib_mod = VisibModPub;
        proto_node->data.fn_proto.is_export = ZigClangFunctionDecl_hasBody(fn_decl) ? c->want_export : false;
    } else if (sc == ZigClangStorageClass_Extern || sc == ZigClangStorageClass_Static) {
        proto_node->data.fn_proto.visib_mod = VisibModPub;
    } else if (sc == ZigClangStorageClass_PrivateExtern) {
        emit_warning(c, ZigClangFunctionDecl_getLocation(fn_decl), "unsupported storage class: private extern");
        return;
    } else {
        emit_warning(c, ZigClangFunctionDecl_getLocation(fn_decl), "unsupported storage class: unknown");
        return;
    }

    TransScope *scope = &c->global_scope->base;

    for (size_t i = 0; i < proto_node->data.fn_proto.params.length; i += 1) {
        AstNode *param_node = proto_node->data.fn_proto.params.at(i);
        const ZigClangParmVarDecl *param = ZigClangFunctionDecl_getParamDecl(fn_decl, i);
        const char *name = ZigClangDecl_getName_bytes_begin((const ZigClangDecl *)param);

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

    if (!ZigClangFunctionDecl_hasBody(fn_decl)) {
        // just a prototype
        add_top_level_decl(c, proto_node->data.fn_proto.name, proto_node);
        return;
    }

    // actual function definition with body
    c->ptr_params.clear();
    const ZigClangStmt *body = ZigClangFunctionDecl_getBody(fn_decl);
    AstNode *actual_body_node;
    TransScope *result_scope = trans_stmt(c, scope, body, &actual_body_node);
    if (result_scope == nullptr) {
        emit_warning(c, ZigClangFunctionDecl_getLocation(fn_decl), "unable to translate function");
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

static AstNode *resolve_typdef_as_builtin(Context *c, const ZigClangTypedefNameDecl *typedef_decl, const char *primitive_name) {
    AstNode *node = trans_create_node_symbol_str(c, primitive_name);
    c->decl_table.put(typedef_decl, node);
    return node;
}

static AstNode *resolve_typedef_decl(Context *c, const ZigClangTypedefNameDecl *typedef_decl) {
    auto existing_entry = c->decl_table.maybe_get((void*)ZigClangTypedefNameDecl_getCanonicalDecl(typedef_decl));
    if (existing_entry) {
        return existing_entry->value;
    }

    ZigClangQualType child_qt = ZigClangTypedefNameDecl_getUnderlyingType(typedef_decl);
    Buf *type_name = buf_create_from_str(ZigClangDecl_getName_bytes_begin((const ZigClangDecl *)typedef_decl));

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
    c->decl_table.put(ZigClangTypedefNameDecl_getCanonicalDecl(typedef_decl), symbol_node);

    AstNode *type_node = trans_qual_type(c, child_qt, ZigClangTypedefNameDecl_getLocation(typedef_decl));
    if (type_node == nullptr) {
        emit_warning(c, ZigClangTypedefNameDecl_getLocation(typedef_decl),
                "typedef %s - unresolved child type", buf_ptr(type_name));
        c->decl_table.put(typedef_decl, nullptr);
        // TODO add global var with type_name equal to @compileError("unable to resolve C type")
        return nullptr;
    }
    add_global_var(c, type_name, type_node);

    return symbol_node;
}

struct AstNode *demote_enum_to_opaque(Context *c, const ZigClangEnumDecl *enum_decl, Buf *full_type_name,
        Buf *bare_name)
{
    AstNode *opaque_node = trans_create_node_opaque(c);
    if (full_type_name == nullptr) {
        c->decl_table.put(ZigClangEnumDecl_getCanonicalDecl(enum_decl), opaque_node);
        return opaque_node;
    }
    AstNode *symbol_node = trans_create_node_symbol(c, full_type_name);
    add_global_weak_alias(c, bare_name, full_type_name);
    add_global_var(c, full_type_name, opaque_node);
    c->decl_table.put(ZigClangEnumDecl_getCanonicalDecl(enum_decl), symbol_node);
    return symbol_node;
}

static AstNode *resolve_enum_decl(Context *c, const ZigClangEnumDecl *enum_decl) {
    auto existing_entry = c->decl_table.maybe_get(ZigClangEnumDecl_getCanonicalDecl(enum_decl));
    if (existing_entry) {
        return existing_entry->value;
    }

    const char *raw_name = ZigClangDecl_getName_bytes_begin((const ZigClangDecl *)enum_decl);
    bool is_anonymous = (raw_name[0] == 0);
    Buf *bare_name = is_anonymous ? nullptr : buf_create_from_str(raw_name);
    Buf *full_type_name = is_anonymous ? nullptr : buf_sprintf("enum_%s", buf_ptr(bare_name));

    const ZigClangEnumDecl *enum_def = ZigClangEnumDecl_getDefinition(enum_decl);
    if (!enum_def) {
        return demote_enum_to_opaque(c, enum_decl, full_type_name, bare_name);
    }


    bool pure_enum = true;
    uint32_t field_count = 0;
    for (ZigClangEnumDecl_enumerator_iterator it = ZigClangEnumDecl_enumerator_begin(enum_def),
            it_end = ZigClangEnumDecl_enumerator_end(enum_def);
        ZigClangEnumDecl_enumerator_iterator_neq(it, it_end);
        it = ZigClangEnumDecl_enumerator_iterator_next(it), field_count += 1)
    {
        const ZigClangEnumConstantDecl *enum_const = ZigClangEnumDecl_enumerator_iterator_deref(it);
        if (ZigClangEnumConstantDecl_getInitExpr(enum_const)) {
            pure_enum = false;
        }
    }
    AstNode *tag_int_type = trans_qual_type(c, ZigClangEnumDecl_getIntegerType(enum_decl),
            ZigClangEnumDecl_getLocation(enum_decl));
    assert(tag_int_type);

    AstNode *enum_node = trans_create_node(c, NodeTypeContainerDecl);
    enum_node->data.container_decl.kind = ContainerKindEnum;
    enum_node->data.container_decl.layout = ContainerLayoutExtern;
    // TODO only emit this tag type if the enum tag type is not the default.
    // I don't know what the default is, need to figure out how clang is deciding.
    // it appears to at least be different across gcc/msvc
    if (!c_is_builtin_type(c, ZigClangEnumDecl_getIntegerType(enum_decl), ZigClangBuiltinTypeUInt) &&
        !c_is_builtin_type(c, ZigClangEnumDecl_getIntegerType(enum_decl), ZigClangBuiltinTypeInt))
    {
        enum_node->data.container_decl.init_arg_expr = tag_int_type;
    }
    enum_node->data.container_decl.fields.resize(field_count);
    uint32_t i = 0;
    for (ZigClangEnumDecl_enumerator_iterator it = ZigClangEnumDecl_enumerator_begin(enum_def),
            it_end = ZigClangEnumDecl_enumerator_end(enum_def);
        ZigClangEnumDecl_enumerator_iterator_neq(it, it_end);
        it = ZigClangEnumDecl_enumerator_iterator_next(it), i += 1)
    {
        const ZigClangEnumConstantDecl *enum_const = ZigClangEnumDecl_enumerator_iterator_deref(it);

        Buf *enum_val_name = buf_create_from_str(ZigClangDecl_getName_bytes_begin((const ZigClangDecl *)enum_const));
        Buf *field_name;
        if (bare_name != nullptr && buf_starts_with_buf(enum_val_name, bare_name)) {
            field_name = buf_slice(enum_val_name, buf_len(bare_name), buf_len(enum_val_name));
        } else {
            field_name = enum_val_name;
        }

        AstNode *int_node = pure_enum && !is_anonymous ?
            nullptr : trans_create_node_apint(c, ZigClangEnumConstantDecl_getInitVal(enum_const));
        AstNode *field_node = trans_create_node(c, NodeTypeStructField);
        field_node->data.struct_field.name = field_name;
        field_node->data.struct_field.type = nullptr;
        field_node->data.struct_field.value = int_node;
        enum_node->data.container_decl.fields.items[i] = field_node;

        // in C each enum value is in the global namespace. so we put them there too.
        // at this point we can rely on the enum emitting successfully
        if (is_anonymous) {
            Buf *enum_val_name = buf_create_from_str(ZigClangDecl_getName_bytes_begin((const ZigClangDecl *)enum_const));
            add_global_var(c, enum_val_name, int_node);
        } else {
            AstNode *field_access_node = trans_create_node_field_access(c,
                    trans_create_node_symbol(c, full_type_name), field_name);
            add_global_var(c, enum_val_name, field_access_node);
        }
    }

    if (is_anonymous) {
        c->decl_table.put(ZigClangEnumDecl_getCanonicalDecl(enum_decl), enum_node);
        return enum_node;
    } else {
        AstNode *symbol_node = trans_create_node_symbol(c, full_type_name);
        add_global_weak_alias(c, bare_name, full_type_name);
        add_global_var(c, full_type_name, enum_node);
        c->decl_table.put(ZigClangEnumDecl_getCanonicalDecl(enum_decl), symbol_node);
        return enum_node;
    }
}

static AstNode *demote_struct_to_opaque(Context *c, const ZigClangRecordDecl *record_decl,
        Buf *full_type_name, Buf *bare_name)
{
    AstNode *opaque_node = trans_create_node_opaque(c);
    if (full_type_name == nullptr) {
        c->decl_table.put(ZigClangRecordDecl_getCanonicalDecl(record_decl), opaque_node);
        return opaque_node;
    }
    AstNode *symbol_node = trans_create_node_symbol(c, full_type_name);
    add_global_weak_alias(c, bare_name, full_type_name);
    add_global_var(c, full_type_name, opaque_node);
    c->decl_table.put(ZigClangRecordDecl_getCanonicalDecl(record_decl), symbol_node);
    return symbol_node;
}

static AstNode *resolve_record_decl(Context *c, const ZigClangRecordDecl *record_decl) {
    auto existing_entry = c->decl_table.maybe_get(ZigClangRecordDecl_getCanonicalDecl(record_decl));
    if (existing_entry) {
        return existing_entry->value;
    }

    const char *raw_name = ZigClangDecl_getName_bytes_begin((const ZigClangDecl *)record_decl);
    const char *container_kind_name;
    ContainerKind container_kind;
    if (ZigClangRecordDecl_isUnion(record_decl)) {
        container_kind_name = "union";
        container_kind = ContainerKindUnion;
    } else if (ZigClangRecordDecl_isStruct(record_decl)) {
        container_kind_name = "struct";
        container_kind = ContainerKindStruct;
    } else {
        emit_warning(c, ZigClangRecordDecl_getLocation(record_decl),
                "skipping record %s, not a struct or union", raw_name);
        c->decl_table.put(ZigClangRecordDecl_getCanonicalDecl(record_decl), nullptr);
        return nullptr;
    }

    bool is_anonymous = ZigClangRecordDecl_isAnonymousStructOrUnion(record_decl) || raw_name[0] == 0;
    Buf *bare_name = is_anonymous ? nullptr : buf_create_from_str(raw_name);
    Buf *full_type_name = (bare_name == nullptr) ?
        nullptr : buf_sprintf("%s_%s", container_kind_name, buf_ptr(bare_name));

    const ZigClangRecordDecl *record_def = ZigClangRecordDecl_getDefinition(record_decl);
    if (record_def == nullptr) {
        return demote_struct_to_opaque(c, record_decl, full_type_name, bare_name);
    }

    // count fields and validate
    uint32_t field_count = 0;
    for (ZigClangRecordDecl_field_iterator it = ZigClangRecordDecl_field_begin(record_def),
        it_end = ZigClangRecordDecl_field_end(record_def);
        ZigClangRecordDecl_field_iterator_neq(it, it_end);
        it = ZigClangRecordDecl_field_iterator_next(it), field_count += 1)
    {
        const ZigClangFieldDecl *field_decl = ZigClangRecordDecl_field_iterator_deref(it);

        if (ZigClangFieldDecl_isBitField(field_decl)) {
            emit_warning(c, ZigClangFieldDecl_getLocation(field_decl),
                    "%s %s demoted to opaque type - has bitfield", container_kind_name,
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
        c->decl_table.put(ZigClangRecordDecl_getCanonicalDecl(record_decl), struct_node);
    } else {
        c->decl_table.put(ZigClangRecordDecl_getCanonicalDecl(record_decl), trans_create_node_symbol(c, full_type_name));
    }

    uint32_t i = 0;
    for (ZigClangRecordDecl_field_iterator it = ZigClangRecordDecl_field_begin(record_def),
        it_end = ZigClangRecordDecl_field_end(record_def);
        ZigClangRecordDecl_field_iterator_neq(it, it_end);
        it = ZigClangRecordDecl_field_iterator_next(it), i += 1)
    {
        const ZigClangFieldDecl *field_decl = ZigClangRecordDecl_field_iterator_deref(it);

        AstNode *field_node = trans_create_node(c, NodeTypeStructField);
        field_node->data.struct_field.name = buf_create_from_str(ZigClangDecl_getName_bytes_begin((const ZigClangDecl *)field_decl));
        field_node->data.struct_field.type = trans_qual_type(c, ZigClangFieldDecl_getType(field_decl),
                ZigClangFieldDecl_getLocation(field_decl));

        if (field_node->data.struct_field.type == nullptr) {
            emit_warning(c, ZigClangFieldDecl_getLocation(field_decl),
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

static AstNode *trans_ap_value(Context *c, const ZigClangAPValue *ap_value, ZigClangQualType qt,
        ZigClangSourceLocation source_loc)
{
    switch (ZigClangAPValue_getKind(ap_value)) {
        case ZigClangAPValueInt:
            return trans_create_node_apint(c, ZigClangAPValue_getInt(ap_value));
        case ZigClangAPValueNone:
            return trans_create_node(c, NodeTypeUndefinedLiteral);
        case ZigClangAPValueArray: {
            emit_warning(c, source_loc, "TODO add a test case for this code");

            unsigned init_count = ZigClangAPValue_getArrayInitializedElts(ap_value);
            unsigned all_count = ZigClangAPValue_getArraySize(ap_value);
            unsigned leftover_count = all_count - init_count;
            AstNode *init_node = trans_create_node(c, NodeTypeContainerInitExpr);
            AstNode *arr_type_node = trans_qual_type(c, qt, source_loc);
            if (leftover_count != 0) { // We can't use the size of the final array for a partial initializer.
                bigint_init_unsigned(arr_type_node->data.array_type.size->data.int_literal.bigint, init_count);
            }
            init_node->data.container_init_expr.type = arr_type_node;
            init_node->data.container_init_expr.kind = ContainerInitKindArray;

            const ZigClangType *qt_type = ZigClangQualType_getTypePtr(qt);
            ZigClangQualType child_qt = ZigClangArrayType_getElementType(ZigClangType_getAsArrayTypeUnsafe(qt_type));

            for (size_t i = 0; i < init_count; i += 1) {
                const ZigClangAPValue *elem_ap_val = ZigClangAPValue_getArrayInitializedElt(ap_value, i);
                AstNode *elem_node = trans_ap_value(c, elem_ap_val, child_qt, source_loc);
                if (elem_node == nullptr)
                    return nullptr;
                init_node->data.container_init_expr.entries.append(elem_node);
            }
            if (leftover_count == 0) {
                return init_node;
            }

            const ZigClangAPValue *filler_ap_val = ZigClangAPValue_getArrayFiller(ap_value);
            AstNode *filler_node = trans_ap_value(c, filler_ap_val, child_qt, source_loc);
            if (filler_node == nullptr)
                return nullptr;

            AstNode* filler_arr_type = trans_create_node(c, NodeTypeArrayType);
            *filler_arr_type = *arr_type_node;
            filler_arr_type->data.array_type.size = trans_create_node_unsigned(c, 1);

            AstNode *filler_arr_1 = trans_create_node(c, NodeTypeContainerInitExpr);
            filler_arr_1->data.container_init_expr.type = filler_arr_type;
            filler_arr_1->data.container_init_expr.kind = ContainerInitKindArray;
            filler_arr_1->data.container_init_expr.entries.append(filler_node);

            AstNode *rhs_node;
            if (leftover_count == 1) {
                rhs_node = filler_arr_1;
            } else {
                AstNode *amt_node = trans_create_node_unsigned(c, leftover_count);
                rhs_node = trans_create_node_bin_op(c, filler_arr_1, BinOpTypeArrayMult, amt_node);
            }

            if (init_count == 0) {
                return rhs_node;
            }

            return trans_create_node_bin_op(c, init_node, BinOpTypeArrayCat, rhs_node);
        }
        case ZigClangAPValueLValue: {
            const ZigClangAPValueLValueBase lval_base = ZigClangAPValue_getLValueBase(ap_value);
            if (const ZigClangExpr *expr = ZigClangAPValueLValueBase_dyn_cast_Expr(lval_base)) {
                return trans_expr(c, ResultUsedYes, &c->global_scope->base, expr, TransRValue);
            }
            emit_warning(c, source_loc, "TODO handle initializer LValue ValueDecl");
            return nullptr;
        }
        case ZigClangAPValueFloat:
            emit_warning(c, source_loc, "unsupported initializer value kind: Float");
            return nullptr;
        case ZigClangAPValueComplexInt:
            emit_warning(c, source_loc, "unsupported initializer value kind: ComplexInt");
            return nullptr;
        case ZigClangAPValueComplexFloat:
            emit_warning(c, source_loc, "unsupported initializer value kind: ComplexFloat");
            return nullptr;
        case ZigClangAPValueVector:
            emit_warning(c, source_loc, "unsupported initializer value kind: Vector");
            return nullptr;
        case ZigClangAPValueStruct:
            emit_warning(c, source_loc, "unsupported initializer value kind: Struct");
            return nullptr;
        case ZigClangAPValueUnion:
            emit_warning(c, source_loc, "unsupported initializer value kind: Union");
            return nullptr;
        case ZigClangAPValueMemberPointer:
            emit_warning(c, source_loc, "unsupported initializer value kind: MemberPointer");
            return nullptr;
        case ZigClangAPValueAddrLabelDiff:
            emit_warning(c, source_loc, "unsupported initializer value kind: AddrLabelDiff");
            return nullptr;
        case ZigClangAPValueIndeterminate:
            emit_warning(c, source_loc, "unsupported initializer value kind: Indeterminate");
            return nullptr;
        case ZigClangAPValueFixedPoint:
            emit_warning(c, source_loc, "unsupported initializer value kind: FixedPoint");
            return nullptr;
    }
    zig_unreachable();
}

static void visit_var_decl(Context *c, const ZigClangVarDecl *var_decl) {
    Buf *name = buf_create_from_str(ZigClangDecl_getName_bytes_begin((const ZigClangDecl *)var_decl));

    switch (ZigClangVarDecl_getTLSKind(var_decl)) {
        case ZigClangVarDecl_TLSKind_None:
            break;
        case ZigClangVarDecl_TLSKind_Static:
            emit_warning(c, ZigClangVarDecl_getLocation(var_decl),
                    "ignoring variable '%s' - static thread local storage", buf_ptr(name));
            return;
        case ZigClangVarDecl_TLSKind_Dynamic:
            emit_warning(c, ZigClangVarDecl_getLocation(var_decl),
                    "ignoring variable '%s' - dynamic thread local storage", buf_ptr(name));
            return;
    }

    ZigClangQualType qt = ZigClangVarDecl_getType(var_decl);
    AstNode *var_type = trans_qual_type(c, qt, ZigClangVarDecl_getLocation(var_decl));
    if (var_type == nullptr) {
        emit_warning(c, ZigClangVarDecl_getLocation(var_decl), "ignoring variable '%s' - unresolved type", buf_ptr(name));
        return;
    }

    bool is_extern = ZigClangVarDecl_hasExternalStorage(var_decl);
    bool is_static = ZigClangVarDecl_isFileVarDecl(var_decl);
    bool is_const = ZigClangQualType_isConstQualified(qt);

    if (is_static && !is_extern) {
        AstNode *init_node;
        if (ZigClangVarDecl_hasInit(var_decl)) {
            const ZigClangAPValue *ap_value = ZigClangVarDecl_evaluateValue(var_decl);
            if (ap_value == nullptr) {
                emit_warning(c, ZigClangVarDecl_getLocation(var_decl),
                        "ignoring variable '%s' - unable to evaluate initializer", buf_ptr(name));
                return;
            }
            init_node = trans_ap_value(c, ap_value, qt, ZigClangVarDecl_getLocation(var_decl));
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

    emit_warning(c, ZigClangVarDecl_getLocation(var_decl),
        "ignoring variable '%s' - non-extern, non-static variable", buf_ptr(name));
    return;
}

static bool decl_visitor(void *context, const ZigClangDecl *decl) {
    Context *c = (Context*)context;

    switch (ZigClangDecl_getKind(decl)) {
        case ZigClangDeclFunction:
            visit_fn_decl(c, reinterpret_cast<const ZigClangFunctionDecl*>(decl));
            break;
        case ZigClangDeclTypedef:
            resolve_typedef_decl(c, reinterpret_cast<const ZigClangTypedefNameDecl *>(decl));
            break;
        case ZigClangDeclEnum:
            resolve_enum_decl(c, reinterpret_cast<const ZigClangEnumDecl *>(decl));
            break;
        case ZigClangDeclRecord:
            resolve_record_decl(c, reinterpret_cast<const ZigClangRecordDecl *>(decl));
            break;
        case ZigClangDeclVar:
            visit_var_decl(c, reinterpret_cast<const ZigClangVarDecl *>(decl));
            break;
        default:
            emit_warning(c, ZigClangDecl_getLocation(decl), "ignoring %s decl", ZigClangDecl_getDeclKindName(decl));
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
            return trans_create_node_str_lit(c, buf_create_from_buf(&tok->data.str_lit));
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


                //if (@typeId(@TypeOf(x)) == @import("builtin").TypeId.Pointer)
                //    @ptrCast(dest, x)
                //else if (@typeId(@TypeOf(x)) == @import("builtin").TypeId.Integer)
                //    @intToPtr(dest, x)
                //else
                //    (dest)(x)

                AstNode *import_builtin = trans_create_node_builtin_fn_call_str(c, "import");
                import_builtin->data.fn_call_expr.params.append(trans_create_node_str_lit(c, buf_create_from_str("builtin")));
                AstNode *typeid_type = trans_create_node_field_access_str(c, import_builtin, "TypeId");
                AstNode *typeid_pointer = trans_create_node_field_access_str(c, typeid_type, "Pointer");
                AstNode *typeid_integer = trans_create_node_field_access_str(c, typeid_type, "Int");
                AstNode *typeof_x = trans_create_node_builtin_fn_call_str(c, "TypeOf");
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
        case CTokIdShl:
        case CTokIdLt:
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

            node = trans_create_node_ptr_type(c, false, false, node, PtrLenC);
        } else if (first_tok->id == CTokIdShl) {
            *tok_i += 1;

            AstNode *rhs_node = parse_ctok_expr(c, ctok, tok_i);
            if (rhs_node == nullptr)
                return nullptr;
            node = trans_create_node_bin_op(c, node, BinOpTypeBitShiftLeft, rhs_node);
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

static void process_preprocessor_entities(Context *c, ZigClangASTUnit *unit) {
    CTokenize ctok = {{0}};

    // TODO if we see #undef, delete it from the table
    for (ZigClangPreprocessingRecord_iterator it = ZigClangASTUnit_getLocalPreprocessingEntities_begin(unit),
        it_end = ZigClangASTUnit_getLocalPreprocessingEntities_end(unit); it.I != it_end.I; it.I += 1)
    {
        ZigClangPreprocessedEntity *entity = ZigClangPreprocessingRecord_iterator_deref(it);

        switch (ZigClangPreprocessedEntity_getKind(entity)) {
            case ZigClangPreprocessedEntity_InvalidKind:
            case ZigClangPreprocessedEntity_InclusionDirectiveKind:
            case ZigClangPreprocessedEntity_MacroExpansionKind:
                continue;
            case ZigClangPreprocessedEntity_MacroDefinitionKind:
                {
                    ZigClangMacroDefinitionRecord *macro = reinterpret_cast<ZigClangMacroDefinitionRecord *>(entity);
                    const char *raw_name = ZigClangMacroDefinitionRecord_getName_getNameStart(macro);
                    ZigClangSourceLocation begin_loc = ZigClangMacroDefinitionRecord_getSourceRange_getBegin(macro);
                    ZigClangSourceLocation end_loc = ZigClangMacroDefinitionRecord_getSourceRange_getEnd(macro);

                    if (ZigClangSourceLocation_eq(begin_loc, end_loc)) {
                        // this means it is a macro without a value
                        // we don't care about such things
                        continue;
                    }
                    Buf *name = buf_create_from_str(raw_name);
                    if (name_exists_global(c, name)) {
                        continue;
                    }

                    const char *begin_c = ZigClangSourceManager_getCharacterData(c->source_manager, begin_loc);
                    process_macro(c, &ctok, name, begin_c);
                }
        }
    }
}

Error parse_h_file(CodeGen *codegen, AstNode **out_root_node,
        Stage2ErrorMsg **errors_ptr, size_t *errors_len,
        const char **args_begin, const char **args_end,
        TranslateMode mode, const char *resources_path)
{
    Context context = {0};
    Context *c = &context;
    c->warnings_on = codegen->verbose_cimport;
    if (mode == TranslateModeImport) {
        c->want_export = false;
    } else {
        c->want_export = true;
    }
    c->decl_table.init(8);
    c->macro_table.init(8);
    c->global_table.init(8);
    c->ptr_params.init(8);
    c->codegen = codegen;
    c->global_scope = trans_scope_root_create(c);

    ZigClangASTUnit *ast_unit = ZigClangLoadFromCommandLine(args_begin, args_end, errors_ptr, errors_len,
            resources_path);
    if (ast_unit == nullptr) {
        if (*errors_len == 0) return ErrorNoMem;
        return ErrorCCompileErrors;
    }

    c->ctx = ZigClangASTUnit_getASTContext(ast_unit);
    c->source_manager = ZigClangASTUnit_getSourceManager(ast_unit);
    c->root = trans_create_node(c, NodeTypeContainerDecl);
    c->root->data.container_decl.is_root = true;

    ZigClangASTUnit_visitLocalTopLevelDecls(ast_unit, c, decl_visitor);

    process_preprocessor_entities(c, ast_unit);

    render_macros(c);
    render_aliases(c);

    *out_root_node = c->root;

    ZigClangASTUnit_delete(ast_unit);

    return ErrorNone;
}
