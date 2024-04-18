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
const ErrorMsg = Module.ErrorMsg;
const InternPool = @import("InternPool.zig");
const Liveness = @import("Liveness.zig");
const Zcu = @import("Module.zig");
const Module = Zcu;
const Target = std.Target;
const Type = @import("type.zig").Type;
const Value = @import("Value.zig");
const Zir = std.zig.Zir;
const Alignment = InternPool.Alignment;

pub const Result = union(enum) {
    /// The `code` parameter passed to `generateSymbol` has the value ok.
    ok: void,

    /// There was a codegen error.
    fail: *ErrorMsg,
};

pub const CodeGenError = error{
    OutOfMemory,
    Overflow,
    CodegenFail,
};

pub const DebugInfoOutput = union(enum) {
    dwarf: *link.File.Dwarf.DeclState,
    plan9: *link.File.Plan9.DebugInfoOutput,
    none,
};

pub fn generateFunction(
    lf: *link.File,
    src_loc: Module.SrcLoc,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
) CodeGenError!Result {
    const zcu = lf.comp.module.?;
    const func = zcu.funcInfo(func_index);
    const decl = zcu.declPtr(func.owner_decl);
    const namespace = zcu.namespacePtr(decl.src_namespace);
    const target = namespace.file_scope.mod.resolved_target.result;
    switch (target.cpu.arch) {
        .arm,
        .armeb,
        => return @import("arch/arm/CodeGen.zig").generate(lf, src_loc, func_index, air, liveness, code, debug_output),
        .aarch64,
        .aarch64_be,
        .aarch64_32,
        => return @import("arch/aarch64/CodeGen.zig").generate(lf, src_loc, func_index, air, liveness, code, debug_output),
        .riscv64 => return @import("arch/riscv64/CodeGen.zig").generate(lf, src_loc, func_index, air, liveness, code, debug_output),
        .sparc64 => return @import("arch/sparc64/CodeGen.zig").generate(lf, src_loc, func_index, air, liveness, code, debug_output),
        .x86_64 => return @import("arch/x86_64/CodeGen.zig").generate(lf, src_loc, func_index, air, liveness, code, debug_output),
        .wasm32,
        .wasm64,
        => return @import("arch/wasm/CodeGen.zig").generate(lf, src_loc, func_index, air, liveness, code, debug_output),
        else => unreachable,
    }
}

pub fn generateLazyFunction(
    lf: *link.File,
    src_loc: Module.SrcLoc,
    lazy_sym: link.File.LazySymbol,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
) CodeGenError!Result {
    const zcu = lf.comp.module.?;
    const decl_index = lazy_sym.ty.getOwnerDecl(zcu);
    const decl = zcu.declPtr(decl_index);
    const namespace = zcu.namespacePtr(decl.src_namespace);
    const target = namespace.file_scope.mod.resolved_target.result;
    switch (target.cpu.arch) {
        .x86_64 => return @import("arch/x86_64/CodeGen.zig").generateLazy(lf, src_loc, lazy_sym, code, debug_output),
        else => unreachable,
    }
}

fn writeFloat(comptime F: type, f: F, target: Target, endian: std.builtin.Endian, code: []u8) void {
    _ = target;
    const bits = @typeInfo(F).Float.bits;
    const Int = @Type(.{ .Int = .{ .signedness = .unsigned, .bits = bits } });
    const int: Int = @bitCast(f);
    mem.writeInt(Int, code[0..@divExact(bits, 8)], int, endian);
}

