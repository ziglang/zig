const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
const link = @import("link.zig");
const log = std.log.scoped(.codegen);
const mem = std.mem;
const math = std.math;
const target_util = @import("target.zig");
const trace = @import("tracy.zig").trace;

const Air = @import("Air.zig");
const Allocator = mem.Allocator;
const Compilation = @import("Compilation.zig");
const ErrorMsg = Zcu.ErrorMsg;
const InternPool = @import("InternPool.zig");
const Zcu = @import("Zcu.zig");

const Type = @import("Type.zig");
const Value = @import("Value.zig");
const Zir = std.zig.Zir;
const Alignment = InternPool.Alignment;
const dev = @import("dev.zig");

pub const CodeGenError = GenerateSymbolError || error{
    /// Indicates the error is already stored in Zcu `failed_codegen`.
    CodegenFail,
};

fn devFeatureForBackend(backend: std.builtin.CompilerBackend) dev.Feature {
    return switch (backend) {
        .other, .stage1 => unreachable,
        .stage2_aarch64 => .aarch64_backend,
        .stage2_arm => .arm_backend,
        .stage2_c => .c_backend,
        .stage2_llvm => .llvm_backend,
        .stage2_powerpc => unreachable,
        .stage2_riscv64 => .riscv64_backend,
        .stage2_sparc64 => .sparc64_backend,
        .stage2_spirv => .spirv_backend,
        .stage2_wasm => .wasm_backend,
        .stage2_x86 => .x86_backend,
        .stage2_x86_64 => .x86_64_backend,
        _ => unreachable,
    };
}

fn importBackend(comptime backend: std.builtin.CompilerBackend) type {
    return switch (backend) {
        .other, .stage1 => unreachable,
        .stage2_aarch64 => unreachable,
        .stage2_arm => unreachable,
        .stage2_c => @import("codegen/c.zig"),
        .stage2_llvm => @import("codegen/llvm.zig"),
        .stage2_powerpc => unreachable,
        .stage2_riscv64 => @import("arch/riscv64/CodeGen.zig"),
        .stage2_sparc64 => @import("arch/sparc64/CodeGen.zig"),
        .stage2_spirv => @import("codegen/spirv.zig"),
        .stage2_wasm => @import("arch/wasm/CodeGen.zig"),
        .stage2_x86, .stage2_x86_64 => @import("arch/x86_64/CodeGen.zig"),
        _ => unreachable,
    };
}

pub fn legalizeFeatures(pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) ?*const Air.Legalize.Features {
    const zcu = pt.zcu;
    const target = &zcu.navFileScope(nav_index).mod.?.resolved_target.result;
    switch (target_util.zigBackend(target, zcu.comp.config.use_llvm)) {
        else => unreachable,
        inline .stage2_llvm,
        .stage2_c,
        .stage2_wasm,
        .stage2_x86_64,
        .stage2_x86,
        .stage2_riscv64,
        .stage2_sparc64,
        .stage2_spirv,
        => |backend| {
            dev.check(devFeatureForBackend(backend));
            return importBackend(backend).legalizeFeatures(target);
        },
    }
}

/// Every code generation backend has a different MIR representation. However, we want to pass
/// MIR from codegen to the linker *regardless* of which backend is in use. So, we use this: a
/// union of all MIR types. The active tag is known from the backend in use; see `AnyMir.tag`.
pub const AnyMir = union {
    riscv64: @import("arch/riscv64/Mir.zig"),
    sparc64: @import("arch/sparc64/Mir.zig"),
    x86_64: @import("arch/x86_64/Mir.zig"),
    wasm: @import("arch/wasm/Mir.zig"),
    c: @import("codegen/c.zig").Mir,

    pub inline fn tag(comptime backend: std.builtin.CompilerBackend) []const u8 {
        return switch (backend) {
            .stage2_aarch64 => "aarch64",
            .stage2_arm => "arm",
            .stage2_riscv64 => "riscv64",
            .stage2_sparc64 => "sparc64",
            .stage2_x86_64 => "x86_64",
            .stage2_wasm => "wasm",
            .stage2_c => "c",
            else => unreachable,
        };
    }

    pub fn deinit(mir: *AnyMir, zcu: *const Zcu) void {
        const gpa = zcu.gpa;
        const backend = target_util.zigBackend(&zcu.root_mod.resolved_target.result, zcu.comp.config.use_llvm);
        switch (backend) {
            else => unreachable,
            inline .stage2_riscv64,
            .stage2_sparc64,
            .stage2_x86_64,
            .stage2_wasm,
            .stage2_c,
            => |backend_ct| @field(mir, tag(backend_ct)).deinit(gpa),
        }
    }
};

/// Runs code generation for a function. This process converts the `Air` emitted by `Sema`,
/// alongside annotated `Liveness` data, to machine code in the form of MIR (see `AnyMir`).
///
/// This is supposed to be a "pure" process, but some backends are currently buggy; see
/// `Zcu.Feature.separate_thread` for details.
pub fn generateFunction(
    lf: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    func_index: InternPool.Index,
    air: *const Air,
    liveness: *const Air.Liveness,
) CodeGenError!AnyMir {
    const zcu = pt.zcu;
    const func = zcu.funcInfo(func_index);
    const target = &zcu.navFileScope(func.owner_nav).mod.?.resolved_target.result;
    switch (target_util.zigBackend(target, false)) {
        else => unreachable,
        inline .stage2_riscv64,
        .stage2_sparc64,
        .stage2_x86_64,
        .stage2_wasm,
        .stage2_c,
        => |backend| {
            dev.check(devFeatureForBackend(backend));
            const CodeGen = importBackend(backend);
            const mir = try CodeGen.generate(lf, pt, src_loc, func_index, air, liveness);
            return @unionInit(AnyMir, AnyMir.tag(backend), mir);
        },
    }
}

