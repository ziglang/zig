#include "eval.hpp"
#include "analyze.hpp"
#include "error.hpp"

static bool eval_fn_args(EvalFnRoot *efr, FnTableEntry *fn, ConstExprValue *args, ConstExprValue *out_val);

bool const_values_equal(ConstExprValue *a, ConstExprValue *b, TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdEnum:
            {
                ConstEnumValue *enum1 = &a->data.x_enum;
                ConstEnumValue *enum2 = &b->data.x_enum;
                if (enum1->tag == enum2->tag) {
                    TypeEnumField *enum_field = &type_entry->data.enumeration.fields[enum1->tag];
                    if (type_has_bits(enum_field->type_entry)) {
                        zig_panic("TODO const expr analyze enum special value for equality");
                    } else {
                        return true;
                    }
                }
                return false;
            }
        case TypeTableEntryIdMetaType:
            return a->data.x_type == b->data.x_type;
        case TypeTableEntryIdVoid:
            return true;
        case TypeTableEntryIdPureError:
            return a->data.x_err.err == b->data.x_err.err;
        case TypeTableEntryIdFn:
            return a->data.x_fn == b->data.x_fn;
        case TypeTableEntryIdBool:
            return a->data.x_bool == b->data.x_bool;
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
            return bignum_cmp_eq(&a->data.x_bignum, &b->data.x_bignum);
        case TypeTableEntryIdPointer:
            zig_panic("TODO");
        case TypeTableEntryIdArray:
            zig_panic("TODO");
        case TypeTableEntryIdStruct:
            zig_panic("TODO");
        case TypeTableEntryIdUnion:
            zig_panic("TODO");
        case TypeTableEntryIdUndefLit:
            zig_panic("TODO");
        case TypeTableEntryIdMaybe:
            zig_panic("TODO");
        case TypeTableEntryIdErrorUnion:
            zig_panic("TODO");
        case TypeTableEntryIdTypeDecl:
            zig_panic("TODO");
        case TypeTableEntryIdNamespace:
            zig_panic("TODO");
        case TypeTableEntryIdGenericFn:
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdUnreachable:
            zig_unreachable();
    }
    zig_unreachable();
}


static bool eval_expr(EvalFn *ef, AstNode *node, ConstExprValue *out);

static bool eval_block(EvalFn *ef, AstNode *node, ConstExprValue *out) {
    assert(node->type == NodeTypeBlock);

    EvalScope *my_scope = allocate<EvalScope>(1);
    my_scope->block_context = node->block_context;
    ef->scope_stack.append(my_scope);

    for (int i = 0; i < node->data.block.statements.length; i += 1) {
        AstNode *child = node->data.block.statements.at(i);
        memset(out, 0, sizeof(ConstExprValue));
        if (eval_expr(ef, child, out)) return true;
    }

    ef->scope_stack.pop();

    return false;
}

static bool eval_return(EvalFn *ef, AstNode *node, ConstExprValue *out) {
    assert(node->type == NodeTypeReturnExpr);

    eval_expr(ef, node->data.return_expr.expr, ef->return_expr);
    return true;
}

static bool eval_bool_bin_op_bool(bool a, BinOpType bin_op, bool b) {
    if (bin_op == BinOpTypeBoolOr) {
        return a || b;
    } else if (bin_op == BinOpTypeBoolAnd) {
        return a && b;
    } else {
        zig_unreachable();
    }
}

static uint64_t max_unsigned_val(TypeTableEntry *type_entry) {
    assert(type_entry->id == TypeTableEntryIdInt);
    if (type_entry->data.integral.bit_count == 64) {
        return UINT64_MAX;
    } else if (type_entry->data.integral.bit_count == 32) {
        return UINT32_MAX;
    } else if (type_entry->data.integral.bit_count == 16) {
        return UINT16_MAX;
    } else if (type_entry->data.integral.bit_count == 8) {
        return UINT8_MAX;
    } else {
        zig_unreachable();
    }
}

static int64_t max_signed_val(TypeTableEntry *type_entry) {
    assert(type_entry->id == TypeTableEntryIdInt);
    if (type_entry->data.integral.bit_count == 64) {
        return INT64_MAX;
    } else if (type_entry->data.integral.bit_count == 32) {
        return INT32_MAX;
    } else if (type_entry->data.integral.bit_count == 16) {
        return INT16_MAX;
    } else if (type_entry->data.integral.bit_count == 8) {
        return INT8_MAX;
    } else {
        zig_unreachable();
    }
}

static int64_t min_signed_val(TypeTableEntry *type_entry) {
    assert(type_entry->id == TypeTableEntryIdInt);
    if (type_entry->data.integral.bit_count == 64) {
        return INT64_MIN;
    } else if (type_entry->data.integral.bit_count == 32) {
        return INT32_MIN;
    } else if (type_entry->data.integral.bit_count == 16) {
        return INT16_MIN;
    } else if (type_entry->data.integral.bit_count == 8) {
        return INT8_MIN;
    } else {
        zig_unreachable();
    }
}

static int eval_const_expr_bin_op_bignum(ConstExprValue *op1_val, ConstExprValue *op2_val,
        ConstExprValue *out_val, bool (*bignum_fn)(BigNum *, BigNum *, BigNum *),
        TypeTableEntry *type)
{
    bool overflow = bignum_fn(&out_val->data.x_bignum, &op1_val->data.x_bignum, &op2_val->data.x_bignum);
    if (overflow) {
        return ErrorOverflow;
    }

    if (type->id == TypeTableEntryIdInt && !bignum_fits_in_bits(&out_val->data.x_bignum,
                type->data.integral.bit_count, type->data.integral.is_signed))
    {
        if (type->data.integral.is_wrapping) {
            if (type->data.integral.is_signed) {
                out_val->data.x_bignum.data.x_uint = max_unsigned_val(type) - out_val->data.x_bignum.data.x_uint + 1;
                out_val->data.x_bignum.is_negative = !out_val->data.x_bignum.is_negative;
            } else if (out_val->data.x_bignum.is_negative) {
                out_val->data.x_bignum.data.x_uint = max_unsigned_val(type) - out_val->data.x_bignum.data.x_uint + 1;
                out_val->data.x_bignum.is_negative = false;
            } else {
                bignum_truncate(&out_val->data.x_bignum, type->data.integral.bit_count);
            }
        } else {
            return ErrorOverflow;
        }
    }

    out_val->ok = true;
    out_val->depends_on_compile_var = op1_val->depends_on_compile_var || op2_val->depends_on_compile_var;
    return 0;
}

