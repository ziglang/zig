/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "parser.hpp"
#include "errmsg.hpp"
#include "analyze.hpp"

#include <stdarg.h>
#include <stdio.h>


static const char *bin_op_str(BinOpType bin_op) {
    switch (bin_op) {
        case BinOpTypeInvalid:             return "(invalid)";
        case BinOpTypeBoolOr:              return "||";
        case BinOpTypeBoolAnd:             return "&&";
        case BinOpTypeCmpEq:               return "==";
        case BinOpTypeCmpNotEq:            return "!=";
        case BinOpTypeCmpLessThan:         return "<";
        case BinOpTypeCmpGreaterThan:      return ">";
        case BinOpTypeCmpLessOrEq:         return "<=";
        case BinOpTypeCmpGreaterOrEq:      return ">=";
        case BinOpTypeBinOr:               return "|";
        case BinOpTypeBinXor:              return "^";
        case BinOpTypeBinAnd:              return "&";
        case BinOpTypeBitShiftLeft:        return "<<";
        case BinOpTypeBitShiftRight:       return ">>";
        case BinOpTypeAdd:                 return "+";
        case BinOpTypeSub:                 return "-";
        case BinOpTypeMult:                return "*";
        case BinOpTypeDiv:                 return "/";
        case BinOpTypeMod:                 return "%";
        case BinOpTypeAssign:              return "=";
        case BinOpTypeAssignTimes:         return "*=";
        case BinOpTypeAssignDiv:           return "/=";
        case BinOpTypeAssignMod:           return "%=";
        case BinOpTypeAssignPlus:          return "+=";
        case BinOpTypeAssignMinus:         return "-=";
        case BinOpTypeAssignBitShiftLeft:  return "<<=";
        case BinOpTypeAssignBitShiftRight: return ">>=";
        case BinOpTypeAssignBitAnd:        return "&=";
        case BinOpTypeAssignBitXor:        return "^=";
        case BinOpTypeAssignBitOr:         return "|=";
        case BinOpTypeAssignBoolAnd:       return "&&=";
        case BinOpTypeAssignBoolOr:        return "||=";
    }
    zig_unreachable();
}

static const char *prefix_op_str(PrefixOp prefix_op) {
    switch (prefix_op) {
        case PrefixOpInvalid: return "(invalid)";
        case PrefixOpNegation: return "-";
        case PrefixOpBoolNot: return "!";
        case PrefixOpBinNot: return "~";
    }
    zig_unreachable();
}

const char *node_type_str(NodeType node_type) {
    switch (node_type) {
        case NodeTypeRoot:
            return "Root";
        case NodeTypeRootExportDecl:
            return "RootExportDecl";
        case NodeTypeFnDef:
            return "FnDef";
        case NodeTypeFnDecl:
            return "FnDecl";
        case NodeTypeFnProto:
            return "FnProto";
        case NodeTypeParamDecl:
            return "ParamDecl";
        case NodeTypeType:
            return "Type";
        case NodeTypeBlock:
            return "Block";
        case NodeTypeBinOpExpr:
            return "BinOpExpr";
        case NodeTypeFnCallExpr:
            return "FnCallExpr";
        case NodeTypeArrayAccessExpr:
            return "ArrayAccessExpr";
        case NodeTypeExternBlock:
            return "ExternBlock";
        case NodeTypeDirective:
            return "Directive";
        case NodeTypeReturnExpr:
            return "ReturnExpr";
        case NodeTypeVariableDeclaration:
            return "VariableDeclaration";
        case NodeTypeCastExpr:
            return "CastExpr";
        case NodeTypeNumberLiteral:
            return "NumberLiteral";
        case NodeTypeStringLiteral:
            return "StringLiteral";
        case NodeTypeUnreachable:
            return "Unreachable";
        case NodeTypeSymbol:
            return "Symbol";
        case NodeTypePrefixOpExpr:
            return "PrefixOpExpr";
        case NodeTypeUse:
            return "Use";
        case NodeTypeVoid:
            return "Void";
        case NodeTypeBoolLiteral:
            return "BoolLiteral";
        case NodeTypeIfExpr:
            return "IfExpr";
        case NodeTypeLabel:
            return "Label";
        case NodeTypeGoto:
            return "Goto";
        case NodeTypeAsmExpr:
            return "AsmExpr";
        case NodeTypeFieldAccessExpr:
            return "FieldAccessExpr";
        case NodeTypeStructDecl:
            return "StructDecl";
        case NodeTypeStructField:
            return "StructField";
    }
    zig_unreachable();
}

void ast_print(AstNode *node, int indent) {
    for (int i = 0; i < indent; i += 1) {
        fprintf(stderr, " ");
    }

    switch (node->type) {
        case NodeTypeRoot:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            for (int i = 0; i < node->data.root.top_level_decls.length; i += 1) {
                AstNode *child = node->data.root.top_level_decls.at(i);
                ast_print(child, indent + 2);
            }
            break;
        case NodeTypeRootExportDecl:
            fprintf(stderr, "%s %s '%s'\n", node_type_str(node->type),
                    buf_ptr(&node->data.root_export_decl.type),
                    buf_ptr(&node->data.root_export_decl.name));
            break;
        case NodeTypeFnDef:
            {
                fprintf(stderr, "%s\n", node_type_str(node->type));
                AstNode *child = node->data.fn_def.fn_proto;
                ast_print(child, indent + 2);
                ast_print(node->data.fn_def.body, indent + 2);
                break;
            }
        case NodeTypeFnProto:
            {
                Buf *name_buf = &node->data.fn_proto.name;
                fprintf(stderr, "%s '%s'\n", node_type_str(node->type), buf_ptr(name_buf));

                for (int i = 0; i < node->data.fn_proto.params.length; i += 1) {
                    AstNode *child = node->data.fn_proto.params.at(i);
                    ast_print(child, indent + 2);
                }

                ast_print(node->data.fn_proto.return_type, indent + 2);

                break;
            }
        case NodeTypeBlock:
            {
                fprintf(stderr, "%s\n", node_type_str(node->type));
                for (int i = 0; i < node->data.block.statements.length; i += 1) {
                    AstNode *child = node->data.block.statements.at(i);
                    ast_print(child, indent + 2);
                }
                break;
            }
        case NodeTypeParamDecl:
            {
                Buf *name_buf = &node->data.param_decl.name;
                fprintf(stderr, "%s '%s'\n", node_type_str(node->type), buf_ptr(name_buf));

                ast_print(node->data.param_decl.type, indent + 2);

                break;
            }
        case NodeTypeType:
            switch (node->data.type.type) {
                case AstNodeTypeTypePrimitive:
                    {
                        Buf *name_buf = &node->data.type.primitive_name;
                        fprintf(stderr, "%s '%s'\n", node_type_str(node->type), buf_ptr(name_buf));
                        break;
                    }
                case AstNodeTypeTypePointer:
                    {
                        const char *const_or_mut_str = node->data.type.is_const ? "const" : "mut";
                        fprintf(stderr, "'%s' PointerType\n", const_or_mut_str);

                        ast_print(node->data.type.child_type, indent + 2);
                        break;
                    }
                case AstNodeTypeTypeArray:
                    {
                        fprintf(stderr, "ArrayType\n");
                        ast_print(node->data.type.child_type, indent + 2);
                        ast_print(node->data.type.array_size, indent + 2);
                        break;
                    }
            }
            break;
        case NodeTypeReturnExpr:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            if (node->data.return_expr.expr)
                ast_print(node->data.return_expr.expr, indent + 2);
            break;
        case NodeTypeVariableDeclaration:
            {
                Buf *name_buf = &node->data.variable_declaration.symbol;
                fprintf(stderr, "%s '%s'\n", node_type_str(node->type), buf_ptr(name_buf));
                if (node->data.variable_declaration.type)
                    ast_print(node->data.variable_declaration.type, indent + 2);
                if (node->data.variable_declaration.expr)
                    ast_print(node->data.variable_declaration.expr, indent + 2);
                break;
            }
        case NodeTypeExternBlock:
            {
                fprintf(stderr, "%s\n", node_type_str(node->type));
                for (int i = 0; i < node->data.extern_block.fn_decls.length; i += 1) {
                    AstNode *child = node->data.extern_block.fn_decls.at(i);
                    ast_print(child, indent + 2);
                }
                break;
            }
        case NodeTypeFnDecl:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            ast_print(node->data.fn_decl.fn_proto, indent + 2);
            break;
        case NodeTypeBinOpExpr:
            fprintf(stderr, "%s %s\n", node_type_str(node->type),
                    bin_op_str(node->data.bin_op_expr.bin_op));
            ast_print(node->data.bin_op_expr.op1, indent + 2);
            ast_print(node->data.bin_op_expr.op2, indent + 2);
            break;
        case NodeTypeFnCallExpr:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            ast_print(node->data.fn_call_expr.fn_ref_expr, indent + 2);
            for (int i = 0; i < node->data.fn_call_expr.params.length; i += 1) {
                AstNode *child = node->data.fn_call_expr.params.at(i);
                ast_print(child, indent + 2);
            }
            break;
        case NodeTypeArrayAccessExpr:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            ast_print(node->data.array_access_expr.array_ref_expr, indent + 2);
            ast_print(node->data.array_access_expr.subscript, indent + 2);
            break;
        case NodeTypeDirective:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            break;
        case NodeTypeCastExpr:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            ast_print(node->data.cast_expr.expr, indent + 2);
            if (node->data.cast_expr.type)
                ast_print(node->data.cast_expr.type, indent + 2);
            break;
        case NodeTypePrefixOpExpr:
            fprintf(stderr, "%s %s\n", node_type_str(node->type),
                    prefix_op_str(node->data.prefix_op_expr.prefix_op));
            ast_print(node->data.prefix_op_expr.primary_expr, indent + 2);
            break;
        case NodeTypeNumberLiteral:
            {
                NumLit num_lit = node->data.number_literal.kind;
                const char *name = node_type_str(node->type);
                const char *kind_str = num_lit_str(num_lit);
                if (is_num_lit_signed(num_lit)) {
                    fprintf(stderr, "%s %s %" PRId64 "\n", name, kind_str, node->data.number_literal.data.x_int);
                } else if (is_num_lit_unsigned(num_lit)) {
                    fprintf(stderr, "%s %s %" PRIu64 "\n", name, kind_str, node->data.number_literal.data.x_uint);
                } else {
                    fprintf(stderr, "%s %s %f\n", name, kind_str, node->data.number_literal.data.x_float);
                }
                break;
            }
        case NodeTypeStringLiteral:
            {
                const char *c = node->data.string_literal.c ? "c" : "";
                fprintf(stderr, "StringLiteral %s'%s'\n", c,
                        buf_ptr(&node->data.string_literal.buf));
                break;
            }
        case NodeTypeUnreachable:
            fprintf(stderr, "Unreachable\n");
            break;
        case NodeTypeSymbol:
            fprintf(stderr, "Symbol %s\n",
                    buf_ptr(&node->data.symbol));
            break;
        case NodeTypeUse:
            fprintf(stderr, "%s '%s'\n", node_type_str(node->type), buf_ptr(&node->data.use.path));
            break;
        case NodeTypeVoid:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            break;
        case NodeTypeBoolLiteral:
            fprintf(stderr, "%s '%s'\n", node_type_str(node->type), node->data.bool_literal ? "true" : "false");
            break;
        case NodeTypeIfExpr:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            if (node->data.if_expr.condition)
                ast_print(node->data.if_expr.condition, indent + 2);
            ast_print(node->data.if_expr.then_block, indent + 2);
            if (node->data.if_expr.else_node)
                ast_print(node->data.if_expr.else_node, indent + 2);
            break;
        case NodeTypeLabel:
            fprintf(stderr, "%s '%s'\n", node_type_str(node->type), buf_ptr(&node->data.label.name));
            break;
        case NodeTypeGoto:
            fprintf(stderr, "%s '%s'\n", node_type_str(node->type), buf_ptr(&node->data.go_to.name));
            break;
        case NodeTypeAsmExpr:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            break;
        case NodeTypeFieldAccessExpr:
            fprintf(stderr, "%s '%s'\n", node_type_str(node->type),
                    buf_ptr(&node->data.field_access_expr.field_name));
            ast_print(node->data.field_access_expr.struct_expr, indent + 2);
            break;
        case NodeTypeStructDecl:
            fprintf(stderr, "%s '%s'\n",
                    node_type_str(node->type), buf_ptr(&node->data.struct_decl.name));
            break;
        case NodeTypeStructField:
            fprintf(stderr, "%s '%s'\n", node_type_str(node->type), buf_ptr(&node->data.struct_field.name));
            ast_print(node->data.struct_field.type, indent + 2);
            break;
    }
}

