//! Analyzed Intermediate Representation.
//! This data is produced by Sema and consumed by codegen.
//! Unlike ZIR where there is one instance for an entire source file, each function
//! gets its own `Air` instance.

const std = @import("std");
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const Module = @import("Module.zig");
const assert = std.debug.assert;
const Air = @This();

instructions: std.MultiArrayList(Inst).Slice,
/// The meaning of this data is determined by `Inst.Tag` value.
/// The first few indexes are reserved. See `ExtraIndex` for the values.
extra: []const u32,
values: []const Value,

pub const ExtraIndex = enum(u32) {
    /// Payload index of the main `Block` in the `extra` array.
    main_block,

    _,
};

pub const Inst = struct {
    tag: Tag,
    data: Data,

    pub const Tag = enum(u8) {
        /// The first N instructions in the main block must be one arg instruction per
        /// function parameter. This makes function parameters participate in
        /// liveness analysis without any special handling.
        /// Uses the `ty_str` field.
        /// The string is the parameter name.
        arg,
        /// Float or integer addition. For integers, wrapping is undefined behavior.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        add,
        /// Integer addition. Wrapping is defined to be twos complement wrapping.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        addwrap,
        /// Float or integer subtraction. For integers, wrapping is undefined behavior.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        sub,
        /// Integer subtraction. Wrapping is defined to be twos complement wrapping.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        subwrap,
        /// Float or integer multiplication. For integers, wrapping is undefined behavior.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        mul,
        /// Integer multiplication. Wrapping is defined to be twos complement wrapping.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        mulwrap,
        /// Integer or float division. For integers, wrapping is undefined behavior.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        div,
        /// Add an offset to a pointer, returning a new pointer.
        /// The offset is in element type units, not bytes.
        /// Wrapping is undefined behavior.
        /// The lhs is the pointer, rhs is the offset. Result type is the same as lhs.
        /// Uses the `bin_op` field.
        ptr_add,
        /// Subtract an offset from a pointer, returning a new pointer.
        /// The offset is in element type units, not bytes.
        /// Wrapping is undefined behavior.
        /// The lhs is the pointer, rhs is the offset. Result type is the same as lhs.
        /// Uses the `bin_op` field.
        ptr_sub,
        /// Allocates stack local memory.
        /// Uses the `ty` field.
        alloc,
        /// Inline assembly. Uses the `ty_pl` field. Payload is `Asm`.
        assembly,
        /// Bitwise AND. `&`.
        /// Result type is the same as both operands.
        /// Uses the `bin_op` field.
        bit_and,
        /// Bitwise OR. `|`.
        /// Result type is the same as both operands.
        /// Uses the `bin_op` field.
        bit_or,
        /// Shift right. `>>`
        /// Uses the `bin_op` field.
        shr,
        /// Shift left. `<<`
        /// Uses the `bin_op` field.
        shl,
        /// Bitwise XOR. `^`
        /// Uses the `bin_op` field.
        xor,
        /// Boolean or binary NOT.
        /// Uses the `ty_op` field.
        not,
        /// Reinterpret the memory representation of a value as a different type.
        /// Uses the `ty_op` field.
        bitcast,
        /// Uses the `ty_pl` field with payload `Block`.
        block,
        /// A labeled block of code that loops forever. At the end of the body it is implied
        /// to repeat; no explicit "repeat" instruction terminates loop bodies.
        /// Result type is always noreturn; no instructions in a block follow this one.
        /// Uses the `ty_pl` field. Payload is `Block`.
        loop,
        /// Return from a block with a result.
        /// Result type is always noreturn; no instructions in a block follow this one.
        /// Uses the `br` field.
        br,
        /// Lowers to a hardware trap instruction, or the next best thing.
        /// Result type is always void.
        breakpoint,
        /// Function call.
        /// Result type is the return type of the function being called.
        /// Uses the `pl_op` field with the `Call` payload. operand is the callee.
        call,
        /// `<`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_lt,
        /// `<=`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_lte,
        /// `==`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_eq,
        /// `>=`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_gte,
        /// `>`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_gt,
        /// `!=`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_neq,
        /// Conditional branch.
        /// Result type is always noreturn; no instructions in a block follow this one.
        /// Uses the `pl_op` field. Operand is the condition. Payload is `CondBr`.
        cond_br,
        /// Switch branch.
        /// Result type is always noreturn; no instructions in a block follow this one.
        /// Uses the `pl_op` field. Operand is the condition. Payload is `SwitchBr`.
        switch_br,
        /// A comptime-known value. Uses the `ty_pl` field, payload is index of
        /// `values` array.
        constant,
        /// A comptime-known type. Uses the `ty` field.
        const_ty,
        /// Notes the beginning of a source code statement and marks the line and column.
        /// Result type is always void.
        /// Uses the `dbg_stmt` field.
        dbg_stmt,
        /// ?T => bool
        /// Result type is always bool.
        /// Uses the `un_op` field.
        is_null,
        /// ?T => bool (inverted logic)
        /// Result type is always bool.
        /// Uses the `un_op` field.
        is_non_null,
        /// *?T => bool
        /// Result type is always bool.
        /// Uses the `un_op` field.
        is_null_ptr,
        /// *?T => bool (inverted logic)
        /// Result type is always bool.
        /// Uses the `un_op` field.
        is_non_null_ptr,
        /// E!T => bool
        /// Result type is always bool.
        /// Uses the `un_op` field.
        is_err,
        /// E!T => bool (inverted logic)
        /// Result type is always bool.
        /// Uses the `un_op` field.
        is_non_err,
        /// *E!T => bool
        /// Result type is always bool.
        /// Uses the `un_op` field.
        is_err_ptr,
        /// *E!T => bool (inverted logic)
        /// Result type is always bool.
        /// Uses the `un_op` field.
        is_non_err_ptr,
        /// Result type is always bool.
        /// Uses the `bin_op` field.
        bool_and,
        /// Result type is always bool.
        /// Uses the `bin_op` field.
        bool_or,
        /// Read a value from a pointer.
        /// Uses the `ty_op` field.
        load,
        /// Converts a pointer to its address. Result type is always `usize`.
        /// Uses the `un_op` field.
        ptrtoint,
        /// Given a boolean, returns 0 or 1.
        /// Result type is always `u1`.
        /// Uses the `un_op` field.
        bool_to_int,
        /// Return a value from a function.
        /// Result type is always noreturn; no instructions in a block follow this one.
        /// Uses the `un_op` field.
        ret,
        /// Write a value to a pointer. LHS is pointer, RHS is value.
        /// Result type is always void.
        /// Uses the `bin_op` field.
        store,
        /// Indicates the program counter will never get to this instruction.
        /// Result type is always noreturn; no instructions in a block follow this one.
        unreach,
        /// Convert from one float type to another.
        /// Uses the `ty_op` field.
        floatcast,
        /// Returns an integer with a different type than the operand. The new type may have
        /// fewer, the same, or more bits than the operand type. However, the instruction
        /// guarantees that the same integer value fits in both types.
        /// See `trunc` for integer truncation.
        /// Uses the `ty_op` field.
        intcast,
        /// Truncate higher bits from an integer, resulting in an integer with the same
        /// sign but an equal or smaller number of bits.
        /// Uses the `ty_op` field.
        trunc,
        /// ?T => T. If the value is null, undefined behavior.
        /// Uses the `ty_op` field.
        optional_payload,
        /// *?T => *T. If the value is null, undefined behavior.
        /// Uses the `ty_op` field.
        optional_payload_ptr,
        /// Given a payload value, wraps it in an optional type.
        /// Uses the `ty_op` field.
        wrap_optional,
        /// E!T -> T. If the value is an error, undefined behavior.
        /// Uses the `ty_op` field.
        unwrap_errunion_payload,
        /// E!T -> E. If the value is not an error, undefined behavior.
        /// Uses the `ty_op` field.
        unwrap_errunion_err,
        /// *(E!T) -> *T. If the value is an error, undefined behavior.
        /// Uses the `ty_op` field.
        unwrap_errunion_payload_ptr,
        /// *(E!T) -> E. If the value is not an error, undefined behavior.
        /// Uses the `ty_op` field.
        unwrap_errunion_err_ptr,
        /// wrap from T to E!T
        /// Uses the `ty_op` field.
        wrap_errunion_payload,
        /// wrap from E to E!T
        /// Uses the `ty_op` field.
        wrap_errunion_err,
        /// Given a pointer to a struct and a field index, returns a pointer to the field.
        /// Uses the `ty_pl` field, payload is `StructField`.
        struct_field_ptr,
        /// Given a pointer to a struct, returns a pointer to the field.
        /// The field index is the number at the end of the name.
        /// Uses `ty_op` field.
        struct_field_ptr_index_0,
        struct_field_ptr_index_1,
        struct_field_ptr_index_2,
        struct_field_ptr_index_3,
        /// Given a byval struct and a field index, returns the field byval.
        /// Uses the `ty_pl` field, payload is `StructField`.
        struct_field_val,
        /// Given a slice value, return the length.
        /// Result type is always usize.
        /// Uses the `ty_op` field.
        slice_len,
        /// Given a slice value, return the pointer.
        /// Uses the `ty_op` field.
        slice_ptr,
        /// Given a slice value, and element index, return the element value at that index.
        /// Result type is the element type of the slice operand.
        /// Uses the `bin_op` field.
        slice_elem_val,
        /// Given a pointer to a slice, and element index, return the element value at that index.
        /// Result type is the element type of the slice operand (2 element type operations).
        /// Uses the `bin_op` field.
        ptr_slice_elem_val,
        /// Given a pointer value, and element index, return the element value at that index.
        /// Result type is the element type of the pointer operand.
        /// Uses the `bin_op` field.
        ptr_elem_val,
        /// Given a pointer value, and element index, return the element pointer at that index.
        /// Result type is pointer to the element type of the pointer operand.
        /// Uses the `ty_pl` field with payload `Bin`.
        ptr_elem_ptr,
        /// Given a pointer to a pointer, and element index, return the element value of the inner
        /// pointer at that index.
        /// Result type is the element type of the inner pointer operand.
        /// Uses the `bin_op` field.
        ptr_ptr_elem_val,

        pub fn fromCmpOp(op: std.math.CompareOperator) Tag {
            return switch (op) {
                .lt => .cmp_lt,
                .lte => .cmp_lte,
                .eq => .cmp_eq,
                .gte => .cmp_gte,
                .gt => .cmp_gt,
                .neq => .cmp_neq,
            };
        }

        pub fn toCmpOp(tag: Tag) ?std.math.CompareOperator {
            return switch (tag) {
                .cmp_lt => .lt,
                .cmp_lte => .lte,
                .cmp_eq => .eq,
                .cmp_gte => .gte,
                .cmp_gt => .gt,
                .cmp_neq => .neq,
                else => null,
            };
        }
    };

    /// The position of an AIR instruction within the `Air` instructions array.
    pub const Index = u32;

    pub const Ref = @import("Zir.zig").Inst.Ref;

    /// All instructions have an 8-byte payload, which is contained within
    /// this union. `Tag` determines which union field is active, as well as
    /// how to interpret the data within.
    pub const Data = union {
        no_op: void,
        un_op: Ref,
        bin_op: struct {
            lhs: Ref,
            rhs: Ref,
        },
        ty: Type,
        ty_op: struct {
            ty: Ref,
            operand: Ref,
        },
        ty_pl: struct {
            ty: Ref,
            // Index into a different array.
            payload: u32,
        },
        ty_str: struct {
            ty: Ref,
            // ZIR string table index.
            str: u32,
        },
        br: struct {
            block_inst: Index,
            operand: Ref,
        },
        pl_op: struct {
            operand: Ref,
            payload: u32,
        },
        dbg_stmt: struct {
            line: u32,
            column: u32,
        },

        // Make sure we don't accidentally add a field to make this union
        // bigger than expected. Note that in Debug builds, Zig is allowed
        // to insert a secret field for safety checks.
        comptime {
            if (std.builtin.mode != .Debug) {
                assert(@sizeOf(Data) == 8);
            }
        }
    };
};