/// Converts the MIR returned by `generateFunction` to finalized machine code to be placed in
/// the output binary. This is called from linker implementations, and may query linker state.
///
/// This function is not called for the C backend, as `link.C` directly understands its MIR.
///
/// The `air` parameter is not supposed to exist, but some backends are currently buggy; see
/// `Zcu.Feature.separate_thread` for details.
pub fn emitFunction(
    lf: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    func_index: InternPool.Index,
    any_mir: *const AnyMir,
    code: *std.ArrayListUnmanaged(u8),
    debug_output: link.File.DebugInfoOutput,
) CodeGenError!void {
    const zcu = pt.zcu;
    const func = zcu.funcInfo(func_index);
    const target = &zcu.navFileScope(func.owner_nav).mod.?.resolved_target.result;
    switch (target_util.zigBackend(target, zcu.comp.config.use_llvm)) {
        else => unreachable,
        inline .stage2_riscv64,
        .stage2_sparc64,
        .stage2_x86_64,
        => |backend| {
            dev.check(devFeatureForBackend(backend));
            const mir = &@field(any_mir, AnyMir.tag(backend));
            return mir.emit(lf, pt, src_loc, func_index, code, debug_output);
        },
    }
}

pub fn generateLazyFunction(
    lf: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    lazy_sym: link.File.LazySymbol,
    code: *std.ArrayListUnmanaged(u8),
    debug_output: link.File.DebugInfoOutput,
) CodeGenError!void {
    const zcu = pt.zcu;
    const target = if (Type.fromInterned(lazy_sym.ty).typeDeclInstAllowGeneratedTag(zcu)) |inst_index|
        &zcu.fileByIndex(inst_index.resolveFile(&zcu.intern_pool)).mod.?.resolved_target.result
    else
        zcu.getTarget();
    switch (target_util.zigBackend(target, zcu.comp.config.use_llvm)) {
        else => unreachable,
        inline .stage2_riscv64, .stage2_x86_64 => |backend| {
            dev.check(devFeatureForBackend(backend));
            return importBackend(backend).generateLazy(lf, pt, src_loc, lazy_sym, code, debug_output);
        },
    }
}

fn writeFloat(comptime F: type, f: F, target: *const std.Target, endian: std.builtin.Endian, code: []u8) void {
    _ = target;
    const bits = @typeInfo(F).float.bits;
    const Int = @Type(.{ .int = .{ .signedness = .unsigned, .bits = bits } });
    const int: Int = @bitCast(f);
    mem.writeInt(Int, code[0..@divExact(bits, 8)], int, endian);
}

pub fn generateLazySymbol(
    bin_file: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    lazy_sym: link.File.LazySymbol,
    // TODO don't use an "out" parameter like this; put it in the result instead
    alignment: *Alignment,
    code: *std.ArrayListUnmanaged(u8),
    debug_output: link.File.DebugInfoOutput,
    reloc_parent: link.File.RelocInfo.Parent,
) CodeGenError!void {
    _ = reloc_parent;

    const tracy = trace(@src());
    defer tracy.end();

    const comp = bin_file.comp;
    const gpa = comp.gpa;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const target = &comp.root_mod.resolved_target.result;
    const endian = target.cpu.arch.endian();

    log.debug("generateLazySymbol: kind = {s}, ty = {}", .{
        @tagName(lazy_sym.kind),
        Type.fromInterned(lazy_sym.ty).fmt(pt),
    });

    if (lazy_sym.kind == .code) {
        alignment.* = target_util.defaultFunctionAlignment(target);
        return generateLazyFunction(bin_file, pt, src_loc, lazy_sym, code, debug_output);
    }

    if (lazy_sym.ty == .anyerror_type) {
        alignment.* = .@"4";
        const err_names = ip.global_error_set.getNamesFromMainThread();
        var offset_index: u32 = @intCast(code.items.len);
        var string_index: u32 = @intCast(4 * (1 + err_names.len + @intFromBool(err_names.len > 0)));
        try code.resize(gpa, offset_index + string_index);
        mem.writeInt(u32, code.items[offset_index..][0..4], @intCast(err_names.len), endian);
        if (err_names.len == 0) return;
        offset_index += 4;
        for (err_names) |err_name_nts| {
            const err_name = err_name_nts.toSlice(ip);
            mem.writeInt(u32, code.items[offset_index..][0..4], string_index, endian);
            offset_index += 4;
            try code.ensureUnusedCapacity(gpa, err_name.len + 1);
            code.appendSliceAssumeCapacity(err_name);
            code.appendAssumeCapacity(0);
            string_index += @intCast(err_name.len + 1);
        }
        mem.writeInt(u32, code.items[offset_index..][0..4], string_index, endian);
    } else if (Type.fromInterned(lazy_sym.ty).zigTypeTag(zcu) == .@"enum") {
        alignment.* = .@"1";
        const enum_ty = Type.fromInterned(lazy_sym.ty);
        const tag_names = enum_ty.enumFields(zcu);
        for (0..tag_names.len) |tag_index| {
            const tag_name = tag_names.get(ip)[tag_index].toSlice(ip);
            try code.ensureUnusedCapacity(gpa, tag_name.len + 1);
            code.appendSliceAssumeCapacity(tag_name);
            code.appendAssumeCapacity(0);
        }
    } else {
        return zcu.codegenFailType(lazy_sym.ty, "TODO implement generateLazySymbol for {s} {}", .{
            @tagName(lazy_sym.kind), Type.fromInterned(lazy_sym.ty).fmt(pt),
        });
    }
}

pub const GenerateSymbolError = error{
    OutOfMemory,
    /// Compiler was asked to operate on a number larger than supported.
    Overflow,
    /// Compiler was asked to produce a non-byte-aligned relocation.
    RelocationNotByteAligned,
};