struct ParseContext {
    Buf *buf;
    AstNode *root;
    ZigList<Token> *tokens;
    ZigList<AstNode *> *directive_list;
    ImportTableEntry *owner;
    ErrColor err_color;
};

__attribute__ ((format (printf, 4, 5)))
__attribute__ ((noreturn))
static void ast_asm_error(ParseContext *pc, AstNode *node, int offset, const char *format, ...) {
    assert(node->type == NodeTypeAsmExpr);

    ErrorMsg *err = allocate<ErrorMsg>(1);

    SrcPos pos = node->data.asm_expr.offset_map.at(offset);

    err->line_start = pos.line;
    err->column_start = pos.column;
    err->line_end = -1;
    err->column_end = -1;

    va_list ap;
    va_start(ap, format);
    err->msg = buf_vprintf(format, ap);
    va_end(ap);

    err->path = pc->owner->path;
    err->source = pc->owner->source_code;
    err->line_offsets = pc->owner->line_offsets;

    print_err_msg(err, pc->err_color);
    exit(EXIT_FAILURE);
}

__attribute__ ((format (printf, 3, 4)))
__attribute__ ((noreturn))
static void ast_error(ParseContext *pc, Token *token, const char *format, ...) {
    ErrorMsg *err = allocate<ErrorMsg>(1);
    err->line_start = token->start_line;
    err->column_start = token->start_column;
    err->line_end = -1;
    err->column_end = -1;

    va_list ap;
    va_start(ap, format);
    err->msg = buf_vprintf(format, ap);
    va_end(ap);

    err->path = pc->owner->path;
    err->source = pc->owner->source_code;
    err->line_offsets = pc->owner->line_offsets;

    print_err_msg(err, pc->err_color);
    exit(EXIT_FAILURE);
}

static AstNode *ast_create_node_no_line_info(ParseContext *pc, NodeType type) {
    AstNode *node = allocate<AstNode>(1);
    node->type = type;
    node->owner = pc->owner;
    return node;
}

static void ast_update_node_line_info(AstNode *node, Token *first_token) {
    node->line = first_token->start_line;
    node->column = first_token->start_column;
}

static AstNode *ast_create_node(ParseContext *pc, NodeType type, Token *first_token) {
    AstNode *node = ast_create_node_no_line_info(pc, type);
    ast_update_node_line_info(node, first_token);
    return node;
}

static AstNode *ast_create_node_with_node(ParseContext *pc, NodeType type, AstNode *other_node) {
    AstNode *node = ast_create_node_no_line_info(pc, type);
    node->line = other_node->line;
    node->column = other_node->column;
    return node;
}

static AstNode *ast_create_void_type_node(ParseContext *pc, Token *token) {
    AstNode *node = ast_create_node(pc, NodeTypeType, token);
    node->data.type.type = AstNodeTypeTypePrimitive;
    buf_init_from_str(&node->data.type.primitive_name, "void");
    return node;
}

static void ast_buf_from_token(ParseContext *pc, Token *token, Buf *buf) {
    buf_init_from_mem(buf, buf_ptr(pc->buf) + token->start_pos, token->end_pos - token->start_pos);
}

static void parse_asm_template(ParseContext *pc, AstNode *node) {
    Buf *asm_template = &node->data.asm_expr.asm_template;

    enum State {
        StateStart,
        StatePercent,
        StateTemplate,
        StateVar,
    };

    ZigList<AsmToken> *tok_list = &node->data.asm_expr.token_list;
    assert(tok_list->length == 0);

    AsmToken *cur_tok = nullptr;

    enum State state = StateStart;

    for (int i = 0; i < buf_len(asm_template); i += 1) {
        uint8_t c = *((uint8_t*)buf_ptr(asm_template) + i);
        switch (state) {
            case StateStart:
                if (c == '%') {
                    tok_list->add_one();
                    cur_tok = &tok_list->last();
                    cur_tok->id = AsmTokenIdPercent;
                    cur_tok->start = i;
                    state = StatePercent;
                } else {
                    tok_list->add_one();
                    cur_tok = &tok_list->last();
                    cur_tok->id = AsmTokenIdTemplate;
                    cur_tok->start = i;
                    state = StateTemplate;
                }
                break;
            case StatePercent:
                if (c == '%') {
                    cur_tok->end = i;
                    state = StateStart;
                } else if (c == '[') {
                    cur_tok->id = AsmTokenIdVar;
                    state = StateVar;
                } else {
                    ast_asm_error(pc, node, i, "expected a '%%' or '['");
                }
                break;
            case StateTemplate:
                if (c == '%') {
                    cur_tok->end = i;
                    i -= 1;
                    cur_tok = nullptr;
                    state = StateStart;
                }
                break;
            case StateVar:
                if (c == ']') {
                    cur_tok->end = i;
                    state = StateStart;
                } else if ((c >= 'a' && c <= 'z') ||
                        (c >= '0' && c <= '9') ||
                        (c == '_'))
                {
                    // do nothing
                } else {
                    ast_asm_error(pc, node, i, "invalid substitution character: '%c'", c);
                }
                break;
        }
    }

    switch (state) {
        case StateStart:
            break;
        case StatePercent:
        case StateVar:
            ast_asm_error(pc, node, buf_len(asm_template), "unexpected end of assembly template");
            break;
        case StateTemplate:
            cur_tok->end = buf_len(asm_template);
            break;
    }
}

static void parse_string_literal(ParseContext *pc, Token *token, Buf *buf, bool *out_c_str,
        ZigList<SrcPos> *offset_map)
{
    // skip the double quotes at beginning and end
    // convert escape sequences
    // detect c string literal

    buf_resize(buf, 0);
    bool escape = false;
    bool skip_quote;
    SrcPos pos = {token->start_line, token->start_column};
    for (int i = token->start_pos; i < token->end_pos - 1; i += 1) {
        uint8_t c = *((uint8_t*)buf_ptr(pc->buf) + i);
        if (i == token->start_pos) {
            skip_quote = (c == 'c');
            if (out_c_str) {
                *out_c_str = skip_quote;
            } else if (skip_quote) {
                ast_error(pc, token, "C string literal not allowed here");
            }
        } else if (skip_quote) {
            skip_quote = false;
        } else {
            if (escape) {
                switch (c) {
                    case '\\':
                        buf_append_char(buf, '\\');
                        if (offset_map) offset_map->append(pos);
                        break;
                    case 'r':
                        buf_append_char(buf, '\r');
                        if (offset_map) offset_map->append(pos);
                        break;
                    case 'n':
                        buf_append_char(buf, '\n');
                        if (offset_map) offset_map->append(pos);
                        break;
                    case 't':
                        buf_append_char(buf, '\t');
                        if (offset_map) offset_map->append(pos);
                        break;
                    case '"':
                        buf_append_char(buf, '"');
                        if (offset_map) offset_map->append(pos);
                        break;
                }
                escape = false;
            } else if (c == '\\') {
                escape = true;
            } else {
                buf_append_char(buf, c);
                if (offset_map) offset_map->append(pos);
            }
        }
        if (c == '\n') {
            pos.line += 1;
            pos.column = 0;
        } else {
            pos.column += 1;
        }
    }
    assert(!escape);
    if (offset_map) offset_map->append(pos);
}