pub fn generateLazySymbol(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    lazy_sym: link.File.LazySymbol,
    // TODO don't use an "out" parameter like this; put it in the result instead
    alignment: *Alignment,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
    reloc_info: RelocInfo,
) CodeGenError!Result {
    _ = reloc_info;

    const tracy = trace(@src());
    defer tracy.end();

    const comp = bin_file.comp;
    const zcu = comp.module.?;
    const ip = &zcu.intern_pool;
    const target = comp.root_mod.resolved_target.result;
    const endian = target.cpu.arch.endian();
    const gpa = comp.gpa;

    log.debug("generateLazySymbol: kind = {s}, ty = {}", .{
        @tagName(lazy_sym.kind),
        lazy_sym.ty.fmt(zcu),
    });

    if (lazy_sym.kind == .code) {
        alignment.* = target_util.defaultFunctionAlignment(target);
        return generateLazyFunction(bin_file, src_loc, lazy_sym, code, debug_output);
    }

    if (lazy_sym.ty.isAnyError(zcu)) {
        alignment.* = .@"4";
        const err_names = zcu.global_error_set.keys();
        mem.writeInt(u32, try code.addManyAsArray(4), @intCast(err_names.len), endian);
        var offset = code.items.len;
        try code.resize((1 + err_names.len + 1) * 4);
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
    } else if (lazy_sym.ty.zigTypeTag(zcu) == .Enum) {
        alignment.* = .@"1";
        const tag_names = lazy_sym.ty.enumFields(zcu);
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
        .{ @tagName(lazy_sym.kind), lazy_sym.ty.fmt(zcu) },
    ) };
}

