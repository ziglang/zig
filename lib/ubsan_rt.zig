const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const panic = std.debug.panicExtra;

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
            else => @trap(),
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

    fn getFloat(value: Value) f128 {
        assert(value.td.kind == .float);
        const size = value.td.info.float;
        const max_inline_size = @bitSizeOf(ValueHandle);
        if (size <= max_inline_size and @bitSizeOf(usize) >= 32) {
            return @as(switch (@bitSizeOf(usize)) {
                32 => f32,
                64 => f64,
                else => @compileError("unsupported target"),
            }, @bitCast(@intFromPtr(value.handle)));
        }
        return @floatCast(switch (size) {
            32 => @as(*const f32, @alignCast(@ptrCast(value.handle))).*,
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

        // Work around x86_64 backend limitation.
        if (builtin.zig_backend == .stage2_x86_64 and builtin.os.tag == .windows) {
            try writer.writeAll("(unknown)");
            return;
        }

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
        fn abort(
            data: *const OverflowData,
            lhs_handle: ValueHandle,
            rhs_handle: ValueHandle,
        ) callconv(.c) noreturn {
            handler(data, lhs_handle, rhs_handle);
        }

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

            panic(@returnAddress(), fmt, .{
                if (is_signed) "signed" else "unsigned",
                lhs,
                rhs,
                data.td.getName(),
            });
        }
    };

    exportHandlerWithAbort(&S.handler, &S.abort, sym_name);
}

fn negationHandlerAbort(
    data: *const OverflowData,
    value_handle: ValueHandle,
) callconv(.c) noreturn {
    negationHandler(data, value_handle);
}

fn negationHandler(
    data: *const OverflowData,
    value_handle: ValueHandle,
) callconv(.c) noreturn {
    const value: Value = .{ .handle = value_handle, .td = data.td };
    panic(
        @returnAddress(),
        "negation of {} cannot be represented in type {s}",
        .{ value, data.td.getName() },
    );
}

fn divRemHandlerAbort(
    data: *const OverflowData,
    lhs_handle: ValueHandle,
    rhs_handle: ValueHandle,
) callconv(.c) noreturn {
    divRemHandler(data, lhs_handle, rhs_handle);
}

fn divRemHandler(
    data: *const OverflowData,
    lhs_handle: ValueHandle,
    rhs_handle: ValueHandle,
) callconv(.c) noreturn {
    const lhs: Value = .{ .handle = lhs_handle, .td = data.td };
    const rhs: Value = .{ .handle = rhs_handle, .td = data.td };

    if (rhs.isMinusOne()) {
        panic(
            @returnAddress(),
            "division of {} by -1 cannot be represented in type {s}",
            .{ lhs, data.td.getName() },
        );
    } else panic(@returnAddress(), "division by zero", .{});
}

const AlignmentAssumptionData = extern struct {
    loc: SourceLocation,
    assumption_loc: SourceLocation,
    td: *const TypeDescriptor,
};