int eval_const_expr_bin_op(ConstExprValue *op1_val, TypeTableEntry *op1_type,
        BinOpType bin_op, ConstExprValue *op2_val, TypeTableEntry *op2_type, ConstExprValue *out_val)
{
    assert(op1_val->ok);
    assert(op2_val->ok);
    assert(op1_type->id != TypeTableEntryIdInvalid);
    assert(op2_type->id != TypeTableEntryIdInvalid);

    switch (bin_op) {
        case BinOpTypeAssign:
        case BinOpTypeAssignTimes:
        case BinOpTypeAssignDiv:
        case BinOpTypeAssignMod:
        case BinOpTypeAssignPlus:
        case BinOpTypeAssignMinus:
        case BinOpTypeAssignBitShiftLeft:
        case BinOpTypeAssignBitShiftRight:
        case BinOpTypeAssignBitAnd:
        case BinOpTypeAssignBitXor:
        case BinOpTypeAssignBitOr:
        case BinOpTypeAssignBoolAnd:
        case BinOpTypeAssignBoolOr:
            zig_unreachable();
        case BinOpTypeBoolOr:
        case BinOpTypeBoolAnd:
            assert(op1_type->id == TypeTableEntryIdBool);
            assert(op2_type->id == TypeTableEntryIdBool);
            out_val->data.x_bool = eval_bool_bin_op_bool(op1_val->data.x_bool, bin_op, op2_val->data.x_bool);
            out_val->ok = true;
            out_val->depends_on_compile_var = op1_val->depends_on_compile_var || op2_val->depends_on_compile_var;
            return 0;
        case BinOpTypeCmpEq:
        case BinOpTypeCmpNotEq:
        case BinOpTypeCmpLessThan:
        case BinOpTypeCmpGreaterThan:
        case BinOpTypeCmpLessOrEq:
        case BinOpTypeCmpGreaterOrEq:
            {
                bool type_can_gt_lt_cmp = (op1_type->id == TypeTableEntryIdNumLitFloat ||
                        op1_type->id == TypeTableEntryIdNumLitInt ||
                        op1_type->id == TypeTableEntryIdFloat ||
                        op1_type->id == TypeTableEntryIdInt);
                bool answer;
                if (type_can_gt_lt_cmp) {
                    bool (*bignum_cmp)(BigNum *, BigNum *);
                    if (bin_op == BinOpTypeCmpEq) {
                        bignum_cmp = bignum_cmp_eq;
                    } else if (bin_op == BinOpTypeCmpNotEq) {
                        bignum_cmp = bignum_cmp_neq;
                    } else if (bin_op == BinOpTypeCmpLessThan) {
                        bignum_cmp = bignum_cmp_lt;
                    } else if (bin_op == BinOpTypeCmpGreaterThan) {
                        bignum_cmp = bignum_cmp_gt;
                    } else if (bin_op == BinOpTypeCmpLessOrEq) {
                        bignum_cmp = bignum_cmp_lte;
                    } else if (bin_op == BinOpTypeCmpGreaterOrEq) {
                        bignum_cmp = bignum_cmp_gte;
                    } else {
                        zig_unreachable();
                    }

                    answer = bignum_cmp(&op1_val->data.x_bignum, &op2_val->data.x_bignum);
                } else {
                    bool are_equal = const_values_equal(op1_val, op2_val, op1_type);
                    if (bin_op == BinOpTypeCmpEq) {
                        answer = are_equal;
                    } else if (bin_op == BinOpTypeCmpNotEq) {
                        answer = !are_equal;
                    } else {
                        zig_unreachable();
                    }
                }

                out_val->depends_on_compile_var =
                    op1_val->depends_on_compile_var || op2_val->depends_on_compile_var;
                out_val->data.x_bool = answer;
                out_val->ok = true;
                return 0;
            }
        case BinOpTypeAdd:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_add, op1_type);
        case BinOpTypeBinOr:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_or, op1_type);
        case BinOpTypeBinXor:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_xor, op1_type);
        case BinOpTypeBinAnd:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_and, op1_type);
        case BinOpTypeBitShiftLeft:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_shl, op1_type);
        case BinOpTypeBitShiftRight:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_shr, op1_type);
        case BinOpTypeSub:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_sub, op1_type);
        case BinOpTypeMult:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_mul, op1_type);
        case BinOpTypeDiv:
            {
                bool is_int = false;
                bool is_float = false;
                if (op1_type->id == TypeTableEntryIdInt ||
                    op1_type->id == TypeTableEntryIdNumLitInt)
                {
                    is_int = true;
                } else if (op1_type->id == TypeTableEntryIdFloat ||
                           op1_type->id == TypeTableEntryIdNumLitFloat)
                {
                    is_float = true;
                }
                if ((is_int && op2_val->data.x_bignum.data.x_uint == 0) ||
                    (is_float && op2_val->data.x_bignum.data.x_float == 0.0))
                {
                    return ErrorDivByZero;
                } else {
                    return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_div, op1_type);
                }
            }
        case BinOpTypeMod:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_mod, op1_type);
        case BinOpTypeUnwrapMaybe:
            zig_panic("TODO");
        case BinOpTypeArrayCat:
        case BinOpTypeArrayMult:
        case BinOpTypeInvalid:
            zig_unreachable();
    }
    zig_unreachable();
}

static bool eval_bin_op_expr(EvalFn *ef, AstNode *node, ConstExprValue *out_val) {
    assert(node->type == NodeTypeBinOpExpr);

    AstNode *op1 = node->data.bin_op_expr.op1;
    AstNode *op2 = node->data.bin_op_expr.op2;
    BinOpType bin_op = node->data.bin_op_expr.bin_op;

    switch (bin_op) {
        case BinOpTypeAssign:
        case BinOpTypeAssignTimes:
        case BinOpTypeAssignDiv:
        case BinOpTypeAssignMod:
        case BinOpTypeAssignPlus:
        case BinOpTypeAssignMinus:
        case BinOpTypeAssignBitShiftLeft:
        case BinOpTypeAssignBitShiftRight:
        case BinOpTypeAssignBitAnd:
        case BinOpTypeAssignBitXor:
        case BinOpTypeAssignBitOr:
        case BinOpTypeAssignBoolAnd:
        case BinOpTypeAssignBoolOr:
            zig_panic("TODO");
        case BinOpTypeBoolOr:
        case BinOpTypeBoolAnd:
        case BinOpTypeCmpEq:
        case BinOpTypeCmpNotEq:
        case BinOpTypeCmpLessThan:
        case BinOpTypeCmpGreaterThan:
        case BinOpTypeCmpLessOrEq:
        case BinOpTypeCmpGreaterOrEq:
        case BinOpTypeBinOr:
        case BinOpTypeBinXor:
        case BinOpTypeBinAnd:
        case BinOpTypeBitShiftLeft:
        case BinOpTypeBitShiftRight:
        case BinOpTypeAdd:
        case BinOpTypeSub:
        case BinOpTypeMult:
        case BinOpTypeDiv:
        case BinOpTypeMod:
        case BinOpTypeUnwrapMaybe:
        case BinOpTypeArrayCat:
        case BinOpTypeArrayMult:
            break;
        case BinOpTypeInvalid:
            zig_unreachable();
    }

    TypeTableEntry *op1_type = get_resolved_expr(op1)->type_entry;
    TypeTableEntry *op2_type = get_resolved_expr(op2)->type_entry;

    assert(op1_type);
    assert(op2_type);

    ConstExprValue op1_val = {0};
    if (eval_expr(ef, op1, &op1_val)) return true;

    ConstExprValue op2_val = {0};
    if (eval_expr(ef, op2, &op2_val)) return true;

    int err;
    if ((err = eval_const_expr_bin_op(&op1_val, op1_type, bin_op, &op2_val, op2_type, out_val))) {
        ef->root->abort = true;
        if (err == ErrorDivByZero) {
            ErrorMsg *msg = add_node_error(ef->root->codegen, ef->root->fn->fn_def_node,
                    buf_sprintf("function evaluation caused division by zero"));
            add_error_note(ef->root->codegen, msg, ef->root->call_node, buf_sprintf("called from here"));
            add_error_note(ef->root->codegen, msg, node, buf_sprintf("division by zero here"));
        } else if (err == ErrorOverflow) {
            ErrorMsg *msg = add_node_error(ef->root->codegen, ef->root->fn->fn_def_node,
                    buf_sprintf("function evaluation caused overflow"));
            add_error_note(ef->root->codegen, msg, ef->root->call_node, buf_sprintf("called from here"));
            add_error_note(ef->root->codegen, msg, node, buf_sprintf("overflow occurred here"));
        } else {
            zig_unreachable();
        }
        return true;
    }

    assert(out_val->ok);

    return false;
}

