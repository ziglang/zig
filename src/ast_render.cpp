#include "ast_render.hpp"

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
        case BinOpTypeUnwrapMaybe:         return "??";
        case BinOpTypeArrayCat:            return "++";
        case BinOpTypeArrayMult:           return "**";
    }
    zig_unreachable();
}

static const char *prefix_op_str(PrefixOp prefix_op) {
    switch (prefix_op) {
        case PrefixOpInvalid: return "(invalid)";
        case PrefixOpNegation: return "-";
        case PrefixOpBoolNot: return "!";
        case PrefixOpBinNot: return "~";
        case PrefixOpAddressOf: return "&";
        case PrefixOpConstAddressOf: return "&const ";
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

static const char *extern_string(bool is_extern) {
    return is_extern ? "extern " : "";
}

static const char *inline_string(bool is_inline) {
    return is_inline ? "inline " : "";
}

static const char *const_or_var_string(bool is_const) {
    return is_const ? "const" : "var";
}

static const char *container_string(ContainerKind kind) {
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
        case NodeTypeDirective:
            return "Directive";
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

static bool is_node_void(AstNode *node) {
    if (node->type == NodeTypeSymbol) {
        if (node->data.symbol_expr.override_type_entry) {
            return node->data.symbol_expr.override_type_entry->id == TypeTableEntryIdVoid;
        } else if (buf_eql_str(&node->data.symbol_expr.symbol, "void")) {
            return true;
        }
    }
    return false;
}

static bool is_alpha_under(uint8_t c) {
    return (c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') || c == '_';
}

static bool is_digit(uint8_t c) {
    return (c >= '0' && c <= '9');
}

static bool is_printable(uint8_t c) {
    return is_alpha_under(c) || is_digit(c) || c == ' ';
}

static void string_literal_escape(Buf *source, Buf *dest) {
    buf_resize(dest, 0);
    for (int i = 0; i < buf_len(source); i += 1) {
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
    for (int i = 1; i < buf_len(symbol); i += 1) {
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

static void render_node(AstRender *ar, AstNode *node) {
    assert(node->type == NodeTypeRoot || *node->parent_field == node);

    switch (node->type) {
        case NodeTypeRoot:
            for (int i = 0; i < node->data.root.top_level_decls.length; i += 1) {
                AstNode *child = node->data.root.top_level_decls.at(i);
                print_indent(ar);
                render_node(ar, child);

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
                const char *pub_str = visib_mod_string(node->data.fn_proto.top_level_decl.visib_mod);
                const char *extern_str = extern_string(node->data.fn_proto.is_extern);
                const char *inline_str = inline_string(node->data.fn_proto.is_inline);
                fprintf(ar->f, "%s%s%sfn ", pub_str, inline_str, extern_str);
                print_symbol(ar, &node->data.fn_proto.name);
                fprintf(ar->f, "(");
                int arg_count = node->data.fn_proto.params.length;
                bool is_var_args = node->data.fn_proto.is_var_args;
                for (int arg_i = 0; arg_i < arg_count; arg_i += 1) {
                    AstNode *param_decl = node->data.fn_proto.params.at(arg_i);
                    assert(param_decl->type == NodeTypeParamDecl);
                    if (buf_len(&param_decl->data.param_decl.name) > 0) {
                        const char *noalias_str = param_decl->data.param_decl.is_noalias ? "noalias " : "";
                        const char *inline_str = param_decl->data.param_decl.is_inline ? "inline  " : "";
                        fprintf(ar->f, "%s%s", noalias_str, inline_str);
                        print_symbol(ar, &param_decl->data.param_decl.name);
                        fprintf(ar->f, ": ");
                    }
                    render_node(ar, param_decl->data.param_decl.type);

                    if (arg_i + 1 < arg_count || is_var_args) {
                        fprintf(ar->f, ", ");
                    }
                }
                if (is_var_args) {
                    fprintf(ar->f, "...");
                }
                fprintf(ar->f, ")");

                AstNode *return_type_node = node->data.fn_proto.return_type;
                if (!is_node_void(return_type_node)) {
                    fprintf(ar->f, " -> ");
                    render_node(ar, return_type_node);
                }
                break;
            }
        case NodeTypeFnDef:
            {
                ZigList<AstNode *> *directives =
                    node->data.fn_def.fn_proto->data.fn_proto.top_level_decl.directives;
                if (directives) {
                    for (int i = 0; i < directives->length; i += 1) {
                        render_node(ar, directives->at(i));
                    }
                }
                render_node(ar, node->data.fn_def.fn_proto);
                fprintf(ar->f, " ");
                render_node(ar, node->data.fn_def.body);
                break;
            }
        case NodeTypeFnDecl:
            zig_panic("TODO");
        case NodeTypeParamDecl:
            zig_panic("TODO");
        case NodeTypeBlock:
            fprintf(ar->f, "{\n");
            ar->indent += ar->indent_size;
            for (int i = 0; i < node->data.block.statements.length; i += 1) {
                AstNode *statement = node->data.block.statements.at(i);
                print_indent(ar);
                render_node(ar, statement);
                fprintf(ar->f, ";\n");
            }
            ar->indent -= ar->indent_size;
            print_indent(ar);
            fprintf(ar->f, "}");
            break;
        case NodeTypeDirective:
            fprintf(ar->f, "#%s(",  buf_ptr(&node->data.directive.name));
            render_node(ar, node->data.directive.expr);
            fprintf(ar->f, ")\n");
            break;
        case NodeTypeReturnExpr:
            zig_panic("TODO");
        case NodeTypeDefer:
            zig_panic("TODO");
        case NodeTypeVariableDeclaration:
            {
                const char *pub_str = visib_mod_string(node->data.variable_declaration.top_level_decl.visib_mod);
                const char *extern_str = extern_string(node->data.variable_declaration.is_extern);
                const char *const_or_var = const_or_var_string(node->data.variable_declaration.is_const);
                fprintf(ar->f, "%s%s%s ", pub_str, extern_str, const_or_var);
                print_symbol(ar, &node->data.variable_declaration.symbol);

                if (node->data.variable_declaration.type) {
                    fprintf(ar->f, ": ");
                    render_node(ar, node->data.variable_declaration.type);
                }
                if (node->data.variable_declaration.expr) {
                    fprintf(ar->f, " = ");
                    render_node(ar, node->data.variable_declaration.expr);
                }
                break;
            }
        case NodeTypeTypeDecl:
            {
                const char *pub_str = visib_mod_string(node->data.type_decl.top_level_decl.visib_mod);
                const char *var_name = buf_ptr(&node->data.type_decl.symbol);
                fprintf(ar->f, "%stype %s = ", pub_str, var_name);
                render_node(ar, node->data.type_decl.child_type);
                break;
            }
        case NodeTypeErrorValueDecl:
            zig_panic("TODO");
        case NodeTypeBinOpExpr:
            fprintf(ar->f, "(");
            render_node(ar, node->data.bin_op_expr.op1);
            fprintf(ar->f, " %s ", bin_op_str(node->data.bin_op_expr.bin_op));
            render_node(ar, node->data.bin_op_expr.op2);
            fprintf(ar->f, ")");
            break;
        case NodeTypeUnwrapErrorExpr:
            zig_panic("TODO");
        case NodeTypeNumberLiteral:
            switch (node->data.number_literal.kind) {
                case NumLitUInt:
                    fprintf(ar->f, "%" PRIu64, node->data.number_literal.data.x_uint);
                    break;
                case NumLitFloat:
                    fprintf(ar->f, "%f", node->data.number_literal.data.x_float);
                    break;
            }
            break;
        case NodeTypeStringLiteral:
            {
                if (node->data.string_literal.c) {
                    fprintf(ar->f, "c");
                }
                Buf tmp_buf = BUF_INIT;
                string_literal_escape(&node->data.string_literal.buf, &tmp_buf);
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
            {
                TypeTableEntry *override_type = node->data.symbol_expr.override_type_entry;
                if (override_type) {
                    fprintf(ar->f, "%s", buf_ptr(&override_type->name));
                } else {
                    fprintf(ar->f, "%s", buf_ptr(&node->data.symbol_expr.symbol));
                }
            }
            break;
        case NodeTypePrefixOpExpr:
            {
                PrefixOp op = node->data.prefix_op_expr.prefix_op;
                fprintf(ar->f, "%s", prefix_op_str(op));

                render_node(ar, node->data.prefix_op_expr.primary_expr);
                break;
            }
        case NodeTypeFnCallExpr:
            if (node->data.fn_call_expr.is_builtin) {
                fprintf(ar->f, "@");
            }
            fprintf(ar->f, "(");
            render_node(ar, node->data.fn_call_expr.fn_ref_expr);
            fprintf(ar->f, ")(");
            for (int i = 0; i < node->data.fn_call_expr.params.length; i += 1) {
                AstNode *param = node->data.fn_call_expr.params.at(i);
                if (i != 0) {
                    fprintf(ar->f, ", ");
                }
                render_node(ar, param);
            }
            fprintf(ar->f, ")");
            break;
        case NodeTypeArrayAccessExpr:
            render_node(ar, node->data.array_access_expr.array_ref_expr);
            fprintf(ar->f, "[");
            render_node(ar, node->data.array_access_expr.subscript);
            fprintf(ar->f, "]");
            break;
        case NodeTypeSliceExpr:
            zig_panic("TODO");
        case NodeTypeFieldAccessExpr:
            {
                AstNode *lhs = node->data.field_access_expr.struct_expr;
                Buf *rhs = &node->data.field_access_expr.field_name;
                render_node(ar, lhs);
                fprintf(ar->f, ".");
                print_symbol(ar, rhs);
                break;
            }
        case NodeTypeUse:
            zig_panic("TODO");
        case NodeTypeBoolLiteral:
            zig_panic("TODO");
        case NodeTypeNullLiteral:
            zig_panic("TODO");
        case NodeTypeUndefinedLiteral:
            zig_panic("TODO");
        case NodeTypeIfBoolExpr:
            zig_panic("TODO");
        case NodeTypeIfVarExpr:
            zig_panic("TODO");
        case NodeTypeWhileExpr:
            zig_panic("TODO");
        case NodeTypeForExpr:
            zig_panic("TODO");
        case NodeTypeSwitchExpr:
            zig_panic("TODO");
        case NodeTypeSwitchProng:
            zig_panic("TODO");
        case NodeTypeSwitchRange:
            zig_panic("TODO");
        case NodeTypeLabel:
            zig_panic("TODO");
        case NodeTypeGoto:
            zig_panic("TODO");
        case NodeTypeBreak:
            zig_panic("TODO");
        case NodeTypeContinue:
            zig_panic("TODO");
        case NodeTypeAsmExpr:
            zig_panic("TODO");
        case NodeTypeContainerDecl:
            {
                const char *struct_name = buf_ptr(&node->data.struct_decl.name);
                const char *pub_str = visib_mod_string(node->data.struct_decl.top_level_decl.visib_mod);
                const char *container_str = container_string(node->data.struct_decl.kind);
                fprintf(ar->f, "%s%s %s {\n", pub_str, container_str, struct_name);
                ar->indent += ar->indent_size;
                for (int field_i = 0; field_i < node->data.struct_decl.fields.length; field_i += 1) {
                    AstNode *field_node = node->data.struct_decl.fields.at(field_i);
                    assert(field_node->type == NodeTypeStructField);
                    print_indent(ar);
                    print_symbol(ar, &field_node->data.struct_field.name);
                    if (!is_node_void(field_node->data.struct_field.type)) {
                        fprintf(ar->f, ": ");
                        render_node(ar, field_node->data.struct_field.type);
                    }
                    fprintf(ar->f, ",\n");
                }

                ar->indent -= ar->indent_size;
                fprintf(ar->f, "}");
                break;
            }
        case NodeTypeStructField:
            zig_panic("TODO");
        case NodeTypeContainerInitExpr:
            fprintf(ar->f, "(");
            render_node(ar, node->data.container_init_expr.type);
            fprintf(ar->f, "){");
            assert(node->data.container_init_expr.entries.length == 0);
            fprintf(ar->f, "}");
            break;
        case NodeTypeStructValueField:
            zig_panic("TODO");
        case NodeTypeArrayType:
            {
                fprintf(ar->f, "[");
                if (node->data.array_type.size) {
                    render_node(ar, node->data.array_type.size);
                }
                fprintf(ar->f, "]");
                if (node->data.array_type.is_const) {
                    fprintf(ar->f, "const ");
                }
                render_node(ar, node->data.array_type.child_type);
                break;
            }
        case NodeTypeErrorType:
            fprintf(ar->f, "error");
            break;
        case NodeTypeTypeLiteral:
            fprintf(ar->f, "type");
            break;
    }
}


void ast_render(FILE *f, AstNode *node, int indent_size) {
    AstRender ar = {0};
    ar.f = f;
    ar.indent_size = indent_size;
    ar.indent = 0;

    assert(node->type == NodeTypeRoot);

    render_node(&ar, node);
}