fn alignmentAssumptionHandlerAbort(
    data: *const AlignmentAssumptionData,
    pointer: ValueHandle,
    alignment_handle: ValueHandle,
    maybe_offset: ?ValueHandle,
) callconv(.c) noreturn {
    alignmentAssumptionHandler(
        data,
        pointer,
        alignment_handle,
        maybe_offset,
    );
}

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
        panic(
            @returnAddress(),
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
        panic(
            @returnAddress(),
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

fn shiftOobAbort(
    data: *const ShiftOobData,
    lhs_handle: ValueHandle,
    rhs_handle: ValueHandle,
) callconv(.c) noreturn {
    shiftOob(data, lhs_handle, rhs_handle);
}

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
            panic(@returnAddress(), "shift exponent {} is negative", .{rhs});
        } else {
            panic(
                @returnAddress(),
                "shift exponent {} is too large for {}-bit type {s}",
                .{ rhs, data.lhs_type.getIntegerSize(), data.lhs_type.getName() },
            );
        }
    } else {
        if (lhs.isNegative()) {
            panic(@returnAddress(), "left shift of negative value {}", .{lhs});
        } else {
            panic(
                @returnAddress(),
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

fn outOfBoundsAbort(
    data: *const OutOfBoundsData,
    index_handle: ValueHandle,
) callconv(.c) noreturn {
    outOfBounds(data, index_handle);
}

fn outOfBounds(
    data: *const OutOfBoundsData,
    index_handle: ValueHandle,
) callconv(.c) noreturn {
    const index: Value = .{ .handle = index_handle, .td = data.index_type };
    panic(
        @returnAddress(),
        "index {} out of bounds for type {s}",
        .{ index, data.array_type.getName() },
    );
}

const PointerOverflowData = extern struct {
    loc: SourceLocation,
};

fn pointerOverflowAbort(
    data: *const PointerOverflowData,
    base: usize,
    result: usize,
) callconv(.c) noreturn {
    pointerOverflow(data, base, result);
}

fn pointerOverflow(
    _: *const PointerOverflowData,
    base: usize,
    result: usize,
) callconv(.c) noreturn {
    if (base == 0) {
        if (result == 0) {
            panic(@returnAddress(), "applying zero offset to null pointer", .{});
        } else {
            panic(@returnAddress(), "applying non-zero offset {} to null pointer", .{result});
        }
    } else {
        if (result == 0) {
            panic(
                @returnAddress(),
                "applying non-zero offset to non-null pointer 0x{x} produced null pointer",
                .{base},
            );
        } else {
            const signed_base: isize = @bitCast(base);
            const signed_result: isize = @bitCast(result);
            if ((signed_base >= 0) == (signed_result >= 0)) {
                if (base > result) {
                    panic(
                        @returnAddress(),
                        "addition of unsigned offset to 0x{x} overflowed to 0x{x}",
                        .{ base, result },
                    );
                } else {
                    panic(
                        @returnAddress(),
                        "subtraction of unsigned offset to 0x{x} overflowed to 0x{x}",
                        .{ base, result },
                    );
                }
            } else {
                panic(
                    @returnAddress(),
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

fn typeMismatchAbort(
    data: *const TypeMismatchData,
    pointer: ?ValueHandle,
) callconv(.c) noreturn {
    typeMismatch(data, pointer);
}

fn typeMismatch(
    data: *const TypeMismatchData,
    pointer: ?ValueHandle,
) callconv(.c) noreturn {
    const alignment = @as(usize, 1) << @intCast(data.log_alignment);
    const handle: usize = @intFromPtr(pointer);

    if (pointer == null) {
        panic(
            @returnAddress(),
            "{s} null pointer of type {s}",
            .{ data.kind.getName(), data.td.getName() },
        );
    } else if (!std.mem.isAligned(handle, alignment)) {
        panic(
            @returnAddress(),
            "{s} misaligned address 0x{x} for type {s}, which requires {} byte alignment",
            .{ data.kind.getName(), handle, data.td.getName(), alignment },
        );
    } else {
        panic(
            @returnAddress(),
            "{s} address 0x{x} with insufficient space for an object of type {s}",
            .{ data.kind.getName(), handle, data.td.getName() },
        );
    }
}

const UnreachableData = extern struct {
    loc: SourceLocation,
};

fn builtinUnreachable(_: *const UnreachableData) callconv(.c) noreturn {
    panic(@returnAddress(), "execution reached an unreachable program point", .{});
}

fn missingReturn(_: *const UnreachableData) callconv(.c) noreturn {
    panic(@returnAddress(), "execution reached the end of a value-returning function without returning a value", .{});
}

const NonNullReturnData = extern struct {
    attribute_loc: SourceLocation,
};

fn nonNullReturnAbort(data: *const NonNullReturnData) callconv(.c) noreturn {
    nonNullReturn(data);
}
fn nonNullReturn(_: *const NonNullReturnData) callconv(.c) noreturn {
    panic(@returnAddress(), "null pointer returned from function declared to never return null", .{});
}

const NonNullArgData = extern struct {
    loc: SourceLocation,
    attribute_loc: SourceLocation,
    arg_index: i32,
};

fn nonNullArgAbort(data: *const NonNullArgData) callconv(.c) noreturn {
    nonNullArg(data);
}

fn nonNullArg(data: *const NonNullArgData) callconv(.c) noreturn {
    panic(
        @returnAddress(),
        "null pointer passed as argument {}, which is declared to never be null",
        .{data.arg_index},
    );
}

const InvalidValueData = extern struct {
    loc: SourceLocation,
    td: *const TypeDescriptor,
};

fn loadInvalidValueAbort(
    data: *const InvalidValueData,
    value_handle: ValueHandle,
) callconv(.c) noreturn {
    loadInvalidValue(data, value_handle);
}

fn loadInvalidValue(
    data: *const InvalidValueData,
    value_handle: ValueHandle,
) callconv(.c) noreturn {
    const value: Value = .{ .handle = value_handle, .td = data.td };
    panic(
        @returnAddress(),
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
fn invalidBuiltinAbort(data: *const InvalidBuiltinData) callconv(.c) noreturn {
    invalidBuiltin(data);
}

fn invalidBuiltin(data: *const InvalidBuiltinData) callconv(.c) noreturn {
    panic(
        @returnAddress(),
        "passing zero to {s}(), which is not a valid argument",
        .{@tagName(data.kind)},
    );
}

const VlaBoundNotPositive = extern struct {
    loc: SourceLocation,
    td: *const TypeDescriptor,
};

fn vlaBoundNotPositiveAbort(
    data: *const VlaBoundNotPositive,
    bound_handle: ValueHandle,
) callconv(.c) noreturn {
    vlaBoundNotPositive(data, bound_handle);
}

fn vlaBoundNotPositive(
    data: *const VlaBoundNotPositive,
    bound_handle: ValueHandle,
) callconv(.c) noreturn {
    const bound: Value = .{ .handle = bound_handle, .td = data.td };
    panic(
        @returnAddress(),
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

fn floatCastOverflowAbort(
    data_handle: *align(8) const anyopaque,
    from_handle: ValueHandle,
) callconv(.c) noreturn {
    floatCastOverflow(data_handle, from_handle);
}

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
        panic(@returnAddress(), "{} is outside the range of representable values of type {s}", .{
            from_value, data.to.getName(),
        });
    } else {
        const data: *const FloatCastOverflowDataV2 = @ptrCast(data_handle);
        const from_value: Value = .{ .handle = from_handle, .td = data.from };
        panic(@returnAddress(), "{} is outside the range of representable values of type {s}", .{
            from_value, data.to.getName(),
        });
    }
}

fn exportHandler(
    handler: anytype,
    comptime sym_name: []const u8,
) void {
    // Work around x86_64 backend limitation.
    const linkage = if (builtin.zig_backend == .stage2_x86_64 and builtin.os.tag == .windows) .internal else .weak;
    const N = "__ubsan_handle_" ++ sym_name;
    @export(handler, .{ .name = N, .linkage = linkage });
}

fn exportHandlerWithAbort(
    handler: anytype,
    abort_handler: anytype,
    comptime sym_name: []const u8,
) void {
    // Work around x86_64 backend limitation.
    const linkage = if (builtin.zig_backend == .stage2_x86_64 and builtin.os.tag == .windows) .internal else .weak;
    {
        const N = "__ubsan_handle_" ++ sym_name;
        @export(handler, .{ .name = N, .linkage = linkage });
    }
    {
        const N = "__ubsan_handle_" ++ sym_name ++ "_abort";
        @export(abort_handler, .{ .name = N, .linkage = linkage });
    }
}

const can_build_ubsan = switch (builtin.zig_backend) {
    .stage2_riscv64 => false,
    else => true,
};

comptime {
    if (can_build_ubsan) {
        overflowHandler("add_overflow", "+");
        overflowHandler("mul_overflow", "*");
        overflowHandler("sub_overflow", "-");
        exportHandlerWithAbort(&alignmentAssumptionHandler, &alignmentAssumptionHandlerAbort, "alignment_assumption");

        exportHandlerWithAbort(&divRemHandler, &divRemHandlerAbort, "divrem_overflow");
        exportHandlerWithAbort(&floatCastOverflow, &floatCastOverflowAbort, "float_cast_overflow");
        exportHandlerWithAbort(&invalidBuiltin, &invalidBuiltinAbort, "invalid_builtin");
        exportHandlerWithAbort(&loadInvalidValue, &loadInvalidValueAbort, "load_invalid_value");

        exportHandlerWithAbort(&negationHandler, &negationHandlerAbort, "negate_overflow");
        exportHandlerWithAbort(&nonNullArg, &nonNullArgAbort, "nonnull_arg");
        exportHandlerWithAbort(&nonNullReturn, &nonNullReturnAbort, "nonnull_return_v1");
        exportHandlerWithAbort(&outOfBounds, &outOfBoundsAbort, "out_of_bounds");
        exportHandlerWithAbort(&pointerOverflow, &pointerOverflowAbort, "pointer_overflow");
        exportHandlerWithAbort(&shiftOob, &shiftOobAbort, "shift_out_of_bounds");
        exportHandlerWithAbort(&typeMismatch, &typeMismatchAbort, "type_mismatch_v1");
        exportHandlerWithAbort(&vlaBoundNotPositive, &vlaBoundNotPositiveAbort, "vla_bound_not_positive");

        exportHandler(&builtinUnreachable, "builtin_unreachable");
        exportHandler(&missingReturn, "missing_return");
    }

    // these checks are nearly impossible to replicate in zig, as they rely on nuances
    // in the Itanium C++ ABI.
    // exportHandlerWithAbort(&dynamicTypeCacheMiss, &dynamicTypeCacheMissAbort, "dynamic-type-cache-miss");
    // exportHandlerWithAbort(&vptrTypeCache, &vptrTypeCacheAbort, "vptr-type-cache");

    // we disable -fsanitize=function for reasons explained in src/Compilation.zig
    // exportHandlerWithAbort(&functionTypeMismatch, &functionTypeMismatchAbort, "function-type-mismatch");
    // exportHandlerWithAbort(&functionTypeMismatchV1, &functionTypeMismatchV1Abort, "function-type-mismatch-v1");
}
