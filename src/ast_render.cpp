/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "ast_render.hpp"
#include "analyze.hpp"

#include <stdio.h>

static const char *bin_op_str(BinOpType bin_op) {
    switch (bin_op) {
        case BinOpTypeInvalid:                return "(invalid)";
        case BinOpTypeBoolOr:                 return "||";
        case BinOpTypeBoolAnd:                return "&&";
        case BinOpTypeCmpEq:                  return "==";
        case BinOpTypeCmpNotEq:               return "!=";
        case BinOpTypeCmpLessThan:            return "<";
        case BinOpTypeCmpGreaterThan:         return ">";
        case BinOpTypeCmpLessOrEq:            return "<=";
        case BinOpTypeCmpGreaterOrEq:         return ">=";
        case BinOpTypeBinOr:                  return "|";
        case BinOpTypeBinXor:                 return "^";
        case BinOpTypeBinAnd:                 return "&";
        case BinOpTypeBitShiftLeft:           return "<<";
        case BinOpTypeBitShiftLeftWrap:       return "<<%";
        case BinOpTypeBitShiftRight:          return ">>";
        case BinOpTypeAdd:                    return "+";
        case BinOpTypeAddWrap:                return "+%";
        case BinOpTypeSub:                    return "-";
        case BinOpTypeSubWrap:                return "-%";
        case BinOpTypeMult:                   return "*";
        case BinOpTypeMultWrap:               return "*%";
        case BinOpTypeDiv:                    return "/";
        case BinOpTypeMod:                    return "%";
        case BinOpTypeAssign:                 return "=";
        case BinOpTypeAssignTimes:            return "*=";
        case BinOpTypeAssignTimesWrap:        return "*%=";
        case BinOpTypeAssignDiv:              return "/=";
        case BinOpTypeAssignMod:              return "%=";
        case BinOpTypeAssignPlus:             return "+=";
        case BinOpTypeAssignPlusWrap:         return "+%=";
        case BinOpTypeAssignMinus:            return "-=";
        case BinOpTypeAssignMinusWrap:        return "-%=";
        case BinOpTypeAssignBitShiftLeft:     return "<<=";
        case BinOpTypeAssignBitShiftLeftWrap: return "<<%=";
        case BinOpTypeAssignBitShiftRight:    return ">>=";
        case BinOpTypeAssignBitAnd:           return "&=";
        case BinOpTypeAssignBitXor:           return "^=";
        case BinOpTypeAssignBitOr:            return "|=";
        case BinOpTypeAssignBoolAnd:          return "&&=";
        case BinOpTypeAssignBoolOr:           return "||=";
        case BinOpTypeUnwrapMaybe:            return "??";
        case BinOpTypeArrayCat:               return "++";
        case BinOpTypeArrayMult:              return "**";
    }
    zig_unreachable();
}

static const char *prefix_op_str(PrefixOp prefix_op) {
    switch (prefix_op) {
        case PrefixOpInvalid: return "(invalid)";
        case PrefixOpNegation: return "-";
        case PrefixOpNegationWrap: return "-%";
        case PrefixOpBoolNot: return "!";
        case PrefixOpBinNot: return "~";
        case PrefixOpAddressOf: return "&";
        case PrefixOpConstAddressOf: return "&const ";
        case PrefixOpVolatileAddressOf: return "&volatile ";
        case PrefixOpConstVolatileAddressOf: return "&const volatile ";
        case PrefixOpDereference: return "*";
        case PrefixOpMaybe: return "?";
        case PrefixOpError: return "%";
        case PrefixOpUnwrapError: return "%%";
        case PrefixOpUnwrapMaybe: return "??";
    }
    zig_unreachable();
}

static const char *visib_mod_string(VisibMod mod) {
    switch (mod) {
        case VisibModPub: return "pub ";
        case VisibModPrivate: return "";
        case VisibModExport: return "export ";
    }
    zig_unreachable();
}

static const char *return_string(ReturnKind kind) {
    switch (kind) {
        case ReturnKindUnconditional: return "return";
        case ReturnKindError: return "%return";
        case ReturnKindMaybe: return "?return";
    }
    zig_unreachable();
}

static const char *defer_string(ReturnKind kind) {
    switch (kind) {
        case ReturnKindUnconditional: return "defer";
        case ReturnKindError: return "%defer";
        case ReturnKindMaybe: return "?defer";
    }
    zig_unreachable();
}

static const char *layout_string(ContainerLayout layout) {
    switch (layout) {
        case ContainerLayoutAuto: return "";
        case ContainerLayoutExtern: return "extern ";
        case ContainerLayoutPacked: return "packed ";
    }
    zig_unreachable();
}

static const char *extern_string(bool is_extern) {
    return is_extern ? "extern " : "";
}

static const char *inline_string(bool is_inline) {
    return is_inline ? "inline " : "";
}

static const char *const_or_var_string(bool is_const) {
    return is_const ? "const" : "var";
}

const char *container_string(ContainerKind kind) {
    switch (kind) {
        case ContainerKindEnum: return "enum";
        case ContainerKindStruct: return "struct";
        case ContainerKindUnion: return "union";
    }
    zig_unreachable();
}