enum ParseNumLitState {
    ParseNumLitStateStart,
    ParseNumLitStateBase,
    ParseNumLitStateDigits,
    ParseNumLitStateExpectFirstDigit,
    ParseNumLitStateDecimal,
    ParseNumLitStateESign,
    ParseNumLitStateEDigit,
};

static void parse_number_literal(ParseContext *pc, Token *token, AstNodeNumberLiteral *num_lit) {
    ParseNumLitState state = ParseNumLitStateStart;
    unsigned long long base = 10;
    bool negative = false;
    int digits_start;
    int digits_end;
    int decimal_start = -1;
    int decimal_end;
    bool e_present = false;
    bool e_positive;
    int e_digit_start;
    int e_digit_end;

    for (int i = token->start_pos; i < token->end_pos; i += 1) {
        uint8_t c = *((uint8_t*)buf_ptr(pc->buf) + i);
        switch (state) {
            case ParseNumLitStateStart:
                if (c == '-') {
                    negative = true;
                } else if (c == '0') {
                    state = ParseNumLitStateBase;
                } else if (c >= '1' && c <= '9') {
                    digits_start = i;
                    state = ParseNumLitStateDigits;
                } else {
                    zig_unreachable();
                }
                break;
            case ParseNumLitStateBase:
                if (c == 'x') {
                    base = 16;
                    state = ParseNumLitStateExpectFirstDigit;
                } else if (c == 'o') {
                    base = 8;
                    state = ParseNumLitStateExpectFirstDigit;
                } else if (c == 'b') {
                    base = 2;
                    state = ParseNumLitStateExpectFirstDigit;
                } else {
                    zig_unreachable();
                }
                break;

            case ParseNumLitStateExpectFirstDigit:
                state = ParseNumLitStateDigits;
                break;

            case ParseNumLitStateDigits:
                if (c == '.') {
                    assert(base == 10);
                    digits_end = i;
                    decimal_start = i + 1;
                    state = ParseNumLitStateDecimal;
                }
                break;
            case ParseNumLitStateDecimal:
                if (c == 'E') {
                    e_present = false;
                    decimal_end = i;
                    state = ParseNumLitStateESign;
                }
                break;
            case ParseNumLitStateESign:
                if (c == '+') {
                    e_positive = true;
                    e_digit_start = i + 1;
                    state = ParseNumLitStateEDigit;
                } else if (c == '-') {
                    e_positive = false;
                    e_digit_start = i + 1;
                    state = ParseNumLitStateEDigit;
                } else {
                    zig_unreachable();
                }
                break;
            case ParseNumLitStateEDigit:
                assert(c >= '0' && c <= '9');
                break;
        }
    }

    switch (state) {
        case ParseNumLitStateDigits:
            digits_end = token->end_pos;
            break;
        case ParseNumLitStateDecimal:
            decimal_end = token->end_pos;
            break;
        case ParseNumLitStateEDigit:
            e_digit_end = token->end_pos;
            break;
        case ParseNumLitStateBase:
            num_lit->kind = NumLitU8;
            num_lit->data.x_uint = 0;
            return;
        case ParseNumLitStateESign:
        case ParseNumLitStateExpectFirstDigit:
        case ParseNumLitStateStart:
            zig_unreachable();
    }

    if (decimal_start >= 0) {
        // float
        double x;

        (void)x;
        zig_panic("TODO parse float");
    } else {
        // integer
        unsigned long long x = 0;

        unsigned long long mult = 1;
        for (int i = digits_end - 1; ; i -= 1) {
            uint8_t c = *((uint8_t*)buf_ptr(pc->buf) + i);
            unsigned long long digit = (c - '0');

            // digit *= mult
            if (__builtin_umulll_overflow(digit, mult, &digit)) {
                num_lit->overflow = true;
                return;
            }

            // x += digit
            if (__builtin_uaddll_overflow(x, digit, &x)) {
                num_lit->overflow = true;
                return;
            }

            if (i == digits_start)
                break;

            // mult *= base
            if (__builtin_umulll_overflow(mult, base, &mult)) {
                num_lit->overflow = true;
                return;
            }
        }

        if (negative) {
            if (x <= 128ull) {
                num_lit->kind = NumLitI8;
            } else if (x <= 32768ull) {
                num_lit->kind = NumLitI16;
            } else if (x <= 2147483648ull) {
                num_lit->kind = NumLitI32;
            } else if (x <= 9223372036854775808ull) {
                num_lit->kind = NumLitI64;
            } else {
                num_lit->overflow = true;
                return;
            }

            num_lit->data.x_int = -((int64_t)x);
        } else {
            num_lit->data.x_uint = x;

            if (x <= UINT8_MAX) {
                num_lit->kind = NumLitU8;
            } else if (x <= UINT16_MAX) {
                num_lit->kind = NumLitU16;
            } else if (x <= UINT32_MAX) {
                num_lit->kind = NumLitU32;
            } else {
                num_lit->kind = NumLitU64;
            }
        }
    }
}


__attribute__ ((noreturn))
static void ast_invalid_token_error(ParseContext *pc, Token *token) {
    Buf token_value = BUF_INIT;
    ast_buf_from_token(pc, token, &token_value);
    ast_error(pc, token, "invalid token: '%s'", buf_ptr(&token_value));
}

static AstNode *ast_parse_expression(ParseContext *pc, int *token_index, bool mandatory);
static AstNode *ast_parse_block(ParseContext *pc, int *token_index, bool mandatory);
static AstNode *ast_parse_if_expr(ParseContext *pc, int *token_index, bool mandatory);
static AstNode *ast_parse_block_expr(ParseContext *pc, int *token_index, bool mandatory);

static void ast_expect_token(ParseContext *pc, Token *token, TokenId token_id) {
    if (token->id != token_id) {
        ast_invalid_token_error(pc, token);
    }
}

static Token *ast_eat_token(ParseContext *pc, int *token_index, TokenId token_id) {
    Token *token = &pc->tokens->at(*token_index);
    ast_expect_token(pc, token, token_id);
    *token_index += 1;
    return token;
}


static AstNode *ast_parse_directive(ParseContext *pc, int token_index, int *new_token_index) {
    Token *number_sign = &pc->tokens->at(token_index);
    token_index += 1;
    ast_expect_token(pc, number_sign, TokenIdNumberSign);

    AstNode *node = ast_create_node(pc, NodeTypeDirective, number_sign);

    Token *name_symbol = &pc->tokens->at(token_index);
    token_index += 1;
    ast_expect_token(pc, name_symbol, TokenIdSymbol);

    ast_buf_from_token(pc, name_symbol, &node->data.directive.name);

    Token *l_paren = &pc->tokens->at(token_index);
    token_index += 1;
    ast_expect_token(pc, l_paren, TokenIdLParen);

    Token *param_str = &pc->tokens->at(token_index);
    token_index += 1;
    ast_expect_token(pc, param_str, TokenIdStringLiteral);

    parse_string_literal(pc, param_str, &node->data.directive.param, nullptr, nullptr);

    Token *r_paren = &pc->tokens->at(token_index);
    token_index += 1;
    ast_expect_token(pc, r_paren, TokenIdRParen);

    *new_token_index = token_index;
    return node;
}

static void ast_parse_directives(ParseContext *pc, int *token_index,
        ZigList<AstNode *> *directives)
{
    for (;;) {
        Token *token = &pc->tokens->at(*token_index);
        if (token->id == TokenIdNumberSign) {
            AstNode *directive_node = ast_parse_directive(pc, *token_index, token_index);
            directives->append(directive_node);
        } else {
            return;
        }
    }
    zig_unreachable();
}


/*
Type : token(Symbol) | token(Unreachable) | token(Void) | PointerType | ArrayType
PointerType : token(Star) (token(Const) | token(Mut)) Type
ArrayType : token(LBracket) Type token(Semicolon) token(Number) token(RBracket)
*/
static AstNode *ast_parse_type(ParseContext *pc, int token_index, int *new_token_index) {
    Token *token = &pc->tokens->at(token_index);
    token_index += 1;

    AstNode *node = ast_create_node(pc, NodeTypeType, token);

    if (token->id == TokenIdKeywordUnreachable) {
        node->data.type.type = AstNodeTypeTypePrimitive;
        buf_init_from_str(&node->data.type.primitive_name, "unreachable");
    } else if (token->id == TokenIdKeywordVoid) {
        node->data.type.type = AstNodeTypeTypePrimitive;
        buf_init_from_str(&node->data.type.primitive_name, "void");
    } else if (token->id == TokenIdSymbol) {
        node->data.type.type = AstNodeTypeTypePrimitive;
        ast_buf_from_token(pc, token, &node->data.type.primitive_name);
    } else if (token->id == TokenIdStar) {
        node->data.type.type = AstNodeTypeTypePointer;
        Token *const_or_mut = &pc->tokens->at(token_index);
        token_index += 1;
        if (const_or_mut->id == TokenIdKeywordMut) {
            node->data.type.is_const = false;
        } else if (const_or_mut->id == TokenIdKeywordConst) {
            node->data.type.is_const = true;
        } else {
            ast_invalid_token_error(pc, const_or_mut);
        }

        node->data.type.child_type = ast_parse_type(pc, token_index, &token_index);
    } else if (token->id == TokenIdLBracket) {
        node->data.type.type = AstNodeTypeTypeArray;

        node->data.type.child_type = ast_parse_type(pc, token_index, &token_index);

        Token *semicolon_token = &pc->tokens->at(token_index);
        token_index += 1;
        ast_expect_token(pc, semicolon_token, TokenIdSemicolon);

        node->data.type.array_size = ast_parse_expression(pc, &token_index, true);

        Token *rbracket_token = &pc->tokens->at(token_index);
        token_index += 1;
        ast_expect_token(pc, rbracket_token, TokenIdRBracket);
    } else {
        ast_invalid_token_error(pc, token);
    }

    *new_token_index = token_index;
    return node;
}