pub fn generateSymbol(
    bin_file: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    val: Value,
    code: *std.ArrayListUnmanaged(u8),
    reloc_parent: link.File.RelocInfo.Parent,
) GenerateSymbolError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const ty = val.typeOf(zcu);

    const target = zcu.getTarget();
    const endian = target.cpu.arch.endian();

    log.debug("generateSymbol: val = {}", .{val.fmtValue(pt)});

    if (val.isUndefDeep(zcu)) {
        const abi_size = math.cast(usize, ty.abiSize(zcu)) orelse return error.Overflow;
        try code.appendNTimes(gpa, 0xaa, abi_size);
        return;
    }

    switch (ip.indexToKey(val.toIntern())) {
        .int_type,
        .ptr_type,
        .array_type,
        .vector_type,
        .opt_type,
        .anyframe_type,
        .error_union_type,
        .simple_type,
        .struct_type,
        .tuple_type,
        .union_type,
        .opaque_type,
        .enum_type,
        .func_type,
        .error_set_type,
        .inferred_error_set_type,
        => unreachable, // types, not values

        .undef => unreachable, // handled above
        .simple_value => |simple_value| switch (simple_value) {
            .undefined => unreachable, // non-runtime value
            .void => unreachable, // non-runtime value
            .null => unreachable, // non-runtime value
            .@"unreachable" => unreachable, // non-runtime value
            .empty_tuple => return,
            .false, .true => try code.append(gpa, switch (simple_value) {
                .false => 0,
                .true => 1,
                else => unreachable,
            }),
        },
        .variable,
        .@"extern",
        .func,
        .enum_literal,
        .empty_enum_value,
        => unreachable, // non-runtime values
        .int => {
            const abi_size = math.cast(usize, ty.abiSize(zcu)) orelse return error.Overflow;
            var space: Value.BigIntSpace = undefined;
            const int_val = val.toBigInt(&space, zcu);
            int_val.writeTwosComplement(try code.addManyAsSlice(gpa, abi_size), endian);
        },
        .err => |err| {
            const int = try pt.getErrorValue(err.name);
            try code.writer(gpa).writeInt(u16, @intCast(int), endian);
        },
        .error_union => |error_union| {
            const payload_ty = ty.errorUnionPayload(zcu);
            const err_val: u16 = switch (error_union.val) {
                .err_name => |err_name| @intCast(try pt.getErrorValue(err_name)),
                .payload => 0,
            };

            if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                try code.writer(gpa).writeInt(u16, err_val, endian);
                return;
            }

            const payload_align = payload_ty.abiAlignment(zcu);
            const error_align = Type.anyerror.abiAlignment(zcu);
            const abi_align = ty.abiAlignment(zcu);

            // error value first when its type is larger than the error union's payload
            if (error_align.order(payload_align) == .gt) {
                try code.writer(gpa).writeInt(u16, err_val, endian);
            }

            // emit payload part of the error union
            {
                const begin = code.items.len;
                try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(switch (error_union.val) {
                    .err_name => try pt.intern(.{ .undef = payload_ty.toIntern() }),
                    .payload => |payload| payload,
                }), code, reloc_parent);
                const unpadded_end = code.items.len - begin;
                const padded_end = abi_align.forward(unpadded_end);
                const padding = math.cast(usize, padded_end - unpadded_end) orelse return error.Overflow;

                if (padding > 0) {
                    try code.appendNTimes(gpa, 0, padding);
                }
            }

            // Payload size is larger than error set, so emit our error set last
            if (error_align.compare(.lte, payload_align)) {
                const begin = code.items.len;
                try code.writer(gpa).writeInt(u16, err_val, endian);
                const unpadded_end = code.items.len - begin;
                const padded_end = abi_align.forward(unpadded_end);
                const padding = math.cast(usize, padded_end - unpadded_end) orelse return error.Overflow;

                if (padding > 0) {
                    try code.appendNTimes(gpa, 0, padding);
                }
            }
        },
        .enum_tag => |enum_tag| {
            const int_tag_ty = ty.intTagType(zcu);
            try generateSymbol(bin_file, pt, src_loc, try pt.getCoerced(Value.fromInterned(enum_tag.int), int_tag_ty), code, reloc_parent);
        },
        .float => |float| switch (float.storage) {
            .f16 => |f16_val| writeFloat(f16, f16_val, target, endian, try code.addManyAsArray(gpa, 2)),
            .f32 => |f32_val| writeFloat(f32, f32_val, target, endian, try code.addManyAsArray(gpa, 4)),
            .f64 => |f64_val| writeFloat(f64, f64_val, target, endian, try code.addManyAsArray(gpa, 8)),
            .f80 => |f80_val| {
                writeFloat(f80, f80_val, target, endian, try code.addManyAsArray(gpa, 10));
                const abi_size = math.cast(usize, ty.abiSize(zcu)) orelse return error.Overflow;
                try code.appendNTimes(gpa, 0, abi_size - 10);
            },
            .f128 => |f128_val| writeFloat(f128, f128_val, target, endian, try code.addManyAsArray(gpa, 16)),
        },
        .ptr => try lowerPtr(bin_file, pt, src_loc, val.toIntern(), code, reloc_parent, 0),
        .slice => |slice| {
            try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(slice.ptr), code, reloc_parent);
            try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(slice.len), code, reloc_parent);
        },
        .opt => {
            const payload_type = ty.optionalChild(zcu);
            const payload_val = val.optionalValue(zcu);
            const abi_size = math.cast(usize, ty.abiSize(zcu)) orelse return error.Overflow;

            if (ty.optionalReprIsPayload(zcu)) {
                if (payload_val) |value| {
                    try generateSymbol(bin_file, pt, src_loc, value, code, reloc_parent);
                } else {
                    try code.appendNTimes(gpa, 0, abi_size);
                }
            } else {
                const padding = abi_size - (math.cast(usize, payload_type.abiSize(zcu)) orelse return error.Overflow) - 1;
                if (payload_type.hasRuntimeBits(zcu)) {
                    const value = payload_val orelse Value.fromInterned(try pt.intern(.{
                        .undef = payload_type.toIntern(),
                    }));
                    try generateSymbol(bin_file, pt, src_loc, value, code, reloc_parent);
                }
                try code.writer(gpa).writeByte(@intFromBool(payload_val != null));
                try code.appendNTimes(gpa, 0, padding);
            }
        },
        .aggregate => |aggregate| switch (ip.indexToKey(ty.toIntern())) {
            .array_type => |array_type| switch (aggregate.storage) {
                .bytes => |bytes| try code.appendSlice(gpa, bytes.toSlice(array_type.lenIncludingSentinel(), ip)),
                .elems, .repeated_elem => {
                    var index: u64 = 0;
                    while (index < array_type.lenIncludingSentinel()) : (index += 1) {
                        try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(switch (aggregate.storage) {
                            .bytes => unreachable,
                            .elems => |elems| elems[@intCast(index)],
                            .repeated_elem => |elem| if (index < array_type.len)
                                elem
                            else
                                array_type.sentinel,
                        }), code, reloc_parent);
                    }
                },
            },
            .vector_type => |vector_type| {
                const abi_size = math.cast(usize, ty.abiSize(zcu)) orelse return error.Overflow;
                if (vector_type.child == .bool_type) {
                    const bytes = try code.addManyAsSlice(gpa, abi_size);
                    @memset(bytes, 0xaa);
                    var index: usize = 0;
                    const len = math.cast(usize, vector_type.len) orelse return error.Overflow;
                    while (index < len) : (index += 1) {
                        const bit_index = switch (endian) {
                            .big => len - 1 - index,
                            .little => index,
                        };
                        const byte = &bytes[bit_index / 8];
                        const mask = @as(u8, 1) << @truncate(bit_index);
                        if (switch (switch (aggregate.storage) {
                            .bytes => unreachable,
                            .elems => |elems| elems[index],
                            .repeated_elem => |elem| elem,
                        }) {
                            .bool_true => true,
                            .bool_false => false,
                            else => |elem| switch (ip.indexToKey(elem)) {
                                .undef => continue,
                                .int => |int| switch (int.storage) {
                                    .u64 => |x| switch (x) {
                                        0 => false,
                                        1 => true,
                                        else => unreachable,
                                    },
                                    .i64 => |x| switch (x) {
                                        -1 => true,
                                        0 => false,
                                        else => unreachable,
                                    },
                                    else => unreachable,
                                },
                                else => unreachable,
                            },
                        }) byte.* |= mask else byte.* &= ~mask;
                    }
                } else {
                    switch (aggregate.storage) {
                        .bytes => |bytes| try code.appendSlice(gpa, bytes.toSlice(vector_type.len, ip)),
                        .elems, .repeated_elem => {
                            var index: u64 = 0;
                            while (index < vector_type.len) : (index += 1) {
                                try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(switch (aggregate.storage) {
                                    .bytes => unreachable,
                                    .elems => |elems| elems[
                                        math.cast(usize, index) orelse return error.Overflow
                                    ],
                                    .repeated_elem => |elem| elem,
                                }), code, reloc_parent);
                            }
                        },
                    }

                    const padding = abi_size -
                        (math.cast(usize, Type.fromInterned(vector_type.child).abiSize(zcu) * vector_type.len) orelse
                            return error.Overflow);
                    if (padding > 0) try code.appendNTimes(gpa, 0, padding);
                }
            },
            .tuple_type => |tuple| {
                const struct_begin = code.items.len;
                for (
                    tuple.types.get(ip),
                    tuple.values.get(ip),
                    0..,
                ) |field_ty, comptime_val, index| {
                    if (comptime_val != .none) continue;
                    if (!Type.fromInterned(field_ty).hasRuntimeBits(zcu)) continue;

                    const field_val = switch (aggregate.storage) {
                        .bytes => |bytes| try pt.intern(.{ .int = .{
                            .ty = field_ty,
                            .storage = .{ .u64 = bytes.at(index, ip) },
                        } }),
                        .elems => |elems| elems[index],
                        .repeated_elem => |elem| elem,
                    };

                    try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(field_val), code, reloc_parent);
                    const unpadded_field_end = code.items.len - struct_begin;

                    // Pad struct members if required
                    const padded_field_end = ty.structFieldOffset(index + 1, zcu);
                    const padding = math.cast(usize, padded_field_end - unpadded_field_end) orelse
                        return error.Overflow;

                    if (padding > 0) {
                        try code.appendNTimes(gpa, 0, padding);
                    }
                }
            },
            .struct_type => {
                const struct_type = ip.loadStructType(ty.toIntern());
                switch (struct_type.layout) {
                    .@"packed" => {
                        const abi_size = math.cast(usize, ty.abiSize(zcu)) orelse return error.Overflow;
                        const current_pos = code.items.len;
                        try code.appendNTimes(gpa, 0, abi_size);
                        var bits: u16 = 0;

                        for (struct_type.field_types.get(ip), 0..) |field_ty, index| {
                            const field_val = switch (aggregate.storage) {
                                .bytes => |bytes| try pt.intern(.{ .int = .{
                                    .ty = field_ty,
                                    .storage = .{ .u64 = bytes.at(index, ip) },
                                } }),
                                .elems => |elems| elems[index],
                                .repeated_elem => |elem| elem,
                            };

                            // pointer may point to a decl which must be marked used
                            // but can also result in a relocation. Therefore we handle those separately.
                            if (Type.fromInterned(field_ty).zigTypeTag(zcu) == .pointer) {
                                const field_offset = std.math.divExact(u16, bits, 8) catch |err| switch (err) {
                                    error.DivisionByZero => unreachable,
                                    error.UnexpectedRemainder => return error.RelocationNotByteAligned,
                                };
                                code.items.len = current_pos + field_offset;
                                // TODO: code.lockPointers();
                                defer {
                                    assert(code.items.len == current_pos + field_offset + @divExact(target.ptrBitWidth(), 8));
                                    // TODO: code.unlockPointers();
                                    code.items.len = current_pos + abi_size;
                                }
                                try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(field_val), code, reloc_parent);
                            } else {
                                Value.fromInterned(field_val).writeToPackedMemory(Type.fromInterned(field_ty), pt, code.items[current_pos..], bits) catch unreachable;
                            }
                            bits += @intCast(Type.fromInterned(field_ty).bitSize(zcu));
                        }
                    },
                    .auto, .@"extern" => {
                        const struct_begin = code.items.len;
                        const field_types = struct_type.field_types.get(ip);
                        const offsets = struct_type.offsets.get(ip);

                        var it = struct_type.iterateRuntimeOrder(ip);
                        while (it.next()) |field_index| {
                            const field_ty = field_types[field_index];
                            if (!Type.fromInterned(field_ty).hasRuntimeBits(zcu)) continue;

                            const field_val = switch (ip.indexToKey(val.toIntern()).aggregate.storage) {
                                .bytes => |bytes| try pt.intern(.{ .int = .{
                                    .ty = field_ty,
                                    .storage = .{ .u64 = bytes.at(field_index, ip) },
                                } }),
                                .elems => |elems| elems[field_index],
                                .repeated_elem => |elem| elem,
                            };

                            const padding = math.cast(
                                usize,
                                offsets[field_index] - (code.items.len - struct_begin),
                            ) orelse return error.Overflow;
                            if (padding > 0) try code.appendNTimes(gpa, 0, padding);

                            try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(field_val), code, reloc_parent);
                        }

                        const size = struct_type.sizeUnordered(ip);
                        const alignment = struct_type.flagsUnordered(ip).alignment.toByteUnits().?;

                        const padding = math.cast(
                            usize,
                            std.mem.alignForward(u64, size, @max(alignment, 1)) -
                                (code.items.len - struct_begin),
                        ) orelse return error.Overflow;
                        if (padding > 0) try code.appendNTimes(gpa, 0, padding);
                    },
                }
            },
            else => unreachable,
        },
        .un => |un| {
            const layout = ty.unionGetLayout(zcu);

            if (layout.payload_size == 0) {
                return generateSymbol(bin_file, pt, src_loc, Value.fromInterned(un.tag), code, reloc_parent);
            }

            // Check if we should store the tag first.
            if (layout.tag_size > 0 and layout.tag_align.compare(.gte, layout.payload_align)) {
                try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(un.tag), code, reloc_parent);
            }

            const union_obj = zcu.typeToUnion(ty).?;
            if (un.tag != .none) {
                const field_index = ty.unionTagFieldIndex(Value.fromInterned(un.tag), zcu).?;
                const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[field_index]);
                if (!field_ty.hasRuntimeBits(zcu)) {
                    try code.appendNTimes(gpa, 0xaa, math.cast(usize, layout.payload_size) orelse return error.Overflow);
                } else {
                    try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(un.val), code, reloc_parent);

                    const padding = math.cast(usize, layout.payload_size - field_ty.abiSize(zcu)) orelse return error.Overflow;
                    if (padding > 0) {
                        try code.appendNTimes(gpa, 0, padding);
                    }
                }
            } else {
                try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(un.val), code, reloc_parent);
            }

            if (layout.tag_size > 0 and layout.tag_align.compare(.lt, layout.payload_align)) {
                try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(un.tag), code, reloc_parent);

                if (layout.padding > 0) {
                    try code.appendNTimes(gpa, 0, layout.padding);
                }
            }
        },
        .memoized_call => unreachable,
    }
}