static const char *node_type_str(NodeType node_type) {
    switch (node_type) {
        case NodeTypeRoot:
            return "Root";
        case NodeTypeFnDef:
            return "FnDef";
        case NodeTypeFnDecl:
            return "FnDecl";
        case NodeTypeFnProto:
            return "FnProto";
        case NodeTypeParamDecl:
            return "ParamDecl";
        case NodeTypeBlock:
            return "Block";
        case NodeTypeBinOpExpr:
            return "BinOpExpr";
        case NodeTypeUnwrapErrorExpr:
            return "UnwrapErrorExpr";
        case NodeTypeFnCallExpr:
            return "FnCallExpr";
        case NodeTypeArrayAccessExpr:
            return "ArrayAccessExpr";
        case NodeTypeSliceExpr:
            return "SliceExpr";
        case NodeTypeReturnExpr:
            return "ReturnExpr";
        case NodeTypeDefer:
            return "Defer";
        case NodeTypeVariableDeclaration:
            return "VariableDeclaration";
        case NodeTypeTypeDecl:
            return "TypeDecl";
        case NodeTypeErrorValueDecl:
            return "ErrorValueDecl";
        case NodeTypeTestDecl:
            return "TestDecl";
        case NodeTypeNumberLiteral:
            return "NumberLiteral";
        case NodeTypeStringLiteral:
            return "StringLiteral";
        case NodeTypeCharLiteral:
            return "CharLiteral";
        case NodeTypeSymbol:
            return "Symbol";
        case NodeTypePrefixOpExpr:
            return "PrefixOpExpr";
        case NodeTypeUse:
            return "Use";
        case NodeTypeBoolLiteral:
            return "BoolLiteral";
        case NodeTypeNullLiteral:
            return "NullLiteral";
        case NodeTypeUndefinedLiteral:
            return "UndefinedLiteral";
        case NodeTypeThisLiteral:
            return "ThisLiteral";
        case NodeTypeIfBoolExpr:
            return "IfBoolExpr";
        case NodeTypeIfVarExpr:
            return "IfVarExpr";
        case NodeTypeWhileExpr:
            return "WhileExpr";
        case NodeTypeForExpr:
            return "ForExpr";
        case NodeTypeSwitchExpr:
            return "SwitchExpr";
        case NodeTypeSwitchProng:
            return "SwitchProng";
        case NodeTypeSwitchRange:
            return "SwitchRange";
        case NodeTypeLabel:
            return "Label";
        case NodeTypeGoto:
            return "Goto";
        case NodeTypeCompTime:
            return "CompTime";
        case NodeTypeBreak:
            return "Break";
        case NodeTypeContinue:
            return "Continue";
        case NodeTypeAsmExpr:
            return "AsmExpr";
        case NodeTypeFieldAccessExpr:
            return "FieldAccessExpr";
        case NodeTypeContainerDecl:
            return "ContainerDecl";
        case NodeTypeStructField:
            return "StructField";
        case NodeTypeStructValueField:
            return "StructValueField";
        case NodeTypeContainerInitExpr:
            return "ContainerInitExpr";
        case NodeTypeArrayType:
            return "ArrayType";
        case NodeTypeErrorType:
            return "ErrorType";
        case NodeTypeTypeLiteral:
            return "TypeLiteral";
        case NodeTypeVarLiteral:
            return "VarLiteral";
        case NodeTypeTryExpr:
            return "TryExpr";
    }
    zig_unreachable();
}

struct AstPrint {
    int indent;
    FILE *f;
};

static void ast_print_visit(AstNode **node_ptr, void *context) {
    AstNode *node = *node_ptr;
    AstPrint *ap = (AstPrint *)context;

    for (int i = 0; i < ap->indent; i += 1) {
        fprintf(ap->f, " ");
    }

    fprintf(ap->f, "%s\n", node_type_str(node->type));

    AstPrint new_ap;
    new_ap.indent = ap->indent + 2;
    new_ap.f = ap->f;

    ast_visit_node_children(node, ast_print_visit, &new_ap);
}

void ast_print(FILE *f, AstNode *node, int indent) {
    AstPrint ap;
    ap.indent = indent;
    ap.f = f;
    ast_visit_node_children(node, ast_print_visit, &ap);
}


struct AstRender {
    int indent;
    int indent_size;
    FILE *f;
};

static void print_indent(AstRender *ar) {
    for (int i = 0; i < ar->indent; i += 1) {
        fprintf(ar->f, " ");
    }
}