static EvalVar *find_var(EvalFn *ef, Buf *name) {
    int scope_index = ef->scope_stack.length - 1;
    while (scope_index >= 0) {
        EvalScope *scope = ef->scope_stack.at(scope_index);
        for (int var_i = 0; var_i < scope->vars.length; var_i += 1) {
            EvalVar *var = &scope->vars.at(var_i);
            if (buf_eql_buf(var->name, name)) {
                return var;
            }
        }
        scope_index -= 1;
    }

    return nullptr;
}

static bool eval_symbol_expr(EvalFn *ef, AstNode *node, ConstExprValue *out_val) {
    assert(node->type == NodeTypeSymbol);

    Buf *name = &node->data.symbol_expr.symbol;
    EvalVar *var = find_var(ef, name);
    assert(var);

    *out_val = var->value;

    return false;
}

static TypeTableEntry *resolve_expr_type(AstNode *node) {
    Expr *expr = get_resolved_expr(node);
    TypeTableEntry *type_entry = expr->type_entry;
    assert(type_entry->id == TypeTableEntryIdMetaType);
    ConstExprValue *const_val = &expr->const_val;
    assert(const_val->ok);
    return const_val->data.x_type;
}

static bool eval_container_init_expr(EvalFn *ef, AstNode *node, ConstExprValue *out_val) {
    assert(node->type == NodeTypeContainerInitExpr);

    AstNodeContainerInitExpr *container_init_expr = &node->data.container_init_expr;
    ContainerInitKind kind = container_init_expr->kind;

    if (container_init_expr->enum_type) {
        zig_panic("TODO");
    }

    TypeTableEntry *container_type = resolve_expr_type(container_init_expr->type);
    out_val->ok = true;

    if (container_type->id == TypeTableEntryIdStruct &&
        !container_type->data.structure.is_slice &&
        kind == ContainerInitKindStruct)
    {
        int expr_field_count = container_init_expr->entries.length;
        int actual_field_count = container_type->data.structure.src_field_count;
        assert(expr_field_count == actual_field_count);

        out_val->data.x_struct.fields = allocate<ConstExprValue*>(actual_field_count);

        for (int i = 0; i < expr_field_count; i += 1) {
            AstNode *val_field_node = container_init_expr->entries.at(i);
            assert(val_field_node->type == NodeTypeStructValueField);

            TypeStructField *type_field = val_field_node->data.struct_val_field.type_struct_field;
            int field_index = type_field->src_index;

            ConstExprValue src_field_val = {0};
            if (eval_expr(ef, val_field_node->data.struct_val_field.expr, &src_field_val)) return true;

            ConstExprValue *dest_field_val = allocate<ConstExprValue>(1);
            *dest_field_val = src_field_val;

            out_val->data.x_struct.fields[field_index] = dest_field_val;
            out_val->depends_on_compile_var = out_val->depends_on_compile_var ||
                src_field_val.depends_on_compile_var;
        }
    } else if (container_type->id == TypeTableEntryIdVoid) {
        return false;
    } else if (container_type->id == TypeTableEntryIdUnreachable) {
        ef->root->abort = true;
        ErrorMsg *msg = add_node_error(ef->root->codegen, ef->root->fn->fn_def_node,
                buf_sprintf("function evaluation reached unreachable expression"));
        add_error_note(ef->root->codegen, msg, ef->root->call_node, buf_sprintf("called from here"));
        add_error_note(ef->root->codegen, msg, node, buf_sprintf("unreachable expression here"));
        return true;
    } else if (container_type->id == TypeTableEntryIdStruct &&
               container_type->data.structure.is_slice &&
               kind == ContainerInitKindArray)
    {

        int elem_count = container_init_expr->entries.length;

        out_val->ok = true;
        out_val->data.x_array.fields = allocate<ConstExprValue*>(elem_count);

        for (int i = 0; i < elem_count; i += 1) {
            AstNode *elem_node = container_init_expr->entries.at(i);

            ConstExprValue *elem_val = allocate<ConstExprValue>(1);
            if (eval_expr(ef, elem_node, elem_val)) return true;

            assert(elem_val->ok);

            out_val->data.x_array.fields[i] = elem_val;
            out_val->depends_on_compile_var = out_val->depends_on_compile_var ||
                elem_val->depends_on_compile_var;
        }
    } else {
        zig_panic("TODO");
    }


    return false;
}

static bool eval_if_bool_expr(EvalFn *ef, AstNode *node, ConstExprValue *out_val) {
    assert(node->type == NodeTypeIfBoolExpr);

    ConstExprValue cond_val = {0};
    if (eval_expr(ef, node->data.if_bool_expr.condition, &cond_val)) return true;

    AstNode *exec_node = cond_val.data.x_bool ?
        node->data.if_bool_expr.then_block : node->data.if_bool_expr.else_node;

    if (exec_node) {
        if (eval_expr(ef, exec_node, out_val)) return true;
    }
    out_val->ok = true;
    return false;
}

