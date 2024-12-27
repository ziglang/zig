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
        float: u16,
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

const ValueHandle = *const opaque {};

const Value = extern struct {
    td: *const TypeDescriptor,
    handle: ValueHandle,

    fn getUnsignedInteger(value: Value) u128 {
        assert(!value.td.isSigned());
        const size = value.td.getIntegerSize();
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
        assert(value.td.isSigned());
        const size = value.td.getIntegerSize();
        const max_inline_size = @bitSizeOf(ValueHandle);
        if (size <= max_inline_size) {
            const extra_bits: std.math.Log2Int(usize) = @intCast(max_inline_size - size);
            const handle: isize = @bitCast(@intFromPtr(value.handle));
            return (handle << extra_bits) >> extra_bits;
        }
        return switch (size) {
            64 => @as(*const i64, @alignCast(@ptrCast(value.handle))).*,
            128 => @as(*const i128, @alignCast(@ptrCast(value.handle))).*,
            else => @trap(),
        };
    }

    fn getFloat(value: Value) c_longdouble {
        assert(value.td.kind == .float);
        const size = value.td.info.float;
        const max_inline_size = @bitSizeOf(ValueHandle);
        if (size <= max_inline_size) {
            return @bitCast(@intFromPtr(value.handle));
        }
        return @floatCast(switch (size) {
            64 => @as(*const f64, @alignCast(@ptrCast(value.handle))).*,
            80 => @as(*const f80, @alignCast(@ptrCast(value.handle))).*,
            128 => @as(*const f128, @alignCast(@ptrCast(value.handle))).*,
            else => @trap(),
        });
    }

    fn isMinusOne(value: Value) bool {
        return value.td.isSigned() and
            value.getSignedInteger() == -1;
    }

    fn isNegative(value: Value) bool {
        return value.td.isSigned() and
            value.getSignedInteger() < 0;
    }

    fn getPositiveInteger(value: Value) u128 {
        if (value.td.isSigned()) {
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

        switch (value.td.kind) {
            .integer => {
                if (value.td.isSigned()) {
                    try writer.print("{}", .{value.getSignedInteger()});
                } else {
                    try writer.print("{}", .{value.getUnsignedInteger()});
                }
            },
            .float => try writer.print("{}", .{value.getFloat()}),
            .unknown => try writer.writeAll("(unknown)"),
        }
    }
};

const OverflowData = extern struct {
    loc: SourceLocation,
    td: *const TypeDescriptor,
};

fn overflowHandler(
    comptime sym_name: []const u8,
    comptime operator: []const u8,
) void {
    const S = struct {
        fn handler(
            data: *const OverflowData,
            lhs_handle: ValueHandle,
            rhs_handle: ValueHandle,
        ) callconv(.c) noreturn {
            const lhs: Value = .{ .handle = lhs_handle, .td = data.td };
            const rhs: Value = .{ .handle = rhs_handle, .td = data.td };

            const is_signed = data.td.isSigned();
            const fmt = "{s} integer overflow: " ++ "{} " ++
                operator ++ " {} cannot be represented in type {s}";

            logMessage(fmt, .{
                if (is_signed) "signed" else "unsigned",
                lhs,
                rhs,
                data.td.getName(),
            });
        }
    };

    exportHandler(&S.handler, sym_name, true);
}

fn negationHandler(
    data: *const OverflowData,
    value_handle: ValueHandle,
) callconv(.c) noreturn {
    const value: Value = .{ .handle = value_handle, .td = data.td };
    logMessage(
        "negation of {} cannot be represented in type {s}",
        .{ value, data.td.getName() },
    );
}

fn divRemHandler(
    data: *const OverflowData,
    lhs_handle: ValueHandle,
    rhs_handle: ValueHandle,
) callconv(.c) noreturn {
    const lhs: Value = .{ .handle = lhs_handle, .td = data.lhs_type };
    const rhs: Value = .{ .handle = rhs_handle, .td = data.rhs_type };

    if (rhs.isMinusOne()) {
        logMessage(
            "division of {} by -1 cannot be represented in type {s}",
            .{ lhs, data.td.getName() },
        );
    } else logMessage("division by zero", .{});
}

const AlignmentAssumptionData = extern struct {
    loc: SourceLocation,
    assumption_loc: SourceLocation,
    td: *const TypeDescriptor,
};

fn alignmentAssumptionHandler(
    data: *const AlignmentAssumptionData,
    pointer: ValueHandle,
    alignment_handle: ValueHandle,
    maybe_offset: ?ValueHandle,
) callconv(.c) noreturn {
    const real_pointer = @intFromPtr(pointer) - @intFromPtr(maybe_offset);
    const lsb = @ctz(real_pointer);
    const actual_alignment = @as(u64, 1) << @intCast(lsb);
    const mask = @intFromPtr(alignment_handle) - 1;
    const misalignment_offset = real_pointer & mask;
    const alignment: Value = .{ .handle = alignment_handle, .td = data.td };

    if (maybe_offset) |offset| {
        logMessage(
            "assumption of {} byte alignment (with offset of {} byte) for pointer of type {s} failed\n" ++
                "offset address is {} aligned, misalignment offset is {} bytes",
            .{
                alignment,
                @intFromPtr(offset),
                data.td.getName(),
                actual_alignment,
                misalignment_offset,
            },
        );
    } else {
        logMessage(
            "assumption of {} byte alignment for pointer of type {s} failed\n" ++
                "address is {} aligned, misalignment offset is {} bytes",
            .{
                alignment,
                data.td.getName(),
                actual_alignment,
                misalignment_offset,
            },
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
) callconv(.c) noreturn {
    const lhs: Value = .{ .handle = lhs_handle, .td = data.lhs_type };
    const rhs: Value = .{ .handle = rhs_handle, .td = data.rhs_type };

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

fn outOfBounds(data: *const OutOfBoundsData, index_handle: ValueHandle) callconv(.c) noreturn {
    const index: Value = .{ .handle = index_handle, .td = data.index_type };
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
) callconv(.c) noreturn {
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
            const signed_base: isize = @bitCast(base);
            const signed_result: isize = @bitCast(result);
            if ((signed_base >= 0) == (signed_result >= 0)) {
                if (base > result) {
                    logMessage(
                        "addition of unsigned offset to 0x{x} overflowed to 0x{x}",
                        .{ base, result },
                    );
                } else {
                    logMessage(
                        "subtraction of unsigned offset to 0x{x} overflowed to 0x{x}",
                        .{ base, result },
                    );
                }
            } else {
                logMessage(
                    "pointer index expression with base 0x{x} overflowed to 0x{x}",
                    .{ base, result },
                );
            }
        }
    }
}

const TypeMismatchData = extern struct {
    loc: SourceLocation,
    td: *const TypeDescriptor,
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

        fn getName(kind: @This()) []const u8 {
            return switch (kind) {
                .load => "load of",
                .store => "store of",
                .reference_binding => "reference binding to",
                .member_access => "member access within",
                .member_call => "member call on",
                .constructor_call => "constructor call on",
                .downcast_pointer, .downcast_reference => "downcast of",
                .upcast => "upcast of",
                .upcast_to_virtual_base => "cast to virtual base of",
                .nonnull_assign => "_Nonnull binding to",
                .dynamic_operation => "dynamic operation on",
            };
        }
    },
};

fn typeMismatch(
    data: *const TypeMismatchData,
    pointer: ?ValueHandle,
) callconv(.c) noreturn {
    const alignment = @as(usize, 1) << @intCast(data.log_alignment);
    const handle: usize = @intFromPtr(pointer);

    if (pointer == null) {
        logMessage(
            "{s} null pointer of type {s}",
            .{ data.kind.getName(), data.td.getName() },
        );
    } else if (!std.mem.isAligned(handle, alignment)) {
        logMessage(
            "{s} misaligned address 0x{x} for type {s}, which requires {} byte alignment",
            .{ data.kind.getName(), handle, data.td.getName(), alignment },
        );
    } else {
        logMessage(
            "{s} address 0x{x} with insufficient space for an object of type {s}",
            .{ data.kind.getName(), handle, data.td.getName() },
        );
    }
}

const UnreachableData = extern struct {
    loc: SourceLocation,
};

fn builtinUnreachable(_: *const UnreachableData) callconv(.c) noreturn {
    logMessage("execution reached an unreachable program point", .{});
}

fn missingReturn(_: *const UnreachableData) callconv(.c) noreturn {
    logMessage("execution reached the end of a value-returning function without returning a value", .{});
}

const NonNullReturnData = extern struct {
    attribute_loc: SourceLocation,
};

fn nonNullReturn(_: *const NonNullReturnData) callconv(.c) noreturn {
    logMessage("null pointer returned from function declared to never return null", .{});
}

const NonNullArgData = extern struct {
    loc: SourceLocation,
    attribute_loc: SourceLocation,
    arg_index: i32,
};

fn nonNullArg(data: *const NonNullArgData) callconv(.c) noreturn {
    logMessage(
        "null pointer passed as argument {}, which is declared to never be null",
        .{data.arg_index},
    );
}

const InvalidValueData = extern struct {
    loc: SourceLocation,
    td: *const TypeDescriptor,
};

fn loadInvalidValue(
    data: *const InvalidValueData,
    value_handle: ValueHandle,
) callconv(.c) noreturn {
    const value: Value = .{ .handle = value_handle, .td = data.td };
    logMessage(
        "load of value {}, which is not valid for type {s}",
        .{ value, data.td.getName() },
    );
}

const InvalidBuiltinData = extern struct {
    loc: SourceLocation,
    kind: enum(u8) {
        ctz,
        clz,
    },
};

fn invalidBuiltin(data: *const InvalidBuiltinData) callconv(.c) noreturn {
    logMessage(
        "passing zero to {s}(), which is not a valid argument",
        .{@tagName(data.kind)},
    );
}

const VlaBoundNotPositive = extern struct {
    loc: SourceLocation,
    td: *const TypeDescriptor,
};

fn vlaBoundNotPositive(
    data: *const VlaBoundNotPositive,
    bound_handle: ValueHandle,
) callconv(.c) noreturn {
    const bound: Value = .{ .handle = bound_handle, .td = data.td };
    logMessage(
        "variable length array bound evaluates to non-positive value {}",
        .{bound},
    );
}

const FloatCastOverflowData = extern struct {
    from: *const TypeDescriptor,
    to: *const TypeDescriptor,
};

const FloatCastOverflowDataV2 = extern struct {
    loc: SourceLocation,
    from: *const TypeDescriptor,
    to: *const TypeDescriptor,
};

fn floatCastOverflow(
    data_handle: *align(8) const anyopaque,
    from_handle: ValueHandle,
) callconv(.c) noreturn {
    // See: https://github.com/llvm/llvm-project/blob/release/19.x/compiler-rt/lib/ubsan/ubsan_handlers.cpp#L463
    // for more information on this check.
    const ptr: [*]const u8 = @ptrCast(data_handle);
    if (@as(u16, ptr[0]) + @as(u16, ptr[1]) < 2 or ptr[0] == 0xFF or ptr[1] == 0xFF) {
        const data: *const FloatCastOverflowData = @ptrCast(data_handle);
        const from_value: Value = .{ .handle = from_handle, .td = data.from };
        logMessage("{} is outside the range of representable values of type {s}", .{
            from_value, data.to.getName(),
        });
    } else {
        const data: *const FloatCastOverflowDataV2 = @ptrCast(data_handle);
        const from_value: Value = .{ .handle = from_handle, .td = data.from };
        logMessage("{} is outside the range of representable values of type {s}", .{
            from_value, data.to.getName(),
        });
    }
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
    comptime err_name: []const u8,
    comptime sym_name: []const u8,
    comptime abort: bool,
) void {
    const S = struct {
        fn handler() callconv(.c) noreturn {
            logMessage("{s}", .{err_name});
        }
    };
    const linkage = if (builtin.is_test) .internal else .weak;
    {
        const N = "__ubsan_handle_" ++ sym_name ++ "_minimal";
        @export(&S.handler, .{ .name = N, .linkage = linkage });
    }
    if (abort) {
        const N = "__ubsan_handle_" ++ sym_name ++ "_minimal_abort";
        @export(&S.handler, .{ .name = N, .linkage = linkage });
    }
}

comptime {
    overflowHandler("add_overflow", "+");
    overflowHandler("mul_overflow", "*");
    overflowHandler("sub_overflow", "-");
    exportHandler(&alignmentAssumptionHandler, "alignment_assumption", true);
    exportHandler(&builtinUnreachable, "builtin_unreachable", false);
    exportHandler(&divRemHandler, "divrem_overflow", true);
    exportHandler(&floatCastOverflow, "float_cast_overflow", true);
    exportHandler(&invalidBuiltin, "invalid_builtin", true);
    exportHandler(&loadInvalidValue, "load_invalid_value", true);
    exportHandler(&missingReturn, "missing_return", false);
    exportHandler(&negationHandler, "negate_overflow", true);
    exportHandler(&nonNullArg, "nonnull_arg", true);
    exportHandler(&nonNullReturn, "nonnull_return_v1", true);
    exportHandler(&outOfBounds, "out_of_bounds", true);
    exportHandler(&pointerOverflow, "pointer_overflow", true);
    exportHandler(&shiftOob, "shift_out_of_bounds", true);
    exportHandler(&typeMismatch, "type_mismatch_v1", true);
    exportHandler(&vlaBoundNotPositive, "vla_bound_not_positive", true);

    exportMinimal("add-overflow", "add_overflow", true);
    exportMinimal("sub-overflow", "sub_overflow", true);
    exportMinimal("mul-overflow", "mul_overflow", true);
    exportMinimal("alignment-assumption-handler", "alignment_assumption", true);
    exportMinimal("builtin-unreachable", "builtin_unreachable", false);
    exportMinimal("divrem-handler", "divrem_overflow", true);
    exportMinimal("float-cast-overflow", "float_cast_overflow", true);
    exportMinimal("invalid-builtin", "invalid_builtin", true);
    exportMinimal("load-invalid-value", "load_invalid_value", true);
    exportMinimal("missing-return", "missing_return", true);
    exportMinimal("negation-handler", "negate_overflow", true);
    exportMinimal("nonnull-arg", "nonnull_arg", true);
    exportMinimal("out-of-bounds", "out_of_bounds", true);
    exportMinimal("pointer-overflow", "pointer_overflow", true);
    exportMinimal("shift-oob", "shift_out_of_bounds", true);
    exportMinimal("type-mismatch", "type_mismatch", true);
    exportMinimal("vla-bound-not-positive", "vla_bound_not_positive", true);

    // these checks are nearly impossible to duplicate in zig, as they rely on nuances
    // in the Itanium C++ ABI.
    // exportHelper("dynamic_type_cache_miss", "dynamic-type-cache-miss", true);
    // exportHelper("vptr_type_cache", "vptr-type-cache", true);

    // we disable -fsanitize=function for reasons explained in src/Compilation.zig
    // exportHelper("function-type-mismatch", "function_type_mismatch", true);
    // exportHelper("function-type-mismatch-v1", "function_type_mismatch_v1", true);
}