static bool is_alpha_under(uint8_t c) {
    return (c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') || c == '_';
}

static bool is_digit(uint8_t c) {
    return (c >= '0' && c <= '9');
}

static bool is_printable(uint8_t c) {
    static const uint8_t printables[] =
        " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.~`!@#$%^&*()_-+=\\{}[];'\"?/<>,";
    for (size_t i = 0; i < array_length(printables); i += 1) {
        if (c == printables[i]) return true;
    }
    return false;
}

static void string_literal_escape(Buf *source, Buf *dest) {
    buf_resize(dest, 0);
    for (size_t i = 0; i < buf_len(source); i += 1) {
        uint8_t c = *((uint8_t*)buf_ptr(source) + i);
        if (is_printable(c)) {
            buf_append_char(dest, c);
        } else if (c == '\'') {
            buf_append_str(dest, "\\'");
        } else if (c == '"') {
            buf_append_str(dest, "\\\"");
        } else if (c == '\\') {
            buf_append_str(dest, "\\\\");
        } else if (c == '\a') {
            buf_append_str(dest, "\\a");
        } else if (c == '\b') {
            buf_append_str(dest, "\\b");
        } else if (c == '\f') {
            buf_append_str(dest, "\\f");
        } else if (c == '\n') {
            buf_append_str(dest, "\\n");
        } else if (c == '\r') {
            buf_append_str(dest, "\\r");
        } else if (c == '\t') {
            buf_append_str(dest, "\\t");
        } else if (c == '\v') {
            buf_append_str(dest, "\\v");
        } else {
            buf_appendf(dest, "\\x%x", (int)c);
        }
    }
}

static bool is_valid_bare_symbol(Buf *symbol) {
    if (buf_len(symbol) == 0) {
        return false;
    }
    uint8_t first_char = *buf_ptr(symbol);
    if (!is_alpha_under(first_char)) {
        return false;
    }
    for (size_t i = 1; i < buf_len(symbol); i += 1) {
        uint8_t c = *((uint8_t*)buf_ptr(symbol) + i);
        if (!is_alpha_under(c) && !is_digit(c)) {
            return false;
        }
    }
    return true;
}

static void print_symbol(AstRender *ar, Buf *symbol) {
    if (is_zig_keyword(symbol)) {
        fprintf(ar->f, "@\"%s\"", buf_ptr(symbol));
        return;
    }
    if (is_valid_bare_symbol(symbol)) {
        fprintf(ar->f, "%s", buf_ptr(symbol));
        return;
    }
    Buf escaped = BUF_INIT;
    string_literal_escape(symbol, &escaped);
    fprintf(ar->f, "@\"%s\"", buf_ptr(&escaped));
}

static void render_node_extra(AstRender *ar, AstNode *node, bool grouped);

static void render_node_grouped(AstRender *ar, AstNode *node) {
    return render_node_extra(ar, node, true);
}

static void render_node_ungrouped(AstRender *ar, AstNode *node) {
    return render_node_extra(ar, node, false);
}

static void render_node_extra(AstRender *ar, AstNode *node, bool grouped) {
    switch (node->type) {
        case NodeTypeSwitchProng:
        case NodeTypeSwitchRange:
        case NodeTypeLabel:
        case NodeTypeStructValueField:
            zig_unreachable();
        case NodeTypeRoot:
            for (size_t i = 0; i < node->data.root.top_level_decls.length; i += 1) {
                AstNode *child = node->data.root.top_level_decls.at(i);
                print_indent(ar);
                render_node_grouped(ar, child);

                if (child->type == NodeTypeUse ||
                    child->type == NodeTypeVariableDeclaration ||
                    child->type == NodeTypeTypeDecl ||
                    child->type == NodeTypeErrorValueDecl ||
                    child->type == NodeTypeFnProto)
                {
                    fprintf(ar->f, ";");
                }
                fprintf(ar->f, "\n");
            }
            break;
        case NodeTypeFnProto:
            {
                const char *pub_str = visib_mod_string(node->data.fn_proto.visib_mod);
                const char *extern_str = extern_string(node->data.fn_proto.is_extern);
                const char *inline_str = inline_string(node->data.fn_proto.is_inline);
                fprintf(ar->f, "%s%s%sfn ", pub_str, inline_str, extern_str);
                print_symbol(ar, node->data.fn_proto.name);
                fprintf(ar->f, "(");
                int arg_count = node->data.fn_proto.params.length;
                for (int arg_i = 0; arg_i < arg_count; arg_i += 1) {
                    AstNode *param_decl = node->data.fn_proto.params.at(arg_i);
                    assert(param_decl->type == NodeTypeParamDecl);
                    if (buf_len(param_decl->data.param_decl.name) > 0) {
                        const char *noalias_str = param_decl->data.param_decl.is_noalias ? "noalias " : "";
                        const char *inline_str = param_decl->data.param_decl.is_inline ? "inline " : "";
                        fprintf(ar->f, "%s%s", noalias_str, inline_str);
                        print_symbol(ar, param_decl->data.param_decl.name);
                        fprintf(ar->f, ": ");
                    }
                    if (param_decl->data.param_decl.is_var_args) {
                        fprintf(ar->f, "...");
                    } else {
                        render_node_grouped(ar, param_decl->data.param_decl.type);
                    }

                    if (arg_i + 1 < arg_count) {
                        fprintf(ar->f, ", ");
                    }
                }
                fprintf(ar->f, ")");

                AstNode *return_type_node = node->data.fn_proto.return_type;
                fprintf(ar->f, " -> ");
                render_node_grouped(ar, return_type_node);
                break;
            }
        case NodeTypeFnDef:
            {
                render_node_grouped(ar, node->data.fn_def.fn_proto);
                fprintf(ar->f, " ");
                render_node_grouped(ar, node->data.fn_def.body);
                break;
            }
        case NodeTypeBlock:
            if (node->data.block.statements.length == 0) {
                fprintf(ar->f, "{}");
                break;
            }
            fprintf(ar->f, "{\n");
            ar->indent += ar->indent_size;
            for (size_t i = 0; i < node->data.block.statements.length; i += 1) {
                AstNode *statement = node->data.block.statements.at(i);
                if (statement->type == NodeTypeLabel) {
                    ar->indent -= ar->indent_size;
                    print_indent(ar);
                    fprintf(ar->f, "%s:\n", buf_ptr(statement->data.label.name));
                    ar->indent += ar->indent_size;
                    continue;
                }
                print_indent(ar);
                render_node_grouped(ar, statement);
                if (i != node->data.block.statements.length - 1)
                    fprintf(ar->f, ";");
                fprintf(ar->f, "\n");
            }
            ar->indent -= ar->indent_size;
            print_indent(ar);
            fprintf(ar->f, "}");
            break;
        case NodeTypeReturnExpr:
            {
                const char *return_str = return_string(node->data.return_expr.kind);
                fprintf(ar->f, "%s", return_str);
                if (node->data.return_expr.expr) {
                    fprintf(ar->f, " ");
                    render_node_grouped(ar, node->data.return_expr.expr);
                }
                break;
            }
        case NodeTypeDefer:
            {
                const char *defer_str = defer_string(node->data.defer.kind);
                fprintf(ar->f, "%s ", defer_str);
                render_node_grouped(ar, node->data.return_expr.expr);
                break;
            }
        case NodeTypeVariableDeclaration:
            {
                const char *pub_str = visib_mod_string(node->data.variable_declaration.visib_mod);
                const char *extern_str = extern_string(node->data.variable_declaration.is_extern);
                const char *const_or_var = const_or_var_string(node->data.variable_declaration.is_const);
                fprintf(ar->f, "%s%s%s ", pub_str, extern_str, const_or_var);
                print_symbol(ar, node->data.variable_declaration.symbol);

                if (node->data.variable_declaration.type) {
                    fprintf(ar->f, ": ");
                    render_node_grouped(ar, node->data.variable_declaration.type);
                }
                if (node->data.variable_declaration.expr) {
                    fprintf(ar->f, " = ");
                    render_node_grouped(ar, node->data.variable_declaration.expr);
                }
                break;
            }
        case NodeTypeTypeDecl:
            {
                const char *pub_str = visib_mod_string(node->data.type_decl.visib_mod);
                const char *var_name = buf_ptr(node->data.type_decl.symbol);
                fprintf(ar->f, "%stype %s = ", pub_str, var_name);
                render_node_grouped(ar, node->data.type_decl.child_type);
                break;
            }
        case NodeTypeBinOpExpr:
            if (!grouped) fprintf(ar->f, "(");
            render_node_ungrouped(ar, node->data.bin_op_expr.op1);
            fprintf(ar->f, " %s ", bin_op_str(node->data.bin_op_expr.bin_op));
            render_node_ungrouped(ar, node->data.bin_op_expr.op2);
            if (!grouped) fprintf(ar->f, ")");
            break;
        case NodeTypeNumberLiteral:
            switch (node->data.number_literal.bignum->kind) {
                case BigNumKindInt:
                    {
                        const char *negative_str = node->data.number_literal.bignum->is_negative ? "-" : "";
                        fprintf(ar->f, "%s%llu", negative_str, node->data.number_literal.bignum->data.x_uint);
                    }
                    break;
                case BigNumKindFloat:
                    fprintf(ar->f, "%f", node->data.number_literal.bignum->data.x_float);
                    break;
            }
            break;
        case NodeTypeStringLiteral:
            {
                if (node->data.string_literal.c) {
                    fprintf(ar->f, "c");
                }
                Buf tmp_buf = BUF_INIT;
                string_literal_escape(node->data.string_literal.buf, &tmp_buf);
                fprintf(ar->f, "\"%s\"", buf_ptr(&tmp_buf));
            }
            break;
        case NodeTypeCharLiteral:
            {
                uint8_t c = node->data.char_literal.value;
                if (is_printable(c)) {
                    fprintf(ar->f, "'%c'", c);
                } else {
                    fprintf(ar->f, "'\\x%x'", (int)c);
                }
                break;
            }
        case NodeTypeSymbol:
            print_symbol(ar, node->data.symbol_expr.symbol);
            break;
        case NodeTypePrefixOpExpr:
            {
                PrefixOp op = node->data.prefix_op_expr.prefix_op;
                fprintf(ar->f, "%s", prefix_op_str(op));

                render_node_ungrouped(ar, node->data.prefix_op_expr.primary_expr);
                break;
            }
        case NodeTypeFnCallExpr:
            {
                if (node->data.fn_call_expr.is_builtin) {
                    fprintf(ar->f, "@");
                }
                AstNode *fn_ref_node = node->data.fn_call_expr.fn_ref_expr;
                bool grouped = (fn_ref_node->type != NodeTypeBinOpExpr);
                render_node_extra(ar, fn_ref_node, grouped);
                fprintf(ar->f, "(");
                for (size_t i = 0; i < node->data.fn_call_expr.params.length; i += 1) {
                    AstNode *param = node->data.fn_call_expr.params.at(i);
                    if (i != 0) {
                        fprintf(ar->f, ", ");
                    }
                    render_node_grouped(ar, param);
                }
                fprintf(ar->f, ")");
                break;
            }
        case NodeTypeArrayAccessExpr:
            render_node_ungrouped(ar, node->data.array_access_expr.array_ref_expr);
            fprintf(ar->f, "[");
            render_node_grouped(ar, node->data.array_access_expr.subscript);
            fprintf(ar->f, "]");
            break;
        case NodeTypeFieldAccessExpr:
            {
                AstNode *lhs = node->data.field_access_expr.struct_expr;
                Buf *rhs = node->data.field_access_expr.field_name;
                render_node_ungrouped(ar, lhs);
                fprintf(ar->f, ".");
                print_symbol(ar, rhs);
                break;
            }
        case NodeTypeUndefinedLiteral:
            fprintf(ar->f, "undefined");
            break;
        case NodeTypeContainerDecl:
            {
                const char *container_str = container_string(node->data.container_decl.kind);
                fprintf(ar->f, "%s {\n", container_str);
                ar->indent += ar->indent_size;
                for (size_t field_i = 0; field_i < node->data.container_decl.fields.length; field_i += 1) {
                    AstNode *field_node = node->data.container_decl.fields.at(field_i);
                    assert(field_node->type == NodeTypeStructField);
                    print_indent(ar);
                    print_symbol(ar, field_node->data.struct_field.name);
                    fprintf(ar->f, ": ");
                    render_node_grouped(ar, field_node->data.struct_field.type);
                    fprintf(ar->f, ",\n");
                }

                ar->indent -= ar->indent_size;
                print_indent(ar);
                fprintf(ar->f, "}");
                break;
            }
        case NodeTypeContainerInitExpr:
            render_node_ungrouped(ar, node->data.container_init_expr.type);
            if (node->data.container_init_expr.kind == ContainerInitKindStruct) {
                fprintf(ar->f, "{\n");
                ar->indent += ar->indent_size;
            } else {
                fprintf(ar->f, "{");
            }
            for (size_t i = 0; i < node->data.container_init_expr.entries.length; i += 1) {
                AstNode *entry = node->data.container_init_expr.entries.at(i);
                if (entry->type == NodeTypeStructValueField) {
                    Buf *name = entry->data.struct_val_field.name;
                    AstNode *expr = entry->data.struct_val_field.expr;
                    print_indent(ar);
                    fprintf(ar->f, ".%s = ", buf_ptr(name));
                    render_node_grouped(ar, expr);
                    fprintf(ar->f, ",\n");
                } else {
                    if (i != 0)
                        fprintf(ar->f, ", ");
                    render_node_grouped(ar, entry);
                }
            }
            if (node->data.container_init_expr.kind == ContainerInitKindStruct) {
                ar->indent -= ar->indent_size;
            }
            print_indent(ar);
            fprintf(ar->f, "}");
            break;
        case NodeTypeArrayType:
            {
                fprintf(ar->f, "[");
                if (node->data.array_type.size) {
                    render_node_grouped(ar, node->data.array_type.size);
                }
                fprintf(ar->f, "]");
                if (node->data.array_type.is_const) {
                    fprintf(ar->f, "const ");
                }
                render_node_ungrouped(ar, node->data.array_type.child_type);
                break;
            }
        case NodeTypeErrorType:
            fprintf(ar->f, "error");
            break;
        case NodeTypeTypeLiteral:
            fprintf(ar->f, "type");
            break;
        case NodeTypeVarLiteral:
            fprintf(ar->f, "var");
            break;
        case NodeTypeAsmExpr:
            {
                AstNodeAsmExpr *asm_expr = &node->data.asm_expr;
                const char *volatile_str = asm_expr->is_volatile ? " volatile" : "";
                fprintf(ar->f, "asm%s (\"%s\"\n", volatile_str, buf_ptr(asm_expr->asm_template));
                print_indent(ar);
                fprintf(ar->f, ": ");
                for (size_t i = 0; i < asm_expr->output_list.length; i += 1) {
                    AsmOutput *asm_output = asm_expr->output_list.at(i);

                    if (i != 0) {
                        fprintf(ar->f, ",\n");
                        print_indent(ar);
                    }

                    fprintf(ar->f, "[%s] \"%s\" (",
                            buf_ptr(asm_output->asm_symbolic_name),
                            buf_ptr(asm_output->constraint));
                    if (asm_output->return_type) {
                        fprintf(ar->f, "-> ");
                        render_node_grouped(ar, asm_output->return_type);
                    } else {
                        fprintf(ar->f, "%s", buf_ptr(asm_output->variable_name));
                    }
                    fprintf(ar->f, ")");
                }
                fprintf(ar->f, "\n");
                print_indent(ar);
                fprintf(ar->f, ": ");
                for (size_t i = 0; i < asm_expr->input_list.length; i += 1) {
                    AsmInput *asm_input = asm_expr->input_list.at(i);

                    if (i != 0) {
                        fprintf(ar->f, ",\n");
                        print_indent(ar);
                    }

                    fprintf(ar->f, "[%s] \"%s\" (",
                            buf_ptr(asm_input->asm_symbolic_name),
                            buf_ptr(asm_input->constraint));
                    render_node_grouped(ar, asm_input->expr);
                    fprintf(ar->f, ")");
                }
                fprintf(ar->f, "\n");
                print_indent(ar);
                fprintf(ar->f, ": ");
                for (size_t i = 0; i < asm_expr->clobber_list.length; i += 1) {
                    Buf *reg_name = asm_expr->clobber_list.at(i);
                    if (i != 0) fprintf(ar->f, ", ");
                    fprintf(ar->f, "\"%s\"", buf_ptr(reg_name));
                }
                fprintf(ar->f, ")");
                break;
            }
        case NodeTypeWhileExpr:
            {
                const char *inline_str = node->data.while_expr.is_inline ? "inline " : "";
                fprintf(ar->f, "%swhile (", inline_str);
                render_node_grouped(ar, node->data.while_expr.condition);
                if (node->data.while_expr.continue_expr) {
                    fprintf(ar->f, "; ");
                    render_node_grouped(ar, node->data.while_expr.continue_expr);
                }
                fprintf(ar->f, ") ");
                render_node_grouped(ar, node->data.while_expr.body);
                break;
            }
        case NodeTypeThisLiteral:
            {
                fprintf(ar->f, "this");
                break;
            }
        case NodeTypeBoolLiteral:
            {
                const char *bool_str = node->data.bool_literal.value ? "true" : "false";
                fprintf(ar->f, "%s", bool_str);
                break;
            }
        case NodeTypeIfBoolExpr:
            {
                fprintf(ar->f, "if (");
                render_node_grouped(ar, node->data.if_bool_expr.condition);
                fprintf(ar->f, ") ");
                render_node_grouped(ar, node->data.if_bool_expr.then_block);
                if (node->data.if_bool_expr.else_node) {
                    fprintf(ar->f, " else ");
                    render_node_grouped(ar, node->data.if_bool_expr.else_node);
                }
                break;
            }
        case NodeTypeNullLiteral:
            {
                fprintf(ar->f, "null");
                break;
            }
        case NodeTypeIfVarExpr:
            {
                AstNodeVariableDeclaration *var_decl = &node->data.if_var_expr.var_decl;
                const char *var_str = var_decl->is_const ? "const" : "var";
                const char *var_name = buf_ptr(var_decl->symbol);
                const char *ptr_str = node->data.if_var_expr.var_is_ptr ? "*" : "";
                fprintf(ar->f, "if (%s %s%s", var_str, ptr_str, var_name);
                if (var_decl->type) {
                    fprintf(ar->f, ": ");
                    render_node_ungrouped(ar, var_decl->type);
                }
                fprintf(ar->f, " ?= ");
                render_node_grouped(ar, var_decl->expr);
                fprintf(ar->f, ") ");
                render_node_grouped(ar, node->data.if_var_expr.then_block);
                if (node->data.if_var_expr.else_node) {
                    fprintf(ar->f, " else ");
                    render_node_grouped(ar, node->data.if_var_expr.else_node);
                }
                break;
            }
        case NodeTypeTryExpr:
            {
                fprintf(ar->f, "try (");
                if (node->data.try_expr.var_symbol) {
                    const char *var_str = node->data.try_expr.var_is_const ? "const" : "var";
                    const char *var_name = buf_ptr(node->data.try_expr.var_symbol);
                    const char *ptr_str = node->data.try_expr.var_is_ptr ? "*" : "";
                    fprintf(ar->f, "%s %s%s = ", var_str, ptr_str, var_name);
                }
                render_node_grouped(ar, node->data.try_expr.target_node);
                fprintf(ar->f, ") ");
                render_node_grouped(ar, node->data.try_expr.then_node);
                if (node->data.try_expr.else_node) {
                    fprintf(ar->f, " else ");
                    if (node->data.try_expr.err_symbol) {
                        fprintf(ar->f, "|%s| ", buf_ptr(node->data.try_expr.err_symbol));
                    }
                    render_node_grouped(ar, node->data.try_expr.else_node);
                }
                break;
            }
        case NodeTypeSwitchExpr:
            {
                AstNodeSwitchExpr *switch_expr = &node->data.switch_expr;
                fprintf(ar->f, "switch (");
                render_node_grouped(ar, switch_expr->expr);
                fprintf(ar->f, ") {\n");
                ar->indent += ar->indent_size;

                for (size_t prong_i = 0; prong_i < switch_expr->prongs.length; prong_i += 1) {
                    AstNode *prong_node = switch_expr->prongs.at(prong_i);
                    AstNodeSwitchProng *switch_prong = &prong_node->data.switch_prong;
                    print_indent(ar);
                    for (size_t item_i = 0; item_i < switch_prong->items.length; item_i += 1) {
                        AstNode *item_node = switch_prong->items.at(item_i);
                        if (item_i != 0)
                            fprintf(ar->f, ", ");
                        if (item_node->type == NodeTypeSwitchRange) {
                            AstNode *start_node = item_node->data.switch_range.start;
                            AstNode *end_node = item_node->data.switch_range.end;
                            render_node_grouped(ar, start_node);
                            fprintf(ar->f, "...");
                            render_node_grouped(ar, end_node);
                        } else {
                            render_node_grouped(ar, item_node);
                        }
                    }
                    const char *else_str = (switch_prong->items.length == 0) ? "else" : "";
                    fprintf(ar->f, "%s => ", else_str);
                    if (switch_prong->var_symbol) {
                        const char *star_str = switch_prong->var_is_ptr ? "*" : "";
                        Buf *var_name = switch_prong->var_symbol->data.symbol_expr.symbol;
                        fprintf(ar->f, "|%s%s| ", star_str, buf_ptr(var_name));
                    }
                    render_node_grouped(ar, switch_prong->expr);
                    fprintf(ar->f, ",\n");
                }

                ar->indent -= ar->indent_size;
                print_indent(ar);
                fprintf(ar->f, "}");
                break;
            }
        case NodeTypeGoto:
            {
                fprintf(ar->f, "goto %s", buf_ptr(node->data.goto_expr.name));
                break;
            }
        case NodeTypeCompTime:
            {
                fprintf(ar->f, "comptime ");
                render_node_grouped(ar, node->data.comptime_expr.expr);
                break;
            }
        case NodeTypeForExpr:
            {
                const char *inline_str = node->data.for_expr.is_inline ? "inline " : "";
                fprintf(ar->f, "%sfor (", inline_str);
                render_node_grouped(ar, node->data.for_expr.array_expr);
                fprintf(ar->f, ") ");
                if (node->data.for_expr.elem_node) {
                    fprintf(ar->f, "|");
                    if (node->data.for_expr.elem_is_ptr)
                        fprintf(ar->f, "*");
                    render_node_grouped(ar, node->data.for_expr.elem_node);
                    if (node->data.for_expr.index_node) {
                        fprintf(ar->f, ", ");
                        render_node_grouped(ar, node->data.for_expr.index_node);
                    }
                    fprintf(ar->f, "| ");
                }
                render_node_grouped(ar, node->data.for_expr.body);
                break;
            }
        case NodeTypeBreak:
            {
                fprintf(ar->f, "break");
                break;
            }
        case NodeTypeContinue:
            {
                fprintf(ar->f, "continue");
                break;
            }
        case NodeTypeSliceExpr:
            {
                render_node_ungrouped(ar, node->data.slice_expr.array_ref_expr);
                fprintf(ar->f, "[");
                render_node_grouped(ar, node->data.slice_expr.start);
                fprintf(ar->f, "...");
                if (node->data.slice_expr.end)
                    render_node_grouped(ar, node->data.slice_expr.end);
                fprintf(ar->f, "]");
                if (node->data.slice_expr.is_const)
                    fprintf(ar->f, "const");
                break;
            }
        case NodeTypeUnwrapErrorExpr:
            {
                render_node_ungrouped(ar, node->data.unwrap_err_expr.op1);
                fprintf(ar->f, " %%%% ");
                if (node->data.unwrap_err_expr.symbol) {
                    Buf *var_name = node->data.unwrap_err_expr.symbol->data.symbol_expr.symbol;
                    fprintf(ar->f, "|%s| ", buf_ptr(var_name));
                }
                render_node_ungrouped(ar, node->data.unwrap_err_expr.op2);
                break;
            }
        case NodeTypeFnDecl:
        case NodeTypeParamDecl:
        case NodeTypeErrorValueDecl:
        case NodeTypeTestDecl:
        case NodeTypeStructField:
        case NodeTypeUse:
            zig_panic("TODO more ast rendering");
    }
}


void ast_render(FILE *f, AstNode *node, int indent_size) {
    AstRender ar = {0};
    ar.f = f;
    ar.indent_size = indent_size;
    ar.indent = 0;

    render_node_grouped(&ar, node);
}

static void ast_render_tld_fn(AstRender *ar, Buf *name, TldFn *tld_fn) {
    FnTableEntry *fn_entry = tld_fn->fn_entry;
    FnTypeId *fn_type_id = &fn_entry->type_entry->data.fn.fn_type_id;
    const char *visib_mod_str = visib_mod_string(tld_fn->base.visib_mod);
    const char *extern_str = extern_string(fn_type_id->is_extern);
    const char *coldcc_str = fn_type_id->is_cold ? "coldcc " : "";
    const char *nakedcc_str = fn_type_id->is_naked ? "nakedcc " : "";
    fprintf(ar->f, "%s%s%s%sfn %s(", visib_mod_str, extern_str, coldcc_str, nakedcc_str, buf_ptr(&fn_entry->symbol_name));
    for (size_t i = 0; i < fn_type_id->param_count; i += 1) {
        FnTypeParamInfo *param_info = &fn_type_id->param_info[i];
        if (i != 0) {
            fprintf(ar->f, ", ");
        }
        if (param_info->is_noalias) {
            fprintf(ar->f, "noalias ");
        }
        Buf *param_name = tld_fn->fn_entry->param_names ? tld_fn->fn_entry->param_names[i] : buf_sprintf("arg%zu", i);
        fprintf(ar->f, "%s: %s", buf_ptr(param_name), buf_ptr(&param_info->type->name));
    }
    if (fn_type_id->return_type->id == TypeTableEntryIdVoid) {
        fprintf(ar->f, ");\n");
    } else {
        fprintf(ar->f, ") -> %s;\n", buf_ptr(&fn_type_id->return_type->name));
    }
}

static void ast_render_tld_var(AstRender *ar, Buf *name, TldVar *tld_var) {
    VariableTableEntry *var = tld_var->var;
    const char *visib_mod_str = visib_mod_string(tld_var->base.visib_mod);
    const char *const_or_var = const_or_var_string(var->src_is_const);
    const char *extern_str = extern_string(var->linkage == VarLinkageExternal);
    fprintf(ar->f, "%s%s%s %s", visib_mod_str, extern_str, const_or_var, buf_ptr(name));

    if (var->value->type->id == TypeTableEntryIdNumLitFloat ||
        var->value->type->id == TypeTableEntryIdNumLitInt ||
        var->value->type->id == TypeTableEntryIdMetaType)
    {
        // skip type
    } else {
        fprintf(ar->f, ": %s", buf_ptr(&var->value->type->name));
    }

    if (var->value->special == ConstValSpecialRuntime) {
        fprintf(ar->f, ";\n");
        return;
    }

    fprintf(ar->f, " = ");

    if (var->value->special == ConstValSpecialStatic &&
        var->value->type->id == TypeTableEntryIdMetaType)
    {
        TypeTableEntry *type_entry = var->value->data.x_type;
        if (type_entry->id == TypeTableEntryIdStruct) {
            const char *layout_str = layout_string(type_entry->data.structure.layout);
            fprintf(ar->f, "%sstruct {\n", layout_str);
            if (type_entry->data.structure.complete) {
                for (size_t i = 0; i < type_entry->data.structure.src_field_count; i += 1) {
                    TypeStructField *field = &type_entry->data.structure.fields[i];
                    fprintf(ar->f, "    ");
                    print_symbol(ar, field->name);
                    fprintf(ar->f, ": %s,\n", buf_ptr(&field->type_entry->name));
                }
            }
            fprintf(ar->f, "}");
        } else if (type_entry->id == TypeTableEntryIdEnum) {
            const char *layout_str = layout_string(type_entry->data.enumeration.layout);
            fprintf(ar->f, "%senum {\n", layout_str);
            if (type_entry->data.enumeration.complete) {
                for (size_t i = 0; i < type_entry->data.enumeration.src_field_count; i += 1) {
                    TypeEnumField *field = &type_entry->data.enumeration.fields[i];
                    fprintf(ar->f, "    ");
                    print_symbol(ar, field->name);
                    if (field->type_entry->id == TypeTableEntryIdVoid) {
                        fprintf(ar->f, ",\n");
                    } else {
                        fprintf(ar->f, ": %s,\n", buf_ptr(&field->type_entry->name));
                    }
                }
            }
            fprintf(ar->f, "}");
        } else if (type_entry->id == TypeTableEntryIdUnion) {
            fprintf(ar->f, "union {");
            fprintf(ar->f, "TODO");
            fprintf(ar->f, "}");
        } else {
            fprintf(ar->f, "%s", buf_ptr(&type_entry->name));
        }
    } else {
        Buf buf = BUF_INIT;
        buf_resize(&buf, 0);
        render_const_value(&buf, var->value);
        fprintf(ar->f, "%s", buf_ptr(&buf));
    }

    fprintf(ar->f, ";\n");
}

static void ast_render_tld_typedef(AstRender *ar, Buf *name, TldTypeDef *tld_typedef) {
    TypeTableEntry *type_entry = tld_typedef->type_entry;
    TypeTableEntry *canon_type = get_underlying_type(type_entry);

    fprintf(ar->f, "pub type ");
    print_symbol(ar, name);
    fprintf(ar->f, " = %s;\n", buf_ptr(&canon_type->name));
}

void ast_render_decls(FILE *f, int indent_size, ImportTableEntry *import) {
    AstRender ar = {0};
    ar.f = f;
    ar.indent_size = indent_size;
    ar.indent = 0;

    auto it = import->decls_scope->decl_table.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        Tld *tld = entry->value;

        if (!buf_eql_buf(entry->key, tld->name)) {
            fprintf(ar.f, "pub const ");
            print_symbol(&ar, entry->key);
            fprintf(ar.f, " = %s;\n", buf_ptr(tld->name));
            continue;
        }

        switch (tld->id) {
            case TldIdVar:
                ast_render_tld_var(&ar, entry->key, (TldVar *)tld);
                break;
            case TldIdFn:
                ast_render_tld_fn(&ar, entry->key, (TldFn *)tld);
                break;
            case TldIdContainer:
                fprintf(stdout, "container\n");
                break;
            case TldIdTypeDef:
                ast_render_tld_typedef(&ar, entry->key, (TldTypeDef *)tld);
                break;
        }
    }
}