void eval_const_expr_implicit_cast(CastOp cast_op,
        ConstExprValue *other_val, TypeTableEntry *other_type,
        ConstExprValue *const_val, TypeTableEntry *new_type)
{
    const_val->depends_on_compile_var = other_val->depends_on_compile_var;
    const_val->undef = other_val->undef;

    assert(other_val != const_val);
    switch (cast_op) {
        case CastOpNoCast:
            zig_unreachable();
        case CastOpNoop:
        case CastOpWidenOrShorten:
            *const_val = *other_val;
            break;
        case CastOpPointerReinterpret:
            if (other_type->id == TypeTableEntryIdPointer &&
                new_type->id == TypeTableEntryIdPointer)
            {
                TypeTableEntry *other_child_type = other_type->data.pointer.child_type;
                TypeTableEntry *new_child_type = new_type->data.pointer.child_type;

                if ((other_child_type->id == TypeTableEntryIdInt ||
                    other_child_type->id == TypeTableEntryIdFloat) &&
                    (new_child_type->id == TypeTableEntryIdInt ||
                    new_child_type->id == TypeTableEntryIdFloat))
                {
                    ConstExprValue **ptr_val = allocate<ConstExprValue*>(1);
                    *ptr_val = other_val->data.x_ptr.ptr[0];
                    const_val->data.x_ptr.ptr = ptr_val;
                    const_val->data.x_ptr.len = 1;
                    const_val->ok = true;
                    const_val->undef = other_val->undef;
                    const_val->depends_on_compile_var = other_val->depends_on_compile_var;
                } else {
                    zig_panic("TODO");
                }
            } else if (other_type->id == TypeTableEntryIdMaybe &&
                       new_type->id == TypeTableEntryIdMaybe)
            {
                if (!other_val->data.x_maybe) {
                    *const_val = *other_val;
                    break;
                }

                TypeTableEntry *other_ptr_type = other_type->data.maybe.child_type;
                TypeTableEntry *new_ptr_type = new_type->data.maybe.child_type;

                if (other_ptr_type->id == TypeTableEntryIdPointer &&
                    new_ptr_type->id == TypeTableEntryIdPointer) 
                {
                    TypeTableEntry *other_child_type = other_ptr_type->data.pointer.child_type;
                    TypeTableEntry *new_child_type = new_ptr_type->data.pointer.child_type;

                    if ((other_child_type->id == TypeTableEntryIdInt ||
                        other_child_type->id == TypeTableEntryIdFloat) &&
                        (new_child_type->id == TypeTableEntryIdInt ||
                        new_child_type->id == TypeTableEntryIdFloat))
                    {
                        ConstExprValue *ptr_parent = allocate<ConstExprValue>(1);
                        ConstExprValue **ptr_val = allocate<ConstExprValue*>(1);
                        *ptr_val = other_val->data.x_maybe->data.x_ptr.ptr[0];
                        ptr_parent->data.x_ptr.ptr = ptr_val;
                        ptr_parent->data.x_ptr.len = 1;
                        ptr_parent->ok = true;

                        const_val->data.x_maybe = ptr_parent;
                        const_val->ok = true;
                        const_val->undef = other_val->undef;
                        const_val->depends_on_compile_var = other_val->depends_on_compile_var;
                    } else {
                        zig_panic("TODO");
                    }
                } else {
                    zig_panic("TODO");
                }
            }
            break;
        case CastOpPtrToInt:
        case CastOpIntToPtr:
        case CastOpResizeSlice:
            // can't do it
            break;
        case CastOpToUnknownSizeArray:
            {
                assert(other_type->id == TypeTableEntryIdArray);

                ConstExprValue *all_fields = allocate<ConstExprValue>(2);
                ConstExprValue *ptr_field = &all_fields[0];
                ConstExprValue *len_field = &all_fields[1];

                const_val->data.x_struct.fields = allocate<ConstExprValue*>(2);
                const_val->data.x_struct.fields[0] = ptr_field;
                const_val->data.x_struct.fields[1] = len_field;

                ptr_field->ok = true;
                ptr_field->data.x_ptr.ptr = other_val->data.x_array.fields;
                ptr_field->data.x_ptr.len = other_type->data.array.len;

                len_field->ok = true;
                bignum_init_unsigned(&len_field->data.x_bignum, other_type->data.array.len);

                const_val->ok = true;
                break;
            }
        case CastOpMaybeWrap:
            const_val->data.x_maybe = other_val;
            const_val->ok = true;
            break;
        case CastOpErrorWrap:
            const_val->data.x_err.err = nullptr;
            const_val->data.x_err.payload = other_val;
            const_val->ok = true;
            break;
        case CastOpPureErrorWrap:
            const_val->data.x_err.err = other_val->data.x_err.err;
            const_val->ok = true;
            break;
        case CastOpErrToInt:
            {
                uint64_t value = other_val->data.x_err.err ? other_val->data.x_err.err->value : 0;
                bignum_init_unsigned(&const_val->data.x_bignum, value);
                const_val->ok = true;
                break;
            }
        case CastOpIntToFloat:
            bignum_cast_to_float(&const_val->data.x_bignum, &other_val->data.x_bignum);
            const_val->ok = true;
            break;
        case CastOpFloatToInt:
            bignum_cast_to_int(&const_val->data.x_bignum, &other_val->data.x_bignum);
            const_val->ok = true;
            break;
        case CastOpBoolToInt:
            bignum_init_unsigned(&const_val->data.x_bignum, other_val->data.x_bool ? 1 : 0);
            const_val->ok = true;
            break;
        case CastOpIntToEnum:
            {
                uint64_t value = other_val->data.x_bignum.data.x_uint;
                assert(new_type->id == TypeTableEntryIdEnum);
                assert(value < new_type->data.enumeration.field_count);
                const_val->data.x_enum.tag = value;
                const_val->data.x_enum.payload = NULL;
                const_val->ok = true;
                break;
            }
    }
}

static bool int_type_depends_on_compile_var(CodeGen *g, TypeTableEntry *int_type) {
    assert(int_type->id == TypeTableEntryIdInt);

    for (int i = 0; i < CIntTypeCount; i += 1) {
        if (int_type == g->builtin_types.entry_c_int[i]) {
            return true;
        }
    }
    return false;
}

void eval_min_max_value(CodeGen *g, TypeTableEntry *type_entry, ConstExprValue *const_val, bool is_max) {
    if (type_entry->id == TypeTableEntryIdInt) {
        const_val->ok = true;
        const_val->depends_on_compile_var = int_type_depends_on_compile_var(g, type_entry);
        if (is_max) {
            if (type_entry->data.integral.is_signed) {
                int64_t val = max_signed_val(type_entry);
                bignum_init_signed(&const_val->data.x_bignum, val);
            } else {
                uint64_t val = max_unsigned_val(type_entry);
                bignum_init_unsigned(&const_val->data.x_bignum, val);
            }
        } else {
            if (type_entry->data.integral.is_signed) {
                int64_t val = min_signed_val(type_entry);
                bignum_init_signed(&const_val->data.x_bignum, val);
            } else {
                bignum_init_unsigned(&const_val->data.x_bignum, 0);
            }
        }
    } else if (type_entry->id == TypeTableEntryIdFloat) {
        zig_panic("TODO analyze_min_max_value float");
    } else if (type_entry->id == TypeTableEntryIdBool) {
        const_val->ok = true;
        const_val->data.x_bool = is_max;
    } else {
        zig_unreachable();
    }
}

