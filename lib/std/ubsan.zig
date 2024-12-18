//! Minimal UBSan Runtime

const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const SourceLocation = extern struct {
    file_name: ?[*:0]const u8,
    line: u32,
    col: u32,
};

const TypeDescriptor = extern struct {
    kind: Kind,
    info: Info,
    // name: [?:0]u8

    const Kind = enum(u16) {
        integer = 0x0000,
        float = 0x0001,
        unknown = 0xFFFF,
    };

    const Info = extern union {
        integer: packed struct(u16) {
            signed: bool,
            bit_width: u15,
        },
    };

    fn getIntegerSize(desc: TypeDescriptor) u64 {
        assert(desc.kind == .integer);
        const bit_width = desc.info.integer.bit_width;
        return @as(u64, 1) << @intCast(bit_width);
    }

    fn isSigned(desc: TypeDescriptor) bool {
        return desc.kind == .integer and desc.info.integer.signed;
    }

    fn getName(desc: *const TypeDescriptor) [:0]const u8 {
        return std.mem.span(@as([*:0]const u8, @ptrCast(desc)) + @sizeOf(TypeDescriptor));
    }
};

const ValueHandle = *const opaque {
    fn getValue(handle: ValueHandle, data: anytype) Value {
        return .{ .handle = handle, .type_descriptor = data.type_descriptor };
    }
};

const Value = extern struct {
    type_descriptor: *const TypeDescriptor,
    handle: ValueHandle,

    fn getUnsignedInteger(value: Value) u128 {
        assert(!value.type_descriptor.isSigned());
        const size = value.type_descriptor.getIntegerSize();
        const max_inline_size = @bitSizeOf(ValueHandle);
        if (size <= max_inline_size) {
            return @intFromPtr(value.handle);
        }

        return switch (size) {
            64 => @as(*const u64, @alignCast(@ptrCast(value.handle))).*,
            128 => @as(*const u128, @alignCast(@ptrCast(value.handle))).*,
            else => unreachable,
        };
    }

    fn getSignedInteger(value: Value) i128 {
        assert(value.type_descriptor.isSigned());
        const size = value.type_descriptor.getIntegerSize();
        const max_inline_size = @bitSizeOf(ValueHandle);
        if (size <= max_inline_size) {
            const extra_bits: u6 = @intCast(max_inline_size - size);
            const handle: i64 = @bitCast(@intFromPtr(value.handle));
            return (handle << extra_bits) >> extra_bits;
        }
        return switch (size) {
            64 => @as(*const i64, @alignCast(@ptrCast(value.handle))).*,
            128 => @as(*const i128, @alignCast(@ptrCast(value.handle))).*,
            else => unreachable,
        };
    }

    fn isMinusOne(value: Value) bool {
        return value.type_descriptor.isSigned() and
            value.getSignedInteger() == -1;
    }

    fn isNegative(value: Value) bool {
        return value.type_descriptor.isSigned() and
            value.getSignedInteger() < 0;
    }

    fn getPositiveInteger(value: Value) u128 {
        if (value.type_descriptor.isSigned()) {
            const signed = value.getSignedInteger();
            assert(signed >= 0);
            return @intCast(signed);
        } else {
            return value.getUnsignedInteger();
        }
    }

    pub fn format(
        value: Value,
        comptime fmt: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        comptime assert(fmt.len == 0);

        switch (value.type_descriptor.kind) {
            .integer => {
                if (value.type_descriptor.isSigned()) {
                    try writer.print("{}", .{value.getSignedInteger()});
                } else {
                    try writer.print("{}", .{value.getUnsignedInteger()});
                }
            },
            .float => @panic("TODO: write float"),
            .unknown => try writer.writeAll("(unknown)"),
        }
    }
};

const OverflowData = extern struct {
    loc: SourceLocation,
    type_descriptor: *const TypeDescriptor,
};

fn overflowHandler(
    comptime sym_name: []const u8,
    comptime operator: []const u8,
) void {
    const S = struct {
        fn handler(
            data: *OverflowData,
            lhs_handle: ValueHandle,
            rhs_handle: ValueHandle,
        ) callconv(.C) noreturn {
            const lhs = lhs_handle.getValue(data);
            const rhs = rhs_handle.getValue(data);

            const is_signed = data.type_descriptor.isSigned();
            const fmt = "{s} integer overflow: " ++ "{} " ++
                operator ++ " {} cannot be represented in type {s}";

            logMessage(fmt, .{
                if (is_signed) "signed" else "unsigned",
                lhs,
                rhs,
                data.type_descriptor.getName(),
            });
        }
    };

    exportHandler(&S.handler, sym_name, true);
}