fn lowerPtr(
    bin_file: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    ptr_val: InternPool.Index,
    code: *std.ArrayListUnmanaged(u8),
    reloc_parent: link.File.RelocInfo.Parent,
    prev_offset: u64,
) GenerateSymbolError!void {
    const zcu = pt.zcu;
    const ptr = zcu.intern_pool.indexToKey(ptr_val).ptr;
    const offset: u64 = prev_offset + ptr.byte_offset;
    return switch (ptr.base_addr) {
        .nav => |nav| try lowerNavRef(bin_file, pt, nav, code, reloc_parent, offset),
        .uav => |uav| try lowerUavRef(bin_file, pt, src_loc, uav, code, reloc_parent, offset),
        .int => try generateSymbol(bin_file, pt, src_loc, try pt.intValue(Type.usize, offset), code, reloc_parent),
        .eu_payload => |eu_ptr| try lowerPtr(
            bin_file,
            pt,
            src_loc,
            eu_ptr,
            code,
            reloc_parent,
            offset + errUnionPayloadOffset(
                Value.fromInterned(eu_ptr).typeOf(zcu).childType(zcu).errorUnionPayload(zcu),
                zcu,
            ),
        ),
        .opt_payload => |opt_ptr| try lowerPtr(bin_file, pt, src_loc, opt_ptr, code, reloc_parent, offset),
        .field => |field| {
            const base_ptr = Value.fromInterned(field.base);
            const base_ty = base_ptr.typeOf(zcu).childType(zcu);
            const field_off: u64 = switch (base_ty.zigTypeTag(zcu)) {
                .pointer => off: {
                    assert(base_ty.isSlice(zcu));
                    break :off switch (field.index) {
                        Value.slice_ptr_index => 0,
                        Value.slice_len_index => @divExact(zcu.getTarget().ptrBitWidth(), 8),
                        else => unreachable,
                    };
                },
                .@"struct", .@"union" => switch (base_ty.containerLayout(zcu)) {
                    .auto => base_ty.structFieldOffset(@intCast(field.index), zcu),
                    .@"extern", .@"packed" => unreachable,
                },
                else => unreachable,
            };
            return lowerPtr(bin_file, pt, src_loc, field.base, code, reloc_parent, offset + field_off);
        },
        .arr_elem, .comptime_field, .comptime_alloc => unreachable,
    };
}