static bool eval_min_max(EvalFn *ef, AstNode *node, ConstExprValue *out_val, bool is_max) {
    assert(node->type == NodeTypeFnCallExpr);
    AstNode *type_node = node->data.fn_call_expr.params.at(0);
    TypeTableEntry *type_entry = resolve_expr_type(type_node);
    eval_min_max_value(ef->root->codegen, type_entry, out_val, is_max);
    return false;
}

static bool eval_div_exact(EvalFn *ef, AstNode *node, ConstExprValue *out_val) {
    assert(node->type == NodeTypeFnCallExpr);
    AstNode *op1_node = node->data.fn_call_expr.params.at(0);
    AstNode *op2_node = node->data.fn_call_expr.params.at(1);

    TypeTableEntry *type_entry = get_resolved_expr(op1_node)->type_entry;
    assert(type_entry->id == TypeTableEntryIdInt);

    ConstExprValue op1_val = {0};
    if (eval_expr(ef, op1_node, &op1_val)) return true;

    ConstExprValue op2_val = {0};
    if (eval_expr(ef, op2_node, &op2_val)) return true;

    if (op2_val.data.x_bignum.data.x_uint == 0) {
        ErrorMsg *msg = add_node_error(ef->root->codegen, ef->root->fn->fn_def_node,
                buf_sprintf("function evaluation caused division by zero"));
        add_error_note(ef->root->codegen, msg, ef->root->call_node, buf_sprintf("called from here"));
        add_error_note(ef->root->codegen, msg, node, buf_sprintf("division by zero here"));
        return true;
    }

    bignum_div(&out_val->data.x_bignum, &op1_val.data.x_bignum, &op2_val.data.x_bignum);

    BigNum orig_bn;
    bignum_mul(&orig_bn, &out_val->data.x_bignum, &op2_val.data.x_bignum);

    if (bignum_cmp_neq(&orig_bn, &op1_val.data.x_bignum)) {
        ErrorMsg *msg = add_node_error(ef->root->codegen, ef->root->fn->fn_def_node,
                buf_sprintf("function evaluation violated exact division"));
        add_error_note(ef->root->codegen, msg, ef->root->call_node, buf_sprintf("called from here"));
        add_error_note(ef->root->codegen, msg, node, buf_sprintf("exact division violation here"));
        return true;
    }

    out_val->ok = true;
    out_val->depends_on_compile_var = op1_val.depends_on_compile_var || op2_val.depends_on_compile_var;
    return false;
}

static bool eval_fn_with_overflow(EvalFn *ef, AstNode *node, ConstExprValue *out_val,
    bool (*bignum_fn)(BigNum *dest, BigNum *op1, BigNum *op2))
{
    assert(node->type == NodeTypeFnCallExpr);

    AstNode *type_node = node->data.fn_call_expr.params.at(0);
    TypeTableEntry *int_type = resolve_expr_type(type_node);
    assert(int_type->id == TypeTableEntryIdInt);

    AstNode *op1_node = node->data.fn_call_expr.params.at(1);
    AstNode *op2_node = node->data.fn_call_expr.params.at(2);
    AstNode *result_node = node->data.fn_call_expr.params.at(3);

    ConstExprValue op1_val = {0};
    if (eval_expr(ef, op1_node, &op1_val)) return true;

    ConstExprValue op2_val = {0};
    if (eval_expr(ef, op2_node, &op2_val)) return true;

    ConstExprValue result_ptr_val = {0};
    if (eval_expr(ef, result_node, &result_ptr_val)) return true;

    ConstExprValue *result_val = result_ptr_val.data.x_ptr.ptr[0];

    out_val->ok = true;
    bool overflow = bignum_fn(&result_val->data.x_bignum, &op1_val.data.x_bignum, &op2_val.data.x_bignum);

    overflow = overflow || !bignum_fits_in_bits(&result_val->data.x_bignum,
            int_type->data.integral.bit_count, int_type->data.integral.is_signed);

    out_val->data.x_bool = overflow;

    if (overflow) {
        bignum_truncate(&result_val->data.x_bignum, int_type->data.integral.bit_count);
    }

    return false;
}

static bool eval_fn_call_builtin(EvalFn *ef, AstNode *node, ConstExprValue *out_val) {
    assert(node->type == NodeTypeFnCallExpr);

    BuiltinFnEntry *builtin_fn = node->data.fn_call_expr.builtin_fn;
    switch (builtin_fn->id) {
        case BuiltinFnIdMaxValue:
            return eval_min_max(ef, node, out_val, true);
        case BuiltinFnIdMinValue:
            return eval_min_max(ef, node, out_val, false);
        case BuiltinFnIdMulWithOverflow:
            return eval_fn_with_overflow(ef, node, out_val, bignum_mul);
        case BuiltinFnIdAddWithOverflow:
            return eval_fn_with_overflow(ef, node, out_val, bignum_add);
        case BuiltinFnIdSubWithOverflow:
            return eval_fn_with_overflow(ef, node, out_val, bignum_sub);
        case BuiltinFnIdShlWithOverflow:
            return eval_fn_with_overflow(ef, node, out_val, bignum_shl);
        case BuiltinFnIdFence:
            return false;
        case BuiltinFnIdDivExact:
            return eval_div_exact(ef, node, out_val);
        case BuiltinFnIdMemcpy:
        case BuiltinFnIdMemset:
        case BuiltinFnIdSizeof:
        case BuiltinFnIdAlignof:
        case BuiltinFnIdMemberCount:
        case BuiltinFnIdTypeof:
        case BuiltinFnIdCInclude:
        case BuiltinFnIdCDefine:
        case BuiltinFnIdCUndef:
        case BuiltinFnIdCompileVar:
        case BuiltinFnIdConstEval:
        case BuiltinFnIdCtz:
        case BuiltinFnIdClz:
        case BuiltinFnIdImport:
        case BuiltinFnIdCImport:
        case BuiltinFnIdErrName:
        case BuiltinFnIdEmbedFile:
        case BuiltinFnIdCmpExchange:
        case BuiltinFnIdTruncate:
            zig_panic("TODO");
        case BuiltinFnIdBreakpoint:
        case BuiltinFnIdInvalid:
        case BuiltinFnIdFrameAddress:
        case BuiltinFnIdReturnAddress:
        case BuiltinFnIdCompileErr:
        case BuiltinFnIdIntType:
            zig_unreachable();
    }

    return false;
}