fn negationHandler(
    data: *const OverflowData,
    old_value_handle: ValueHandle,
) callconv(.C) noreturn {
    const old_value = old_value_handle.getValue(data);
    logMessage(
        "negation of {} cannot be represented in type {s}",
        .{ old_value, data.type_descriptor.getName() },
    );
}

fn divRemHandler(
    data: *const OverflowData,
    lhs_handle: ValueHandle,
    rhs_handle: ValueHandle,
) callconv(.C) noreturn {
    const is_signed = data.type_descriptor.isSigned();
    const lhs = lhs_handle.getValue(data);
    const rhs = rhs_handle.getValue(data);

    if (is_signed and rhs.getSignedInteger() == -1) {
        logMessage(
            "division of {} by -1 cannot be represented in type {s}",
            .{ lhs, data.type_descriptor.getName() },
        );
    } else logMessage("division by zero", .{});
}

const AlignmentAssumptionData = extern struct {
    loc: SourceLocation,
    assumption_loc: SourceLocation,
    type_descriptor: *const TypeDescriptor,
};

fn alignmentAssumptionHandler(
    data: *const AlignmentAssumptionData,
    pointer: ValueHandle,
    alignment: ValueHandle,
    maybe_offset: ?ValueHandle,
) callconv(.C) noreturn {
    _ = pointer;
    // TODO: add the hint here?
    // const real_pointer = @intFromPtr(pointer) - @intFromPtr(maybe_offset);
    // const lsb = @ctz(real_pointer);
    // const actual_alignment = @as(u64, 1) << @intCast(lsb);
    // const mask = @intFromPtr(alignment) - 1;
    // const misalignment_offset = real_pointer & mask;
    // _ = actual_alignment;
    // _ = misalignment_offset;

    if (maybe_offset) |offset| {
        logMessage(
            "assumption of {} byte alignment (with offset of {} byte) for pointer of type {s} failed",
            .{ alignment.getValue(data), @intFromPtr(offset), data.type_descriptor.getName() },
        );
    } else {
        logMessage(
            "assumption of {} byte alignment for pointer of type {s} failed",
            .{ alignment.getValue(data), data.type_descriptor.getName() },
        );
    }
}

const ShiftOobData = extern struct {
    loc: SourceLocation,
    lhs_type: *const TypeDescriptor,
    rhs_type: *const TypeDescriptor,
};

fn shiftOob(
    data: *const ShiftOobData,
    lhs_handle: ValueHandle,
    rhs_handle: ValueHandle,
) callconv(.C) noreturn {
    const lhs: Value = .{ .handle = lhs_handle, .type_descriptor = data.lhs_type };
    const rhs: Value = .{ .handle = rhs_handle, .type_descriptor = data.rhs_type };

    if (rhs.isNegative() or
        rhs.getPositiveInteger() >= data.lhs_type.getIntegerSize())
    {
        if (rhs.isNegative()) {
            logMessage("shift exponent {} is negative", .{rhs});
        } else {
            logMessage(
                "shift exponent {} is too large for {}-bit type {s}",
                .{ rhs, data.lhs_type.getIntegerSize(), data.lhs_type.getName() },
            );
        }
    } else {
        if (lhs.isNegative()) {
            logMessage("left shift of negative value {}", .{lhs});
        } else {
            logMessage(
                "left shift of {} by {} places cannot be represented in type {s}",
                .{ lhs, rhs, data.lhs_type.getName() },
            );
        }
    }
}

const OutOfBoundsData = extern struct {
    loc: SourceLocation,
    array_type: *const TypeDescriptor,
    index_type: *const TypeDescriptor,
};

fn outOfBounds(data: *const OutOfBoundsData, index_handle: ValueHandle) callconv(.C) noreturn {
    const index: Value = .{ .handle = index_handle, .type_descriptor = data.index_type };
    logMessage(
        "index {} out of bounds for type {s}",
        .{ index, data.array_type.getName() },
    );
}

const PointerOverflowData = extern struct {
    loc: SourceLocation,
};

fn pointerOverflow(
    _: *const PointerOverflowData,
    base: usize,
    result: usize,
) callconv(.C) noreturn {
    if (base == 0) {
        if (result == 0) {
            logMessage("applying zero offset to null pointer", .{});
        } else {
            logMessage("applying non-zero offset {} to null pointer", .{result});
        }
    } else {
        if (result == 0) {
            logMessage(
                "applying non-zero offset to non-null pointer 0x{x} produced null pointer",
                .{base},
            );
        } else {
            @panic("TODO");
        }
    }
}