/// Trailing is a list of instruction indexes for every `body_len`.
pub const Block = struct {
    body_len: u32,
};

/// Trailing is a list of `Inst.Ref` for every `args_len`.
pub const Call = struct {
    args_len: u32,
};

/// This data is stored inside extra, with two sets of trailing `Inst.Ref`:
/// * 0. the then body, according to `then_body_len`.
/// * 1. the else body, according to `else_body_len`.
pub const CondBr = struct {
    then_body_len: u32,
    else_body_len: u32,
};

/// Trailing:
/// * 0. `Case` for each `cases_len`
/// * 1. the else body, according to `else_body_len`.
pub const SwitchBr = struct {
    cases_len: u32,
    else_body_len: u32,

    /// Trailing:
    /// * item: Inst.Ref // for each `items_len`.
    /// * instruction index for each `body_len`.
    pub const Case = struct {
        items_len: u32,
        body_len: u32,
    };
};

pub const StructField = struct {
    /// Whether this is a pointer or byval is determined by the AIR tag.
    struct_operand: Inst.Ref,
    field_index: u32,
};

pub const Bin = struct {
    lhs: Inst.Ref,
    rhs: Inst.Ref,
};

/// Trailing:
/// 0. `Inst.Ref` for every outputs_len
/// 1. `Inst.Ref` for every inputs_len
pub const Asm = struct {
    /// Index to the corresponding ZIR instruction.
    /// `asm_source`, `outputs_len`, `inputs_len`, `clobbers_len`, `is_volatile`, and
    /// clobbers are found via here.
    zir_index: u32,
};