static bool eval_fn_call_expr(EvalFn *ef, AstNode *node, ConstExprValue *out_val) {
    assert(node->type == NodeTypeFnCallExpr);

    AstNode *fn_ref_expr = node->data.fn_call_expr.fn_ref_expr;
    CastOp cast_op = node->data.fn_call_expr.cast_op;
    if (node->data.fn_call_expr.is_builtin) {
        return eval_fn_call_builtin(ef, node, out_val);
    } else if (cast_op != CastOpNoCast) {
        TypeTableEntry *new_type = resolve_expr_type(fn_ref_expr);
        AstNode *param_node = node->data.fn_call_expr.params.at(0);
        TypeTableEntry *old_type = get_resolved_expr(param_node)->type_entry;
        ConstExprValue param_val = {0};
        if (eval_expr(ef, param_node, &param_val)) return true;
        eval_const_expr_implicit_cast(cast_op, &param_val, old_type, out_val, new_type);
        return false;
    }

    FnTableEntry *fn_table_entry = node->data.fn_call_expr.fn_entry;

    if (fn_ref_expr->type == NodeTypeFieldAccessExpr &&
        fn_ref_expr->data.field_access_expr.is_member_fn)
    {
        zig_panic("TODO");
    }

    if (!fn_table_entry) {
        ConstExprValue fn_val = {0};
        if (eval_expr(ef, fn_ref_expr, &fn_val)) return true;
        fn_table_entry = fn_val.data.x_fn;
    }

    int param_count = node->data.fn_call_expr.params.length;
    ConstExprValue *args = allocate<ConstExprValue>(param_count);
    for (int call_i = 0; call_i < param_count; call_i += 1) {
        AstNode *param_expr_node = node->data.fn_call_expr.params.at(call_i);
        ConstExprValue *param_val = &args[call_i];
        if (eval_expr(ef, param_expr_node, param_val)) return true;
    }

    ef->root->branches_used += 1;

    eval_fn_args(ef->root, fn_table_entry, args, out_val);
    return false;
}

static bool eval_field_access_expr(EvalFn *ef, AstNode *node, ConstExprValue *out_val) {
    assert(node->type == NodeTypeFieldAccessExpr);

    AstNode *struct_expr = node->data.field_access_expr.struct_expr;
    TypeTableEntry *struct_type = get_resolved_expr(struct_expr)->type_entry;

    if (struct_type->id == TypeTableEntryIdArray) {
        Buf *name = &node->data.field_access_expr.field_name;
        assert(buf_eql_str(name, "len"));
        zig_panic("TODO");
    } else if (struct_type->id == TypeTableEntryIdStruct || (struct_type->id == TypeTableEntryIdPointer &&
               struct_type->data.pointer.child_type->id == TypeTableEntryIdStruct))
    {
        TypeStructField *tsf = node->data.field_access_expr.type_struct_field;
        assert(tsf);
        if (struct_type->id == TypeTableEntryIdStruct) {
            ConstExprValue struct_val = {0};
            if (eval_expr(ef, struct_expr, &struct_val)) return true;
            ConstExprValue *field_value = struct_val.data.x_struct.fields[tsf->src_index];
            *out_val = *field_value;
            assert(out_val->ok);
        } else {
            zig_panic("TODO");
        }
    } else if (struct_type->id == TypeTableEntryIdMetaType) {
        TypeTableEntry *child_type = resolve_expr_type(struct_expr);
        if (child_type->id == TypeTableEntryIdPureError) {
            *out_val = get_resolved_expr(node)->const_val;
        } else {
            zig_panic("TODO");
        }
    } else if (struct_type->id == TypeTableEntryIdNamespace) {
        zig_panic("TODO");
    } else {
        zig_unreachable();
    }

    return false;
}

static bool eval_for_expr(EvalFn *ef, AstNode *node, ConstExprValue *out_val) {
    assert(node->type == NodeTypeForExpr);

    AstNode *array_node = node->data.for_expr.array_expr;
    AstNode *elem_node = node->data.for_expr.elem_node;
    AstNode *index_node = node->data.for_expr.index_node;
    AstNode *body_node = node->data.for_expr.body;

    TypeTableEntry *array_type = get_resolved_expr(array_node)->type_entry;

    ConstExprValue array_val = {0};
    if (eval_expr(ef, array_node, &array_val)) return true;

    assert(elem_node->type == NodeTypeSymbol);
    Buf *elem_var_name = &elem_node->data.symbol_expr.symbol;

    if (node->data.for_expr.elem_is_ptr) {
        zig_panic("TODO");
    }

    Buf *index_var_name = nullptr;
    if (index_node) {
        assert(index_node->type == NodeTypeSymbol);
        index_var_name = &index_node->data.symbol_expr.symbol;
    }

    uint64_t it_index = 0;
    uint64_t array_len;
    ConstExprValue **array_ptr_val;
    if (array_type->id == TypeTableEntryIdArray) {
        array_len = array_type->data.array.len;
        array_ptr_val = array_val.data.x_array.fields;
    } else if (array_type->id == TypeTableEntryIdStruct) {
        ConstExprValue *len_field_val = array_val.data.x_struct.fields[1];
        array_len = len_field_val->data.x_bignum.data.x_uint;
        array_ptr_val = array_val.data.x_struct.fields[0]->data.x_ptr.ptr;
    } else {
        zig_unreachable();
    }

    EvalScope *my_scope = allocate<EvalScope>(1);
    my_scope->block_context = body_node->block_context;
    ef->scope_stack.append(my_scope);

    for (; it_index < array_len; it_index += 1) {
        my_scope->vars.resize(0);

        if (index_var_name) {
            my_scope->vars.add_one();
            EvalVar *index_var = &my_scope->vars.last();
            index_var->name = index_var_name;
            memset(&index_var->value, 0, sizeof(ConstExprValue));
            index_var->value.ok = true;
            bignum_init_unsigned(&index_var->value.data.x_bignum, it_index);
        }
        {
            my_scope->vars.add_one();
            EvalVar *elem_var = &my_scope->vars.last();
            elem_var->name = elem_var_name;
            elem_var->value = *array_ptr_val[it_index];
        }

        ConstExprValue body_val = {0};
        if (eval_expr(ef, body_node, &body_val)) return true;

        ef->root->branches_used += 1;
    }

    ef->scope_stack.pop();

    return false;
}

