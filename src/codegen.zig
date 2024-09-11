const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
const leb128 = std.leb;
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
const Liveness = @import("Liveness.zig");
const Zcu = @import("Zcu.zig");

const Type = @import("Type.zig");
const Value = @import("Value.zig");
const Zir = std.zig.Zir;
const Alignment = InternPool.Alignment;
const dev = @import("dev.zig");

pub const Result = union(enum) {
    /// The `code` parameter passed to `generateSymbol` has the value ok.
    ok,

    /// There was a codegen error.
    fail: *ErrorMsg,
};

pub const CodeGenError = error{
    OutOfMemory,
    Overflow,
    CodegenFail,
} || link.File.UpdateDebugInfoError;

fn devFeatureForBackend(comptime backend: std.builtin.CompilerBackend) dev.Feature {
    comptime assert(mem.startsWith(u8, @tagName(backend), "stage2_"));
    return @field(dev.Feature, @tagName(backend)["stage2_".len..] ++ "_backend");
}

fn importBackend(comptime backend: std.builtin.CompilerBackend) type {
    return switch (backend) {
        .stage2_aarch64 => @import("arch/aarch64/CodeGen.zig"),
        .stage2_arm => @import("arch/arm/CodeGen.zig"),
        .stage2_riscv64 => @import("arch/riscv64/CodeGen.zig"),
        .stage2_sparc64 => @import("arch/sparc64/CodeGen.zig"),
        .stage2_wasm => @import("arch/wasm/CodeGen.zig"),
        .stage2_x86_64 => @import("arch/x86_64/CodeGen.zig"),
        else => unreachable,
    };
}

pub fn generateFunction(
    lf: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
    code: *std.ArrayList(u8),
    debug_output: link.File.DebugInfoOutput,
) CodeGenError!Result {
    const zcu = pt.zcu;
    const func = zcu.funcInfo(func_index);
    const target = zcu.navFileScope(func.owner_nav).mod.resolved_target.result;
    switch (target_util.zigBackend(target, false)) {
        else => unreachable,
        inline .stage2_aarch64,
        .stage2_arm,
        .stage2_riscv64,
        .stage2_sparc64,
        .stage2_wasm,
        .stage2_x86_64,
        => |backend| {
            dev.check(devFeatureForBackend(backend));
            return importBackend(backend).generate(lf, pt, src_loc, func_index, air, liveness, code, debug_output);
        },
    }
}

pub fn generateLazyFunction(
    lf: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    lazy_sym: link.File.LazySymbol,
    code: *std.ArrayList(u8),
    debug_output: link.File.DebugInfoOutput,
) CodeGenError!Result {
    const zcu = pt.zcu;
    const file = Type.fromInterned(lazy_sym.ty).typeDeclInstAllowGeneratedTag(zcu).?.resolveFile(&zcu.intern_pool);
    const target = zcu.fileByIndex(file).mod.resolved_target.result;
    switch (target_util.zigBackend(target, false)) {
        else => unreachable,
        inline .stage2_x86_64,
        .stage2_riscv64,
        => |backend| {
            dev.check(devFeatureForBackend(backend));
            return importBackend(backend).generateLazy(lf, pt, src_loc, lazy_sym, code, debug_output);
        },
    }
}