fn lowerUavRef(
    lf: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    uav: InternPool.Key.Ptr.BaseAddr.Uav,
    code: *std.ArrayListUnmanaged(u8),
    reloc_parent: link.File.RelocInfo.Parent,
    offset: u64,
) GenerateSymbolError!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const comp = lf.comp;
    const target = &comp.root_mod.resolved_target.result;
    const ptr_width_bytes = @divExact(target.ptrBitWidth(), 8);
    const uav_val = uav.val;
    const uav_ty = Type.fromInterned(ip.typeOf(uav_val));
    const is_fn_body = uav_ty.zigTypeTag(zcu) == .@"fn";

    log.debug("lowerUavRef: ty = {}", .{uav_ty.fmt(pt)});
    try code.ensureUnusedCapacity(gpa, ptr_width_bytes);

    if (!is_fn_body and !uav_ty.hasRuntimeBits(zcu)) {
        code.appendNTimesAssumeCapacity(0xaa, ptr_width_bytes);
        return;
    }

    switch (lf.tag) {
        .c => unreachable,
        .spirv => unreachable,
        .wasm => {
            dev.check(link.File.Tag.wasm.devFeature());
            const wasm = lf.cast(.wasm).?;
            assert(reloc_parent == .none);
            try wasm.addUavReloc(code.items.len, uav.val, uav.orig_ty, @intCast(offset));
            code.appendNTimesAssumeCapacity(0, ptr_width_bytes);
            return;
        },
        else => {},
    }

    const uav_align = ip.indexToKey(uav.orig_ty).ptr_type.flags.alignment;
    switch (try lf.lowerUav(pt, uav_val, uav_align, src_loc)) {
        .sym_index => {},
        .fail => |em| std.debug.panic("TODO rework lowerUav. internal error: {s}", .{em.msg}),
    }

    const vaddr = try lf.getUavVAddr(uav_val, .{
        .parent = reloc_parent,
        .offset = code.items.len,
        .addend = @intCast(offset),
    });
    const endian = target.cpu.arch.endian();
    switch (ptr_width_bytes) {
        2 => mem.writeInt(u16, code.addManyAsArrayAssumeCapacity(2), @intCast(vaddr), endian),
        4 => mem.writeInt(u32, code.addManyAsArrayAssumeCapacity(4), @intCast(vaddr), endian),
        8 => mem.writeInt(u64, code.addManyAsArrayAssumeCapacity(8), vaddr, endian),
        else => unreachable,
    }
}