/*
ParamDecl : token(Symbol) token(Colon) Type | token(Ellipsis)
*/
static AstNode *ast_parse_param_decl(ParseContext *pc, int token_index, int *new_token_index) {
    Token *param_name = &pc->tokens->at(token_index);
    token_index += 1;

    if (param_name->id == TokenIdSymbol) {
        AstNode *node = ast_create_node(pc, NodeTypeParamDecl, param_name);

        ast_buf_from_token(pc, param_name, &node->data.param_decl.name);

        Token *colon = &pc->tokens->at(token_index);
        token_index += 1;
        ast_expect_token(pc, colon, TokenIdColon);

        node->data.param_decl.type = ast_parse_type(pc, token_index, &token_index);

        *new_token_index = token_index;
        return node;
    } else if (param_name->id == TokenIdEllipsis) {
        *new_token_index = token_index;
        return nullptr;
    } else {
        ast_invalid_token_error(pc, param_name);
    }
}


static void ast_parse_param_decl_list(ParseContext *pc, int token_index, int *new_token_index,
        ZigList<AstNode *> *params, bool *is_var_args)
{
    *is_var_args = false;

    Token *l_paren = &pc->tokens->at(token_index);
    token_index += 1;
    ast_expect_token(pc, l_paren, TokenIdLParen);

    Token *token = &pc->tokens->at(token_index);
    if (token->id == TokenIdRParen) {
        token_index += 1;
        *new_token_index = token_index;
        return;
    }

    for (;;) {
        AstNode *param_decl_node = ast_parse_param_decl(pc, token_index, &token_index);
        bool expect_end = false;
        if (param_decl_node) {
            params->append(param_decl_node);
        } else {
            *is_var_args = true;
            expect_end = true;
        }

        Token *token = &pc->tokens->at(token_index);
        token_index += 1;
        if (token->id == TokenIdRParen) {
            *new_token_index = token_index;
            return;
        } else if (expect_end) {
            ast_invalid_token_error(pc, token);
        } else {
            ast_expect_token(pc, token, TokenIdComma);
        }
    }
    zig_unreachable();
}

static void ast_parse_fn_call_param_list(ParseContext *pc, int token_index, int *new_token_index,
        ZigList<AstNode*> *params)
{
    Token *token = &pc->tokens->at(token_index);
    if (token->id == TokenIdRParen) {
        token_index += 1;
        *new_token_index = token_index;
        return;
    }

    for (;;) {
        AstNode *expr = ast_parse_expression(pc, &token_index, true);
        params->append(expr);

        Token *token = &pc->tokens->at(token_index);
        token_index += 1;
        if (token->id == TokenIdRParen) {
            *new_token_index = token_index;
            return;
        } else {
            ast_expect_token(pc, token, TokenIdComma);
        }
    }
    zig_unreachable();
}

/*
GroupedExpression : token(LParen) Expression token(RParen)
*/
static AstNode *ast_parse_grouped_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *l_paren = &pc->tokens->at(*token_index);
    if (l_paren->id != TokenIdLParen) {
        if (mandatory) {
            ast_invalid_token_error(pc, l_paren);
        } else {
            return nullptr;
        }
    }

    *token_index += 1;

    AstNode *node = ast_parse_expression(pc, token_index, true);

    Token *r_paren = &pc->tokens->at(*token_index);
    *token_index += 1;
    ast_expect_token(pc, r_paren, TokenIdRParen);

    return node;
}

/*
PrimaryExpression : token(Number) | token(String) | KeywordLiteral | GroupedExpression | token(Symbol) | Goto | BlockExpression
*/
static AstNode *ast_parse_primary_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);

    if (token->id == TokenIdNumberLiteral) {
        AstNode *node = ast_create_node(pc, NodeTypeNumberLiteral, token);
        parse_number_literal(pc, token, &node->data.number_literal);
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdStringLiteral) {
        AstNode *node = ast_create_node(pc, NodeTypeStringLiteral, token);
        parse_string_literal(pc, token, &node->data.string_literal.buf, &node->data.string_literal.c, nullptr);
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdKeywordUnreachable) {
        AstNode *node = ast_create_node(pc, NodeTypeUnreachable, token);
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdKeywordVoid) {
        AstNode *node = ast_create_node(pc, NodeTypeVoid, token);
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdKeywordTrue) {
        AstNode *node = ast_create_node(pc, NodeTypeBoolLiteral, token);
        node->data.bool_literal = true;
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdKeywordFalse) {
        AstNode *node = ast_create_node(pc, NodeTypeBoolLiteral, token);
        node->data.bool_literal = false;
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdSymbol) {
        AstNode *node = ast_create_node(pc, NodeTypeSymbol, token);
        ast_buf_from_token(pc, token, &node->data.symbol);
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdKeywordGoto) {
        AstNode *node = ast_create_node(pc, NodeTypeGoto, token);
        *token_index += 1;

        Token *dest_symbol = &pc->tokens->at(*token_index);
        *token_index += 1;
        ast_expect_token(pc, dest_symbol, TokenIdSymbol);

        ast_buf_from_token(pc, dest_symbol, &node->data.go_to.name);
        return node;
    }

    AstNode *grouped_expr_node = ast_parse_grouped_expr(pc, token_index, false);
    if (grouped_expr_node) {
        return grouped_expr_node;
    }

    AstNode *block_expr_node = ast_parse_block_expr(pc, token_index, false);
    if (block_expr_node) {
        return block_expr_node;
    }

    if (!mandatory)
        return nullptr;

    ast_invalid_token_error(pc, token);
}

/*
SuffixOpExpression : PrimaryExpression option(FnCallExpression | ArrayAccessExpression | FieldAccessExpression)
FnCallExpression : token(LParen) list(Expression, token(Comma)) token(RParen)
ArrayAccessExpression : token(LBracket) Expression token(RBracket)
FieldAccessExpression : token(Dot) token(Symbol)
*/
static AstNode *ast_parse_suffix_op_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *primary_expr = ast_parse_primary_expr(pc, token_index, mandatory);
    if (!primary_expr) {
        return nullptr;
    }

    Token *token = &pc->tokens->at(*token_index);
    if (token->id == TokenIdLParen) {
        *token_index += 1;

        AstNode *node = ast_create_node(pc, NodeTypeFnCallExpr, token);
        node->data.fn_call_expr.fn_ref_expr = primary_expr;
        ast_parse_fn_call_param_list(pc, *token_index, token_index, &node->data.fn_call_expr.params);
        return node;
    } else if (token->id == TokenIdLBracket) {
        *token_index += 1;

        AstNode *node = ast_create_node(pc, NodeTypeArrayAccessExpr, token);
        node->data.array_access_expr.array_ref_expr = primary_expr;
        node->data.array_access_expr.subscript = ast_parse_expression(pc, token_index, true);

        Token *r_bracket = &pc->tokens->at(*token_index);
        *token_index += 1;
        ast_expect_token(pc, r_bracket, TokenIdRBracket);

        return node;
    } else if (token->id == TokenIdDot) {
        *token_index += 1;

        Token *name_token = ast_eat_token(pc, token_index, TokenIdSymbol);

        AstNode *node = ast_create_node(pc, NodeTypeFieldAccessExpr, token);
        node->data.field_access_expr.struct_expr = primary_expr;
        ast_buf_from_token(pc, name_token, &node->data.field_access_expr.field_name);

        return node;
    } else {
        return primary_expr;
    }
}

static PrefixOp tok_to_prefix_op(Token *token) {
    switch (token->id) {
        case TokenIdBang: return PrefixOpBoolNot;
        case TokenIdDash: return PrefixOpNegation;
        case TokenIdTilde: return PrefixOpBinNot;
        default: return PrefixOpInvalid;
    }
}

/*
PrefixOp : token(Not) | token(Dash) | token(Tilde)
*/
static PrefixOp ast_parse_prefix_op(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);
    PrefixOp result = tok_to_prefix_op(token);
    if (result == PrefixOpInvalid) {
        if (mandatory) {
            ast_invalid_token_error(pc, token);
        } else {
            return PrefixOpInvalid;
        }
    }
    *token_index += 1;
    return result;
}

/*
PrefixOpExpression : PrefixOp PrefixOpExpression | SuffixOpExpression
*/
static AstNode *ast_parse_prefix_op_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);
    PrefixOp prefix_op = ast_parse_prefix_op(pc, token_index, false);
    if (prefix_op == PrefixOpInvalid)
        return ast_parse_suffix_op_expr(pc, token_index, mandatory);

    AstNode *prefix_op_expr = ast_parse_prefix_op_expr(pc, token_index, true);
    AstNode *node = ast_create_node(pc, NodeTypePrefixOpExpr, token);
    node->data.prefix_op_expr.primary_expr = prefix_op_expr;
    node->data.prefix_op_expr.prefix_op = prefix_op;

    return node;
}


