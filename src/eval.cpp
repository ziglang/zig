#include "eval.hpp"
#include "analyze.hpp"
#include "error.hpp"

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
        case TypeTableEntryIdNullLit:
            zig_panic("TODO");
        case TypeTableEntryIdMaybe:
            zig_panic("TODO");
        case TypeTableEntryIdErrorUnion:
            zig_panic("TODO");
        case TypeTableEntryIdTypeDecl:
            zig_panic("TODO");
        case TypeTableEntryIdNamespace:
            zig_panic("TODO");
        case TypeTableEntryIdBlock:
            zig_panic("TODO");
        case TypeTableEntryIdGenericFn:
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdVar:
            zig_unreachable();
    }
    zig_unreachable();
}


static bool eval_bool_bin_op_bool(bool a, BinOpType bin_op, bool b) {
    if (bin_op == BinOpTypeBoolOr || bin_op == BinOpTypeAssignBoolOr) {
        return a || b;
    } else if (bin_op == BinOpTypeBoolAnd || bin_op == BinOpTypeAssignBoolAnd) {
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
        TypeTableEntry *type, bool wrapping_op)
{
    bool overflow = bignum_fn(&out_val->data.x_bignum, &op1_val->data.x_bignum, &op2_val->data.x_bignum);
    if (overflow) {
        return ErrorOverflow;
    }

    if (type->id == TypeTableEntryIdInt && !bignum_fits_in_bits(&out_val->data.x_bignum,
                type->data.integral.bit_count, type->data.integral.is_signed))
    {
        if (wrapping_op) {
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

    out_val->special = ConstValSpecialStatic;
    out_val->depends_on_compile_var = op1_val->depends_on_compile_var || op2_val->depends_on_compile_var;
    return 0;
}

int eval_const_expr_bin_op(ConstExprValue *op1_val, TypeTableEntry *op1_type,
        BinOpType bin_op, ConstExprValue *op2_val, TypeTableEntry *op2_type, ConstExprValue *out_val)
{
    assert(op1_val->special != ConstValSpecialRuntime);
    assert(op2_val->special != ConstValSpecialRuntime);
    assert(op1_type->id != TypeTableEntryIdInvalid);
    assert(op2_type->id != TypeTableEntryIdInvalid);

    switch (bin_op) {
        case BinOpTypeAssign:
            *out_val = *op2_val;
            return 0;
        case BinOpTypeBoolOr:
        case BinOpTypeBoolAnd:
        case BinOpTypeAssignBoolAnd:
        case BinOpTypeAssignBoolOr:
            assert(op1_type->id == TypeTableEntryIdBool);
            assert(op2_type->id == TypeTableEntryIdBool);
            out_val->data.x_bool = eval_bool_bin_op_bool(op1_val->data.x_bool, bin_op, op2_val->data.x_bool);
            out_val->special = ConstValSpecialStatic;
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
                out_val->special = ConstValSpecialStatic;
                return 0;
            }
        case BinOpTypeAdd:
        case BinOpTypeAssignPlus:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_add, op1_type, false);
        case BinOpTypeAddWrap:
        case BinOpTypeAssignPlusWrap:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_add, op1_type, true);
        case BinOpTypeBinOr:
        case BinOpTypeAssignBitOr:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_or, op1_type, false);
        case BinOpTypeBinXor:
        case BinOpTypeAssignBitXor:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_xor, op1_type, false);
        case BinOpTypeBinAnd:
        case BinOpTypeAssignBitAnd:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_and, op1_type, false);
        case BinOpTypeBitShiftLeft:
        case BinOpTypeAssignBitShiftLeft:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_shl, op1_type, false);
        case BinOpTypeBitShiftLeftWrap:
        case BinOpTypeAssignBitShiftLeftWrap:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_shl, op1_type, true);
        case BinOpTypeBitShiftRight:
        case BinOpTypeAssignBitShiftRight:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_shr, op1_type, false);
        case BinOpTypeSub:
        case BinOpTypeAssignMinus:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_sub, op1_type, false);
        case BinOpTypeSubWrap:
        case BinOpTypeAssignMinusWrap:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_sub, op1_type, true);
        case BinOpTypeMult:
        case BinOpTypeAssignTimes:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_mul, op1_type, false);
        case BinOpTypeMultWrap:
        case BinOpTypeAssignTimesWrap:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_mul, op1_type, true);
        case BinOpTypeDiv:
        case BinOpTypeAssignDiv:
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
                    return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_div, op1_type, false);
                }
            }
        case BinOpTypeMod:
        case BinOpTypeAssignMod:
            return eval_const_expr_bin_op_bignum(op1_val, op2_val, out_val, bignum_mod, op1_type, false);
        case BinOpTypeUnwrapMaybe:
            zig_panic("TODO");
        case BinOpTypeArrayCat:
        case BinOpTypeArrayMult:
        case BinOpTypeInvalid:
            zig_unreachable();
    }
    zig_unreachable();
}