static bool eval_array_access_expr(EvalFn *ef, AstNode *node, ConstExprValue *out_val) {
    assert(node->type == NodeTypeArrayAccessExpr);

    AstNode *array_ref_node = node->data.array_access_expr.array_ref_expr;
    AstNode *index_node = node->data.array_access_expr.subscript;

    TypeTableEntry *array_type = get_resolved_expr(array_ref_node)->type_entry;

    ConstExprValue array_val = {0};
    if (eval_expr(ef, array_ref_node, &array_val)) return true;

    ConstExprValue index_val = {0};
    if (eval_expr(ef, index_node, &index_val)) return true;
    uint64_t index_int = index_val.data.x_bignum.data.x_uint;

    if (array_type->id == TypeTableEntryIdPointer) {
        if (index_int >= array_val.data.x_ptr.len) {
            zig_panic("TODO");
        }
        *out_val = *array_val.data.x_ptr.ptr[index_int];
    } else if (array_type->id == TypeTableEntryIdStruct) {
        assert(array_type->data.structure.is_slice);

        ConstExprValue *len_value = array_val.data.x_struct.fields[1];
        uint64_t len_int = len_value->data.x_bignum.data.x_uint;
        if (index_int >= len_int) {
            zig_panic("TODO");
        }

        ConstExprValue *ptr_value = array_val.data.x_struct.fields[0];
        *out_val = *ptr_value->data.x_ptr.ptr[index_int];
    } else if (array_type->id == TypeTableEntryIdArray) {
        uint64_t array_len = array_type->data.array.len;
        if (index_int >= array_len) {
            zig_panic("TODO");
        }
        *out_val = *array_val.data.x_array.fields[index_int];
    } else {
        zig_unreachable();
    }

    return false;
}

static bool eval_bool_literal_expr(EvalFn *ef, AstNode *node, ConstExprValue *out_val) {
    assert(node->type == NodeTypeBoolLiteral);

    out_val->ok = true;
    out_val->data.x_bool = node->data.bool_literal.value;

    return false;
}

static bool eval_prefix_op_expr(EvalFn *ef, AstNode *node, ConstExprValue *out_val) {
    assert(node->type == NodeTypePrefixOpExpr);

    PrefixOp prefix_op = node->data.prefix_op_expr.prefix_op;
    AstNode *expr_node = node->data.prefix_op_expr.primary_expr;

    ConstExprValue expr_val = {0};
    if (eval_expr(ef, expr_node, &expr_val)) return true;

    TypeTableEntry *expr_type = get_resolved_expr(expr_node)->type_entry;

    switch (prefix_op) {
        case PrefixOpBoolNot:
            *out_val = expr_val;
            out_val->data.x_bool = !out_val->data.x_bool;
            break;
        case PrefixOpDereference:
            assert(expr_type->id == TypeTableEntryIdPointer);
            *out_val = *expr_val.data.x_ptr.ptr[0];
            break;
        case PrefixOpAddressOf:
        case PrefixOpConstAddressOf:
            {
                ConstExprValue *child_val = allocate<ConstExprValue>(1);
                *child_val = expr_val;

                ConstExprValue **ptr_val = allocate<ConstExprValue*>(1);
                *ptr_val = child_val;

                out_val->data.x_ptr.ptr = ptr_val;
                out_val->data.x_ptr.len = 1;
                out_val->ok = true;
                break;
            }
        case PrefixOpNegation:
            if (expr_type->id == TypeTableEntryIdInt) {
                assert(expr_type->data.integral.is_signed);
                bignum_negate(&out_val->data.x_bignum, &expr_val.data.x_bignum);
                out_val->ok = true;
                bool overflow = !bignum_fits_in_bits(&out_val->data.x_bignum,
                        expr_type->data.integral.bit_count, expr_type->data.integral.is_signed);
                if (expr_type->data.integral.is_wrapping) {
                    if (overflow) {
                        out_val->data.x_bignum.is_negative = true;
                    }
                } else if (overflow) {
                    ErrorMsg *msg = add_node_error(ef->root->codegen, ef->root->fn->fn_def_node,
                            buf_sprintf("function evaluation caused overflow"));
                    add_error_note(ef->root->codegen, msg, ef->root->call_node, buf_sprintf("called from here"));
                    add_error_note(ef->root->codegen, msg, node, buf_sprintf("overflow occurred here"));
                    return true;
                }
            } else if (expr_type->id == TypeTableEntryIdFloat) {
                zig_panic("TODO");
            } else {
                zig_unreachable();
            }
            break;
        case PrefixOpBinNot:
        case PrefixOpMaybe:
        case PrefixOpError:
        case PrefixOpUnwrapError:
        case PrefixOpUnwrapMaybe:
            zig_panic("TODO");
        case PrefixOpInvalid:
            zig_unreachable();
    }

    return false;
}

static bool eval_var_decl_expr(EvalFn *ef, AstNode *node, ConstExprValue *out_val) {
    assert(node->type == NodeTypeVariableDeclaration);

    assert(node->data.variable_declaration.expr);

    EvalScope *my_scope = ef->scope_stack.at(ef->scope_stack.length - 1);

    my_scope->vars.add_one();
    EvalVar *var = &my_scope->vars.last();
    var->name = &node->data.variable_declaration.symbol;

    if (eval_expr(ef, node->data.variable_declaration.expr, &var->value)) return true;

    out_val->ok = true;

    return false;
}

static bool eval_number_literal_expr(EvalFn *ef, AstNode *node, ConstExprValue *out_val) {
    assert(node->type == NodeTypeNumberLiteral);
    assert(!node->data.number_literal.overflow);

    out_val->ok = true;
    if (node->data.number_literal.kind == NumLitUInt) {
        bignum_init_unsigned(&out_val->data.x_bignum, node->data.number_literal.data.x_uint);
    } else if (node->data.number_literal.kind == NumLitFloat) {
        bignum_init_float(&out_val->data.x_bignum, node->data.number_literal.data.x_float);
    } else {
        zig_unreachable();
    }

    return false;
}

static bool eval_char_literal_expr(EvalFn *ef, AstNode *node, ConstExprValue *out_val) {
    assert(node->type == NodeTypeCharLiteral);

    out_val->ok = true;
    bignum_init_unsigned(&out_val->data.x_bignum, node->data.char_literal.value);

    return false;
}

static bool eval_while_expr(EvalFn *ef, AstNode *node, ConstExprValue *out_val) {
    assert(node->type == NodeTypeWhileExpr);

    AstNode *cond_node = node->data.while_expr.condition;
    AstNode *body_node = node->data.while_expr.body;
    AstNode *continue_expr_node = node->data.while_expr.continue_expr;

    EvalScope *my_scope = allocate<EvalScope>(1);
    my_scope->block_context = body_node->block_context;
    ef->scope_stack.append(my_scope);

    for (;;) {
        my_scope->vars.resize(0);

        ConstExprValue cond_val = {0};
        if (eval_expr(ef, cond_node, &cond_val)) return true;

        if (!cond_val.data.x_bool) break;

        ConstExprValue body_val = {0};
        if (eval_expr(ef, body_node, &body_val)) return true;

        if (continue_expr_node) {
            ConstExprValue continue_expr_val = {0};
            if (eval_expr(ef, continue_expr_node, &continue_expr_val)) return true;
        }

        ef->root->branches_used += 1;
    }

    ef->scope_stack.pop();

    return false;
}