const TypeMismatchData = extern struct {
    loc: SourceLocation,
    type_descriptor: *const TypeDescriptor,
    log_alignment: u8,
    kind: enum(u8) {
        load,
        store,
        reference_binding,
        member_access,
        member_call,
        constructor_call,
        downcast_pointer,
        downcast_reference,
        upcast,
        upcast_to_virtual_base,
        nonnull_assign,
        dynamic_operation,
    },
};

fn SimpleHandler(comptime error_name: []const u8) type {
    return struct {
        fn handler() callconv(.C) noreturn {
            logMessage("{s}", .{error_name});
        }
    };
}

inline fn logMessage(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.panicExtra(null, @returnAddress(), fmt, args);
}

fn exportHandler(
    handler: anytype,
    comptime sym_name: []const u8,
    comptime abort: bool,
) void {
    const linkage = if (builtin.is_test) .internal else .weak;
    {
        const N = "__ubsan_handle_" ++ sym_name;
        @export(handler, .{ .name = N, .linkage = linkage });
    }
    if (abort) {
        const N = "__ubsan_handle_" ++ sym_name ++ "_abort";
        @export(handler, .{ .name = N, .linkage = linkage });
    }
}

fn exportMinimal(
    handler: anytype,
    comptime sym_name: []const u8,
    comptime abort: bool,
) void {
    const linkage = if (builtin.is_test) .internal else .weak;
    {
        const N = "__ubsan_handle_" ++ sym_name ++ "_minimal";
        @export(handler, .{ .name = N, .linkage = linkage });
    }
    if (abort) {
        const N = "__ubsan_handle_" ++ sym_name ++ "_minimal_abort";
        @export(handler, .{ .name = N, .linkage = linkage });
    }
}

fn exportHelper(
    comptime err_name: []const u8,
    comptime sym_name: []const u8,
    comptime abort: bool,
) void {
    exportHandler(&SimpleHandler(err_name).handler, sym_name, abort);
    exportMinimal(&SimpleHandler(err_name).handler, sym_name, abort);
}

comptime {
    overflowHandler("add_overflow", "+");
    overflowHandler("sub_overflow", "-");
    overflowHandler("mul_overflow", "*");
    exportHandler(&negationHandler, "negate_overflow", true);
    exportHandler(&divRemHandler, "divrem_overflow", true);
    exportHandler(&alignmentAssumptionHandler, "alignment_assumption", true);
    exportHandler(&shiftOob, "shift_out_of_bounds", true);
    exportHandler(&outOfBounds, "out_of_bounds", true);
    exportHandler(&pointerOverflow, "pointer_overflow", true);

    exportMinimal("add-overflow", "add_overflow", true);
    exportMinimal("sub-overflow", "sub_overflow", true);
    exportMinimal("mul-overflow", "mul_overflow", true);
    exportMinimal("negation-handler", "negate_overflow", true);
    exportMinimal("divrem-handler", "divrem_overflow", true);
    exportMinimal("alignment-assumption-handler", "alignment_assumption", true);
    exportMinimal("shift-oob", "shift_out_of_bounds", true);
    exportMinimal("out-of-bounds", "out_of_bounds", true);
    exportMinimal("pointer-overflow", "pointer_overflow", true);

    exportHandler(&SimpleHandler("type-mismatch-v1").handler, "type_mismatch_v1", true);
    exportMinimal(&SimpleHandler("type-mismatch").handler, "type_mismatch", true);

    exportHelper("builtin-unreachable", "builtin_unreachable", true);
    exportHelper("missing-return", "missing_return", false);
    exportHelper("vla-bound-not-positive", "vla_bound_not_positive", true);
    exportHelper("float-cast-overflow", "float_cast_overflow", true);
    exportHelper("load-invalid-value", "load_invalid_value", true);
    exportHelper("invalid-builtin", "invalid_builtin", true);
    exportHelper("function-type-mismatch", "function_type_mismatch", true);
    exportHelper("implicit-conversion", "implicit_conversion", true);
    exportHelper("nonnull-arg", "nonnull_arg", true);
    exportHelper("nonnull-return", "nonnull_return", true);
    exportHelper("nullability-arg", "nullability_arg", true);
    exportHelper("nullability-return", "nullability_return", true);
    exportHelper("cfi-check-fail", "cfi_check_fail", true);
    exportHelper("function-type-mismatch-v1", "function_type_mismatch_v1", true);

    // these checks are nearly impossible to duplicate in zig, as they rely on nuances
    // in the Itanium C++ ABI.
    // exportHelper("dynamic_type_cache_miss", "dynamic-type-cache-miss", true);
    // exportHelper("vptr_type_cache", "vptr-type-cache", true);
}