/*
CastExpression : CastExpression token(as) Type | PrefixOpExpression
*/
static AstNode *ast_parse_cast_expression(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_prefix_op_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *as_kw = &pc->tokens->at(*token_index);
        if (as_kw->id != TokenIdKeywordAs)
            return operand_1;
        *token_index += 1;

        AstNode *node = ast_create_node(pc, NodeTypeCastExpr, as_kw);
        node->data.cast_expr.expr = operand_1;

        node->data.cast_expr.type = ast_parse_type(pc, *token_index, token_index);

        operand_1 = node;
    }
}

static BinOpType tok_to_mult_op(Token *token) {
    switch (token->id) {
        case TokenIdStar: return BinOpTypeMult;
        case TokenIdSlash: return BinOpTypeDiv;
        case TokenIdPercent: return BinOpTypeMod;
        default: return BinOpTypeInvalid;
    }
}

/*
MultiplyOperator : token(Star) | token(Slash) | token(Percent)
*/
static BinOpType ast_parse_mult_op(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);
    BinOpType result = tok_to_mult_op(token);
    if (result == BinOpTypeInvalid) {
        if (mandatory) {
            ast_invalid_token_error(pc, token);
        } else {
            return BinOpTypeInvalid;
        }
    }
    *token_index += 1;
    return result;
}

/*
MultiplyExpression : CastExpression MultiplyOperator MultiplyExpression | CastExpression
*/
static AstNode *ast_parse_mult_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_cast_expression(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *token = &pc->tokens->at(*token_index);
        BinOpType mult_op = ast_parse_mult_op(pc, token_index, false);
        if (mult_op == BinOpTypeInvalid)
            return operand_1;

        AstNode *operand_2 = ast_parse_cast_expression(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = operand_1;
        node->data.bin_op_expr.bin_op = mult_op;
        node->data.bin_op_expr.op2 = operand_2;

        operand_1 = node;
    }
}

static BinOpType tok_to_add_op(Token *token) {
    switch (token->id) {
        case TokenIdPlus: return BinOpTypeAdd;
        case TokenIdDash: return BinOpTypeSub;
        default: return BinOpTypeInvalid;
    }
}

/*
AdditionOperator : token(Plus) | token(Minus)
*/
static BinOpType ast_parse_add_op(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);
    BinOpType result = tok_to_add_op(token);
    if (result == BinOpTypeInvalid) {
        if (mandatory) {
            ast_invalid_token_error(pc, token);
        } else {
            return BinOpTypeInvalid;
        }
    }
    *token_index += 1;
    return result;
}

/*
AdditionExpression : MultiplyExpression AdditionOperator AdditionExpression | MultiplyExpression
*/
static AstNode *ast_parse_add_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_mult_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *token = &pc->tokens->at(*token_index);
        BinOpType add_op = ast_parse_add_op(pc, token_index, false);
        if (add_op == BinOpTypeInvalid)
            return operand_1;

        AstNode *operand_2 = ast_parse_mult_expr(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = operand_1;
        node->data.bin_op_expr.bin_op = add_op;
        node->data.bin_op_expr.op2 = operand_2;

        operand_1 = node;
    }
}

static BinOpType tok_to_bit_shift_op(Token *token) {
    switch (token->id) {
        case TokenIdBitShiftLeft: return BinOpTypeBitShiftLeft;
        case TokenIdBitShiftRight: return BinOpTypeBitShiftRight;
        default: return BinOpTypeInvalid;
    }
}

/*
BitShiftOperator : token(BitShiftLeft) | token(BitShiftRight)
*/
static BinOpType ast_parse_bit_shift_op(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);
    BinOpType result = tok_to_bit_shift_op(token);
    if (result == BinOpTypeInvalid) {
        if (mandatory) {
            ast_invalid_token_error(pc, token);
        } else {
            return BinOpTypeInvalid;
        }
    }
    *token_index += 1;
    return result;
}

/*
BitShiftExpression : AdditionExpression BitShiftOperator BitShiftExpression | AdditionExpression
*/
static AstNode *ast_parse_bit_shift_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_add_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *token = &pc->tokens->at(*token_index);
        BinOpType bit_shift_op = ast_parse_bit_shift_op(pc, token_index, false);
        if (bit_shift_op == BinOpTypeInvalid)
            return operand_1;

        AstNode *operand_2 = ast_parse_add_expr(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = operand_1;
        node->data.bin_op_expr.bin_op = bit_shift_op;
        node->data.bin_op_expr.op2 = operand_2;

        operand_1 = node;
    }
}


/*
BinaryAndExpression : BitShiftExpression token(BinAnd) BinaryAndExpression | BitShiftExpression
*/
static AstNode *ast_parse_bin_and_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_bit_shift_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *token = &pc->tokens->at(*token_index);
        if (token->id != TokenIdBinAnd)
            return operand_1;
        *token_index += 1;

        AstNode *operand_2 = ast_parse_bit_shift_expr(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = operand_1;
        node->data.bin_op_expr.bin_op = BinOpTypeBinAnd;
        node->data.bin_op_expr.op2 = operand_2;

        operand_1 = node;
    }
}

/*
BinaryXorExpression : BinaryAndExpression token(BinXor) BinaryXorExpression | BinaryAndExpression
*/
static AstNode *ast_parse_bin_xor_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_bin_and_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *token = &pc->tokens->at(*token_index);
        if (token->id != TokenIdBinXor)
            return operand_1;
        *token_index += 1;

        AstNode *operand_2 = ast_parse_bin_and_expr(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = operand_1;
        node->data.bin_op_expr.bin_op = BinOpTypeBinXor;
        node->data.bin_op_expr.op2 = operand_2;

        operand_1 = node;
    }
}

/*
BinaryOrExpression : BinaryXorExpression token(BinOr) BinaryOrExpression | BinaryXorExpression
*/
static AstNode *ast_parse_bin_or_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_bin_xor_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *token = &pc->tokens->at(*token_index);
        if (token->id != TokenIdBinOr)
            return operand_1;
        *token_index += 1;

        AstNode *operand_2 = ast_parse_bin_xor_expr(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = operand_1;
        node->data.bin_op_expr.bin_op = BinOpTypeBinOr;
        node->data.bin_op_expr.op2 = operand_2;

        operand_1 = node;
    }
}

static BinOpType tok_to_cmp_op(Token *token) {
    switch (token->id) {
        case TokenIdCmpEq: return BinOpTypeCmpEq;
        case TokenIdCmpNotEq: return BinOpTypeCmpNotEq;
        case TokenIdCmpLessThan: return BinOpTypeCmpLessThan;
        case TokenIdCmpGreaterThan: return BinOpTypeCmpGreaterThan;
        case TokenIdCmpLessOrEq: return BinOpTypeCmpLessOrEq;
        case TokenIdCmpGreaterOrEq: return BinOpTypeCmpGreaterOrEq;
        default: return BinOpTypeInvalid;
    }
}

static BinOpType ast_parse_comparison_operator(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);
    BinOpType result = tok_to_cmp_op(token);
    if (result == BinOpTypeInvalid) {
        if (mandatory) {
            ast_invalid_token_error(pc, token);
        } else {
            return BinOpTypeInvalid;
        }
    }
    *token_index += 1;
    return result;
}

/*
ComparisonExpression : BinaryOrExpression ComparisonOperator BinaryOrExpression | BinaryOrExpression
*/
static AstNode *ast_parse_comparison_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_bin_or_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    Token *token = &pc->tokens->at(*token_index);
    BinOpType cmp_op = ast_parse_comparison_operator(pc, token_index, false);
    if (cmp_op == BinOpTypeInvalid)
        return operand_1;

    AstNode *operand_2 = ast_parse_bin_or_expr(pc, token_index, true);

    AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
    node->data.bin_op_expr.op1 = operand_1;
    node->data.bin_op_expr.bin_op = cmp_op;
    node->data.bin_op_expr.op2 = operand_2;

    return node;
}

/*
BoolAndExpression : ComparisonExpression token(BoolAnd) BoolAndExpression | ComparisonExpression
 */
static AstNode *ast_parse_bool_and_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_comparison_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *token = &pc->tokens->at(*token_index);
        if (token->id != TokenIdBoolAnd)
            return operand_1;
        *token_index += 1;

        AstNode *operand_2 = ast_parse_comparison_expr(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = operand_1;
        node->data.bin_op_expr.bin_op = BinOpTypeBoolAnd;
        node->data.bin_op_expr.op2 = operand_2;

        operand_1 = node;
    }
}

/*
ElseIf : token(Else) IfExpression
Else : token(Else) Block
*/
static AstNode *ast_parse_else_or_else_if(ParseContext *pc, int *token_index, bool mandatory) {
    Token *else_token = &pc->tokens->at(*token_index);

    if (else_token->id != TokenIdKeywordElse) {
        if (mandatory) {
            ast_invalid_token_error(pc, else_token);
        } else {
            return nullptr;
        }
    }
    *token_index += 1;

    AstNode *if_expr = ast_parse_if_expr(pc, token_index, false);
    if (if_expr)
        return if_expr;

    return ast_parse_block(pc, token_index, true);
}

/*
IfExpression : token(If) Expression Block option(Else | ElseIf)
*/
static AstNode *ast_parse_if_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *if_tok = &pc->tokens->at(*token_index);
    if (if_tok->id != TokenIdKeywordIf) {
        if (mandatory) {
            ast_invalid_token_error(pc, if_tok);
        } else {
            return nullptr;
        }
    }
    *token_index += 1;

    AstNode *node = ast_create_node(pc, NodeTypeIfExpr, if_tok);
    node->data.if_expr.condition = ast_parse_expression(pc, token_index, true);
    node->data.if_expr.then_block = ast_parse_block(pc, token_index, true);
    node->data.if_expr.else_node = ast_parse_else_or_else_if(pc, token_index, false);
    return node;
}