void eval_const_expr_implicit_cast(CastOp cast_op,
        ConstExprValue *other_val, TypeTableEntry *other_type,
        ConstExprValue *const_val, TypeTableEntry *new_type)
{
    const_val->depends_on_compile_var = other_val->depends_on_compile_var;
    const_val->special = other_val->special;

    assert(other_val != const_val);
    switch (cast_op) {
        case CastOpNoCast:
            zig_unreachable();
        case CastOpNoop:
        case CastOpWidenOrShorten:
            *const_val = *other_val;
            break;
        case CastOpPointerReinterpret:
            zig_panic("TODO compile time pointer reinterpret");
            break;
        case CastOpPtrToInt:
        case CastOpIntToPtr:
        case CastOpResizeSlice:
        case CastOpBytesToSlice:
            // can't do it
            break;
        case CastOpToUnknownSizeArray:
            zig_panic("TODO compile time implicit to unknown size array");
            break;
        case CastOpMaybeWrap:
            const_val->data.x_maybe = other_val;
            const_val->special = ConstValSpecialStatic;
            break;
        case CastOpNullToMaybe:
            const_val->data.x_maybe = nullptr;
            const_val->special = ConstValSpecialStatic;
            break;
        case CastOpErrorWrap:
            const_val->data.x_err.err = nullptr;
            const_val->data.x_err.payload = other_val;
            const_val->special = ConstValSpecialStatic;
            break;
        case CastOpPureErrorWrap:
            const_val->data.x_err.err = other_val->data.x_err.err;
            const_val->special = ConstValSpecialStatic;
            break;
        case CastOpErrToInt:
            {
                uint64_t value = other_val->data.x_err.err ? other_val->data.x_err.err->value : 0;
                bignum_init_unsigned(&const_val->data.x_bignum, value);
                const_val->special = ConstValSpecialStatic;
                break;
            }
        case CastOpIntToFloat:
            bignum_cast_to_float(&const_val->data.x_bignum, &other_val->data.x_bignum);
            const_val->special = ConstValSpecialStatic;
            break;
        case CastOpFloatToInt:
            bignum_cast_to_int(&const_val->data.x_bignum, &other_val->data.x_bignum);
            const_val->special = ConstValSpecialStatic;
            break;
        case CastOpBoolToInt:
            bignum_init_unsigned(&const_val->data.x_bignum, other_val->data.x_bool ? 1 : 0);
            const_val->special = ConstValSpecialStatic;
            break;
        case CastOpIntToEnum:
            {
                uint64_t value = other_val->data.x_bignum.data.x_uint;
                assert(new_type->id == TypeTableEntryIdEnum);
                assert(value < new_type->data.enumeration.src_field_count);
                const_val->data.x_enum.tag = value;
                const_val->data.x_enum.payload = NULL;
                const_val->special = ConstValSpecialStatic;
                break;
            }
        case CastOpEnumToInt:
            bignum_init_unsigned(&const_val->data.x_bignum, other_val->data.x_enum.tag);
            const_val->special = ConstValSpecialStatic;
            break;
    }
}

static bool int_type_depends_on_compile_var(CodeGen *g, TypeTableEntry *int_type) {
    assert(int_type->id == TypeTableEntryIdInt);

    for (size_t i = 0; i < CIntTypeCount; i += 1) {
        if (int_type == g->builtin_types.entry_c_int[i]) {
            return true;
        }
    }
    return false;
}

void eval_min_max_value(CodeGen *g, TypeTableEntry *type_entry, ConstExprValue *const_val, bool is_max) {
    if (type_entry->id == TypeTableEntryIdInt) {
        const_val->special = ConstValSpecialStatic;
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
        const_val->special = ConstValSpecialStatic;
        const_val->data.x_bool = is_max;
    } else {
        zig_unreachable();
    }
}