fn lowerNavRef(
    lf: *link.File,
    pt: Zcu.PerThread,
    nav_index: InternPool.Nav.Index,
    code: *std.ArrayListUnmanaged(u8),
    reloc_parent: link.File.RelocInfo.Parent,
    offset: u64,
) GenerateSymbolError!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const target = &zcu.navFileScope(nav_index).mod.?.resolved_target.result;
    const ptr_width_bytes = @divExact(target.ptrBitWidth(), 8);
    const is_obj = lf.comp.config.output_mode == .Obj;
    const nav_ty = Type.fromInterned(ip.getNav(nav_index).typeOf(ip));
    const is_fn_body = nav_ty.zigTypeTag(zcu) == .@"fn";

    try code.ensureUnusedCapacity(gpa, ptr_width_bytes);

    if (!is_fn_body and !nav_ty.hasRuntimeBits(zcu)) {
        code.appendNTimesAssumeCapacity(0xaa, ptr_width_bytes);
        return;
    }

    switch (lf.tag) {
        .c => unreachable,
        .spirv => unreachable,
        .wasm => {
            dev.check(link.File.Tag.wasm.devFeature());
            const wasm = lf.cast(.wasm).?;
            assert(reloc_parent == .none);
            if (is_fn_body) {
                const gop = try wasm.zcu_indirect_function_set.getOrPut(gpa, nav_index);
                if (!gop.found_existing) gop.value_ptr.* = {};
                if (is_obj) {
                    @panic("TODO add out_reloc for this");
                } else {
                    try wasm.func_table_fixups.append(gpa, .{
                        .table_index = @enumFromInt(gop.index),
                        .offset = @intCast(code.items.len),
                    });
                }
            } else {
                if (is_obj) {
                    try wasm.out_relocs.append(gpa, .{
                        .offset = @intCast(code.items.len),
                        .pointee = .{ .symbol_index = try wasm.navSymbolIndex(nav_index) },
                        .tag = if (ptr_width_bytes == 4) .memory_addr_i32 else .memory_addr_i64,
                        .addend = @intCast(offset),
                    });
                } else {
                    try wasm.nav_fixups.ensureUnusedCapacity(gpa, 1);
                    wasm.nav_fixups.appendAssumeCapacity(.{
                        .navs_exe_index = try wasm.refNavExe(nav_index),
                        .offset = @intCast(code.items.len),
                        .addend = @intCast(offset),
                    });
                }
            }
            code.appendNTimesAssumeCapacity(0, ptr_width_bytes);
            return;
        },
        else => {},
    }

    const vaddr = lf.getNavVAddr(pt, nav_index, .{
        .parent = reloc_parent,
        .offset = code.items.len,
        .addend = @intCast(offset),
    }) catch @panic("TODO rework getNavVAddr");
    const endian = target.cpu.arch.endian();
    switch (ptr_width_bytes) {
        2 => mem.writeInt(u16, code.addManyAsArrayAssumeCapacity(2), @intCast(vaddr), endian),
        4 => mem.writeInt(u32, code.addManyAsArrayAssumeCapacity(4), @intCast(vaddr), endian),
        8 => mem.writeInt(u64, code.addManyAsArrayAssumeCapacity(8), vaddr, endian),
        else => unreachable,
    }
}

/// Helper struct to denote that the value is in memory but requires a linker relocation fixup:
/// * got - the value is referenced indirectly via GOT entry index (the linker emits a got-type reloc)
/// * direct - the value is referenced directly via symbol index index (the linker emits a displacement reloc)
/// * import - the value is referenced indirectly via import entry index (the linker emits an import-type reloc)
pub const LinkerLoad = struct {
    type: enum {
        got,
        direct,
        import,
    },
    sym_index: u32,
};