/*
ReturnExpression : token(Return) option(Expression)
*/
static AstNode *ast_parse_return_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *return_tok = &pc->tokens->at(*token_index);
    if (return_tok->id == TokenIdKeywordReturn) {
        *token_index += 1;
        AstNode *node = ast_create_node(pc, NodeTypeReturnExpr, return_tok);
        node->data.return_expr.expr = ast_parse_expression(pc, token_index, false);
        return node;
    } else if (mandatory) {
        ast_invalid_token_error(pc, return_tok);
    } else {
        return nullptr;
    }
}

/*
VariableDeclaration : token(Let) option(token(Mut)) token(Symbol) (token(Eq) Expression | token(Colon) Type option(token(Eq) Expression))
*/
static AstNode *ast_parse_variable_declaration_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *let_tok = &pc->tokens->at(*token_index);
    if (let_tok->id == TokenIdKeywordLet) {
        *token_index += 1;
        AstNode *node = ast_create_node(pc, NodeTypeVariableDeclaration, let_tok);

        Token *name_token;
        Token *token = &pc->tokens->at(*token_index);
        if (token->id == TokenIdKeywordMut) {
            node->data.variable_declaration.is_const = false;
            *token_index += 1;
            name_token = &pc->tokens->at(*token_index);
            ast_expect_token(pc, name_token, TokenIdSymbol);
        } else if (token->id == TokenIdSymbol) {
            node->data.variable_declaration.is_const = true;
            name_token = token;
        } else {
            ast_invalid_token_error(pc, token);
        }

        *token_index += 1;
        ast_buf_from_token(pc, name_token, &node->data.variable_declaration.symbol);

        Token *eq_or_colon = &pc->tokens->at(*token_index);
        *token_index += 1;
        if (eq_or_colon->id == TokenIdEq) {
            node->data.variable_declaration.expr = ast_parse_expression(pc, token_index, true);
            return node;
        } else if (eq_or_colon->id == TokenIdColon) {
            node->data.variable_declaration.type = ast_parse_type(pc, *token_index, token_index);

            Token *eq_token = &pc->tokens->at(*token_index);
            if (eq_token->id == TokenIdEq) {
                *token_index += 1;

                node->data.variable_declaration.expr = ast_parse_expression(pc, token_index, true);
            }
            return node;
        } else {
            ast_invalid_token_error(pc, eq_or_colon);
        }
    } else if (mandatory) {
        ast_invalid_token_error(pc, let_tok);
    } else {
        return nullptr;
    }
}

/*
BoolOrExpression : BoolAndExpression token(BoolOr) BoolOrExpression | BoolAndExpression
*/
static AstNode *ast_parse_bool_or_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_bool_and_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *token = &pc->tokens->at(*token_index);
        if (token->id != TokenIdBoolOr)
            return operand_1;
        *token_index += 1;

        AstNode *operand_2 = ast_parse_bool_and_expr(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = operand_1;
        node->data.bin_op_expr.bin_op = BinOpTypeBoolOr;
        node->data.bin_op_expr.op2 = operand_2;

        operand_1 = node;
    }
}

/*
BlockExpression : IfExpression | Block
*/
static AstNode *ast_parse_block_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);

    AstNode *if_expr = ast_parse_if_expr(pc, token_index, false);
    if (if_expr)
        return if_expr;

    AstNode *block = ast_parse_block(pc, token_index, false);
    if (block)
        return block;

    if (mandatory)
        ast_invalid_token_error(pc, token);

    return nullptr;
}

static BinOpType tok_to_ass_op(Token *token) {
    switch (token->id) {
        case TokenIdEq: return BinOpTypeAssign;
        case TokenIdTimesEq: return BinOpTypeAssignTimes;
        case TokenIdDivEq: return BinOpTypeAssignDiv;
        case TokenIdModEq: return BinOpTypeAssignMod;
        case TokenIdPlusEq: return BinOpTypeAssignPlus;
        case TokenIdMinusEq: return BinOpTypeAssignMinus;
        case TokenIdBitShiftLeftEq: return BinOpTypeAssignBitShiftLeft;
        case TokenIdBitShiftRightEq: return BinOpTypeAssignBitShiftRight;
        case TokenIdBitAndEq: return BinOpTypeAssignBitAnd;
        case TokenIdBitXorEq: return BinOpTypeAssignBitXor;
        case TokenIdBitOrEq: return BinOpTypeAssignBitOr;
        case TokenIdBoolAndEq: return BinOpTypeAssignBoolAnd;
        case TokenIdBoolOrEq: return BinOpTypeAssignBoolOr;
        default: return BinOpTypeInvalid;
    }
}

/*
AssignmentOperator : token(Eq) | token(TimesEq) | token(DivEq) | token(ModEq) | token(PlusEq) | token(MinusEq) | token(BitShiftLeftEq) | token(BitShiftRightEq) | token(BitAndEq) | token(BitXorEq) | token(BitOrEq) | token(BoolAndEq) | token(BoolOrEq)
*/
static BinOpType ast_parse_ass_op(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);
    BinOpType result = tok_to_ass_op(token);
    if (result == BinOpTypeInvalid) {
        if (mandatory) {
            ast_invalid_token_error(pc, token);
        } else {
            return BinOpTypeInvalid;
        }
    }
    *token_index += 1;
    return result;
}

/*
AssignmentExpression : BoolOrExpression AssignmentOperator BoolOrExpression | BoolOrExpression
*/
static AstNode *ast_parse_ass_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *lhs = ast_parse_bool_or_expr(pc, token_index, mandatory);
    if (!lhs)
        return nullptr;

    Token *token = &pc->tokens->at(*token_index);
    BinOpType ass_op = ast_parse_ass_op(pc, token_index, false);
    if (ass_op == BinOpTypeInvalid)
        return lhs;

    AstNode *rhs = ast_parse_bool_or_expr(pc, token_index, true);

    AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
    node->data.bin_op_expr.op1 = lhs;
    node->data.bin_op_expr.bin_op = ass_op;
    node->data.bin_op_expr.op2 = rhs;

    return node;
}

/*
AsmInputItem : token(LBracket) token(Symbol) token(RBracket) token(String) token(LParen) Expression token(RParen)
*/
static void ast_parse_asm_input_item(ParseContext *pc, int *token_index, AstNode *node) {
    ast_eat_token(pc, token_index, TokenIdLBracket);
    Token *alias = ast_eat_token(pc, token_index, TokenIdSymbol);
    ast_eat_token(pc, token_index, TokenIdRBracket);

    Token *constraint = ast_eat_token(pc, token_index, TokenIdStringLiteral);

    ast_eat_token(pc, token_index, TokenIdLParen);
    AstNode *expr_node = ast_parse_expression(pc, token_index, true);
    ast_eat_token(pc, token_index, TokenIdRParen);

    AsmInput *asm_input = allocate<AsmInput>(1);
    ast_buf_from_token(pc, alias, &asm_input->asm_symbolic_name);
    parse_string_literal(pc, constraint, &asm_input->constraint, nullptr, nullptr);
    asm_input->expr = expr_node;
    node->data.asm_expr.input_list.append(asm_input);
}

/*
AsmOutputItem : token(LBracket) token(Symbol) token(RBracket) token(String) token(LParen) token(Symbol) token(RParen)
*/
static void ast_parse_asm_output_item(ParseContext *pc, int *token_index, AstNode *node) {
    ast_eat_token(pc, token_index, TokenIdLBracket);
    Token *alias = ast_eat_token(pc, token_index, TokenIdSymbol);
    ast_eat_token(pc, token_index, TokenIdRBracket);

    Token *constraint = ast_eat_token(pc, token_index, TokenIdStringLiteral);

    ast_eat_token(pc, token_index, TokenIdLParen);
    Token *out_symbol = ast_eat_token(pc, token_index, TokenIdSymbol);
    ast_eat_token(pc, token_index, TokenIdRParen);

    AsmOutput *asm_output = allocate<AsmOutput>(1);
    ast_buf_from_token(pc, alias, &asm_output->asm_symbolic_name);
    parse_string_literal(pc, constraint, &asm_output->constraint, nullptr, nullptr);
    ast_buf_from_token(pc, out_symbol, &asm_output->variable_name);
    node->data.asm_expr.output_list.append(asm_output);
}

/*
AsmClobbers: token(Colon) list(token(String), token(Comma))
*/
static void ast_parse_asm_clobbers(ParseContext *pc, int *token_index, AstNode *node) {
    Token *colon_tok = &pc->tokens->at(*token_index);

    if (colon_tok->id != TokenIdColon)
        return;

    *token_index += 1;

    for (;;) {
        Token *string_tok = &pc->tokens->at(*token_index);
        ast_expect_token(pc, string_tok, TokenIdStringLiteral);
        *token_index += 1;

        Buf *clobber_buf = buf_alloc();
        parse_string_literal(pc, string_tok, clobber_buf, nullptr, nullptr);
        node->data.asm_expr.clobber_list.append(clobber_buf);

        Token *comma = &pc->tokens->at(*token_index);

        if (comma->id == TokenIdComma) {
            *token_index += 1;
            continue;
        } else {
            break;
        }
    }
}

/*
AsmInput : token(Colon) list(AsmInputItem, token(Comma)) option(AsmClobbers)
*/
static void ast_parse_asm_input(ParseContext *pc, int *token_index, AstNode *node) {
    Token *colon_tok = &pc->tokens->at(*token_index);

    if (colon_tok->id != TokenIdColon)
        return;

    *token_index += 1;

    for (;;) {
        ast_parse_asm_input_item(pc, token_index, node);

        Token *comma = &pc->tokens->at(*token_index);

        if (comma->id == TokenIdComma) {
            *token_index += 1;
            continue;
        } else {
            break;
        }
    }

    ast_parse_asm_clobbers(pc, token_index, node);
}