fn writeFloat(comptime F: type, f: F, target: std.Target, endian: std.builtin.Endian, code: []u8) void {
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
    code: *std.ArrayList(u8),
    debug_output: link.File.DebugInfoOutput,
    reloc_parent: link.File.RelocInfo.Parent,
) CodeGenError!Result {
    _ = reloc_parent;

    const tracy = trace(@src());
    defer tracy.end();

    const comp = bin_file.comp;
    const ip = &pt.zcu.intern_pool;
    const target = comp.root_mod.resolved_target.result;
    const endian = target.cpu.arch.endian();
    const gpa = comp.gpa;

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
        mem.writeInt(u32, try code.addManyAsArray(4), @intCast(err_names.len), endian);
        var offset = code.items.len;
        try code.resize((err_names.len + 1) * 4);
        for (err_names) |err_name_nts| {
            const err_name = err_name_nts.toSlice(ip);
            mem.writeInt(u32, code.items[offset..][0..4], @intCast(code.items.len), endian);
            offset += 4;
            try code.ensureUnusedCapacity(err_name.len + 1);
            code.appendSliceAssumeCapacity(err_name);
            code.appendAssumeCapacity(0);
        }
        mem.writeInt(u32, code.items[offset..][0..4], @intCast(code.items.len), endian);
        return Result.ok;
    } else if (Type.fromInterned(lazy_sym.ty).zigTypeTag(pt.zcu) == .@"enum") {
        alignment.* = .@"1";
        const enum_ty = Type.fromInterned(lazy_sym.ty);
        const tag_names = enum_ty.enumFields(pt.zcu);
        for (0..tag_names.len) |tag_index| {
            const tag_name = tag_names.get(ip)[tag_index].toSlice(ip);
            try code.ensureUnusedCapacity(tag_name.len + 1);
            code.appendSliceAssumeCapacity(tag_name);
            code.appendAssumeCapacity(0);
        }
        return Result.ok;
    } else return .{ .fail = try ErrorMsg.create(
        gpa,
        src_loc,
        "TODO implement generateLazySymbol for {s} {}",
        .{ @tagName(lazy_sym.kind), Type.fromInterned(lazy_sym.ty).fmt(pt) },
    ) };
}