pub const SymbolResult = union(enum) { sym_index: u32, fail: *ErrorMsg };

pub fn genNavRef(
    lf: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    nav_index: InternPool.Nav.Index,
    target: *const std.Target,
) CodeGenError!SymbolResult {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);
    log.debug("genNavRef({})", .{nav.fqn.fmt(ip)});

    const lib_name, const linkage, const is_threadlocal = if (nav.getExtern(ip)) |e|
        .{ e.lib_name, e.linkage, e.is_threadlocal and zcu.comp.config.any_non_single_threaded }
    else
        .{ .none, .internal, false };
    if (lf.cast(.elf)) |elf_file| {
        const zo = elf_file.zigObjectPtr().?;
        switch (linkage) {
            .internal => {
                const sym_index = try zo.getOrCreateMetadataForNav(zcu, nav_index);
                if (is_threadlocal) zo.symbol(sym_index).flags.is_tls = true;
                return .{ .sym_index = sym_index };
            },
            .strong, .weak => {
                const sym_index = try elf_file.getGlobalSymbol(nav.name.toSlice(ip), lib_name.toSlice(ip));
                switch (linkage) {
                    .internal => unreachable,
                    .strong => {},
                    .weak => zo.symbol(sym_index).flags.weak = true,
                    .link_once => unreachable,
                }
                if (is_threadlocal) zo.symbol(sym_index).flags.is_tls = true;
                return .{ .sym_index = sym_index };
            },
            .link_once => unreachable,
        }
    } else if (lf.cast(.macho)) |macho_file| {
        const zo = macho_file.getZigObject().?;
        switch (linkage) {
            .internal => {
                const sym_index = try zo.getOrCreateMetadataForNav(macho_file, nav_index);
                if (is_threadlocal) zo.symbols.items[sym_index].flags.tlv = true;
                return .{ .sym_index = sym_index };
            },
            .strong, .weak => {
                const sym_index = try macho_file.getGlobalSymbol(nav.name.toSlice(ip), lib_name.toSlice(ip));
                switch (linkage) {
                    .internal => unreachable,
                    .strong => {},
                    .weak => zo.symbols.items[sym_index].flags.weak = true,
                    .link_once => unreachable,
                }
                if (is_threadlocal) zo.symbols.items[sym_index].flags.tlv = true;
                return .{ .sym_index = sym_index };
            },
            .link_once => unreachable,
        }
    } else if (lf.cast(.coff)) |coff_file| {
        // TODO audit this
        switch (linkage) {
            .internal => {
                const atom_index = try coff_file.getOrCreateAtomForNav(nav_index);
                const sym_index = coff_file.getAtom(atom_index).getSymbolIndex().?;
                return .{ .sym_index = sym_index };
            },
            .strong, .weak => {
                const global_index = try coff_file.getGlobalSymbol(nav.name.toSlice(ip), lib_name.toSlice(ip));
                try coff_file.need_got_table.put(zcu.gpa, global_index, {}); // needs GOT
                return .{ .sym_index = global_index };
            },
            .link_once => unreachable,
        }
    } else if (lf.cast(.plan9)) |p9| {
        return .{ .sym_index = try p9.seeNav(pt, nav_index) };
    } else {
        const msg = try ErrorMsg.create(zcu.gpa, src_loc, "TODO genNavRef for target {}", .{target});
        return .{ .fail = msg };
    }
}

/// deprecated legacy type
pub const GenResult = union(enum) {
    mcv: MCValue,
    fail: *ErrorMsg,

    const MCValue = union(enum) {
        none,
        undef,
        /// The bit-width of the immediate may be smaller than `u64`. For example, on 32-bit targets
        /// such as ARM, the immediate will never exceed 32-bits.
        immediate: u64,
        /// Decl with address deferred until the linker allocates everything in virtual memory.
        /// Payload is a symbol index.
        load_direct: u32,
        /// Decl with address deferred until the linker allocates everything in virtual memory.
        /// Payload is a symbol index.
        lea_direct: u32,
        /// Decl referenced via GOT with address deferred until the linker allocates
        /// everything in virtual memory.
        /// Payload is a symbol index.
        load_got: u32,
        /// Direct by-address reference to memory location.
        memory: u64,
        /// Reference to memory location but deferred until linker allocated the Decl in memory.
        /// Traditionally, this corresponds to emitting a relocation in a relocatable object file.
        load_symbol: u32,
        /// Reference to memory location but deferred until linker allocated the Decl in memory.
        /// Traditionally, this corresponds to emitting a relocation in a relocatable object file.
        lea_symbol: u32,
    };
};

/// deprecated legacy code path
pub fn genTypedValue(
    lf: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    val: Value,
    target: *const std.Target,
) CodeGenError!GenResult {
    const res = try lowerValue(pt, val, target);
    return switch (res) {
        .none => .{ .mcv = .none },
        .undef => .{ .mcv = .undef },
        .immediate => |imm| .{ .mcv = .{ .immediate = imm } },
        .lea_nav => |nav| switch (try genNavRef(lf, pt, src_loc, nav, target)) {
            .sym_index => |sym_index| .{ .mcv = .{ .lea_symbol = sym_index } },
            .fail => |em| .{ .fail = em },
        },
        .load_uav, .lea_uav => |uav| switch (try lf.lowerUav(
            pt,
            uav.val,
            Type.fromInterned(uav.orig_ty).ptrAlignment(pt.zcu),
            src_loc,
        )) {
            .sym_index => |sym_index| .{ .mcv = switch (res) {
                else => unreachable,
                .load_uav => .{ .load_symbol = sym_index },
                .lea_uav => .{ .lea_symbol = sym_index },
            } },
            .fail => |em| .{ .fail = em },
        },
    };
}

const LowerResult = union(enum) {
    none,
    undef,
    /// The bit-width of the immediate may be smaller than `u64`. For example, on 32-bit targets
    /// such as ARM, the immediate will never exceed 32-bits.
    immediate: u64,
    lea_nav: InternPool.Nav.Index,
    load_uav: InternPool.Key.Ptr.BaseAddr.Uav,
    lea_uav: InternPool.Key.Ptr.BaseAddr.Uav,
};

