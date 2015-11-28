/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_PARSER_HPP
#define ZIG_PARSER_HPP

#include "list.hpp"
#include "buffer.hpp"
#include "tokenizer.hpp"

struct AstNode;
struct CodeGenNode;

enum NodeType {
    NodeTypeRoot,
    NodeTypeRootExportDecl,
    NodeTypeFnProto,
    NodeTypeFnDef,
    NodeTypeFnDecl,
    NodeTypeParamDecl,
    NodeTypeType,
    NodeTypeBlock,
    NodeTypeFnCall,
    NodeTypeExternBlock,
    NodeTypeDirective,
    NodeTypeReturnExpr,
    NodeTypeBoolOrExpr,
    NodeTypeBoolAndExpr,
    NodeTypeComparisonExpr,
    NodeTypeBinOrExpr,
    NodeTypeBinXorExpr,
    NodeTypeBinAndExpr,
    NodeTypeBitShiftExpr,
    NodeTypeAddExpr,
    NodeTypeMultExpr,
    NodeTypeCastExpr,
    NodeTypePrimaryExpr,
    NodeTypeGroupedExpr,
};

struct AstNodeRoot {
    AstNode *root_export_decl;
    ZigList<AstNode *> top_level_decls;
};

enum FnProtoVisibMod {
    FnProtoVisibModPrivate,
    FnProtoVisibModPub,
    FnProtoVisibModExport,
};

struct AstNodeFnProto {
    ZigList<AstNode *> *directives;
    FnProtoVisibMod visib_mod;
    Buf name;
    ZigList<AstNode *> params;
    AstNode *return_type;
};

struct AstNodeFnDef {
    AstNode *fn_proto;
    AstNode *body;
};

struct AstNodeFnDecl {
    AstNode *fn_proto;
};

struct AstNodeParamDecl {
    Buf name;
    AstNode *type;
};

enum AstNodeTypeType {
    AstNodeTypeTypePrimitive,
    AstNodeTypeTypePointer,
};

struct AstNodeType {
    AstNodeTypeType type;
    Buf primitive_name;
    AstNode *child_type;
    bool is_const;
};

struct AstNodeBlock {
    ZigList<AstNode *> statements;
};

struct AstNodeReturnExpr {
    // might be null in case of return void;
    AstNode *expr;
};

struct AstNodeBoolOrExpr {
    AstNode *op1;
    // if op2 is non-null, do boolean or, otherwise nothing
    AstNode *op2;
};

struct AstNodeFnCall {
    Buf name;
    ZigList<AstNode *> params;
};

struct AstNodeExternBlock {
    ZigList<AstNode *> *directives;
    ZigList<AstNode *> fn_decls;
};

struct AstNodeDirective {
    Buf name;
    Buf param;
};

struct AstNodeRootExportDecl {
    Buf type;
    Buf name;
};

struct AstNodeBoolAndExpr {
    AstNode *op1;
    // if op2 is non-null, do boolean and, otherwise nothing
    AstNode *op2;
};

enum CmpOp {
    CmpOpInvalid,
    CmpOpEq,
    CmpOpNotEq,
    CmpOpLessThan,
    CmpOpGreaterThan,
    CmpOpLessOrEq,
    CmpOpGreaterOrEq,
};

struct AstNodeComparisonExpr {
    AstNode *op1;
    CmpOp cmp_op;
    // if op2 is non-null, do cmp_op, otherwise nothing
    AstNode *op2;
};

struct AstNodeBinOrExpr {
    AstNode *op1;
    // if op2 is non-null, do binary or, otherwise nothing
    AstNode *op2;
};

struct AstNodeBinXorExpr {
    AstNode *op1;
    // if op2 is non-null, do binary xor, otherwise nothing
    AstNode *op2;
};

struct AstNodeBinAndExpr {
    AstNode *op1;
    // if op2 is non-null, do binary and, otherwise nothing
    AstNode *op2;
};

enum BitShiftOp {
    BitShiftOpInvalid,
    BitShiftOpLeft,
    BitShiftOpRight,
};

struct AstNodeBitShiftExpr {
    AstNode *op1;
    BitShiftOp bit_shift_op;
    // if op2 is non-null, do bit_shift_op, otherwise nothing
    AstNode *op2;
};

enum AddOp {
    AddOpInvalid,
    AddOpAdd,
    AddOpSub,
};

struct AstNodeAddExpr {
    AstNode *op1;
    AddOp add_op;
    // if op2 is non-null, do add_op, otherwise nothing
    AstNode *op2;
};

enum MultOp {
    MultOpInvalid,
    MultOpMult,
    MultOpDiv,
    MultOpMod,
};

struct AstNodeMultExpr {
    AstNode *op1;
    MultOp mult_op;
    // if op2 is non-null, do mult_op, otherwise nothing
    AstNode *op2;
};

struct AstNodeCastExpr {
    AstNode *primary_expr;
    // if type is non-null, do cast, otherwise nothing
    AstNode *type;
};

enum PrimaryExprType {
    PrimaryExprTypeNumber,
    PrimaryExprTypeString,
    PrimaryExprTypeUnreachable,
    PrimaryExprTypeFnCall,
    PrimaryExprTypeGroupedExpr,
    PrimaryExprTypeBlock,
};

struct AstNodePrimaryExpr {
    PrimaryExprType type;
    union {
        Buf number;
        Buf string;
        AstNode *fn_call;
        AstNode *grouped_expr;
        AstNode *block;
    } data;
};

struct AstNodeGroupedExpr {
    AstNode *expr;
};

struct AstNode {
    enum NodeType type;
    AstNode *parent;
    int line;
    int column;
    CodeGenNode *codegen_node;
    union {
        AstNodeRoot root;
        AstNodeRootExportDecl root_export_decl;
        AstNodeFnDef fn_def;
        AstNodeFnDecl fn_decl;
        AstNodeFnProto fn_proto;
        AstNodeType type;
        AstNodeParamDecl param_decl;
        AstNodeBlock block;
        AstNodeReturnExpr return_expr;
        AstNodeBoolOrExpr bool_or_expr;
        AstNodeFnCall fn_call;
        AstNodeExternBlock extern_block;
        AstNodeDirective directive;
        AstNodeBoolAndExpr bool_and_expr;
        AstNodeComparisonExpr comparison_expr;
        AstNodeBinOrExpr bin_or_expr;
        AstNodeBinXorExpr bin_xor_expr;
        AstNodeBinAndExpr bin_and_expr;
        AstNodeBitShiftExpr bit_shift_expr;
        AstNodeAddExpr add_expr;
        AstNodeMultExpr mult_expr;
        AstNodeCastExpr cast_expr;
        AstNodePrimaryExpr primary_expr;
        AstNodeGroupedExpr grouped_expr;
    } data;
};

__attribute__ ((format (printf, 2, 3)))
void ast_token_error(Token *token, const char *format, ...);


// This function is provided by generated code, generated by parsergen.cpp
AstNode * ast_parse(Buf *buf, ZigList<Token> *tokens);

const char *node_type_str(NodeType node_type);

void ast_print(AstNode *node, int indent);

#endif