static bool eval_expr(EvalFn *ef, AstNode *node, ConstExprValue *out) {
    if (ef->root->branches_used > ef->root->branch_quota) {
        ef->root->exceeded_quota_node = node;
        return true;
    }
    ConstExprValue *const_val = &get_resolved_expr(node)->const_val;
    if (const_val->ok) {
        *out = *const_val;
        return false;
    }
    switch (node->type) {
        case NodeTypeBlock:
            return eval_block(ef, node, out);
        case NodeTypeReturnExpr:
            return eval_return(ef, node, out);
        case NodeTypeBinOpExpr:
            return eval_bin_op_expr(ef, node, out);
        case NodeTypeSymbol:
            return eval_symbol_expr(ef, node, out);
        case NodeTypeContainerInitExpr:
            return eval_container_init_expr(ef, node, out);
        case NodeTypeIfBoolExpr:
            return eval_if_bool_expr(ef, node, out);
        case NodeTypeFnCallExpr:
            return eval_fn_call_expr(ef, node, out);
        case NodeTypeFieldAccessExpr:
            return eval_field_access_expr(ef, node, out);
        case NodeTypeForExpr:
            return eval_for_expr(ef, node, out);
        case NodeTypeArrayAccessExpr:
            return eval_array_access_expr(ef, node, out);
        case NodeTypeBoolLiteral:
            return eval_bool_literal_expr(ef, node, out);
        case NodeTypePrefixOpExpr:
            return eval_prefix_op_expr(ef, node, out);
        case NodeTypeVariableDeclaration:
            return eval_var_decl_expr(ef, node, out);
        case NodeTypeNumberLiteral:
            return eval_number_literal_expr(ef, node, out);
        case NodeTypeCharLiteral:
            return eval_char_literal_expr(ef, node, out);
        case NodeTypeWhileExpr:
            return eval_while_expr(ef, node, out);
        case NodeTypeDefer:
        case NodeTypeErrorValueDecl:
        case NodeTypeUnwrapErrorExpr:
        case NodeTypeStringLiteral:
        case NodeTypeSliceExpr:
        case NodeTypeNullLiteral:
        case NodeTypeUndefinedLiteral:
        case NodeTypeIfVarExpr:
        case NodeTypeSwitchExpr:
        case NodeTypeSwitchProng:
        case NodeTypeSwitchRange:
        case NodeTypeLabel:
        case NodeTypeGoto:
        case NodeTypeBreak:
        case NodeTypeContinue:
        case NodeTypeContainerDecl:
        case NodeTypeStructField:
        case NodeTypeStructValueField:
        case NodeTypeArrayType:
        case NodeTypeErrorType:
        case NodeTypeTypeLiteral:
            zig_panic("TODO");
        case NodeTypeRoot:
        case NodeTypeFnProto:
        case NodeTypeFnDef:
        case NodeTypeFnDecl:
        case NodeTypeUse:
        case NodeTypeAsmExpr:
        case NodeTypeParamDecl:
        case NodeTypeDirective:
        case NodeTypeTypeDecl:
            zig_unreachable();
    }
    zig_unreachable();
}

static bool eval_fn_args(EvalFnRoot *efr, FnTableEntry *fn, ConstExprValue *args, ConstExprValue *out_val) {
    AstNode *acting_proto_node;
    if (fn->proto_node->data.fn_proto.generic_proto_node) {
        acting_proto_node = fn->proto_node->data.fn_proto.generic_proto_node;
    } else {
        acting_proto_node = fn->proto_node;
    }

    EvalFn ef = {0};
    ef.root = efr;
    ef.fn = fn;
    ef.return_expr = out_val;

    EvalScope *root_scope = allocate<EvalScope>(1);
    root_scope->block_context = fn->fn_def_node->data.fn_def.body->block_context;
    ef.scope_stack.append(root_scope);

    int param_count = acting_proto_node->data.fn_proto.params.length;
    for (int proto_i = 0; proto_i < param_count; proto_i += 1) {
        AstNode *decl_param_node = acting_proto_node->data.fn_proto.params.at(proto_i);
        assert(decl_param_node->type == NodeTypeParamDecl);

        ConstExprValue *src_const_val = &args[proto_i];
        assert(src_const_val->ok);

        root_scope->vars.add_one();
        EvalVar *eval_var = &root_scope->vars.last();
        eval_var->name = &decl_param_node->data.param_decl.name;
        eval_var->value = *src_const_val;
    }

    return eval_expr(&ef, fn->fn_def_node->data.fn_def.body, out_val);
}

bool eval_fn(CodeGen *g, AstNode *node, FnTableEntry *fn, ConstExprValue *out_val,
        int branch_quota, AstNode *struct_node)
{
    assert(node->type == NodeTypeFnCallExpr);

    EvalFnRoot efr = {0};
    efr.codegen = g;
    efr.fn = fn;
    efr.call_node = node;
    efr.branch_quota = branch_quota;

    AstNode *acting_proto_node;
    if (fn->proto_node->data.fn_proto.generic_proto_node) {
        acting_proto_node = fn->proto_node->data.fn_proto.generic_proto_node;
    } else {
        acting_proto_node = fn->proto_node;
    }

    int call_param_count = node->data.fn_call_expr.params.length;
    int proto_param_count = acting_proto_node->data.fn_proto.params.length;
    ConstExprValue *args = allocate<ConstExprValue>(proto_param_count);
    int next_arg_index = 0;
    if (struct_node) {
        ConstExprValue *struct_val = &get_resolved_expr(struct_node)->const_val;
        assert(struct_val->ok);
        args[next_arg_index] = *struct_val;
        next_arg_index += 1;
    }
    for (int call_index = 0; call_index < call_param_count; call_index += 1) {
        AstNode *call_param_node = node->data.fn_call_expr.params.at(call_index);
        ConstExprValue *src_const_val = &get_resolved_expr(call_param_node)->const_val;
        assert(src_const_val->ok);
        args[next_arg_index] = *src_const_val;
        next_arg_index += 1;
    }
    eval_fn_args(&efr, fn, args, out_val);

    if (efr.exceeded_quota_node) {
        ErrorMsg *msg = add_node_error(g, fn->fn_def_node,
                buf_sprintf("function evaluation exceeded %d branches", efr.branch_quota));

        add_error_note(g, msg, efr.call_node, buf_sprintf("called from here"));
        add_error_note(g, msg, efr.exceeded_quota_node, buf_sprintf("quota exceeded here"));
        return true;
    }

    if (efr.abort) {
        return true;
    }

    assert(out_val->ok);
    return false;
}