pub fn getMainBody(air: Air) []const Air.Inst.Index {
    const body_index = air.extra[@enumToInt(ExtraIndex.main_block)];
    const extra = air.extraData(Block, body_index);
    return air.extra[extra.end..][0..extra.data.body_len];
}

pub fn typeOf(air: Air, inst: Air.Inst.Ref) Type {
    const ref_int = @enumToInt(inst);
    if (ref_int < Air.Inst.Ref.typed_value_map.len) {
        return Air.Inst.Ref.typed_value_map[ref_int].ty;
    }
    return air.typeOfIndex(@intCast(Air.Inst.Index, ref_int - Air.Inst.Ref.typed_value_map.len));
}

pub fn typeOfIndex(air: Air, inst: Air.Inst.Index) Type {
    const datas = air.instructions.items(.data);
    switch (air.instructions.items(.tag)[inst]) {
        .arg => return air.getRefType(datas[inst].ty_str.ty),

        .add,
        .addwrap,
        .sub,
        .subwrap,
        .mul,
        .mulwrap,
        .div,
        .bit_and,
        .bit_or,
        .xor,
        .ptr_add,
        .ptr_sub,
        .shr,
        .shl,
        => return air.typeOf(datas[inst].bin_op.lhs),

        .cmp_lt,
        .cmp_lte,
        .cmp_eq,
        .cmp_gte,
        .cmp_gt,
        .cmp_neq,
        .is_null,
        .is_non_null,
        .is_null_ptr,
        .is_non_null_ptr,
        .is_err,
        .is_non_err,
        .is_err_ptr,
        .is_non_err_ptr,
        .bool_and,
        .bool_or,
        => return Type.initTag(.bool),

        .const_ty => return Type.initTag(.type),

        .alloc => return datas[inst].ty,

        .assembly,
        .block,
        .constant,
        .struct_field_ptr,
        .struct_field_val,
        .ptr_elem_ptr,
        => return air.getRefType(datas[inst].ty_pl.ty),

        .not,
        .bitcast,
        .load,
        .floatcast,
        .intcast,
        .trunc,
        .optional_payload,
        .optional_payload_ptr,
        .wrap_optional,
        .unwrap_errunion_payload,
        .unwrap_errunion_err,
        .unwrap_errunion_payload_ptr,
        .unwrap_errunion_err_ptr,
        .wrap_errunion_payload,
        .wrap_errunion_err,
        .slice_ptr,
        .struct_field_ptr_index_0,
        .struct_field_ptr_index_1,
        .struct_field_ptr_index_2,
        .struct_field_ptr_index_3,
        => return air.getRefType(datas[inst].ty_op.ty),

        .loop,
        .br,
        .cond_br,
        .switch_br,
        .ret,
        .unreach,
        => return Type.initTag(.noreturn),

        .breakpoint,
        .dbg_stmt,
        .store,
        => return Type.initTag(.void),

        .ptrtoint,
        .slice_len,
        => return Type.initTag(.usize),

        .bool_to_int => return Type.initTag(.u1),

        .call => {
            const callee_ty = air.typeOf(datas[inst].pl_op.operand);
            return callee_ty.fnReturnType();
        },

        .slice_elem_val, .ptr_elem_val => {
            const ptr_ty = air.typeOf(datas[inst].bin_op.lhs);
            return ptr_ty.elemType();
        },
        .ptr_slice_elem_val, .ptr_ptr_elem_val => {
            const outer_ptr_ty = air.typeOf(datas[inst].bin_op.lhs);
            const inner_ptr_ty = outer_ptr_ty.elemType();
            return inner_ptr_ty.elemType();
        },
    }
}

