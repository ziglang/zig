/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "analyze.hpp"
#include "ast_render.hpp"
#include "os.hpp"

#include <stdio.h>

static const char *bin_op_str(BinOpType bin_op) {
    switch (bin_op) {
        case BinOpTypeInvalid:                return "(invalid)";
        case BinOpTypeBoolOr:                 return "or";
        case BinOpTypeBoolAnd:                return "and";
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
        case BinOpTypeAssignBitShiftRight:    return ">>=";
        case BinOpTypeAssignBitAnd:           return "&=";
        case BinOpTypeAssignBitXor:           return "^=";
        case BinOpTypeAssignBitOr:            return "|=";
        case BinOpTypeUnwrapOptional:         return "orelse";
        case BinOpTypeArrayCat:               return "++";
        case BinOpTypeArrayMult:              return "**";
        case BinOpTypeErrorUnion:             return "!";
        case BinOpTypeMergeErrorSets:         return "||";
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
        case PrefixOpOptional: return "?";
        case PrefixOpAddrOf: return "&";
    }
    zig_unreachable();
}

static const char *visib_mod_string(VisibMod mod) {
    switch (mod) {
        case VisibModPub: return "pub ";
        case VisibModPrivate: return "";
    }
    zig_unreachable();
}

static const char *return_string(ReturnKind kind) {
    switch (kind) {
        case ReturnKindUnconditional: return "return";
        case ReturnKindError: return "try";
    }
    zig_unreachable();
}