/*
AsmOutput : token(Colon) list(AsmOutputItem, token(Comma)) option(AsmInput)
*/
static void ast_parse_asm_output(ParseContext *pc, int *token_index, AstNode *node) {
    Token *colon_tok = &pc->tokens->at(*token_index);

    if (colon_tok->id != TokenIdColon)
        return;

    *token_index += 1;

    for (;;) {
        ast_parse_asm_output_item(pc, token_index, node);

        Token *comma = &pc->tokens->at(*token_index);

        if (comma->id == TokenIdComma) {
            *token_index += 1;
            continue;
        } else {
            break;
        }
    }

    ast_parse_asm_input(pc, token_index, node);
}

/*
AsmExpression : token(Asm) option(token(Volatile)) token(LParen) token(String) option(AsmOutput) token(RParen)
*/
static AstNode *ast_parse_asm_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *asm_token = &pc->tokens->at(*token_index);

    if (asm_token->id != TokenIdKeywordAsm) {
        if (mandatory) {
            ast_invalid_token_error(pc, asm_token);
        } else {
            return nullptr;
        }
    }

    AstNode *node = ast_create_node(pc, NodeTypeAsmExpr, asm_token);

    *token_index += 1;
    Token *lparen_tok = &pc->tokens->at(*token_index);

    if (lparen_tok->id == TokenIdKeywordVolatile) {
        node->data.asm_expr.is_volatile = true;

        *token_index += 1;
        lparen_tok = &pc->tokens->at(*token_index);
    }

    ast_expect_token(pc, lparen_tok, TokenIdLParen);
    *token_index += 1;

    Token *template_tok = &pc->tokens->at(*token_index);
    ast_expect_token(pc, template_tok, TokenIdStringLiteral);
    *token_index += 1;

    parse_string_literal(pc, template_tok, &node->data.asm_expr.asm_template, nullptr,
            &node->data.asm_expr.offset_map);
    parse_asm_template(pc, node);

    ast_parse_asm_output(pc, token_index, node);

    Token *rparen_tok = &pc->tokens->at(*token_index);
    ast_expect_token(pc, rparen_tok, TokenIdRParen);
    *token_index += 1;

    return node;
}

/*
NonBlockExpression : ReturnExpression | AssignmentExpression | AsmExpression
*/
static AstNode *ast_parse_non_block_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);

    AstNode *return_expr = ast_parse_return_expr(pc, token_index, false);
    if (return_expr)
        return return_expr;

    AstNode *ass_expr = ast_parse_ass_expr(pc, token_index, false);
    if (ass_expr)
        return ass_expr;

    AstNode *asm_expr = ast_parse_asm_expr(pc, token_index, false);
    if (asm_expr)
        return asm_expr;

    if (mandatory)
        ast_invalid_token_error(pc, token);

    return nullptr;
}

/*
Expression : BlockExpression | NonBlockExpression
*/
static AstNode *ast_parse_expression(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);

    AstNode *block_expr = ast_parse_block_expr(pc, token_index, false);
    if (block_expr)
        return block_expr;

    AstNode *non_block_expr = ast_parse_non_block_expr(pc, token_index, false);
    if (non_block_expr)
        return non_block_expr;

    if (mandatory)
        ast_invalid_token_error(pc, token);

    return nullptr;
}

/*
Label: token(Symbol) token(Colon)
*/
static AstNode *ast_parse_label(ParseContext *pc, int *token_index, bool mandatory) {
    Token *symbol_token = &pc->tokens->at(*token_index);
    if (symbol_token->id != TokenIdSymbol) {
        if (mandatory) {
            ast_invalid_token_error(pc, symbol_token);
        } else {
            return nullptr;
        }
    }

    Token *colon_token = &pc->tokens->at(*token_index + 1);
    if (colon_token->id != TokenIdColon) {
        if (mandatory) {
            ast_invalid_token_error(pc, colon_token);
        } else {
            return nullptr;
        }
    }

    *token_index += 2;

    AstNode *node = ast_create_node(pc, NodeTypeLabel, symbol_token);
    ast_buf_from_token(pc, symbol_token, &node->data.label.name);
    return node;
}

/*
Block : token(LBrace) list(option(Statement), token(Semicolon)) token(RBrace)
Statement : Label | VariableDeclaration token(Semicolon) | NonBlockExpression token(Semicolon) | BlockExpression
*/
static AstNode *ast_parse_block(ParseContext *pc, int *token_index, bool mandatory) {
    Token *last_token = &pc->tokens->at(*token_index);

    if (last_token->id != TokenIdLBrace) {
        if (mandatory) {
            ast_invalid_token_error(pc, last_token);
        } else {
            return nullptr;
        }
    }
    *token_index += 1;

    AstNode *node = ast_create_node(pc, NodeTypeBlock, last_token);

    // {}   -> {void}
    // {;}  -> {void;void}
    // {2}  -> {2}
    // {2;} -> {2;void}
    // {;2} -> {void;2}
    for (;;) {
        AstNode *statement_node = ast_parse_label(pc, token_index, false);
        bool semicolon_expected;
        if (statement_node) {
            semicolon_expected = false;
        } else {
            statement_node = ast_parse_variable_declaration_expr(pc, token_index, false);
            if (statement_node) {
                semicolon_expected = true;
            } else {
                statement_node = ast_parse_block_expr(pc, token_index, false);
                semicolon_expected = !statement_node;
                if (!statement_node) {
                    statement_node = ast_parse_non_block_expr(pc, token_index, false);
                    if (!statement_node) {
                        statement_node = ast_create_node(pc, NodeTypeVoid, last_token);
                    }
                }
            }
        }
        node->data.block.statements.append(statement_node);

        last_token = &pc->tokens->at(*token_index);
        if (last_token->id == TokenIdRBrace) {
            *token_index += 1;
            return node;
        } else if (!semicolon_expected) {
            continue;
        } else if (last_token->id == TokenIdSemicolon) {
            *token_index += 1;
        } else {
            ast_invalid_token_error(pc, last_token);
        }
    }
    zig_unreachable();
}

/*
FnProto : many(Directive) option(FnVisibleMod) token(Fn) token(Symbol) ParamDeclList option(token(Arrow) Type)
*/
static AstNode *ast_parse_fn_proto(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);

    FnProtoVisibMod visib_mod;

    if (token->id == TokenIdKeywordPub) {
        visib_mod = FnProtoVisibModPub;
        *token_index += 1;

        Token *fn_token = &pc->tokens->at(*token_index);
        *token_index += 1;
        ast_expect_token(pc, fn_token, TokenIdKeywordFn);
    } else if (token->id == TokenIdKeywordExport) {
        visib_mod = FnProtoVisibModExport;
        *token_index += 1;

        Token *fn_token = &pc->tokens->at(*token_index);
        *token_index += 1;
        ast_expect_token(pc, fn_token, TokenIdKeywordFn);
    } else if (token->id == TokenIdKeywordFn) {
        visib_mod = FnProtoVisibModPrivate;
        *token_index += 1;
    } else if (mandatory) {
        ast_invalid_token_error(pc, token);
    } else {
        return nullptr;
    }

    AstNode *node = ast_create_node(pc, NodeTypeFnProto, token);
    node->data.fn_proto.visib_mod = visib_mod;
    node->data.fn_proto.directives = pc->directive_list;
    pc->directive_list = nullptr;


    Token *fn_name = &pc->tokens->at(*token_index);
    *token_index += 1;
    ast_expect_token(pc, fn_name, TokenIdSymbol);

    ast_buf_from_token(pc, fn_name, &node->data.fn_proto.name);


    ast_parse_param_decl_list(pc, *token_index, token_index,
            &node->data.fn_proto.params, &node->data.fn_proto.is_var_args);

    Token *arrow = &pc->tokens->at(*token_index);
    if (arrow->id == TokenIdArrow) {
        *token_index += 1;
        node->data.fn_proto.return_type = ast_parse_type(pc, *token_index, token_index);
    } else {
        node->data.fn_proto.return_type = ast_create_void_type_node(pc, arrow);
    }

    return node;
}

/*
FnDef : FnProto Block
*/
static AstNode *ast_parse_fn_def(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *fn_proto = ast_parse_fn_proto(pc, token_index, mandatory);
    if (!fn_proto)
        return nullptr;
    AstNode *node = ast_create_node_with_node(pc, NodeTypeFnDef, fn_proto);

    node->data.fn_def.fn_proto = fn_proto;
    node->data.fn_def.body = ast_parse_block(pc, token_index, true);

    return node;
}

/*
FnDecl : FnProto token(Semicolon)
*/
static AstNode *ast_parse_fn_decl(ParseContext *pc, int token_index, int *new_token_index) {
    AstNode *fn_proto = ast_parse_fn_proto(pc, &token_index, true);
    AstNode *node = ast_create_node_with_node(pc, NodeTypeFnDecl, fn_proto);

    node->data.fn_decl.fn_proto = fn_proto;

    Token *semicolon = &pc->tokens->at(token_index);
    token_index += 1;
    ast_expect_token(pc, semicolon, TokenIdSemicolon);

    *new_token_index = token_index;
    return node;
}