pub fn generateSymbol(
    bin_file: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    val: Value,
    code: *std.ArrayList(u8),
    reloc_parent: link.File.RelocInfo.Parent,
) CodeGenError!Result {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const ty = val.typeOf(zcu);

    const target = zcu.getTarget();
    const endian = target.cpu.arch.endian();

    log.debug("generateSymbol: val = {}", .{val.fmtValue(pt)});

    if (val.isUndefDeep(zcu)) {
        const abi_size = math.cast(usize, ty.abiSize(zcu)) orelse return error.Overflow;
        try code.appendNTimes(0xaa, abi_size);
        return .ok;
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
        .anon_struct_type,
        .union_type,
        .opaque_type,
        .enum_type,
        .func_type,
        .error_set_type,
        .inferred_error_set_type,
        => unreachable, // types, not values

        .undef => unreachable, // handled above
        .simple_value => |simple_value| switch (simple_value) {
            .undefined,
            .void,
            .null,
            .empty_struct,
            .@"unreachable",
            .generic_poison,
            => unreachable, // non-runtime values
            .false, .true => try code.append(switch (simple_value) {
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
            int_val.writeTwosComplement(try code.addManyAsSlice(abi_size), endian);
        },
        .err => |err| {
            const int = try pt.getErrorValue(err.name);
            try code.writer().writeInt(u16, @intCast(int), endian);
        },
        .error_union => |error_union| {
            const payload_ty = ty.errorUnionPayload(zcu);
            const err_val: u16 = switch (error_union.val) {
                .err_name => |err_name| @intCast(try pt.getErrorValue(err_name)),
                .payload => 0,
            };

            if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                try code.writer().writeInt(u16, err_val, endian);
                return .ok;
            }

            const payload_align = payload_ty.abiAlignment(zcu);
            const error_align = Type.anyerror.abiAlignment(zcu);
            const abi_align = ty.abiAlignment(zcu);

            // error value first when its type is larger than the error union's payload
            if (error_align.order(payload_align) == .gt) {
                try code.writer().writeInt(u16, err_val, endian);
            }

            // emit payload part of the error union
            {
                const begin = code.items.len;
                switch (try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(switch (error_union.val) {
                    .err_name => try pt.intern(.{ .undef = payload_ty.toIntern() }),
                    .payload => |payload| payload,
                }), code, reloc_parent)) {
                    .ok => {},
                    .fail => |em| return .{ .fail = em },
                }
                const unpadded_end = code.items.len - begin;
                const padded_end = abi_align.forward(unpadded_end);
                const padding = math.cast(usize, padded_end - unpadded_end) orelse return error.Overflow;

                if (padding > 0) {
                    try code.appendNTimes(0, padding);
                }
            }

            // Payload size is larger than error set, so emit our error set last
            if (error_align.compare(.lte, payload_align)) {
                const begin = code.items.len;
                try code.writer().writeInt(u16, err_val, endian);
                const unpadded_end = code.items.len - begin;
                const padded_end = abi_align.forward(unpadded_end);
                const padding = math.cast(usize, padded_end - unpadded_end) orelse return error.Overflow;

                if (padding > 0) {
                    try code.appendNTimes(0, padding);
                }
            }
        },
        .enum_tag => |enum_tag| {
            const int_tag_ty = ty.intTagType(zcu);
            switch (try generateSymbol(bin_file, pt, src_loc, try pt.getCoerced(Value.fromInterned(enum_tag.int), int_tag_ty), code, reloc_parent)) {
                .ok => {},
                .fail => |em| return .{ .fail = em },
            }
        },
        .float => |float| switch (float.storage) {
            .f16 => |f16_val| writeFloat(f16, f16_val, target, endian, try code.addManyAsArray(2)),
            .f32 => |f32_val| writeFloat(f32, f32_val, target, endian, try code.addManyAsArray(4)),
            .f64 => |f64_val| writeFloat(f64, f64_val, target, endian, try code.addManyAsArray(8)),
            .f80 => |f80_val| {
                writeFloat(f80, f80_val, target, endian, try code.addManyAsArray(10));
                const abi_size = math.cast(usize, ty.abiSize(zcu)) orelse return error.Overflow;
                try code.appendNTimes(0, abi_size - 10);
            },
            .f128 => |f128_val| writeFloat(f128, f128_val, target, endian, try code.addManyAsArray(16)),
        },
        .ptr => switch (try lowerPtr(bin_file, pt, src_loc, val.toIntern(), code, reloc_parent, 0)) {
            .ok => {},
            .fail => |em| return .{ .fail = em },
        },
        .slice => |slice| {
            switch (try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(slice.ptr), code, reloc_parent)) {
                .ok => {},
                .fail => |em| return .{ .fail = em },
            }
            switch (try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(slice.len), code, reloc_parent)) {
                .ok => {},
                .fail => |em| return .{ .fail = em },
            }
        },
        .opt => {
            const payload_type = ty.optionalChild(zcu);
            const payload_val = val.optionalValue(zcu);
            const abi_size = math.cast(usize, ty.abiSize(zcu)) orelse return error.Overflow;

            if (ty.optionalReprIsPayload(zcu)) {
                if (payload_val) |value| {
                    switch (try generateSymbol(bin_file, pt, src_loc, value, code, reloc_parent)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }
                } else {
                    try code.appendNTimes(0, abi_size);
                }
            } else {
                const padding = abi_size - (math.cast(usize, payload_type.abiSize(zcu)) orelse return error.Overflow) - 1;
                if (payload_type.hasRuntimeBits(zcu)) {
                    const value = payload_val orelse Value.fromInterned(try pt.intern(.{
                        .undef = payload_type.toIntern(),
                    }));
                    switch (try generateSymbol(bin_file, pt, src_loc, value, code, reloc_parent)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }
                }
                try code.writer().writeByte(@intFromBool(payload_val != null));
                try code.appendNTimes(0, padding);
            }
        },
        .aggregate => |aggregate| switch (ip.indexToKey(ty.toIntern())) {
            .array_type => |array_type| switch (aggregate.storage) {
                .bytes => |bytes| try code.appendSlice(bytes.toSlice(array_type.lenIncludingSentinel(), ip)),
                .elems, .repeated_elem => {
                    var index: u64 = 0;
                    while (index < array_type.lenIncludingSentinel()) : (index += 1) {
                        switch (try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(switch (aggregate.storage) {
                            .bytes => unreachable,
                            .elems => |elems| elems[@intCast(index)],
                            .repeated_elem => |elem| if (index < array_type.len)
                                elem
                            else
                                array_type.sentinel,
                        }), code, reloc_parent)) {
                            .ok => {},
                            .fail => |em| return .{ .fail = em },
                        }
                    }
                },
            },
            .vector_type => |vector_type| {
                const abi_size = math.cast(usize, ty.abiSize(zcu)) orelse return error.Overflow;
                if (vector_type.child == .bool_type) {
                    const bytes = try code.addManyAsSlice(abi_size);
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
                        .bytes => |bytes| try code.appendSlice(bytes.toSlice(vector_type.len, ip)),
                        .elems, .repeated_elem => {
                            var index: u64 = 0;
                            while (index < vector_type.len) : (index += 1) {
                                switch (try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(switch (aggregate.storage) {
                                    .bytes => unreachable,
                                    .elems => |elems| elems[
                                        math.cast(usize, index) orelse return error.Overflow
                                    ],
                                    .repeated_elem => |elem| elem,
                                }), code, reloc_parent)) {
                                    .ok => {},
                                    .fail => |em| return .{ .fail = em },
                                }
                            }
                        },
                    }

                    const padding = abi_size -
                        (math.cast(usize, Type.fromInterned(vector_type.child).abiSize(zcu) * vector_type.len) orelse
                        return error.Overflow);
                    if (padding > 0) try code.appendNTimes(0, padding);
                }
            },
            .anon_struct_type => |tuple| {
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

                    switch (try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(field_val), code, reloc_parent)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }
                    const unpadded_field_end = code.items.len - struct_begin;

                    // Pad struct members if required
                    const padded_field_end = ty.structFieldOffset(index + 1, zcu);
                    const padding = math.cast(usize, padded_field_end - unpadded_field_end) orelse
                        return error.Overflow;

                    if (padding > 0) {
                        try code.appendNTimes(0, padding);
                    }
                }
            },
            .struct_type => {
                const struct_type = ip.loadStructType(ty.toIntern());
                switch (struct_type.layout) {
                    .@"packed" => {
                        const abi_size = math.cast(usize, ty.abiSize(zcu)) orelse return error.Overflow;
                        const current_pos = code.items.len;
                        try code.appendNTimes(0, abi_size);
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
                                const field_size = math.cast(usize, Type.fromInterned(field_ty).abiSize(zcu)) orelse
                                    return error.Overflow;
                                var tmp_list = try std.ArrayList(u8).initCapacity(code.allocator, field_size);
                                defer tmp_list.deinit();
                                switch (try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(field_val), &tmp_list, reloc_parent)) {
                                    .ok => @memcpy(code.items[current_pos..][0..tmp_list.items.len], tmp_list.items),
                                    .fail => |em| return Result{ .fail = em },
                                }
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
                            if (padding > 0) try code.appendNTimes(0, padding);

                            switch (try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(field_val), code, reloc_parent)) {
                                .ok => {},
                                .fail => |em| return Result{ .fail = em },
                            }
                        }

                        const size = struct_type.sizeUnordered(ip);
                        const alignment = struct_type.flagsUnordered(ip).alignment.toByteUnits().?;

                        const padding = math.cast(
                            usize,
                            std.mem.alignForward(u64, size, @max(alignment, 1)) -
                                (code.items.len - struct_begin),
                        ) orelse return error.Overflow;
                        if (padding > 0) try code.appendNTimes(0, padding);
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
                switch (try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(un.tag), code, reloc_parent)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }
            }

            const union_obj = zcu.typeToUnion(ty).?;
            if (un.tag != .none) {
                const field_index = ty.unionTagFieldIndex(Value.fromInterned(un.tag), zcu).?;
                const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[field_index]);
                if (!field_ty.hasRuntimeBits(zcu)) {
                    try code.appendNTimes(0xaa, math.cast(usize, layout.payload_size) orelse return error.Overflow);
                } else {
                    switch (try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(un.val), code, reloc_parent)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }

                    const padding = math.cast(usize, layout.payload_size - field_ty.abiSize(zcu)) orelse return error.Overflow;
                    if (padding > 0) {
                        try code.appendNTimes(0, padding);
                    }
                }
            } else {
                switch (try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(un.val), code, reloc_parent)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }
            }

            if (layout.tag_size > 0 and layout.tag_align.compare(.lt, layout.payload_align)) {
                switch (try generateSymbol(bin_file, pt, src_loc, Value.fromInterned(un.tag), code, reloc_parent)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }

                if (layout.padding > 0) {
                    try code.appendNTimes(0, layout.padding);
                }
            }
        },
        .memoized_call => unreachable,
    }
    return .ok;
}