static const char *defer_string(ReturnKind kind) {
    switch (kind) {
        case ReturnKindUnconditional: return "defer";
        case ReturnKindError: return "errdefer";
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

static const char *export_string(bool is_export) {
    return is_export ? "export " : "";
}

//static const char *calling_convention_string(CallingConvention cc) {
//    switch (cc) {
//        case CallingConventionUnspecified: return "";
//        case CallingConventionC: return "extern ";
//        case CallingConventionCold: return "coldcc ";
//        case CallingConventionNaked: return "nakedcc ";
//        case CallingConventionStdcall: return "stdcallcc ";
//    }
//    zig_unreachable();
//}

static const char *inline_string(bool is_inline) {
    return is_inline ? "inline" : "";
}

static const char *const_or_var_string(bool is_const) {
    return is_const ? "const" : "var";
}

static const char *thread_local_string(Token *tok) {
    return (tok == nullptr) ? "" : "threadlocal ";
}

static const char *token_to_ptr_len_str(Token *tok) {
    assert(tok != nullptr);
    switch (tok->id) {
        case TokenIdStar:
        case TokenIdStarStar:
            return "*";
        case TokenIdLBracket:
            return "[*]";
        case TokenIdSymbol:
            return "[*c]";
        default:
            zig_unreachable();
    }
}

static const char *node_type_str(NodeType node_type) {
    switch (node_type) {
        case NodeTypeFnDef:
            return "FnDef";
        case NodeTypeFnProto:
            return "FnProto";
        case NodeTypeParamDecl:
            return "ParamDecl";
        case NodeTypeBlock:
            return "Block";
        case NodeTypeGroupedExpr:
            return "Parens";
        case NodeTypeBinOpExpr:
            return "BinOpExpr";
        case NodeTypeCatchExpr:
            return "CatchExpr";
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
        case NodeTypeTestDecl:
            return "TestDecl";
        case NodeTypeIntLiteral:
            return "IntLiteral";
        case NodeTypeFloatLiteral:
            return "FloatLiteral";
        case NodeTypeStringLiteral:
            return "StringLiteral";
        case NodeTypeCharLiteral:
            return "CharLiteral";
        case NodeTypeSymbol:
            return "Symbol";
        case NodeTypePrefixOpExpr:
            return "PrefixOpExpr";
        case NodeTypeUsingNamespace:
            return "UsingNamespace";
        case NodeTypeBoolLiteral:
            return "BoolLiteral";
        case NodeTypeNullLiteral:
            return "NullLiteral";
        case NodeTypeUndefinedLiteral:
            return "UndefinedLiteral";
        case NodeTypeIfBoolExpr:
            return "IfBoolExpr";
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
        case NodeTypeCompTime:
            return "CompTime";
        case NodeTypeNoSuspend:
            return "NoSuspend";
        case NodeTypeBreak:
            return "Break";
        case NodeTypeContinue:
            return "Continue";
        case NodeTypeUnreachable:
            return "Unreachable";
        case NodeTypeAsmExpr:
            return "AsmExpr";
        case NodeTypeFieldAccessExpr:
            return "FieldAccessExpr";
        case NodeTypePtrDeref:
            return "PtrDerefExpr";
        case NodeTypeUnwrapOptional:
            return "UnwrapOptional";
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
        case NodeTypeInferredArrayType:
            return "InferredArrayType";
        case NodeTypeErrorType:
            return "ErrorType";
        case NodeTypeIfErrorExpr:
            return "IfErrorExpr";
        case NodeTypeIfOptional:
            return "IfOptional";
        case NodeTypeErrorSetDecl:
            return "ErrorSetDecl";
        case NodeTypeResume:
            return "Resume";
        case NodeTypeAwaitExpr:
            return "AwaitExpr";
        case NodeTypeSuspend:
            return "Suspend";
        case NodeTypePointerType:
            return "PointerType";
        case NodeTypeAnyFrameType:
            return "AnyFrameType";
        case NodeTypeEnumLiteral:
            return "EnumLiteral";
        case NodeTypeErrorSetField:
            return "ErrorSetField";
        case NodeTypeAnyTypeField:
            return "AnyTypeField";
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
    if (c == 0) {
        return false;
    }
    static const uint8_t printables[] =
        " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.~`!@#$%^&*()_-+=\\{}[];'\"?/<>,:";
    for (size_t i = 0; i < array_length(printables); i += 1) {
        if (c == printables[i]) return true;
    }
    return false;
}

static void string_literal_escape(Buf *source, Buf *dest) {
    buf_resize(dest, 0);
    for (size_t i = 0; i < buf_len(source); i += 1) {
        uint8_t c = *((uint8_t*)buf_ptr(source) + i);
        if (c == '\'') {
            buf_append_str(dest, "\\'");
        } else if (c == '"') {
            buf_append_str(dest, "\\\"");
        } else if (c == '\\') {
            buf_append_str(dest, "\\\\");
        } else if (c == '\n') {
            buf_append_str(dest, "\\n");
        } else if (c == '\r') {
            buf_append_str(dest, "\\r");
        } else if (c == '\t') {
            buf_append_str(dest, "\\t");
        } else if (is_printable(c)) {
            buf_append_char(dest, c);
        } else {
            buf_appendf(dest, "\\x%02x", (int)c);
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

static bool statement_terminates_without_semicolon(AstNode *node) {
    switch (node->type) {
        case NodeTypeIfBoolExpr:
            if (node->data.if_bool_expr.else_node)
                return statement_terminates_without_semicolon(node->data.if_bool_expr.else_node);
            return node->data.if_bool_expr.then_block->type == NodeTypeBlock;
        case NodeTypeIfErrorExpr:
            if (node->data.if_err_expr.else_node)
                return statement_terminates_without_semicolon(node->data.if_err_expr.else_node);
            return node->data.if_err_expr.then_node->type == NodeTypeBlock;
        case NodeTypeIfOptional:
            if (node->data.test_expr.else_node)
                return statement_terminates_without_semicolon(node->data.test_expr.else_node);
            return node->data.test_expr.then_node->type == NodeTypeBlock;
        case NodeTypeWhileExpr:
            return node->data.while_expr.body->type == NodeTypeBlock;
        case NodeTypeForExpr:
            return node->data.for_expr.body->type == NodeTypeBlock;
        case NodeTypeCompTime:
            return node->data.comptime_expr.expr->type == NodeTypeBlock;
        case NodeTypeDefer:
            return node->data.defer.expr->type == NodeTypeBlock;
        case NodeTypeSuspend:
            return node->data.suspend.block != nullptr && node->data.suspend.block->type == NodeTypeBlock;
        case NodeTypeSwitchExpr:
        case NodeTypeBlock:
            return true;
        default:
            return false;
    }
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
        case NodeTypeStructValueField:
            zig_unreachable();
        case NodeTypeFnProto:
            {
                const char *pub_str = visib_mod_string(node->data.fn_proto.visib_mod);
                const char *extern_str = extern_string(node->data.fn_proto.is_extern);
                const char *export_str = export_string(node->data.fn_proto.is_export);
                const char *inline_str = inline_string(node->data.fn_proto.is_noinline);
                fprintf(ar->f, "%s%s%s%sfn ", pub_str, inline_str, export_str, extern_str);
                if (node->data.fn_proto.name != nullptr) {
                    print_symbol(ar, node->data.fn_proto.name);
                }
                fprintf(ar->f, "(");
                size_t arg_count = node->data.fn_proto.params.length;
                for (size_t arg_i = 0; arg_i < arg_count; arg_i += 1) {
                    AstNode *param_decl = node->data.fn_proto.params.at(arg_i);
                    assert(param_decl->type == NodeTypeParamDecl);
                    if (param_decl->data.param_decl.name != nullptr) {
                        const char *noalias_str = param_decl->data.param_decl.is_noalias ? "noalias " : "";
                        const char *inline_str = param_decl->data.param_decl.is_comptime ? "comptime " : "";
                        fprintf(ar->f, "%s%s", noalias_str, inline_str);
                        print_symbol(ar, param_decl->data.param_decl.name);
                        fprintf(ar->f, ": ");
                    }
                    if (param_decl->data.param_decl.is_var_args) {
                        fprintf(ar->f, "...");
                    } else if (param_decl->data.param_decl.anytype_token != nullptr) {
                        fprintf(ar->f, "anytype");
                    } else {
                        render_node_grouped(ar, param_decl->data.param_decl.type);
                    }

                    if (arg_i + 1 < arg_count) {
                        fprintf(ar->f, ", ");
                    }
                }
                if (node->data.fn_proto.is_var_args) {
                    fprintf(ar->f, ", ...");
                }
                fprintf(ar->f, ")");
                if (node->data.fn_proto.align_expr) {
                    fprintf(ar->f, " align(");
                    render_node_grouped(ar, node->data.fn_proto.align_expr);
                    fprintf(ar->f, ")");
                }
                if (node->data.fn_proto.section_expr) {
                    fprintf(ar->f, " section(");
                    render_node_grouped(ar, node->data.fn_proto.section_expr);
                    fprintf(ar->f, ")");
                }
                if (node->data.fn_proto.callconv_expr) {
                    fprintf(ar->f, " callconv(");
                    render_node_grouped(ar, node->data.fn_proto.callconv_expr);
                    fprintf(ar->f, ")");
                }

                if (node->data.fn_proto.return_anytype_token != nullptr) {
                    fprintf(ar->f, "anytype");
                } else {
                    AstNode *return_type_node = node->data.fn_proto.return_type;
                    assert(return_type_node != nullptr);
                    fprintf(ar->f, " ");
                    if (node->data.fn_proto.auto_err_set) {
                        fprintf(ar->f, "!");
                    }
                    render_node_grouped(ar, return_type_node);
                }
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
            if (node->data.block.name != nullptr) {
                fprintf(ar->f, "%s: ", buf_ptr(node->data.block.name));
            }
            if (node->data.block.statements.length == 0) {
                fprintf(ar->f, "{}");
                break;
            }
            fprintf(ar->f, "{\n");
            ar->indent += ar->indent_size;
            for (size_t i = 0; i < node->data.block.statements.length; i += 1) {
                AstNode *statement = node->data.block.statements.at(i);
                print_indent(ar);
                render_node_grouped(ar, statement);

                if (!statement_terminates_without_semicolon(statement))
                    fprintf(ar->f, ";");

                fprintf(ar->f, "\n");
            }
            ar->indent -= ar->indent_size;
            print_indent(ar);
            fprintf(ar->f, "}");
            break;
        case NodeTypeGroupedExpr:
            fprintf(ar->f, "(");
            render_node_ungrouped(ar, node->data.grouped_expr);
            fprintf(ar->f, ")");
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
        case NodeTypeBreak:
            {
                fprintf(ar->f, "break");
                if (node->data.break_expr.name != nullptr) {
                    fprintf(ar->f, " :%s", buf_ptr(node->data.break_expr.name));
                }
                if (node->data.break_expr.expr) {
                    fprintf(ar->f, " ");
                    render_node_grouped(ar, node->data.break_expr.expr);
                }
                break;
            }
        case NodeTypeDefer:
            {
                const char *defer_str = defer_string(node->data.defer.kind);
                fprintf(ar->f, "%s ", defer_str);
                render_node_grouped(ar, node->data.defer.expr);
                break;
            }
        case NodeTypeVariableDeclaration:
            {
                const char *pub_str = visib_mod_string(node->data.variable_declaration.visib_mod);
                const char *extern_str = extern_string(node->data.variable_declaration.is_extern);
                const char *thread_local_str = thread_local_string(node->data.variable_declaration.threadlocal_tok);
                const char *const_or_var = const_or_var_string(node->data.variable_declaration.is_const);
                fprintf(ar->f, "%s%s%s%s ", pub_str, extern_str, thread_local_str, const_or_var);
                print_symbol(ar, node->data.variable_declaration.symbol);

                if (node->data.variable_declaration.type) {
                    fprintf(ar->f, ": ");
                    render_node_grouped(ar, node->data.variable_declaration.type);
                }
                if (node->data.variable_declaration.align_expr) {
                    fprintf(ar->f, "align(");
                    render_node_grouped(ar, node->data.variable_declaration.align_expr);
                    fprintf(ar->f, ") ");
                }
                if (node->data.variable_declaration.section_expr) {
                    fprintf(ar->f, "section(");
                    render_node_grouped(ar, node->data.variable_declaration.section_expr);
                    fprintf(ar->f, ") ");
                }
                if (node->data.variable_declaration.expr) {
                    fprintf(ar->f, " = ");
                    render_node_grouped(ar, node->data.variable_declaration.expr);
                }
                break;
            }
        case NodeTypeBinOpExpr:
            if (!grouped) fprintf(ar->f, "(");
            render_node_ungrouped(ar, node->data.bin_op_expr.op1);
            fprintf(ar->f, " %s ", bin_op_str(node->data.bin_op_expr.bin_op));
            render_node_ungrouped(ar, node->data.bin_op_expr.op2);
            if (!grouped) fprintf(ar->f, ")");
            break;
        case NodeTypeFloatLiteral:
            {
                Buf rendered_buf = BUF_INIT;
                buf_resize(&rendered_buf, 0);
                bigfloat_append_buf(&rendered_buf, node->data.float_literal.bigfloat);
                fprintf(ar->f, "%s", buf_ptr(&rendered_buf));
            }
            break;
        case NodeTypeIntLiteral:
            {
                Buf rendered_buf = BUF_INIT;
                buf_resize(&rendered_buf, 0);
                bigint_append_buf(&rendered_buf, node->data.int_literal.bigint, 10);
                fprintf(ar->f, "%s", buf_ptr(&rendered_buf));
            }
            break;
        case NodeTypeStringLiteral:
            {
                Buf tmp_buf = BUF_INIT;
                string_literal_escape(node->data.string_literal.buf, &tmp_buf);
                fprintf(ar->f, "\"%s\"", buf_ptr(&tmp_buf));
            }
            break;
        case NodeTypeCharLiteral:
            {
                uint8_t c = node->data.char_literal.value;
                if (c == '\'') {
                    fprintf(ar->f, "'\\''");
                } else if (c == '\"') {
                    fprintf(ar->f, "'\\\"'");
                } else if (c == '\\') {
                    fprintf(ar->f, "'\\\\'");
                } else if (c == '\n') {
                    fprintf(ar->f, "'\\n'");
                } else if (c == '\r') {
                    fprintf(ar->f, "'\\r'");
                } else if (c == '\t') {
                    fprintf(ar->f, "'\\t'");
                } else if (is_printable(c)) {
                    fprintf(ar->f, "'%c'", c);
                } else {
                    fprintf(ar->f, "'\\x%02x'", (int)c);
                }
                break;
            }
        case NodeTypeSymbol:
            print_symbol(ar, node->data.symbol_expr.symbol);
            break;
        case NodeTypePrefixOpExpr:
            {
                if (!grouped) fprintf(ar->f, "(");
                PrefixOp op = node->data.prefix_op_expr.prefix_op;
                fprintf(ar->f, "%s", prefix_op_str(op));

                AstNode *child_node = node->data.prefix_op_expr.primary_expr;
                bool new_grouped = child_node->type == NodeTypePrefixOpExpr || child_node->type == NodeTypePointerType;
                render_node_extra(ar, child_node, new_grouped);
                if (!grouped) fprintf(ar->f, ")");
                break;
            }
        case NodeTypePointerType:
            {
                if (!grouped) fprintf(ar->f, "(");
                const char *ptr_len_str = token_to_ptr_len_str(node->data.pointer_type.star_token);
                fprintf(ar->f, "%s", ptr_len_str);
                if (node->data.pointer_type.align_expr != nullptr) {
                    fprintf(ar->f, "align(");
                    render_node_grouped(ar, node->data.pointer_type.align_expr);
                    if (node->data.pointer_type.bit_offset_start != nullptr) {
                        assert(node->data.pointer_type.host_int_bytes != nullptr);

                        Buf offset_start_buf = BUF_INIT;
                        buf_resize(&offset_start_buf, 0);
                        bigint_append_buf(&offset_start_buf, node->data.pointer_type.bit_offset_start, 10);

                        Buf offset_end_buf = BUF_INIT;
                        buf_resize(&offset_end_buf, 0);
                        bigint_append_buf(&offset_end_buf, node->data.pointer_type.host_int_bytes, 10);

                        fprintf(ar->f, ":%s:%s ", buf_ptr(&offset_start_buf), buf_ptr(&offset_end_buf));
                    }
                    fprintf(ar->f, ") ");
                }
                if (node->data.pointer_type.is_const) {
                    fprintf(ar->f, "const ");
                }
                if (node->data.pointer_type.is_volatile) {
                    fprintf(ar->f, "volatile ");
                }

                render_node_ungrouped(ar, node->data.pointer_type.op_expr);
                if (!grouped) fprintf(ar->f, ")");
                break;
            }
        case NodeTypeFnCallExpr:
            {
                switch (node->data.fn_call_expr.modifier) {
                    case CallModifierNone:
                        break;
                    case CallModifierNoSuspend:
                        fprintf(ar->f, "nosuspend ");
                        break;
                    case CallModifierAsync:
                        fprintf(ar->f, "async ");
                        break;
                    case CallModifierNeverTail:
                        fprintf(ar->f, "notail ");
                        break;
                    case CallModifierNeverInline:
                        fprintf(ar->f, "noinline ");
                        break;
                    case CallModifierAlwaysTail:
                        fprintf(ar->f, "tail ");
                        break;
                    case CallModifierAlwaysInline:
                        fprintf(ar->f, "inline ");
                        break;
                    case CallModifierCompileTime:
                        fprintf(ar->f, "comptime ");
                        break;
                    case CallModifierBuiltin:
                        fprintf(ar->f, "@");
                        break;
                }
                AstNode *fn_ref_node = node->data.fn_call_expr.fn_ref_expr;
                bool grouped = (fn_ref_node->type != NodeTypePrefixOpExpr && fn_ref_node->type != NodeTypePointerType);
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
                if (lhs->type == NodeTypeErrorType) {
                    fprintf(ar->f, "error");
                } else {
                    render_node_ungrouped(ar, lhs);
                }
                fprintf(ar->f, ".");
                print_symbol(ar, rhs);
                break;
            }
        case NodeTypePtrDeref:
            {
                AstNode *lhs = node->data.ptr_deref_expr.target;
                render_node_ungrouped(ar, lhs);
                fprintf(ar->f, ".*");
                break;
            }
        case NodeTypeUnwrapOptional:
            {
                AstNode *lhs = node->data.unwrap_optional.expr;
                render_node_ungrouped(ar, lhs);
                fprintf(ar->f, ".?");
                break;
            }
        case NodeTypeUndefinedLiteral:
            fprintf(ar->f, "undefined");
            break;
        case NodeTypeContainerDecl:
            {
                if (!node->data.container_decl.is_root) {
                    const char *layout_str = layout_string(node->data.container_decl.layout);
                    const char *container_str = container_string(node->data.container_decl.kind);
                    fprintf(ar->f, "%s%s", layout_str, container_str);
                    if (node->data.container_decl.auto_enum) {
                        fprintf(ar->f, "(enum");
                    }
                    if (node->data.container_decl.init_arg_expr != nullptr) {
                        fprintf(ar->f, "(");
                        render_node_grouped(ar, node->data.container_decl.init_arg_expr);
                        fprintf(ar->f, ")");
                    }
                    if (node->data.container_decl.auto_enum) {
                        fprintf(ar->f, ")");
                    }

                    fprintf(ar->f, " {\n");
                    ar->indent += ar->indent_size;
                }
                for (size_t field_i = 0; field_i < node->data.container_decl.fields.length; field_i += 1) {
                    AstNode *field_node = node->data.container_decl.fields.at(field_i);
                    assert(field_node->type == NodeTypeStructField);
                    print_indent(ar);
                    print_symbol(ar, field_node->data.struct_field.name);
                    if (field_node->data.struct_field.type != nullptr) {
                        fprintf(ar->f, ": ");
                        render_node_grouped(ar, field_node->data.struct_field.type);
                    }
                    if (field_node->data.struct_field.value != nullptr) {
                        fprintf(ar->f, " = ");
                        render_node_grouped(ar, field_node->data.struct_field.value);
                    }
                    fprintf(ar->f, ",\n");
                }

                for (size_t decl_i = 0; decl_i < node->data.container_decl.decls.length; decl_i += 1) {
                    AstNode *decls_node = node->data.container_decl.decls.at(decl_i);
                    render_node_grouped(ar, decls_node);

                    if (decls_node->type == NodeTypeUsingNamespace ||
                        decls_node->type == NodeTypeVariableDeclaration ||
                        decls_node->type == NodeTypeFnProto)
                    {
                        fprintf(ar->f, ";");
                    }
                    fprintf(ar->f, "\n");
                }

                if (!node->data.container_decl.is_root) {
                    ar->indent -= ar->indent_size;
                    print_indent(ar);
                    fprintf(ar->f, "}");
                }
                break;
            }
        case NodeTypeContainerInitExpr:
            if (node->data.container_init_expr.type != nullptr) {
                render_node_ungrouped(ar, node->data.container_init_expr.type);
            }
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
        case NodeTypeInferredArrayType:
            {
                fprintf(ar->f, "[_]");
                render_node_ungrouped(ar, node->data.inferred_array_type.child_type);
                break;
            }
        case NodeTypeAnyFrameType: {
            fprintf(ar->f, "anyframe");
            if (node->data.anyframe_type.payload_type != nullptr) {
                fprintf(ar->f, "->");
                render_node_grouped(ar, node->data.anyframe_type.payload_type);
            }
            break;
        }
        case NodeTypeErrorType:
            fprintf(ar->f, "anyerror");
            break;
        case NodeTypeAsmExpr:
            {
                AstNodeAsmExpr *asm_expr = &node->data.asm_expr;
                const char *volatile_str = (asm_expr->volatile_token != nullptr) ? " volatile" : "";
                fprintf(ar->f, "asm%s (", volatile_str);
                render_node_ungrouped(ar, asm_expr->asm_template);
                fprintf(ar->f, ")");
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
                if (node->data.while_expr.name != nullptr) {
                    fprintf(ar->f, "%s: ", buf_ptr(node->data.while_expr.name));
                }
                const char *inline_str = node->data.while_expr.is_inline ? "inline " : "";
                fprintf(ar->f, "%swhile (", inline_str);
                render_node_grouped(ar, node->data.while_expr.condition);
                fprintf(ar->f, ") ");
                if (node->data.while_expr.var_symbol) {
                    fprintf(ar->f, "|%s| ", buf_ptr(node->data.while_expr.var_symbol));
                }
                if (node->data.while_expr.continue_expr) {
                    fprintf(ar->f, ": (");
                    render_node_grouped(ar, node->data.while_expr.continue_expr);
                    fprintf(ar->f, ") ");
                }
                render_node_grouped(ar, node->data.while_expr.body);
                if (node->data.while_expr.else_node) {
                    fprintf(ar->f, " else ");
                    if (node->data.while_expr.err_symbol) {
                        fprintf(ar->f, "|%s| ", buf_ptr(node->data.while_expr.err_symbol));
                    }
                    render_node_grouped(ar, node->data.while_expr.else_node);
                }
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
        case NodeTypeIfErrorExpr:
            {
                fprintf(ar->f, "if (");
                render_node_grouped(ar, node->data.if_err_expr.target_node);
                fprintf(ar->f, ") ");
                if (node->data.if_err_expr.var_symbol) {
                    const char *ptr_str = node->data.if_err_expr.var_is_ptr ? "*" : "";
                    const char *var_name = buf_ptr(node->data.if_err_expr.var_symbol);
                    fprintf(ar->f, "|%s%s| ", ptr_str, var_name);
                }
                render_node_grouped(ar, node->data.if_err_expr.then_node);
                if (node->data.if_err_expr.else_node) {
                    fprintf(ar->f, " else ");
                    if (node->data.if_err_expr.err_symbol) {
                        fprintf(ar->f, "|%s| ", buf_ptr(node->data.if_err_expr.err_symbol));
                    }
                    render_node_grouped(ar, node->data.if_err_expr.else_node);
                }
                break;
            }
        case NodeTypeIfOptional:
            {
                fprintf(ar->f, "if (");
                render_node_grouped(ar, node->data.test_expr.target_node);
                fprintf(ar->f, ") ");
                if (node->data.test_expr.var_symbol) {
                    const char *ptr_str = node->data.test_expr.var_is_ptr ? "*" : "";
                    const char *var_name = buf_ptr(node->data.test_expr.var_symbol);
                    fprintf(ar->f, "|%s%s| ", ptr_str, var_name);
                }
                render_node_grouped(ar, node->data.test_expr.then_node);
                if (node->data.test_expr.else_node) {
                    fprintf(ar->f, " else ");
                    render_node_grouped(ar, node->data.test_expr.else_node);
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
        case NodeTypeCompTime:
            {
                fprintf(ar->f, "comptime ");
                render_node_grouped(ar, node->data.comptime_expr.expr);
                break;
            }
        case NodeTypeNoSuspend:
            {
                fprintf(ar->f, "nosuspend ");
                render_node_grouped(ar, node->data.nosuspend_expr.expr);
                break;
            }
        case NodeTypeForExpr:
            {
                if (node->data.for_expr.name != nullptr) {
                    fprintf(ar->f, "%s: ", buf_ptr(node->data.for_expr.name));
                }
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
                if (node->data.for_expr.else_node) {
                    fprintf(ar->f, " else");
                    render_node_grouped(ar, node->data.for_expr.else_node);
                }
                break;
            }
        case NodeTypeContinue:
            {
                fprintf(ar->f, "continue");
                if (node->data.continue_expr.name != nullptr) {
                    fprintf(ar->f, " :%s", buf_ptr(node->data.continue_expr.name));
                }
                break;
            }
        case NodeTypeUnreachable:
            {
                fprintf(ar->f, "unreachable");
                break;
            }
        case NodeTypeSliceExpr:
            {
                render_node_ungrouped(ar, node->data.slice_expr.array_ref_expr);
                fprintf(ar->f, "[");
                render_node_grouped(ar, node->data.slice_expr.start);
                fprintf(ar->f, "..");
                if (node->data.slice_expr.end)
                    render_node_grouped(ar, node->data.slice_expr.end);
                fprintf(ar->f, "]");
                break;
            }
        case NodeTypeCatchExpr:
            {
                render_node_ungrouped(ar, node->data.unwrap_err_expr.op1);
                fprintf(ar->f, " catch ");
                if (node->data.unwrap_err_expr.symbol) {
                    Buf *var_name = node->data.unwrap_err_expr.symbol->data.symbol_expr.symbol;
                    fprintf(ar->f, "|%s| ", buf_ptr(var_name));
                }
                render_node_ungrouped(ar, node->data.unwrap_err_expr.op2);
                break;
            }
        case NodeTypeErrorSetDecl:
            {
                fprintf(ar->f, "error {\n");
                ar->indent += ar->indent_size;

                for (size_t i = 0; i < node->data.err_set_decl.decls.length; i += 1) {
                    AstNode *field_node = node->data.err_set_decl.decls.at(i);
                    switch (field_node->type) {
                        case NodeTypeSymbol:
                            print_indent(ar);
                            print_symbol(ar, field_node->data.symbol_expr.symbol);
                            fprintf(ar->f, ",\n");
                            break;
                        case NodeTypeErrorSetField:
                            print_indent(ar);
                            print_symbol(ar, field_node->data.err_set_field.field_name->data.symbol_expr.symbol);
                            fprintf(ar->f, ",\n");
                            break;
                        default:
                            zig_unreachable();
                    }
                }

                ar->indent -= ar->indent_size;
                print_indent(ar);
                fprintf(ar->f, "}");
                break;
            }
        case NodeTypeResume:
            {
                fprintf(ar->f, "resume ");
                render_node_grouped(ar, node->data.resume_expr.expr);
                break;
            }
        case NodeTypeAwaitExpr:
            {
                fprintf(ar->f, "await ");
                render_node_grouped(ar, node->data.await_expr.expr);
                break;
            }
        case NodeTypeSuspend:
            {
                if (node->data.suspend.block != nullptr) {
                    fprintf(ar->f, "suspend ");
                    render_node_grouped(ar, node->data.suspend.block);
                } else {
                    fprintf(ar->f, "suspend\n");
                }
                break;
            }
        case NodeTypeEnumLiteral:
            {
                fprintf(ar->f, ".%s", buf_ptr(&node->data.enum_literal.identifier->data.str_lit.str));
                break;
            }
        case NodeTypeAnyTypeField: {
            fprintf(ar->f, "anytype");
            break;
        }
        case NodeTypeParamDecl:
        case NodeTypeTestDecl:
        case NodeTypeStructField:
        case NodeTypeUsingNamespace:
        case NodeTypeErrorSetField:
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

void AstNode::src() {
    fprintf(stderr, "%s:%" ZIG_PRI_usize ":%" ZIG_PRI_usize "\n",
            buf_ptr(this->owner->data.structure.root_struct->path),
            this->line + 1, this->column + 1);
}