/*
Directive : token(NumberSign) token(Symbol) token(LParen) token(String) token(RParen)
*/
/*
ExternBlock : many(Directive) token(Extern) token(LBrace) many(FnProtoDecl) token(RBrace)
*/
static AstNode *ast_parse_extern_block(ParseContext *pc, int *token_index, bool mandatory) {
    Token *extern_kw = &pc->tokens->at(*token_index);
    if (extern_kw->id != TokenIdKeywordExtern) {
        if (mandatory)
            ast_invalid_token_error(pc, extern_kw);
        else
            return nullptr;
    }
    *token_index += 1;

    AstNode *node = ast_create_node(pc, NodeTypeExternBlock, extern_kw);

    node->data.extern_block.directives = pc->directive_list;
    pc->directive_list = nullptr;

    Token *l_brace = &pc->tokens->at(*token_index);
    *token_index += 1;
    ast_expect_token(pc, l_brace, TokenIdLBrace);

    for (;;) {
        Token *directive_token = &pc->tokens->at(*token_index);
        assert(!pc->directive_list);
        pc->directive_list = allocate<ZigList<AstNode*>>(1);
        ast_parse_directives(pc, token_index, pc->directive_list);

        Token *token = &pc->tokens->at(*token_index);
        if (token->id == TokenIdRBrace) {
            if (pc->directive_list->length > 0) {
                ast_error(pc, directive_token, "invalid directive");
            }
            pc->directive_list = nullptr;

            *token_index += 1;
            return node;
        } else {
            AstNode *child = ast_parse_fn_decl(pc, *token_index, token_index);
            node->data.extern_block.fn_decls.append(child);
        }
    }


    zig_unreachable();
}

/*
RootExportDecl : many(Directive) token(Export) token(Symbol) token(String) token(Semicolon)
*/
static AstNode *ast_parse_root_export_decl(ParseContext *pc, int *token_index, bool mandatory) {
    assert(mandatory == false);

    Token *export_kw = &pc->tokens->at(*token_index);
    if (export_kw->id != TokenIdKeywordExport)
        return nullptr;

    Token *export_type = &pc->tokens->at(*token_index + 1);
    if (export_type->id != TokenIdSymbol)
        return nullptr;

    *token_index += 2;

    AstNode *node = ast_create_node(pc, NodeTypeRootExportDecl, export_kw);
    node->data.root_export_decl.directives = pc->directive_list;
    pc->directive_list = nullptr;

    ast_buf_from_token(pc, export_type, &node->data.root_export_decl.type);

    Token *export_name = &pc->tokens->at(*token_index);
    *token_index += 1;
    ast_expect_token(pc, export_name, TokenIdStringLiteral);

    parse_string_literal(pc, export_name, &node->data.root_export_decl.name, nullptr, nullptr);

    Token *semicolon = &pc->tokens->at(*token_index);
    *token_index += 1;
    ast_expect_token(pc, semicolon, TokenIdSemicolon);

    return node;
}

/*
Use : many(Directive) token(Use) token(String) token(Semicolon)
*/
static AstNode *ast_parse_use(ParseContext *pc, int *token_index) {
    Token *use_kw = &pc->tokens->at(*token_index);
    if (use_kw->id != TokenIdKeywordUse)
        return nullptr;
    *token_index += 1;

    Token *use_name = &pc->tokens->at(*token_index);
    *token_index += 1;
    ast_expect_token(pc, use_name, TokenIdStringLiteral);

    Token *semicolon = &pc->tokens->at(*token_index);
    *token_index += 1;
    ast_expect_token(pc, semicolon, TokenIdSemicolon);

    AstNode *node = ast_create_node(pc, NodeTypeUse, use_kw);

    parse_string_literal(pc, use_name, &node->data.use.path, nullptr, nullptr);

    node->data.use.directives = pc->directive_list;
    pc->directive_list = nullptr;

    return node;
}

/*
StructDecl : many(Directive) token(Struct) token(Symbol) token(LBrace) many(StructField) token(RBrace)
StructField : token(Symbol) token(Colon) Type token(Comma)
*/
static AstNode *ast_parse_struct_decl(ParseContext *pc, int *token_index) {
    Token *struct_kw = &pc->tokens->at(*token_index);
    if (struct_kw->id != TokenIdKeywordStruct)
        return nullptr;
    *token_index += 1;

    Token *struct_name = &pc->tokens->at(*token_index);
    *token_index += 1;
    ast_expect_token(pc, struct_name, TokenIdSymbol);

    AstNode *node = ast_create_node(pc, NodeTypeStructDecl, struct_kw);
    ast_buf_from_token(pc, struct_name, &node->data.struct_decl.name);

    ast_eat_token(pc, token_index, TokenIdLBrace);

    for (;;) {
        Token *token = &pc->tokens->at(*token_index);

        if (token->id == TokenIdRBrace) {
            *token_index += 1;
            break;
        } else if (token->id == TokenIdSymbol) {
            AstNode *field_node = ast_create_node(pc, NodeTypeStructField, token);
            *token_index += 1;

            ast_buf_from_token(pc, token, &field_node->data.struct_field.name);

            ast_eat_token(pc, token_index, TokenIdColon);

            field_node->data.struct_field.type = ast_parse_type(pc, *token_index, token_index);

            ast_eat_token(pc, token_index, TokenIdComma);

            node->data.struct_decl.fields.append(field_node);
        } else {
            ast_invalid_token_error(pc, token);
        }
    }


    node->data.struct_decl.directives = pc->directive_list;
    pc->directive_list = nullptr;

    return node;
}

/*
TopLevelDecl : FnDef | ExternBlock | RootExportDecl | Use | StructDecl
*/
static void ast_parse_top_level_decls(ParseContext *pc, int *token_index, ZigList<AstNode *> *top_level_decls) {
    for (;;) {
        Token *directive_token = &pc->tokens->at(*token_index);
        assert(!pc->directive_list);
        pc->directive_list = allocate<ZigList<AstNode*>>(1);
        ast_parse_directives(pc, token_index, pc->directive_list);

        AstNode *root_export_decl_node = ast_parse_root_export_decl(pc, token_index, false);
        if (root_export_decl_node) {
            top_level_decls->append(root_export_decl_node);
            continue;
        }

        AstNode *fn_def_node = ast_parse_fn_def(pc, token_index, false);
        if (fn_def_node) {
            top_level_decls->append(fn_def_node);
            continue;
        }

        AstNode *extern_node = ast_parse_extern_block(pc, token_index, false);
        if (extern_node) {
            top_level_decls->append(extern_node);
            continue;
        }

        AstNode *use_node = ast_parse_use(pc, token_index);
        if (use_node) {
            top_level_decls->append(use_node);
            continue;
        }

        AstNode *struct_node = ast_parse_struct_decl(pc, token_index);
        if (struct_node) {
            top_level_decls->append(struct_node);
            continue;
        }

        if (pc->directive_list->length > 0) {
            ast_error(pc, directive_token, "invalid directive");
        }
        pc->directive_list = nullptr;

        return;
    }
    zig_unreachable();
}

/*
Root : many(TopLevelDecl) token(EOF)
 */
static AstNode *ast_parse_root(ParseContext *pc, int *token_index) {
    AstNode *node = ast_create_node(pc, NodeTypeRoot, &pc->tokens->at(*token_index));

    ast_parse_top_level_decls(pc, token_index, &node->data.root.top_level_decls);

    if (*token_index != pc->tokens->length - 1) {
        ast_invalid_token_error(pc, &pc->tokens->at(*token_index));
    }

    return node;
}

AstNode *ast_parse(Buf *buf, ZigList<Token> *tokens, ImportTableEntry *owner, ErrColor err_color) {
    ParseContext pc = {0};
    pc.err_color = err_color;
    pc.owner = owner;
    pc.buf = buf;
    pc.tokens = tokens;
    int token_index = 0;
    pc.root = ast_parse_root(&pc, &token_index);
    return pc.root;
}

const char *num_lit_str(NumLit num_lit) {
    switch (num_lit) {
        case NumLitF32:
            return "f32";
        case NumLitF64:
            return "f64";
        case NumLitF128:
            return "f128";
        case NumLitI8:
            return "i8";
        case NumLitI16:
            return "i16";
        case NumLitI32:
            return "i32";
        case NumLitI64:
            return "i64";
        case NumLitU8:
            return "u8";
        case NumLitU16:
            return "u16";
        case NumLitU32:
            return "u32";
        case NumLitU64:
            return "u64";
        case NumLitCount:
            zig_unreachable();
    }
    zig_unreachable();
}

bool is_num_lit_signed(NumLit num_lit) {
    switch (num_lit) {
        case NumLitI8:
        case NumLitI16:
        case NumLitI32:
        case NumLitI64:
            return true;

        case NumLitF32:
        case NumLitF64:
        case NumLitF128:
        case NumLitU8:
        case NumLitU16:
        case NumLitU32:
        case NumLitU64:
            return false;
        case NumLitCount:
            zig_unreachable();
    }
    zig_unreachable();
}

bool is_num_lit_unsigned(NumLit num_lit) {
    switch (num_lit) {
        case NumLitF32:
        case NumLitF64:
        case NumLitF128:
        case NumLitI8:
        case NumLitI16:
        case NumLitI32:
        case NumLitI64:
            return false;
        case NumLitU8:
        case NumLitU16:
        case NumLitU32:
        case NumLitU64:
            return true;
        case NumLitCount:
            zig_unreachable();
    }
    zig_unreachable();
}

bool is_num_lit_float(NumLit num_lit) {
    switch (num_lit) {
        case NumLitF32:
        case NumLitF64:
        case NumLitF128:
            return true;
        case NumLitI8:
        case NumLitI16:
        case NumLitI32:
        case NumLitI64:
        case NumLitU8:
        case NumLitU16:
        case NumLitU32:
        case NumLitU64:
            return false;
        case NumLitCount:
            zig_unreachable();
    }
    zig_unreachable();
}

uint64_t num_lit_bit_count(NumLit num_lit) {
    switch (num_lit) {
        case NumLitI8:
        case NumLitU8:
            return 8;
        case NumLitI16:
        case NumLitU16:
            return 16;
        case NumLitI32:
        case NumLitU32:
        case NumLitF32:
            return 32;
        case NumLitI64:
        case NumLitU64:
        case NumLitF64:
            return 64;
        case NumLitF128:
            return 128;
        case NumLitCount:
            zig_unreachable();
    }
    zig_unreachable();
}