fn lowerPtr(
    bin_file: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    ptr_val: InternPool.Index,
    code: *std.ArrayList(u8),
    reloc_parent: link.File.RelocInfo.Parent,
    prev_offset: u64,
) CodeGenError!Result {
    const zcu = pt.zcu;
    const ptr = zcu.intern_pool.indexToKey(ptr_val).ptr;
    const offset: u64 = prev_offset + ptr.byte_offset;
    return switch (ptr.base_addr) {
        .nav => |nav| try lowerNavRef(bin_file, pt, src_loc, nav, code, reloc_parent, offset),
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
    code: *std.ArrayList(u8),
    reloc_parent: link.File.RelocInfo.Parent,
    offset: u64,
) CodeGenError!Result {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const target = lf.comp.root_mod.resolved_target.result;

    const ptr_width_bytes = @divExact(target.ptrBitWidth(), 8);
    const uav_val = uav.val;
    const uav_ty = Type.fromInterned(ip.typeOf(uav_val));
    log.debug("lowerUavRef: ty = {}", .{uav_ty.fmt(pt)});
    const is_fn_body = uav_ty.zigTypeTag(zcu) == .@"fn";
    if (!is_fn_body and !uav_ty.hasRuntimeBits(zcu)) {
        try code.appendNTimes(0xaa, ptr_width_bytes);
        return Result.ok;
    }

    const uav_align = ip.indexToKey(uav.orig_ty).ptr_type.flags.alignment;
    const res = try lf.lowerUav(pt, uav_val, uav_align, src_loc);
    switch (res) {
        .mcv => {},
        .fail => |em| return .{ .fail = em },
    }

    const vaddr = try lf.getUavVAddr(uav_val, .{
        .parent = reloc_parent,
        .offset = code.items.len,
        .addend = @intCast(offset),
    });
    const endian = target.cpu.arch.endian();
    switch (ptr_width_bytes) {
        2 => mem.writeInt(u16, try code.addManyAsArray(2), @intCast(vaddr), endian),
        4 => mem.writeInt(u32, try code.addManyAsArray(4), @intCast(vaddr), endian),
        8 => mem.writeInt(u64, try code.addManyAsArray(8), vaddr, endian),
        else => unreachable,
    }

    return Result.ok;
}

fn lowerNavRef(
    lf: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    nav_index: InternPool.Nav.Index,
    code: *std.ArrayList(u8),
    reloc_parent: link.File.RelocInfo.Parent,
    offset: u64,
) CodeGenError!Result {
    _ = src_loc;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const target = zcu.navFileScope(nav_index).mod.resolved_target.result;

    const ptr_width = target.ptrBitWidth();
    const nav_ty = Type.fromInterned(ip.getNav(nav_index).typeOf(ip));
    const is_fn_body = nav_ty.zigTypeTag(zcu) == .@"fn";
    if (!is_fn_body and !nav_ty.hasRuntimeBits(zcu)) {
        try code.appendNTimes(0xaa, @divExact(ptr_width, 8));
        return Result.ok;
    }

    const vaddr = try lf.getNavVAddr(pt, nav_index, .{
        .parent = reloc_parent,
        .offset = code.items.len,
        .addend = @intCast(offset),
    });
    const endian = target.cpu.arch.endian();
    switch (ptr_width) {
        16 => mem.writeInt(u16, try code.addManyAsArray(2), @intCast(vaddr), endian),
        32 => mem.writeInt(u32, try code.addManyAsArray(4), @intCast(vaddr), endian),
        64 => mem.writeInt(u64, try code.addManyAsArray(8), vaddr, endian),
        else => unreachable,
    }

    return Result.ok;
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

pub const GenResult = union(enum) {
    mcv: MCValue,
    fail: *ErrorMsg,

    const MCValue = union(enum) {
        none,
        undef,
        /// The bit-width of the immediate may be smaller than `u64`. For example, on 32-bit targets
        /// such as ARM, the immediate will never exceed 32-bits.
        immediate: u64,
        /// Threadlocal variable with address deferred until the linker allocates
        /// everything in virtual memory.
        /// Payload is a symbol index.
        load_tlv: u32,
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

fn genNavRef(
    lf: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    val: Value,
    ref_nav_index: InternPool.Nav.Index,
    target: std.Target,
) CodeGenError!GenResult {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const ty = val.typeOf(zcu);
    log.debug("genNavRef: val = {}", .{val.fmtValue(pt)});

    if (!ty.isFnOrHasRuntimeBitsIgnoreComptime(zcu)) {
        const imm: u64 = switch (@divExact(target.ptrBitWidth(), 8)) {
            1 => 0xaa,
            2 => 0xaaaa,
            4 => 0xaaaaaaaa,
            8 => 0xaaaaaaaaaaaaaaaa,
            else => unreachable,
        };
        return .{ .mcv = .{ .immediate = imm } };
    }

    const comp = lf.comp;
    const gpa = comp.gpa;

    // TODO this feels clunky. Perhaps we should check for it in `genTypedValue`?
    if (ty.castPtrToFn(zcu)) |fn_ty| {
        if (zcu.typeToFunc(fn_ty).?.is_generic) {
            return .{ .mcv = .{ .immediate = fn_ty.abiAlignment(zcu).toByteUnits().? } };
        }
    } else if (ty.zigTypeTag(zcu) == .pointer) {
        const elem_ty = ty.elemType2(zcu);
        if (!elem_ty.hasRuntimeBits(zcu)) {
            return .{ .mcv = .{ .immediate = elem_ty.abiAlignment(zcu).toByteUnits().? } };
        }
    }

    const nav_index, const is_extern, const lib_name, const is_threadlocal = switch (ip.indexToKey(zcu.navValue(ref_nav_index).toIntern())) {
        .func => |func| .{ func.owner_nav, false, .none, false },
        .variable => |variable| .{ variable.owner_nav, false, variable.lib_name, variable.is_threadlocal },
        .@"extern" => |@"extern"| .{ @"extern".owner_nav, true, @"extern".lib_name, @"extern".is_threadlocal },
        else => .{ ref_nav_index, false, .none, false },
    };
    const single_threaded = zcu.navFileScope(nav_index).mod.single_threaded;
    const name = ip.getNav(nav_index).name;
    if (lf.cast(.elf)) |elf_file| {
        const zo = elf_file.zigObjectPtr().?;
        if (is_extern) {
            const sym_index = try elf_file.getGlobalSymbol(name.toSlice(ip), lib_name.toSlice(ip));
            zo.symbol(sym_index).flags.is_extern_ptr = true;
            return .{ .mcv = .{ .lea_symbol = sym_index } };
        }
        const sym_index = try zo.getOrCreateMetadataForNav(elf_file, nav_index);
        if (!single_threaded and is_threadlocal) {
            return .{ .mcv = .{ .load_tlv = sym_index } };
        }
        return .{ .mcv = .{ .lea_symbol = sym_index } };
    } else if (lf.cast(.macho)) |macho_file| {
        const zo = macho_file.getZigObject().?;
        if (is_extern) {
            const sym_index = try macho_file.getGlobalSymbol(name.toSlice(ip), lib_name.toSlice(ip));
            zo.symbols.items[sym_index].flags.is_extern_ptr = true;
            return .{ .mcv = .{ .lea_symbol = sym_index } };
        }
        const sym_index = try zo.getOrCreateMetadataForNav(macho_file, nav_index);
        const sym = zo.symbols.items[sym_index];
        if (!single_threaded and is_threadlocal) {
            return .{ .mcv = .{ .load_tlv = sym.nlist_idx } };
        }
        return .{ .mcv = .{ .lea_symbol = sym.nlist_idx } };
    } else if (lf.cast(.coff)) |coff_file| {
        if (is_extern) {
            // TODO audit this
            const global_index = try coff_file.getGlobalSymbol(name.toSlice(ip), lib_name.toSlice(ip));
            try coff_file.need_got_table.put(gpa, global_index, {}); // needs GOT
            return .{ .mcv = .{ .load_got = link.File.Coff.global_symbol_bit | global_index } };
        }
        const atom_index = try coff_file.getOrCreateAtomForNav(nav_index);
        const sym_index = coff_file.getAtom(atom_index).getSymbolIndex().?;
        return .{ .mcv = .{ .load_got = sym_index } };
    } else if (lf.cast(.plan9)) |p9| {
        const atom_index = try p9.seeNav(pt, nav_index);
        const atom = p9.getAtom(atom_index);
        return .{ .mcv = .{ .memory = atom.getOffsetTableAddress(p9) } };
    } else {
        const msg = try ErrorMsg.create(gpa, src_loc, "TODO genNavRef for target {}", .{target});
        return .{ .fail = msg };
    }
}

pub fn genTypedValue(
    lf: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    val: Value,
    target: std.Target,
) CodeGenError!GenResult {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const ty = val.typeOf(zcu);

    log.debug("genTypedValue: val = {}", .{val.fmtValue(pt)});

    if (val.isUndef(zcu)) return .{ .mcv = .undef };

    switch (ty.zigTypeTag(zcu)) {
        .void => return .{ .mcv = .none },
        .pointer => switch (ty.ptrSize(zcu)) {
            .Slice => {},
            else => switch (val.toIntern()) {
                .null_value => {
                    return .{ .mcv = .{ .immediate = 0 } };
                },
                else => switch (ip.indexToKey(val.toIntern())) {
                    .int => {
                        return .{ .mcv = .{ .immediate = val.toUnsignedInt(zcu) } };
                    },
                    .ptr => |ptr| if (ptr.byte_offset == 0) switch (ptr.base_addr) {
                        .nav => |nav| return genNavRef(lf, pt, src_loc, val, nav, target),
                        .uav => |uav| if (Value.fromInterned(uav.val).typeOf(zcu).hasRuntimeBits(zcu))
                            return switch (try lf.lowerUav(
                                pt,
                                uav.val,
                                Type.fromInterned(uav.orig_ty).ptrAlignment(zcu),
                                src_loc,
                            )) {
                                .mcv => |mcv| return .{ .mcv = switch (mcv) {
                                    .load_direct => |sym_index| .{ .lea_direct = sym_index },
                                    .load_symbol => |sym_index| .{ .lea_symbol = sym_index },
                                    else => unreachable,
                                } },
                                .fail => |em| return .{ .fail = em },
                            }
                        else
                            return .{ .mcv = .{ .immediate = Type.fromInterned(uav.orig_ty).ptrAlignment(zcu)
                                .forward(@intCast((@as(u66, 1) << @intCast(target.ptrBitWidth() | 1)) / 3)) } },
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
                return .{ .mcv = .{ .immediate = unsigned } };
            }
        },
        .bool => {
            return .{ .mcv = .{ .immediate = @intFromBool(val.toBool()) } };
        },
        .optional => {
            if (ty.isPtrLikeOptional(zcu)) {
                return genTypedValue(
                    lf,
                    pt,
                    src_loc,
                    val.optionalValue(zcu) orelse return .{ .mcv = .{ .immediate = 0 } },
                    target,
                );
            } else if (ty.abiSize(zcu) == 1) {
                return .{ .mcv = .{ .immediate = @intFromBool(!val.isNull(zcu)) } };
            }
        },
        .@"enum" => {
            const enum_tag = ip.indexToKey(val.toIntern()).enum_tag;
            return genTypedValue(
                lf,
                pt,
                src_loc,
                Value.fromInterned(enum_tag.int),
                target,
            );
        },
        .error_set => {
            const err_name = ip.indexToKey(val.toIntern()).err.name;
            const error_index = try pt.getErrorValue(err_name);
            return .{ .mcv = .{ .immediate = error_index } };
        },
        .error_union => {
            const err_type = ty.errorUnionSet(zcu);
            const payload_type = ty.errorUnionPayload(zcu);
            if (!payload_type.hasRuntimeBitsIgnoreComptime(zcu)) {
                // We use the error type directly as the type.
                const err_int_ty = try pt.errorIntType();
                switch (ip.indexToKey(val.toIntern()).error_union.val) {
                    .err_name => |err_name| return genTypedValue(
                        lf,
                        pt,
                        src_loc,
                        Value.fromInterned(try pt.intern(.{ .err = .{
                            .ty = err_type.toIntern(),
                            .name = err_name,
                        } })),
                        target,
                    ),
                    .payload => return genTypedValue(
                        lf,
                        pt,
                        src_loc,
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

    return lf.lowerUav(pt, val.toIntern(), .none, src_loc);
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