pub fn generateSymbol(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    val: Value,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
    reloc_info: RelocInfo,
) CodeGenError!Result {
    const tracy = trace(@src());
    defer tracy.end();

    const mod = bin_file.comp.module.?;
    const ip = &mod.intern_pool;
    const ty = val.typeOf(mod);

    const target = mod.getTarget();
    const endian = target.cpu.arch.endian();

    log.debug("generateSymbol: val = {}", .{val.fmtValue(mod, null)});

    if (val.isUndefDeep(mod)) {
        const abi_size = math.cast(usize, ty.abiSize(mod)) orelse return error.Overflow;
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
        .extern_func,
        .func,
        .enum_literal,
        .empty_enum_value,
        => unreachable, // non-runtime values
        .int => {
            const abi_size = math.cast(usize, ty.abiSize(mod)) orelse return error.Overflow;
            var space: Value.BigIntSpace = undefined;
            const int_val = val.toBigInt(&space, mod);
            int_val.writeTwosComplement(try code.addManyAsSlice(abi_size), endian);
        },
        .err => |err| {
            const int = try mod.getErrorValue(err.name);
            try code.writer().writeInt(u16, @intCast(int), endian);
        },
        .error_union => |error_union| {
            const payload_ty = ty.errorUnionPayload(mod);
            const err_val: u16 = switch (error_union.val) {
                .err_name => |err_name| @intCast(try mod.getErrorValue(err_name)),
                .payload => 0,
            };

            if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                try code.writer().writeInt(u16, err_val, endian);
                return .ok;
            }

            const payload_align = payload_ty.abiAlignment(mod);
            const error_align = Type.anyerror.abiAlignment(mod);
            const abi_align = ty.abiAlignment(mod);

            // error value first when its type is larger than the error union's payload
            if (error_align.order(payload_align) == .gt) {
                try code.writer().writeInt(u16, err_val, endian);
            }

            // emit payload part of the error union
            {
                const begin = code.items.len;
                switch (try generateSymbol(bin_file, src_loc, Value.fromInterned(switch (error_union.val) {
                    .err_name => try mod.intern(.{ .undef = payload_ty.toIntern() }),
                    .payload => |payload| payload,
                }), code, debug_output, reloc_info)) {
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
            const int_tag_ty = ty.intTagType(mod);
            switch (try generateSymbol(bin_file, src_loc, try mod.getCoerced(Value.fromInterned(enum_tag.int), int_tag_ty), code, debug_output, reloc_info)) {
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
                const abi_size = math.cast(usize, ty.abiSize(mod)) orelse return error.Overflow;
                try code.appendNTimes(0, abi_size - 10);
            },
            .f128 => |f128_val| writeFloat(f128, f128_val, target, endian, try code.addManyAsArray(16)),
        },
        .ptr => switch (try lowerPtr(bin_file, src_loc, val.toIntern(), code, debug_output, reloc_info, 0)) {
            .ok => {},
            .fail => |em| return .{ .fail = em },
        },
        .slice => |slice| {
            switch (try generateSymbol(bin_file, src_loc, Value.fromInterned(slice.ptr), code, debug_output, reloc_info)) {
                .ok => {},
                .fail => |em| return .{ .fail = em },
            }
            switch (try generateSymbol(bin_file, src_loc, Value.fromInterned(slice.len), code, debug_output, reloc_info)) {
                .ok => {},
                .fail => |em| return .{ .fail = em },
            }
        },
        .opt => {
            const payload_type = ty.optionalChild(mod);
            const payload_val = val.optionalValue(mod);
            const abi_size = math.cast(usize, ty.abiSize(mod)) orelse return error.Overflow;

            if (ty.optionalReprIsPayload(mod)) {
                if (payload_val) |value| {
                    switch (try generateSymbol(bin_file, src_loc, value, code, debug_output, reloc_info)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }
                } else {
                    try code.appendNTimes(0, abi_size);
                }
            } else {
                const padding = abi_size - (math.cast(usize, payload_type.abiSize(mod)) orelse return error.Overflow) - 1;
                if (payload_type.hasRuntimeBits(mod)) {
                    const value = payload_val orelse Value.fromInterned((try mod.intern(.{ .undef = payload_type.toIntern() })));
                    switch (try generateSymbol(bin_file, src_loc, value, code, debug_output, reloc_info)) {
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
                        switch (try generateSymbol(bin_file, src_loc, Value.fromInterned(switch (aggregate.storage) {
                            .bytes => unreachable,
                            .elems => |elems| elems[@intCast(index)],
                            .repeated_elem => |elem| if (index < array_type.len)
                                elem
                            else
                                array_type.sentinel,
                        }), code, debug_output, reloc_info)) {
                            .ok => {},
                            .fail => |em| return .{ .fail = em },
                        }
                    }
                },
            },
            .vector_type => |vector_type| {
                const abi_size = math.cast(usize, ty.abiSize(mod)) orelse
                    return error.Overflow;
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
                                switch (try generateSymbol(bin_file, src_loc, Value.fromInterned(switch (aggregate.storage) {
                                    .bytes => unreachable,
                                    .elems => |elems| elems[
                                        math.cast(usize, index) orelse return error.Overflow
                                    ],
                                    .repeated_elem => |elem| elem,
                                }), code, debug_output, reloc_info)) {
                                    .ok => {},
                                    .fail => |em| return .{ .fail = em },
                                }
                            }
                        },
                    }

                    const padding = abi_size -
                        (math.cast(usize, Type.fromInterned(vector_type.child).abiSize(mod) * vector_type.len) orelse
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
                    if (!Type.fromInterned(field_ty).hasRuntimeBits(mod)) continue;

                    const field_val = switch (aggregate.storage) {
                        .bytes => |bytes| try ip.get(mod.gpa, .{ .int = .{
                            .ty = field_ty,
                            .storage = .{ .u64 = bytes.at(index, ip) },
                        } }),
                        .elems => |elems| elems[index],
                        .repeated_elem => |elem| elem,
                    };

                    switch (try generateSymbol(bin_file, src_loc, Value.fromInterned(field_val), code, debug_output, reloc_info)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }
                    const unpadded_field_end = code.items.len - struct_begin;

                    // Pad struct members if required
                    const padded_field_end = ty.structFieldOffset(index + 1, mod);
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
                        const abi_size = math.cast(usize, ty.abiSize(mod)) orelse
                            return error.Overflow;
                        const current_pos = code.items.len;
                        try code.appendNTimes(0, abi_size);
                        var bits: u16 = 0;

                        for (struct_type.field_types.get(ip), 0..) |field_ty, index| {
                            const field_val = switch (aggregate.storage) {
                                .bytes => |bytes| try ip.get(mod.gpa, .{ .int = .{
                                    .ty = field_ty,
                                    .storage = .{ .u64 = bytes.at(index, ip) },
                                } }),
                                .elems => |elems| elems[index],
                                .repeated_elem => |elem| elem,
                            };

                            // pointer may point to a decl which must be marked used
                            // but can also result in a relocation. Therefore we handle those separately.
                            if (Type.fromInterned(field_ty).zigTypeTag(mod) == .Pointer) {
                                const field_size = math.cast(usize, Type.fromInterned(field_ty).abiSize(mod)) orelse
                                    return error.Overflow;
                                var tmp_list = try std.ArrayList(u8).initCapacity(code.allocator, field_size);
                                defer tmp_list.deinit();
                                switch (try generateSymbol(bin_file, src_loc, Value.fromInterned(field_val), &tmp_list, debug_output, reloc_info)) {
                                    .ok => @memcpy(code.items[current_pos..][0..tmp_list.items.len], tmp_list.items),
                                    .fail => |em| return Result{ .fail = em },
                                }
                            } else {
                                Value.fromInterned(field_val).writeToPackedMemory(Type.fromInterned(field_ty), mod, code.items[current_pos..], bits) catch unreachable;
                            }
                            bits += @intCast(Type.fromInterned(field_ty).bitSize(mod));
                        }
                    },
                    .auto, .@"extern" => {
                        const struct_begin = code.items.len;
                        const field_types = struct_type.field_types.get(ip);
                        const offsets = struct_type.offsets.get(ip);

                        var it = struct_type.iterateRuntimeOrder(ip);
                        while (it.next()) |field_index| {
                            const field_ty = field_types[field_index];
                            if (!Type.fromInterned(field_ty).hasRuntimeBits(mod)) continue;

                            const field_val = switch (ip.indexToKey(val.toIntern()).aggregate.storage) {
                                .bytes => |bytes| try ip.get(mod.gpa, .{ .int = .{
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

                            switch (try generateSymbol(bin_file, src_loc, Value.fromInterned(field_val), code, debug_output, reloc_info)) {
                                .ok => {},
                                .fail => |em| return Result{ .fail = em },
                            }
                        }

                        const size = struct_type.size(ip).*;
                        const alignment = struct_type.flagsPtr(ip).alignment.toByteUnits().?;

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
            const layout = ty.unionGetLayout(mod);

            if (layout.payload_size == 0) {
                return generateSymbol(bin_file, src_loc, Value.fromInterned(un.tag), code, debug_output, reloc_info);
            }

            // Check if we should store the tag first.
            if (layout.tag_size > 0 and layout.tag_align.compare(.gte, layout.payload_align)) {
                switch (try generateSymbol(bin_file, src_loc, Value.fromInterned(un.tag), code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }
            }

            const union_obj = mod.typeToUnion(ty).?;
            if (un.tag != .none) {
                const field_index = ty.unionTagFieldIndex(Value.fromInterned(un.tag), mod).?;
                const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[field_index]);
                if (!field_ty.hasRuntimeBits(mod)) {
                    try code.appendNTimes(0xaa, math.cast(usize, layout.payload_size) orelse return error.Overflow);
                } else {
                    switch (try generateSymbol(bin_file, src_loc, Value.fromInterned(un.val), code, debug_output, reloc_info)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }

                    const padding = math.cast(usize, layout.payload_size - field_ty.abiSize(mod)) orelse return error.Overflow;
                    if (padding > 0) {
                        try code.appendNTimes(0, padding);
                    }
                }
            } else {
                switch (try generateSymbol(bin_file, src_loc, Value.fromInterned(un.val), code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }
            }

            if (layout.tag_size > 0 and layout.tag_align.compare(.lt, layout.payload_align)) {
                switch (try generateSymbol(bin_file, src_loc, Value.fromInterned(un.tag), code, debug_output, reloc_info)) {
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
    src_loc: Module.SrcLoc,
    ptr_val: InternPool.Index,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
    reloc_info: RelocInfo,
    prev_offset: u64,
) CodeGenError!Result {
    const zcu = bin_file.comp.module.?;
    const ptr = zcu.intern_pool.indexToKey(ptr_val).ptr;
    const offset: u64 = prev_offset + ptr.byte_offset;
    return switch (ptr.base_addr) {
        .decl => |decl| try lowerDeclRef(bin_file, src_loc, decl, code, debug_output, reloc_info, offset),
        .anon_decl => |ad| try lowerAnonDeclRef(bin_file, src_loc, ad, code, debug_output, reloc_info, offset),
        .int => try generateSymbol(bin_file, src_loc, try zcu.intValue(Type.usize, offset), code, debug_output, reloc_info),
        .eu_payload => |eu_ptr| try lowerPtr(
            bin_file,
            src_loc,
            eu_ptr,
            code,
            debug_output,
            reloc_info,
            offset + errUnionPayloadOffset(
                Value.fromInterned(eu_ptr).typeOf(zcu).childType(zcu).errorUnionPayload(zcu),
                zcu,
            ),
        ),
        .opt_payload => |opt_ptr| try lowerPtr(
            bin_file,
            src_loc,
            opt_ptr,
            code,
            debug_output,
            reloc_info,
            offset,
        ),
        .field => |field| {
            const base_ptr = Value.fromInterned(field.base);
            const base_ty = base_ptr.typeOf(zcu).childType(zcu);
            const field_off: u64 = switch (base_ty.zigTypeTag(zcu)) {
                .Pointer => off: {
                    assert(base_ty.isSlice(zcu));
                    break :off switch (field.index) {
                        Value.slice_ptr_index => 0,
                        Value.slice_len_index => @divExact(zcu.getTarget().ptrBitWidth(), 8),
                        else => unreachable,
                    };
                },
                .Struct, .Union => switch (base_ty.containerLayout(zcu)) {
                    .auto => base_ty.structFieldOffset(@intCast(field.index), zcu),
                    .@"extern", .@"packed" => unreachable,
                },
                else => unreachable,
            };
            return lowerPtr(bin_file, src_loc, field.base, code, debug_output, reloc_info, offset + field_off);
        },
        .arr_elem, .comptime_field, .comptime_alloc => unreachable,
    };
}

const RelocInfo = struct {
    parent_atom_index: u32,
};

fn lowerAnonDeclRef(
    lf: *link.File,
    src_loc: Module.SrcLoc,
    anon_decl: InternPool.Key.Ptr.BaseAddr.AnonDecl,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
    reloc_info: RelocInfo,
    offset: u64,
) CodeGenError!Result {
    _ = debug_output;
    const zcu = lf.comp.module.?;
    const ip = &zcu.intern_pool;
    const target = lf.comp.root_mod.resolved_target.result;

    const ptr_width_bytes = @divExact(target.ptrBitWidth(), 8);
    const decl_val = anon_decl.val;
    const decl_ty = Type.fromInterned(ip.typeOf(decl_val));
    log.debug("lowerAnonDecl: ty = {}", .{decl_ty.fmt(zcu)});
    const is_fn_body = decl_ty.zigTypeTag(zcu) == .Fn;
    if (!is_fn_body and !decl_ty.hasRuntimeBits(zcu)) {
        try code.appendNTimes(0xaa, ptr_width_bytes);
        return Result.ok;
    }

    const decl_align = ip.indexToKey(anon_decl.orig_ty).ptr_type.flags.alignment;
    const res = try lf.lowerAnonDecl(decl_val, decl_align, src_loc);
    switch (res) {
        .ok => {},
        .fail => |em| return .{ .fail = em },
    }

    const vaddr = try lf.getAnonDeclVAddr(decl_val, .{
        .parent_atom_index = reloc_info.parent_atom_index,
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

fn lowerDeclRef(
    lf: *link.File,
    src_loc: Module.SrcLoc,
    decl_index: InternPool.DeclIndex,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
    reloc_info: RelocInfo,
    offset: u64,
) CodeGenError!Result {
    _ = src_loc;
    _ = debug_output;
    const zcu = lf.comp.module.?;
    const decl = zcu.declPtr(decl_index);
    const namespace = zcu.namespacePtr(decl.src_namespace);
    const target = namespace.file_scope.mod.resolved_target.result;

    const ptr_width = target.ptrBitWidth();
    const is_fn_body = decl.typeOf(zcu).zigTypeTag(zcu) == .Fn;
    if (!is_fn_body and !decl.typeOf(zcu).hasRuntimeBits(zcu)) {
        try code.appendNTimes(0xaa, @divExact(ptr_width, 8));
        return Result.ok;
    }

    const vaddr = try lf.getDeclVAddr(decl_index, .{
        .parent_atom_index = reloc_info.parent_atom_index,
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
        /// Decl referenced via GOT with address deferred until the linker allocates
        /// everything in virtual memory.
        /// Payload is a symbol index.
        load_got: u32,
        /// Direct by-address reference to memory location.
        memory: u64,
        /// Reference to memory location but deferred until linker allocated the Decl in memory.
        /// Traditionally, this corresponds to emitting a relocation in a relocatable object file.
        load_symbol: u32,
    };

    fn mcv(val: MCValue) GenResult {
        return .{ .mcv = val };
    }

    fn fail(
        gpa: Allocator,
        src_loc: Module.SrcLoc,
        comptime format: []const u8,
        args: anytype,
    ) Allocator.Error!GenResult {
        const msg = try ErrorMsg.create(gpa, src_loc, format, args);
        return .{ .fail = msg };
    }
};

fn genDeclRef(
    lf: *link.File,
    src_loc: Module.SrcLoc,
    val: Value,
    ptr_decl_index: InternPool.DeclIndex,
) CodeGenError!GenResult {
    const zcu = lf.comp.module.?;
    const ip = &zcu.intern_pool;
    const ty = val.typeOf(zcu);
    log.debug("genDeclRef: val = {}", .{val.fmtValue(zcu, null)});

    const ptr_decl = zcu.declPtr(ptr_decl_index);
    const namespace = zcu.namespacePtr(ptr_decl.src_namespace);
    const target = namespace.file_scope.mod.resolved_target.result;

    const ptr_bits = target.ptrBitWidth();
    const ptr_bytes: u64 = @divExact(ptr_bits, 8);

    const decl_index = switch (ip.indexToKey(ptr_decl.val.toIntern())) {
        .func => |func| func.owner_decl,
        .extern_func => |extern_func| extern_func.decl,
        else => ptr_decl_index,
    };
    const decl = zcu.declPtr(decl_index);

    if (!decl.typeOf(zcu).isFnOrHasRuntimeBitsIgnoreComptime(zcu)) {
        const imm: u64 = switch (ptr_bytes) {
            1 => 0xaa,
            2 => 0xaaaa,
            4 => 0xaaaaaaaa,
            8 => 0xaaaaaaaaaaaaaaaa,
            else => unreachable,
        };
        return GenResult.mcv(.{ .immediate = imm });
    }

    const comp = lf.comp;
    const gpa = comp.gpa;

    // TODO this feels clunky. Perhaps we should check for it in `genTypedValue`?
    if (ty.castPtrToFn(zcu)) |fn_ty| {
        if (zcu.typeToFunc(fn_ty).?.is_generic) {
            return GenResult.mcv(.{ .immediate = fn_ty.abiAlignment(zcu).toByteUnits().? });
        }
    } else if (ty.zigTypeTag(zcu) == .Pointer) {
        const elem_ty = ty.elemType2(zcu);
        if (!elem_ty.hasRuntimeBits(zcu)) {
            return GenResult.mcv(.{ .immediate = elem_ty.abiAlignment(zcu).toByteUnits().? });
        }
    }

    const decl_namespace = zcu.namespacePtr(decl.src_namespace);
    const single_threaded = decl_namespace.file_scope.mod.single_threaded;
    const is_threadlocal = val.isPtrToThreadLocal(zcu) and !single_threaded;
    const is_extern = decl.isExtern(zcu);

    if (lf.cast(link.File.Elf)) |elf_file| {
        if (is_extern) {
            const name = decl.name.toSlice(ip);
            // TODO audit this
            const lib_name = if (decl.getOwnedVariable(zcu)) |ov| ov.lib_name.toSlice(ip) else null;
            const sym_index = try elf_file.getGlobalSymbol(name, lib_name);
            elf_file.symbol(elf_file.zigObjectPtr().?.symbol(sym_index)).flags.needs_got = true;
            return GenResult.mcv(.{ .load_symbol = sym_index });
        }
        const sym_index = try elf_file.zigObjectPtr().?.getOrCreateMetadataForDecl(elf_file, decl_index);
        const sym = elf_file.symbol(sym_index);
        if (is_threadlocal) {
            return GenResult.mcv(.{ .load_tlv = sym.esym_index });
        }
        return GenResult.mcv(.{ .load_symbol = sym.esym_index });
    } else if (lf.cast(link.File.MachO)) |macho_file| {
        if (is_extern) {
            const name = decl.name.toSlice(ip);
            const lib_name = if (decl.getOwnedVariable(zcu)) |ov| ov.lib_name.toSlice(ip) else null;
            const sym_index = try macho_file.getGlobalSymbol(name, lib_name);
            macho_file.getSymbol(macho_file.getZigObject().?.symbols.items[sym_index]).flags.needs_got = true;
            return GenResult.mcv(.{ .load_symbol = sym_index });
        }
        const sym_index = try macho_file.getZigObject().?.getOrCreateMetadataForDecl(macho_file, decl_index);
        const sym = macho_file.getSymbol(sym_index);
        if (is_threadlocal) {
            return GenResult.mcv(.{ .load_tlv = sym.nlist_idx });
        }
        return GenResult.mcv(.{ .load_symbol = sym.nlist_idx });
    } else if (lf.cast(link.File.Coff)) |coff_file| {
        if (is_extern) {
            const name = decl.name.toSlice(ip);
            // TODO audit this
            const lib_name = if (decl.getOwnedVariable(zcu)) |ov| ov.lib_name.toSlice(ip) else null;
            const global_index = try coff_file.getGlobalSymbol(name, lib_name);
            try coff_file.need_got_table.put(gpa, global_index, {}); // needs GOT
            return GenResult.mcv(.{ .load_got = link.File.Coff.global_symbol_bit | global_index });
        }
        const atom_index = try coff_file.getOrCreateAtomForDecl(decl_index);
        const sym_index = coff_file.getAtom(atom_index).getSymbolIndex().?;
        return GenResult.mcv(.{ .load_got = sym_index });
    } else if (lf.cast(link.File.Plan9)) |p9| {
        const atom_index = try p9.seeDecl(decl_index);
        const atom = p9.getAtom(atom_index);
        return GenResult.mcv(.{ .memory = atom.getOffsetTableAddress(p9) });
    } else {
        return GenResult.fail(gpa, src_loc, "TODO genDeclRef for target {}", .{target});
    }
}

fn genUnnamedConst(
    lf: *link.File,
    src_loc: Module.SrcLoc,
    val: Value,
    owner_decl_index: InternPool.DeclIndex,
) CodeGenError!GenResult {
    const zcu = lf.comp.module.?;
    const gpa = lf.comp.gpa;
    log.debug("genUnnamedConst: val = {}", .{val.fmtValue(zcu, null)});

    const local_sym_index = lf.lowerUnnamedConst(val, owner_decl_index) catch |err| {
        return GenResult.fail(gpa, src_loc, "lowering unnamed constant failed: {s}", .{@errorName(err)});
    };
    switch (lf.tag) {
        .elf => {
            const elf_file = lf.cast(link.File.Elf).?;
            const local = elf_file.symbol(local_sym_index);
            return GenResult.mcv(.{ .load_symbol = local.esym_index });
        },
        .macho => {
            const macho_file = lf.cast(link.File.MachO).?;
            const local = macho_file.getSymbol(local_sym_index);
            return GenResult.mcv(.{ .load_symbol = local.nlist_idx });
        },
        .coff => {
            return GenResult.mcv(.{ .load_direct = local_sym_index });
        },
        .plan9 => {
            const atom_index = local_sym_index; // plan9 returns the atom_index
            return GenResult.mcv(.{ .load_direct = atom_index });
        },

        .c => return GenResult.fail(gpa, src_loc, "TODO genUnnamedConst for -ofmt=c", .{}),
        .wasm => return GenResult.fail(gpa, src_loc, "TODO genUnnamedConst for wasm", .{}),
        .spirv => return GenResult.fail(gpa, src_loc, "TODO genUnnamedConst for spirv", .{}),
        .nvptx => return GenResult.fail(gpa, src_loc, "TODO genUnnamedConst for nvptx", .{}),
    }
}

pub fn genTypedValue(
    lf: *link.File,
    src_loc: Module.SrcLoc,
    val: Value,
    owner_decl_index: InternPool.DeclIndex,
) CodeGenError!GenResult {
    const zcu = lf.comp.module.?;
    const ip = &zcu.intern_pool;
    const ty = val.typeOf(zcu);

    log.debug("genTypedValue: val = {}", .{val.fmtValue(zcu, null)});

    if (val.isUndef(zcu))
        return GenResult.mcv(.undef);

    const owner_decl = zcu.declPtr(owner_decl_index);
    const namespace = zcu.namespacePtr(owner_decl.src_namespace);
    const target = namespace.file_scope.mod.resolved_target.result;
    const ptr_bits = target.ptrBitWidth();

    if (!ty.isSlice(zcu)) switch (ip.indexToKey(val.toIntern())) {
        .ptr => |ptr| if (ptr.byte_offset == 0) switch (ptr.base_addr) {
            .decl => |decl| return genDeclRef(lf, src_loc, val, decl),
            else => {},
        },
        else => {},
    };

    switch (ty.zigTypeTag(zcu)) {
        .Void => return GenResult.mcv(.none),
        .Pointer => switch (ty.ptrSize(zcu)) {
            .Slice => {},
            else => switch (val.toIntern()) {
                .null_value => {
                    return GenResult.mcv(.{ .immediate = 0 });
                },
                .none => {},
                else => switch (ip.indexToKey(val.toIntern())) {
                    .int => {
                        return GenResult.mcv(.{ .immediate = val.toUnsignedInt(zcu) });
                    },
                    else => {},
                },
            },
        },
        .Int => {
            const info = ty.intInfo(zcu);
            if (info.bits <= ptr_bits) {
                const unsigned: u64 = switch (info.signedness) {
                    .signed => @bitCast(val.toSignedInt(zcu)),
                    .unsigned => val.toUnsignedInt(zcu),
                };
                return GenResult.mcv(.{ .immediate = unsigned });
            }
        },
        .Bool => {
            return GenResult.mcv(.{ .immediate = @intFromBool(val.toBool()) });
        },
        .Optional => {
            if (ty.isPtrLikeOptional(zcu)) {
                return genTypedValue(
                    lf,
                    src_loc,
                    val.optionalValue(zcu) orelse return GenResult.mcv(.{ .immediate = 0 }),
                    owner_decl_index,
                );
            } else if (ty.abiSize(zcu) == 1) {
                return GenResult.mcv(.{ .immediate = @intFromBool(!val.isNull(zcu)) });
            }
        },
        .Enum => {
            const enum_tag = ip.indexToKey(val.toIntern()).enum_tag;
            return genTypedValue(
                lf,
                src_loc,
                Value.fromInterned(enum_tag.int),
                owner_decl_index,
            );
        },
        .ErrorSet => {
            const err_name = ip.indexToKey(val.toIntern()).err.name;
            const error_index = zcu.global_error_set.getIndex(err_name).?;
            return GenResult.mcv(.{ .immediate = error_index });
        },
        .ErrorUnion => {
            const err_type = ty.errorUnionSet(zcu);
            const payload_type = ty.errorUnionPayload(zcu);
            if (!payload_type.hasRuntimeBitsIgnoreComptime(zcu)) {
                // We use the error type directly as the type.
                const err_int_ty = try zcu.errorIntType();
                switch (ip.indexToKey(val.toIntern()).error_union.val) {
                    .err_name => |err_name| return genTypedValue(
                        lf,
                        src_loc,
                        Value.fromInterned(try zcu.intern(.{ .err = .{
                            .ty = err_type.toIntern(),
                            .name = err_name,
                        } })),
                        owner_decl_index,
                    ),
                    .payload => return genTypedValue(
                        lf,
                        src_loc,
                        try zcu.intValue(err_int_ty, 0),
                        owner_decl_index,
                    ),
                }
            }
        },

        .ComptimeInt => unreachable,
        .ComptimeFloat => unreachable,
        .Type => unreachable,
        .EnumLiteral => unreachable,
        .NoReturn => unreachable,
        .Undefined => unreachable,
        .Null => unreachable,
        .Opaque => unreachable,

        else => {},
    }

    return genUnnamedConst(lf, src_loc, val, owner_decl_index);
}

pub fn errUnionPayloadOffset(payload_ty: Type, mod: *Module) u64 {
    if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) return 0;
    const payload_align = payload_ty.abiAlignment(mod);
    const error_align = Type.anyerror.abiAlignment(mod);
    if (payload_align.compare(.gte, error_align) or !payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        return 0;
    } else {
        return payload_align.forward(Type.anyerror.abiSize(mod));
    }
}

pub fn errUnionErrorOffset(payload_ty: Type, mod: *Module) u64 {
    if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) return 0;
    const payload_align = payload_ty.abiAlignment(mod);
    const error_align = Type.anyerror.abiAlignment(mod);
    if (payload_align.compare(.gte, error_align) and payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        return error_align.forward(payload_ty.abiSize(mod));
    } else {
        return 0;
    }
}