pub fn getRefType(air: Air, ref: Air.Inst.Ref) Type {
    const ref_int = @enumToInt(ref);
    if (ref_int < Air.Inst.Ref.typed_value_map.len) {
        var buffer: Value.ToTypeBuffer = undefined;
        return Air.Inst.Ref.typed_value_map[ref_int].val.toType(&buffer);
    }
    const inst_index = ref_int - Air.Inst.Ref.typed_value_map.len;
    const air_tags = air.instructions.items(.tag);
    const air_datas = air.instructions.items(.data);
    assert(air_tags[inst_index] == .const_ty);
    return air_datas[inst_index].ty;
}

/// Returns the requested data, as well as the new index which is at the start of the
/// trailers for the object.
pub fn extraData(air: Air, comptime T: type, index: usize) struct { data: T, end: usize } {
    const fields = std.meta.fields(T);
    var i: usize = index;
    var result: T = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.field_type) {
            u32 => air.extra[i],
            Inst.Ref => @intToEnum(Inst.Ref, air.extra[i]),
            i32 => @bitCast(i32, air.extra[i]),
            else => @compileError("bad field type"),
        };
        i += 1;
    }
    return .{
        .data = result,
        .end = i,
    };
}

pub fn deinit(air: *Air, gpa: *std.mem.Allocator) void {
    air.instructions.deinit(gpa);
    gpa.free(air.extra);
    gpa.free(air.values);
    air.* = undefined;
}

const ref_start_index: u32 = Air.Inst.Ref.typed_value_map.len;

pub fn indexToRef(inst: Air.Inst.Index) Air.Inst.Ref {
    return @intToEnum(Air.Inst.Ref, ref_start_index + inst);
}

pub fn refToIndex(inst: Air.Inst.Ref) ?Air.Inst.Index {
    const ref_int = @enumToInt(inst);
    if (ref_int >= ref_start_index) {
        return ref_int - ref_start_index;
    } else {
        return null;
    }
}

/// Returns `null` if runtime-known.
pub fn value(air: Air, inst: Air.Inst.Ref) ?Value {
    const ref_int = @enumToInt(inst);
    if (ref_int < Air.Inst.Ref.typed_value_map.len) {
        return Air.Inst.Ref.typed_value_map[ref_int].val;
    }
    const inst_index = @intCast(Air.Inst.Index, ref_int - Air.Inst.Ref.typed_value_map.len);
    const air_datas = air.instructions.items(.data);
    switch (air.instructions.items(.tag)[inst_index]) {
        .constant => return air.values[air_datas[inst_index].ty_pl.payload],
        .const_ty => unreachable,
        else => return air.typeOfIndex(inst_index).onePossibleValue(),
    }
}