pub fn lowerValue(pt: Zcu.PerThread, val: Value, target: *const std.Target) Allocator.Error!LowerResult {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const ty = val.typeOf(zcu);

    log.debug("lowerValue(@as({}, {}))", .{ ty.fmt(pt), val.fmtValue(pt) });

    if (val.isUndef(zcu)) return .undef;

    switch (ty.zigTypeTag(zcu)) {
        .void => return .none,
        .pointer => switch (ty.ptrSize(zcu)) {
            .slice => {},
            else => switch (val.toIntern()) {
                .null_value => {
                    return .{ .immediate = 0 };
                },
                else => switch (ip.indexToKey(val.toIntern())) {
                    .int => {
                        return .{ .immediate = val.toUnsignedInt(zcu) };
                    },
                    .ptr => |ptr| if (ptr.byte_offset == 0) switch (ptr.base_addr) {
                        .nav => |nav| {
                            if (!ty.isFnOrHasRuntimeBitsIgnoreComptime(zcu)) {
                                const imm: u64 = switch (@divExact(target.ptrBitWidth(), 8)) {
                                    1 => 0xaa,
                                    2 => 0xaaaa,
                                    4 => 0xaaaaaaaa,
                                    8 => 0xaaaaaaaaaaaaaaaa,
                                    else => unreachable,
                                };
                                return .{ .immediate = imm };
                            }

                            if (ty.castPtrToFn(zcu)) |fn_ty| {
                                if (zcu.typeToFunc(fn_ty).?.is_generic) {
                                    return .{ .immediate = fn_ty.abiAlignment(zcu).toByteUnits().? };
                                }
                            } else if (ty.zigTypeTag(zcu) == .pointer) {
                                const elem_ty = ty.elemType2(zcu);
                                if (!elem_ty.hasRuntimeBits(zcu)) {
                                    return .{ .immediate = elem_ty.abiAlignment(zcu).toByteUnits().? };
                                }
                            }

                            return .{ .lea_nav = nav };
                        },
                        .uav => |uav| if (Value.fromInterned(uav.val).typeOf(zcu).hasRuntimeBits(zcu))
                            return .{ .lea_uav = uav }
                        else
                            return .{ .immediate = Type.fromInterned(uav.orig_ty).ptrAlignment(zcu)
                                .forward(@intCast((@as(u66, 1) << @intCast(target.ptrBitWidth() | 1)) / 3)) },
                        else => {},
                    },
                    else => {},
                },
            },
        },
        .int => {
            const info = ty.intInfo(zcu);
            if (info.bits <= target.ptrBitWidth()) {
                const unsigned: u64 = switch (info.signedness) {
                    .signed => @bitCast(val.toSignedInt(zcu)),
                    .unsigned => val.toUnsignedInt(zcu),
                };
                return .{ .immediate = unsigned };
            }
        },
        .bool => {
            return .{ .immediate = @intFromBool(val.toBool()) };
        },
        .optional => {
            if (ty.isPtrLikeOptional(zcu)) {
                return lowerValue(
                    pt,
                    val.optionalValue(zcu) orelse return .{ .immediate = 0 },
                    target,
                );
            } else if (ty.abiSize(zcu) == 1) {
                return .{ .immediate = @intFromBool(!val.isNull(zcu)) };
            }
        },
        .@"enum" => {
            const enum_tag = ip.indexToKey(val.toIntern()).enum_tag;
            return lowerValue(
                pt,
                Value.fromInterned(enum_tag.int),
                target,
            );
        },
        .error_set => {
            const err_name = ip.indexToKey(val.toIntern()).err.name;
            const error_index = ip.getErrorValueIfExists(err_name).?;
            return .{ .immediate = error_index };
        },
        .error_union => {
            const err_type = ty.errorUnionSet(zcu);
            const payload_type = ty.errorUnionPayload(zcu);
            if (!payload_type.hasRuntimeBitsIgnoreComptime(zcu)) {
                // We use the error type directly as the type.
                const err_int_ty = try pt.errorIntType();
                switch (ip.indexToKey(val.toIntern()).error_union.val) {
                    .err_name => |err_name| return lowerValue(
                        pt,
                        Value.fromInterned(try pt.intern(.{ .err = .{
                            .ty = err_type.toIntern(),
                            .name = err_name,
                        } })),
                        target,
                    ),
                    .payload => return lowerValue(
                        pt,
                        try pt.intValue(err_int_ty, 0),
                        target,
                    ),
                }
            }
        },

        .comptime_int => unreachable,
        .comptime_float => unreachable,
        .type => unreachable,
        .enum_literal => unreachable,
        .noreturn => unreachable,
        .undefined => unreachable,
        .null => unreachable,
        .@"opaque" => unreachable,

        else => {},
    }

    return .{ .load_uav = .{
        .val = val.toIntern(),
        .orig_ty = (try pt.singleConstPtrType(ty)).toIntern(),
    } };
}

pub fn errUnionPayloadOffset(payload_ty: Type, zcu: *Zcu) u64 {
    if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) return 0;
    const payload_align = payload_ty.abiAlignment(zcu);
    const error_align = Type.anyerror.abiAlignment(zcu);
    if (payload_align.compare(.gte, error_align) or !payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        return 0;
    } else {
        return payload_align.forward(Type.anyerror.abiSize(zcu));
    }
}

pub fn errUnionErrorOffset(payload_ty: Type, zcu: *Zcu) u64 {
    if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) return 0;
    const payload_align = payload_ty.abiAlignment(zcu);
    const error_align = Type.anyerror.abiAlignment(zcu);
    if (payload_align.compare(.gte, error_align) and payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        return error_align.forward(payload_ty.abiSize(zcu));
    } else {
        return 0;
    }
}
