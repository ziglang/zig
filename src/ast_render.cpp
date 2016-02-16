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
        case BinOpTypeStrCat:              return "++";
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

static const char *return_prefix_str(ReturnKind kind) {
    switch (kind) {
        case ReturnKindError: return "%";
        case ReturnKindMaybe: return "?";
        case ReturnKindUnconditional: return "";
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
    }
    zig_unreachable();
}

static const char *node_type_str(NodeType node_type) {
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
        case NodeTypeImport:
            return "Import";
        case NodeTypeCImport:
            return "CImport";
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
        case NodeTypeStructDecl:
            return "StructDecl";
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


void ast_print(FILE *f, AstNode *node, int indent) {
    for (int i = 0; i < indent; i += 1) {
        fprintf(f, " ");
    }
    assert(node->type == NodeTypeRoot || *node->parent_field == node);

    switch (node->type) {
        case NodeTypeRoot:
            fprintf(f, "%s\n", node_type_str(node->type));
            for (int i = 0; i < node->data.root.top_level_decls.length; i += 1) {
                AstNode *child = node->data.root.top_level_decls.at(i);
                ast_print(f, child, indent + 2);
            }
            break;
        case NodeTypeRootExportDecl:
            fprintf(f, "%s %s '%s'\n", node_type_str(node->type),
                    buf_ptr(&node->data.root_export_decl.type),
                    buf_ptr(&node->data.root_export_decl.name));
            break;
        case NodeTypeFnDef:
            {
                fprintf(f, "%s\n", node_type_str(node->type));
                AstNode *child = node->data.fn_def.fn_proto;
                ast_print(f, child, indent + 2);
                ast_print(f, node->data.fn_def.body, indent + 2);
                break;
            }
        case NodeTypeFnProto:
            {
                Buf *name_buf = &node->data.fn_proto.name;
                fprintf(f, "%s '%s'\n", node_type_str(node->type), buf_ptr(name_buf));

                for (int i = 0; i < node->data.fn_proto.params.length; i += 1) {
                    AstNode *child = node->data.fn_proto.params.at(i);
                    ast_print(f, child, indent + 2);
                }

                ast_print(f, node->data.fn_proto.return_type, indent + 2);

                break;
            }
        case NodeTypeBlock:
            {
                fprintf(f, "%s\n", node_type_str(node->type));
                for (int i = 0; i < node->data.block.statements.length; i += 1) {
                    AstNode *child = node->data.block.statements.at(i);
                    ast_print(f, child, indent + 2);
                }
                break;
            }
        case NodeTypeParamDecl:
            {
                Buf *name_buf = &node->data.param_decl.name;
                fprintf(f, "%s '%s'\n", node_type_str(node->type), buf_ptr(name_buf));

                ast_print(f, node->data.param_decl.type, indent + 2);

                break;
            }
        case NodeTypeReturnExpr:
            {
                const char *prefix_str = return_prefix_str(node->data.return_expr.kind);
                fprintf(f, "%s%s\n", prefix_str, node_type_str(node->type));
                if (node->data.return_expr.expr)
                    ast_print(f, node->data.return_expr.expr, indent + 2);
                break;
            }
        case NodeTypeDefer:
            {
                const char *prefix_str = return_prefix_str(node->data.defer.kind);
                fprintf(f, "%s%s\n", prefix_str, node_type_str(node->type));
                if (node->data.defer.expr)
                    ast_print(f, node->data.defer.expr, indent + 2);
                break;
            }
        case NodeTypeVariableDeclaration:
            {
                Buf *name_buf = &node->data.variable_declaration.symbol;
                fprintf(f, "%s '%s'\n", node_type_str(node->type), buf_ptr(name_buf));
                if (node->data.variable_declaration.type)
                    ast_print(f, node->data.variable_declaration.type, indent + 2);
                if (node->data.variable_declaration.expr)
                    ast_print(f, node->data.variable_declaration.expr, indent + 2);
                break;
            }
        case NodeTypeTypeDecl:
            {
                Buf *name_buf = &node->data.type_decl.symbol;
                fprintf(f, "%s '%s'\n", node_type_str(node->type), buf_ptr(name_buf));
                ast_print(f, node->data.type_decl.child_type, indent + 2);
                break;
            }
        case NodeTypeErrorValueDecl:
            {
                Buf *name_buf = &node->data.error_value_decl.name;
                fprintf(f, "%s '%s'\n", node_type_str(node->type), buf_ptr(name_buf));
                break;
            }
        case NodeTypeFnDecl:
            fprintf(f, "%s\n", node_type_str(node->type));
            ast_print(f, node->data.fn_decl.fn_proto, indent + 2);
            break;
        case NodeTypeBinOpExpr:
            fprintf(f, "%s %s\n", node_type_str(node->type),
                    bin_op_str(node->data.bin_op_expr.bin_op));
            ast_print(f, node->data.bin_op_expr.op1, indent + 2);
            ast_print(f, node->data.bin_op_expr.op2, indent + 2);
            break;
        case NodeTypeUnwrapErrorExpr:
            fprintf(f, "%s\n", node_type_str(node->type));
            ast_print(f, node->data.unwrap_err_expr.op1, indent + 2);
            if (node->data.unwrap_err_expr.symbol) {
                ast_print(f, node->data.unwrap_err_expr.symbol, indent + 2);
            }
            ast_print(f, node->data.unwrap_err_expr.op2, indent + 2);
            break;
        case NodeTypeFnCallExpr:
            fprintf(f, "%s\n", node_type_str(node->type));
            ast_print(f, node->data.fn_call_expr.fn_ref_expr, indent + 2);
            for (int i = 0; i < node->data.fn_call_expr.params.length; i += 1) {
                AstNode *child = node->data.fn_call_expr.params.at(i);
                ast_print(f, child, indent + 2);
            }
            break;
        case NodeTypeArrayAccessExpr:
            fprintf(f, "%s\n", node_type_str(node->type));
            ast_print(f, node->data.array_access_expr.array_ref_expr, indent + 2);
            ast_print(f, node->data.array_access_expr.subscript, indent + 2);
            break;
        case NodeTypeSliceExpr:
            fprintf(f, "%s\n", node_type_str(node->type));
            ast_print(f, node->data.slice_expr.array_ref_expr, indent + 2);
            ast_print(f, node->data.slice_expr.start, indent + 2);
            if (node->data.slice_expr.end) {
                ast_print(f, node->data.slice_expr.end, indent + 2);
            }
            break;
        case NodeTypeDirective:
            fprintf(f, "%s\n", node_type_str(node->type));
            ast_print(f, node->data.directive.expr, indent + 2);
            break;
        case NodeTypePrefixOpExpr:
            fprintf(f, "%s %s\n", node_type_str(node->type),
                    prefix_op_str(node->data.prefix_op_expr.prefix_op));
            ast_print(f, node->data.prefix_op_expr.primary_expr, indent + 2);
            break;
        case NodeTypeNumberLiteral:
            {
                NumLit kind = node->data.number_literal.kind;
                const char *name = node_type_str(node->type);
                if (kind == NumLitUInt) {
                    fprintf(f, "%s uint %" PRIu64 "\n", name, node->data.number_literal.data.x_uint);
                } else {
                    fprintf(f, "%s float %f\n", name, node->data.number_literal.data.x_float);
                }
                break;
            }
        case NodeTypeStringLiteral:
            {
                const char *c = node->data.string_literal.c ? "c" : "";
                fprintf(f, "StringLiteral %s'%s'\n", c,
                        buf_ptr(&node->data.string_literal.buf));
                break;
            }
        case NodeTypeCharLiteral:
            {
                fprintf(f, "%s '%c'\n", node_type_str(node->type), node->data.char_literal.value);
                break;
            }
        case NodeTypeSymbol:
            fprintf(f, "Symbol %s\n", buf_ptr(&node->data.symbol_expr.symbol));
            break;
        case NodeTypeImport:
            fprintf(f, "%s '%s'\n", node_type_str(node->type), buf_ptr(&node->data.import.path));
            break;
        case NodeTypeCImport:
            fprintf(f, "%s\n", node_type_str(node->type));
            ast_print(f, node->data.c_import.block, indent + 2);
            break;
        case NodeTypeBoolLiteral:
            fprintf(f, "%s '%s'\n", node_type_str(node->type),
                    node->data.bool_literal.value ? "true" : "false");
            break;
        case NodeTypeNullLiteral:
            fprintf(f, "%s\n", node_type_str(node->type));
            break;
        case NodeTypeIfBoolExpr:
            fprintf(f, "%s\n", node_type_str(node->type));
            if (node->data.if_bool_expr.condition)
                ast_print(f, node->data.if_bool_expr.condition, indent + 2);
            ast_print(f, node->data.if_bool_expr.then_block, indent + 2);
            if (node->data.if_bool_expr.else_node)
                ast_print(f, node->data.if_bool_expr.else_node, indent + 2);
            break;
        case NodeTypeIfVarExpr:
            {
                Buf *name_buf = &node->data.if_var_expr.var_decl.symbol;
                fprintf(f, "%s '%s'\n", node_type_str(node->type), buf_ptr(name_buf));
                if (node->data.if_var_expr.var_decl.type)
                    ast_print(f, node->data.if_var_expr.var_decl.type, indent + 2);
                if (node->data.if_var_expr.var_decl.expr)
                    ast_print(f, node->data.if_var_expr.var_decl.expr, indent + 2);
                ast_print(f, node->data.if_var_expr.then_block, indent + 2);
                if (node->data.if_var_expr.else_node)
                    ast_print(f, node->data.if_var_expr.else_node, indent + 2);
                break;
            }
        case NodeTypeWhileExpr:
            fprintf(f, "%s\n", node_type_str(node->type));
            ast_print(f, node->data.while_expr.condition, indent + 2);
            ast_print(f, node->data.while_expr.body, indent + 2);
            break;
        case NodeTypeForExpr:
            fprintf(f, "%s\n", node_type_str(node->type));
            ast_print(f, node->data.for_expr.elem_node, indent + 2);
            ast_print(f, node->data.for_expr.array_expr, indent + 2);
            if (node->data.for_expr.index_node) {
                ast_print(f, node->data.for_expr.index_node, indent + 2);
            }
            ast_print(f, node->data.for_expr.body, indent + 2);
            break;
        case NodeTypeSwitchExpr:
            fprintf(f, "%s\n", node_type_str(node->type));
            ast_print(f, node->data.switch_expr.expr, indent + 2);
            for (int i = 0; i < node->data.switch_expr.prongs.length; i += 1) {
                AstNode *child_node = node->data.switch_expr.prongs.at(i);
                ast_print(f, child_node, indent + 2);
            }
            break;
        case NodeTypeSwitchProng:
            fprintf(f, "%s\n", node_type_str(node->type));
            for (int i = 0; i < node->data.switch_prong.items.length; i += 1) {
                AstNode *child_node = node->data.switch_prong.items.at(i);
                ast_print(f, child_node, indent + 2);
            }
            if (node->data.switch_prong.var_symbol) {
                ast_print(f, node->data.switch_prong.var_symbol, indent + 2);
            }
            ast_print(f, node->data.switch_prong.expr, indent + 2);
            break;
        case NodeTypeSwitchRange:
            fprintf(f, "%s\n", node_type_str(node->type));
            ast_print(f, node->data.switch_range.start, indent + 2);
            ast_print(f, node->data.switch_range.end, indent + 2);
            break;
        case NodeTypeLabel:
            fprintf(f, "%s '%s'\n", node_type_str(node->type), buf_ptr(&node->data.label.name));
            break;
        case NodeTypeGoto:
            fprintf(f, "%s '%s'\n", node_type_str(node->type), buf_ptr(&node->data.goto_expr.name));
            break;
        case NodeTypeBreak:
            fprintf(f, "%s\n", node_type_str(node->type));
            break;
        case NodeTypeContinue:
            fprintf(f, "%s\n", node_type_str(node->type));
            break;
        case NodeTypeUndefinedLiteral:
            fprintf(f, "%s\n", node_type_str(node->type));
            break;
        case NodeTypeAsmExpr:
            fprintf(f, "%s\n", node_type_str(node->type));
            break;
        case NodeTypeFieldAccessExpr:
            fprintf(f, "%s '%s'\n", node_type_str(node->type),
                    buf_ptr(&node->data.field_access_expr.field_name));
            ast_print(f, node->data.field_access_expr.struct_expr, indent + 2);
            break;
        case NodeTypeStructDecl:
            fprintf(f, "%s '%s'\n",
                    node_type_str(node->type), buf_ptr(&node->data.struct_decl.name));
            for (int i = 0; i < node->data.struct_decl.fields.length; i += 1) {
                AstNode *child = node->data.struct_decl.fields.at(i);
                ast_print(f, child, indent + 2);
            }
            for (int i = 0; i < node->data.struct_decl.fns.length; i += 1) {
                AstNode *child = node->data.struct_decl.fns.at(i);
                ast_print(f, child, indent + 2);
            }
            break;
        case NodeTypeStructField:
            fprintf(f, "%s '%s'\n", node_type_str(node->type), buf_ptr(&node->data.struct_field.name));
            if (node->data.struct_field.type) {
                ast_print(f, node->data.struct_field.type, indent + 2);
            }
            break;
        case NodeTypeStructValueField:
            fprintf(f, "%s '%s'\n", node_type_str(node->type), buf_ptr(&node->data.struct_val_field.name));
            ast_print(f, node->data.struct_val_field.expr, indent + 2);
            break;
        case NodeTypeContainerInitExpr:
            fprintf(f, "%s\n", node_type_str(node->type));
            ast_print(f, node->data.container_init_expr.type, indent + 2);
            for (int i = 0; i < node->data.container_init_expr.entries.length; i += 1) {
                AstNode *child = node->data.container_init_expr.entries.at(i);
                ast_print(f, child, indent + 2);
            }
            break;
        case NodeTypeArrayType:
            {
                const char *const_str = node->data.array_type.is_const ? "const" : "var";
                fprintf(f, "%s %s\n", node_type_str(node->type), const_str);
                if (node->data.array_type.size) {
                    ast_print(f, node->data.array_type.size, indent + 2);
                }
                ast_print(f, node->data.array_type.child_type, indent + 2);
                break;
            }
        case NodeTypeErrorType:
            fprintf(f, "%s\n", node_type_str(node->type));
            break;
        case NodeTypeTypeLiteral:
            fprintf(f, "%s\n", node_type_str(node->type));
            break;
    }
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

static bool is_printable(uint8_t c) {
    return (c >= 'a' && c <= 'z') ||
           (c >= 'A' && c <= 'A') ||
           (c >= '0' && c <= '9');
}

static void render_node(AstRender *ar, AstNode *node) {
    assert(node->type == NodeTypeRoot || *node->parent_field == node);

    switch (node->type) {
        case NodeTypeRoot:
            for (int i = 0; i < node->data.root.top_level_decls.length; i += 1) {
                AstNode *child = node->data.root.top_level_decls.at(i);
                print_indent(ar);
                render_node(ar, child);

                if (child->type == NodeTypeImport ||
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
        case NodeTypeRootExportDecl:
            zig_panic("TODO");
        case NodeTypeFnProto:
            {
                const char *fn_name = buf_ptr(&node->data.fn_proto.name);
                const char *pub_str = visib_mod_string(node->data.fn_proto.visib_mod);
                const char *extern_str = extern_string(node->data.fn_proto.is_extern);
                const char *inline_str = inline_string(node->data.fn_proto.is_inline);
                fprintf(ar->f, "%s%s%sfn %s(", pub_str, inline_str, extern_str, fn_name);
                int arg_count = node->data.fn_proto.params.length;
                bool is_var_args = node->data.fn_proto.is_var_args;
                for (int arg_i = 0; arg_i < arg_count; arg_i += 1) {
                    AstNode *param_decl = node->data.fn_proto.params.at(arg_i);
                    assert(param_decl->type == NodeTypeParamDecl);
                    const char *arg_name = buf_ptr(&param_decl->data.param_decl.name);
                    if (buf_len(&param_decl->data.param_decl.name) > 0) {
                        const char *noalias_str = param_decl->data.param_decl.is_noalias ? "noalias " : "";
                        fprintf(ar->f, "%s%s: ", noalias_str, arg_name);
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
            if (node->data.fn_def.fn_proto->data.fn_proto.directives) {
                for (int i = 0; i < node->data.fn_def.fn_proto->data.fn_proto.directives->length; i += 1) {
                    render_node(ar, node->data.fn_def.fn_proto->data.fn_proto.directives->at(i));
                }
            }
            render_node(ar, node->data.fn_def.fn_proto);
            fprintf(ar->f, " ");
            render_node(ar, node->data.fn_def.body);
            break;
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
            }
            ar->indent -= ar->indent_size;
            fprintf(ar->f, "\n");
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
                const char *pub_str = visib_mod_string(node->data.variable_declaration.visib_mod);
                const char *extern_str = extern_string(node->data.variable_declaration.is_extern);
                const char *var_name = buf_ptr(&node->data.variable_declaration.symbol);
                const char *const_or_var = const_or_var_string(node->data.variable_declaration.is_const);
                fprintf(ar->f, "%s%s%s %s", pub_str, extern_str, const_or_var, var_name);
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
                const char *pub_str = visib_mod_string(node->data.type_decl.visib_mod);
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
            if (node->data.string_literal.c) {
                fprintf(ar->f, "c");
            }
            fprintf(ar->f, "\"%s\"", buf_ptr(&node->data.string_literal.buf));
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
            zig_panic("TODO");
        case NodeTypeSliceExpr:
            zig_panic("TODO");
        case NodeTypeFieldAccessExpr:
            {
                AstNode *lhs = node->data.field_access_expr.struct_expr;
                Buf *rhs = &node->data.field_access_expr.field_name;
                render_node(ar, lhs);
                fprintf(ar->f, ".%s", buf_ptr(rhs));
                break;
            }
        case NodeTypeImport:
            zig_panic("TODO");
        case NodeTypeCImport:
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
        case NodeTypeStructDecl:
            {
                const char *struct_name = buf_ptr(&node->data.struct_decl.name);
                const char *pub_str = visib_mod_string(node->data.struct_decl.visib_mod);
                const char *container_str = container_string(node->data.struct_decl.kind);
                fprintf(ar->f, "%s%s %s {\n", pub_str, container_str, struct_name);
                ar->indent += ar->indent_size;
                for (int field_i = 0; field_i < node->data.struct_decl.fields.length; field_i += 1) {
                    AstNode *field_node = node->data.struct_decl.fields.at(field_i);
                    assert(field_node->type == NodeTypeStructField);
                    const char *field_name = buf_ptr(&field_node->data.struct_field.name);
                    print_indent(ar);
                    fprintf(ar->f, "%s", field_name);
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
