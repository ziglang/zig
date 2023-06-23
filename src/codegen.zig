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
const Module = @import("Module.zig");
const Target = std.Target;
const Type = @import("type.zig").Type;
const TypedValue = @import("TypedValue.zig");
const Value = @import("value.zig").Value;
const Zir = @import("Zir.zig");

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
    /// the plan9 debuginfo output is a bytecode with 4 opcodes
    /// assume all numbers/variables are bytes
    /// 0 w x y z -> interpret w x y z as a big-endian i32, and add it to the line offset
    /// x when x < 65 -> add x to line offset
    /// x when x < 129 -> subtract 64 from x and subtract it from the line offset
    /// x -> subtract 129 from x, multiply it by the quanta of the instruction size
    /// (1 on x86_64), and add it to the pc
    /// after every opcode, add the quanta of the instruction size to the pc
    plan9: struct {
        /// the actual opcodes
        dbg_line: *std.ArrayList(u8),
        /// what line the debuginfo starts on
        /// this helps because the linker might have to insert some opcodes to make sure that the line count starts at the right amount for the next decl
        start_line: *?u32,
        /// what the line count ends on after codegen
        /// this helps because the linker might have to insert some opcodes to make sure that the line count starts at the right amount for the next decl
        end_line: *u32,
        /// the last pc change op
        /// This is very useful for adding quanta
        /// to it if its not actually the last one.
        pcop_change_index: *?u32,
    },
    none,
};

pub fn generateFunction(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    func_index: Module.Fn.Index,
    air: Air,
    liveness: Liveness,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
) CodeGenError!Result {
    switch (bin_file.options.target.cpu.arch) {
        .arm,
        .armeb,
        => return @import("arch/arm/CodeGen.zig").generate(bin_file, src_loc, func_index, air, liveness, code, debug_output),
        .aarch64,
        .aarch64_be,
        .aarch64_32,
        => return @import("arch/aarch64/CodeGen.zig").generate(bin_file, src_loc, func_index, air, liveness, code, debug_output),
        .riscv64 => return @import("arch/riscv64/CodeGen.zig").generate(bin_file, src_loc, func_index, air, liveness, code, debug_output),
        .sparc64 => return @import("arch/sparc64/CodeGen.zig").generate(bin_file, src_loc, func_index, air, liveness, code, debug_output),
        .x86_64 => return @import("arch/x86_64/CodeGen.zig").generate(bin_file, src_loc, func_index, air, liveness, code, debug_output),
        .wasm32,
        .wasm64,
        => return @import("arch/wasm/CodeGen.zig").generate(bin_file, src_loc, func_index, air, liveness, code, debug_output),
        else => unreachable,
    }
}

pub fn generateLazyFunction(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    lazy_sym: link.File.LazySymbol,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
) CodeGenError!Result {
    switch (bin_file.options.target.cpu.arch) {
        .x86_64 => return @import("arch/x86_64/CodeGen.zig").generateLazy(bin_file, src_loc, lazy_sym, code, debug_output),
        else => unreachable,
    }
}

fn writeFloat(comptime F: type, f: F, target: Target, endian: std.builtin.Endian, code: []u8) void {
    _ = target;
    const bits = @typeInfo(F).Float.bits;
    const Int = @Type(.{ .Int = .{ .signedness = .unsigned, .bits = bits } });
    const int = @bitCast(Int, f);
    mem.writeInt(Int, code[0..@divExact(bits, 8)], int, endian);
}

pub fn generateLazySymbol(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    lazy_sym: link.File.LazySymbol,
    alignment: *u32,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
    reloc_info: RelocInfo,
) CodeGenError!Result {
    _ = reloc_info;

    const tracy = trace(@src());
    defer tracy.end();

    const target = bin_file.options.target;
    const endian = target.cpu.arch.endian();

    const mod = bin_file.options.module.?;
    log.debug("generateLazySymbol: kind = {s}, ty = {}", .{
        @tagName(lazy_sym.kind),
        lazy_sym.ty.fmt(mod),
    });

    if (lazy_sym.kind == .code) {
        alignment.* = target_util.defaultFunctionAlignment(target);
        return generateLazyFunction(bin_file, src_loc, lazy_sym, code, debug_output);
    }

    if (lazy_sym.ty.isAnyError(mod)) {
        alignment.* = 4;
        const err_names = mod.global_error_set.keys();
        mem.writeInt(u32, try code.addManyAsArray(4), @intCast(u32, err_names.len), endian);
        var offset = code.items.len;
        try code.resize((1 + err_names.len + 1) * 4);
        for (err_names) |err_name_nts| {
            const err_name = mod.intern_pool.stringToSlice(err_name_nts);
            mem.writeInt(u32, code.items[offset..][0..4], @intCast(u32, code.items.len), endian);
            offset += 4;
            try code.ensureUnusedCapacity(err_name.len + 1);
            code.appendSliceAssumeCapacity(err_name);
            code.appendAssumeCapacity(0);
        }
        mem.writeInt(u32, code.items[offset..][0..4], @intCast(u32, code.items.len), endian);
        return Result.ok;
    } else if (lazy_sym.ty.zigTypeTag(mod) == .Enum) {
        alignment.* = 1;
        for (lazy_sym.ty.enumFields(mod)) |tag_name_ip| {
            const tag_name = mod.intern_pool.stringToSlice(tag_name_ip);
            try code.ensureUnusedCapacity(tag_name.len + 1);
            code.appendSliceAssumeCapacity(tag_name);
            code.appendAssumeCapacity(0);
        }
        return Result.ok;
    } else return .{ .fail = try ErrorMsg.create(
        bin_file.allocator,
        src_loc,
        "TODO implement generateLazySymbol for {s} {}",
        .{ @tagName(lazy_sym.kind), lazy_sym.ty.fmt(mod) },
    ) };
}

pub fn generateSymbol(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    arg_tv: TypedValue,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
    reloc_info: RelocInfo,
) CodeGenError!Result {
    const tracy = trace(@src());
    defer tracy.end();

    const mod = bin_file.options.module.?;
    var typed_value = arg_tv;
    switch (mod.intern_pool.indexToKey(typed_value.val.toIntern())) {
        .runtime_value => |rt| typed_value.val = rt.val.toValue(),
        else => {},
    }

    const target = mod.getTarget();
    const endian = target.cpu.arch.endian();

    log.debug("generateSymbol: ty = {}, val = {}", .{
        typed_value.ty.fmt(mod),
        typed_value.val.fmtValue(typed_value.ty, mod),
    });

    if (typed_value.val.isUndefDeep(mod)) {
        const abi_size = math.cast(usize, typed_value.ty.abiSize(mod)) orelse return error.Overflow;
        try code.appendNTimes(0xaa, abi_size);
        return .ok;
    }

    switch (mod.intern_pool.indexToKey(typed_value.val.toIntern())) {
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

        .undef, .runtime_value => unreachable, // handled above
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
            const abi_size = math.cast(usize, typed_value.ty.abiSize(mod)) orelse return error.Overflow;
            var space: Value.BigIntSpace = undefined;
            const val = typed_value.val.toBigInt(&space, mod);
            val.writeTwosComplement(try code.addManyAsSlice(abi_size), endian);
        },
        .err => |err| {
            const int = try mod.getErrorValue(err.name);
            try code.writer().writeInt(u16, @intCast(u16, int), endian);
        },
        .error_union => |error_union| {
            const payload_ty = typed_value.ty.errorUnionPayload(mod);
            const err_val = switch (error_union.val) {
                .err_name => |err_name| @intCast(u16, try mod.getErrorValue(err_name)),
                .payload => @as(u16, 0),
            };

            if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                try code.writer().writeInt(u16, err_val, endian);
                return .ok;
            }

            const payload_align = payload_ty.abiAlignment(mod);
            const error_align = Type.anyerror.abiAlignment(mod);
            const abi_align = typed_value.ty.abiAlignment(mod);

            // error value first when its type is larger than the error union's payload
            if (error_align > payload_align) {
                try code.writer().writeInt(u16, err_val, endian);
            }

            // emit payload part of the error union
            {
                const begin = code.items.len;
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = payload_ty,
                    .val = switch (error_union.val) {
                        .err_name => try mod.intern(.{ .undef = payload_ty.toIntern() }),
                        .payload => |payload| payload,
                    }.toValue(),
                }, code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return .{ .fail = em },
                }
                const unpadded_end = code.items.len - begin;
                const padded_end = mem.alignForward(u64, unpadded_end, abi_align);
                const padding = math.cast(usize, padded_end - unpadded_end) orelse return error.Overflow;

                if (padding > 0) {
                    try code.writer().writeByteNTimes(0, padding);
                }
            }

            // Payload size is larger than error set, so emit our error set last
            if (error_align <= payload_align) {
                const begin = code.items.len;
                try code.writer().writeInt(u16, err_val, endian);
                const unpadded_end = code.items.len - begin;
                const padded_end = mem.alignForward(u64, unpadded_end, abi_align);
                const padding = math.cast(usize, padded_end - unpadded_end) orelse return error.Overflow;

                if (padding > 0) {
                    try code.writer().writeByteNTimes(0, padding);
                }
            }
        },
        .enum_tag => |enum_tag| {
            const int_tag_ty = typed_value.ty.intTagType(mod);
            switch (try generateSymbol(bin_file, src_loc, .{
                .ty = int_tag_ty,
                .val = try mod.getCoerced(enum_tag.int.toValue(), int_tag_ty),
            }, code, debug_output, reloc_info)) {
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
                const abi_size = math.cast(usize, typed_value.ty.abiSize(mod)) orelse return error.Overflow;
                try code.appendNTimes(0, abi_size - 10);
            },
            .f128 => |f128_val| writeFloat(f128, f128_val, target, endian, try code.addManyAsArray(16)),
        },
        .ptr => |ptr| {
            // generate ptr
            switch (try lowerParentPtr(bin_file, src_loc, switch (ptr.len) {
                .none => typed_value.val,
                else => typed_value.val.slicePtr(mod),
            }.toIntern(), code, debug_output, reloc_info)) {
                .ok => {},
                .fail => |em| return .{ .fail = em },
            }
            if (ptr.len != .none) {
                // generate len
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = Type.usize,
                    .val = ptr.len.toValue(),
                }, code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }
            }
        },
        .opt => {
            const payload_type = typed_value.ty.optionalChild(mod);
            const payload_val = typed_value.val.optionalValue(mod);
            const abi_size = math.cast(usize, typed_value.ty.abiSize(mod)) orelse return error.Overflow;

            if (typed_value.ty.optionalReprIsPayload(mod)) {
                if (payload_val) |value| {
                    switch (try generateSymbol(bin_file, src_loc, .{
                        .ty = payload_type,
                        .val = value,
                    }, code, debug_output, reloc_info)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }
                } else {
                    try code.writer().writeByteNTimes(0, abi_size);
                }
            } else {
                const padding = abi_size - (math.cast(usize, payload_type.abiSize(mod)) orelse return error.Overflow) - 1;
                if (payload_type.hasRuntimeBits(mod)) {
                    const value = payload_val orelse (try mod.intern(.{ .undef = payload_type.toIntern() })).toValue();
                    switch (try generateSymbol(bin_file, src_loc, .{
                        .ty = payload_type,
                        .val = value,
                    }, code, debug_output, reloc_info)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }
                }
                try code.writer().writeByte(@intFromBool(payload_val != null));
                try code.writer().writeByteNTimes(0, padding);
            }
        },
        .aggregate => |aggregate| switch (mod.intern_pool.indexToKey(typed_value.ty.toIntern())) {
            .array_type => |array_type| switch (aggregate.storage) {
                .bytes => |bytes| try code.appendSlice(bytes),
                .elems, .repeated_elem => {
                    var index: u64 = 0;
                    var len_including_sentinel =
                        array_type.len + @intFromBool(array_type.sentinel != .none);
                    while (index < len_including_sentinel) : (index += 1) {
                        switch (try generateSymbol(bin_file, src_loc, .{
                            .ty = array_type.child.toType(),
                            .val = switch (aggregate.storage) {
                                .bytes => unreachable,
                                .elems => |elems| elems[@intCast(usize, index)],
                                .repeated_elem => |elem| elem,
                            }.toValue(),
                        }, code, debug_output, reloc_info)) {
                            .ok => {},
                            .fail => |em| return .{ .fail = em },
                        }
                    }
                },
            },
            .vector_type => |vector_type| {
                switch (aggregate.storage) {
                    .bytes => |bytes| try code.appendSlice(bytes),
                    .elems, .repeated_elem => {
                        var index: u64 = 0;
                        while (index < vector_type.len) : (index += 1) {
                            switch (try generateSymbol(bin_file, src_loc, .{
                                .ty = vector_type.child.toType(),
                                .val = switch (aggregate.storage) {
                                    .bytes => unreachable,
                                    .elems => |elems| elems[@intCast(usize, index)],
                                    .repeated_elem => |elem| elem,
                                }.toValue(),
                            }, code, debug_output, reloc_info)) {
                                .ok => {},
                                .fail => |em| return .{ .fail = em },
                            }
                        }
                    },
                }

                const padding = math.cast(usize, typed_value.ty.abiSize(mod) -
                    (math.divCeil(u64, vector_type.child.toType().bitSize(mod) * vector_type.len, 8) catch |err| switch (err) {
                    error.DivisionByZero => unreachable,
                    else => |e| return e,
                })) orelse return error.Overflow;
                if (padding > 0) try code.writer().writeByteNTimes(0, padding);
            },
            .anon_struct_type => |tuple| {
                const struct_begin = code.items.len;
                for (tuple.types, tuple.values, 0..) |field_ty, comptime_val, index| {
                    if (comptime_val != .none) continue;
                    if (!field_ty.toType().hasRuntimeBits(mod)) continue;

                    const field_val = switch (aggregate.storage) {
                        .bytes => |bytes| try mod.intern_pool.get(mod.gpa, .{ .int = .{
                            .ty = field_ty,
                            .storage = .{ .u64 = bytes[index] },
                        } }),
                        .elems => |elems| elems[index],
                        .repeated_elem => |elem| elem,
                    };

                    switch (try generateSymbol(bin_file, src_loc, .{
                        .ty = field_ty.toType(),
                        .val = field_val.toValue(),
                    }, code, debug_output, reloc_info)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }
                    const unpadded_field_end = code.items.len - struct_begin;

                    // Pad struct members if required
                    const padded_field_end = typed_value.ty.structFieldOffset(index + 1, mod);
                    const padding = math.cast(usize, padded_field_end - unpadded_field_end) orelse
                        return error.Overflow;

                    if (padding > 0) {
                        try code.writer().writeByteNTimes(0, padding);
                    }
                }
            },
            .struct_type => |struct_type| {
                const struct_obj = mod.structPtrUnwrap(struct_type.index).?;

                if (struct_obj.layout == .Packed) {
                    const fields = struct_obj.fields.values();
                    const abi_size = math.cast(usize, typed_value.ty.abiSize(mod)) orelse
                        return error.Overflow;
                    const current_pos = code.items.len;
                    try code.resize(current_pos + abi_size);
                    var bits: u16 = 0;

                    for (fields, 0..) |field, index| {
                        const field_ty = field.ty;

                        const field_val = switch (aggregate.storage) {
                            .bytes => |bytes| try mod.intern_pool.get(mod.gpa, .{ .int = .{
                                .ty = field_ty.toIntern(),
                                .storage = .{ .u64 = bytes[index] },
                            } }),
                            .elems => |elems| elems[index],
                            .repeated_elem => |elem| elem,
                        };

                        // pointer may point to a decl which must be marked used
                        // but can also result in a relocation. Therefore we handle those separately.
                        if (field_ty.zigTypeTag(mod) == .Pointer) {
                            const field_size = math.cast(usize, field_ty.abiSize(mod)) orelse
                                return error.Overflow;
                            var tmp_list = try std.ArrayList(u8).initCapacity(code.allocator, field_size);
                            defer tmp_list.deinit();
                            switch (try generateSymbol(bin_file, src_loc, .{
                                .ty = field_ty,
                                .val = field_val.toValue(),
                            }, &tmp_list, debug_output, reloc_info)) {
                                .ok => @memcpy(code.items[current_pos..][0..tmp_list.items.len], tmp_list.items),
                                .fail => |em| return Result{ .fail = em },
                            }
                        } else {
                            field_val.toValue().writeToPackedMemory(field_ty, mod, code.items[current_pos..], bits) catch unreachable;
                        }
                        bits += @intCast(u16, field_ty.bitSize(mod));
                    }
                } else {
                    const struct_begin = code.items.len;
                    for (struct_obj.fields.values(), 0..) |field, index| {
                        const field_ty = field.ty;
                        if (!field_ty.hasRuntimeBits(mod)) continue;

                        const field_val = switch (mod.intern_pool.indexToKey(typed_value.val.toIntern()).aggregate.storage) {
                            .bytes => |bytes| try mod.intern_pool.get(mod.gpa, .{ .int = .{
                                .ty = field_ty.toIntern(),
                                .storage = .{ .u64 = bytes[index] },
                            } }),
                            .elems => |elems| elems[index],
                            .repeated_elem => |elem| elem,
                        };

                        switch (try generateSymbol(bin_file, src_loc, .{
                            .ty = field_ty,
                            .val = field_val.toValue(),
                        }, code, debug_output, reloc_info)) {
                            .ok => {},
                            .fail => |em| return Result{ .fail = em },
                        }
                        const unpadded_field_end = code.items.len - struct_begin;

                        // Pad struct members if required
                        const padded_field_end = typed_value.ty.structFieldOffset(index + 1, mod);
                        const padding = math.cast(usize, padded_field_end - unpadded_field_end) orelse return error.Overflow;

                        if (padding > 0) {
                            try code.writer().writeByteNTimes(0, padding);
                        }
                    }
                }
            },
            else => unreachable,
        },
        .un => |un| {
            const layout = typed_value.ty.unionGetLayout(mod);

            if (layout.payload_size == 0) {
                return generateSymbol(bin_file, src_loc, .{
                    .ty = typed_value.ty.unionTagType(mod).?,
                    .val = un.tag.toValue(),
                }, code, debug_output, reloc_info);
            }

            // Check if we should store the tag first.
            if (layout.tag_align >= layout.payload_align) {
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = typed_value.ty.unionTagType(mod).?,
                    .val = un.tag.toValue(),
                }, code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }
            }

            const union_ty = mod.typeToUnion(typed_value.ty).?;
            const field_index = typed_value.ty.unionTagFieldIndex(un.tag.toValue(), mod).?;
            assert(union_ty.haveFieldTypes());
            const field_ty = union_ty.fields.values()[field_index].ty;
            if (!field_ty.hasRuntimeBits(mod)) {
                try code.writer().writeByteNTimes(0xaa, math.cast(usize, layout.payload_size) orelse return error.Overflow);
            } else {
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = field_ty,
                    .val = un.val.toValue(),
                }, code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }

                const padding = math.cast(usize, layout.payload_size - field_ty.abiSize(mod)) orelse return error.Overflow;
                if (padding > 0) {
                    try code.writer().writeByteNTimes(0, padding);
                }
            }

            if (layout.tag_size > 0) {
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = union_ty.tag_ty,
                    .val = un.tag.toValue(),
                }, code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }
            }

            if (layout.padding > 0) {
                try code.writer().writeByteNTimes(0, layout.padding);
            }
        },
        .memoized_call => unreachable,
    }
    return .ok;
}

fn lowerParentPtr(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    parent_ptr: InternPool.Index,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
    reloc_info: RelocInfo,
) CodeGenError!Result {
    const mod = bin_file.options.module.?;
    const ptr = mod.intern_pool.indexToKey(parent_ptr).ptr;
    assert(ptr.len == .none);
    return switch (ptr.addr) {
        .decl, .mut_decl => try lowerDeclRef(
            bin_file,
            src_loc,
            switch (ptr.addr) {
                .decl => |decl| decl,
                .mut_decl => |mut_decl| mut_decl.decl,
                else => unreachable,
            },
            code,
            debug_output,
            reloc_info,
        ),
        .int => |int| try generateSymbol(bin_file, src_loc, .{
            .ty = Type.usize,
            .val = int.toValue(),
        }, code, debug_output, reloc_info),
        .eu_payload => |eu_payload| try lowerParentPtr(
            bin_file,
            src_loc,
            eu_payload,
            code,
            debug_output,
            reloc_info.offset(@intCast(u32, errUnionPayloadOffset(
                mod.intern_pool.typeOf(eu_payload).toType(),
                mod,
            ))),
        ),
        .opt_payload => |opt_payload| try lowerParentPtr(
            bin_file,
            src_loc,
            opt_payload,
            code,
            debug_output,
            reloc_info,
        ),
        .elem => |elem| try lowerParentPtr(
            bin_file,
            src_loc,
            elem.base,
            code,
            debug_output,
            reloc_info.offset(@intCast(u32, elem.index *
                mod.intern_pool.typeOf(elem.base).toType().elemType2(mod).abiSize(mod))),
        ),
        .field => |field| {
            const base_type = mod.intern_pool.indexToKey(mod.intern_pool.typeOf(field.base)).ptr_type.child;
            return lowerParentPtr(
                bin_file,
                src_loc,
                field.base,
                code,
                debug_output,
                reloc_info.offset(switch (mod.intern_pool.indexToKey(base_type)) {
                    .ptr_type => |ptr_type| switch (ptr_type.flags.size) {
                        .One, .Many, .C => unreachable,
                        .Slice => switch (field.index) {
                            0 => 0,
                            1 => @divExact(mod.getTarget().ptrBitWidth(), 8),
                            else => unreachable,
                        },
                    },
                    .struct_type,
                    .anon_struct_type,
                    .union_type,
                    => @intCast(u32, base_type.toType().structFieldOffset(
                        @intCast(u32, field.index),
                        mod,
                    )),
                    else => unreachable,
                }),
            );
        },
        .comptime_field => unreachable,
    };
}

const RelocInfo = struct {
    parent_atom_index: u32,
    addend: ?u32 = null,

    fn offset(ri: RelocInfo, addend: u32) RelocInfo {
        return .{ .parent_atom_index = ri.parent_atom_index, .addend = (ri.addend orelse 0) + addend };
    }
};

fn lowerDeclRef(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    decl_index: Module.Decl.Index,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
    reloc_info: RelocInfo,
) CodeGenError!Result {
    _ = src_loc;
    _ = debug_output;
    const target = bin_file.options.target;
    const mod = bin_file.options.module.?;

    const ptr_width = target.ptrBitWidth();
    const decl = mod.declPtr(decl_index);
    const is_fn_body = decl.ty.zigTypeTag(mod) == .Fn;
    if (!is_fn_body and !decl.ty.hasRuntimeBits(mod)) {
        try code.writer().writeByteNTimes(0xaa, @divExact(ptr_width, 8));
        return Result.ok;
    }

    try mod.markDeclAlive(decl);

    const vaddr = try bin_file.getDeclVAddr(decl_index, .{
        .parent_atom_index = reloc_info.parent_atom_index,
        .offset = code.items.len,
        .addend = reloc_info.addend orelse 0,
    });
    const endian = target.cpu.arch.endian();
    switch (ptr_width) {
        16 => mem.writeInt(u16, try code.addManyAsArray(2), @intCast(u16, vaddr), endian),
        32 => mem.writeInt(u32, try code.addManyAsArray(4), @intCast(u32, vaddr), endian),
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
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    tv: TypedValue,
    decl_index: Module.Decl.Index,
) CodeGenError!GenResult {
    const mod = bin_file.options.module.?;
    log.debug("genDeclRef: ty = {}, val = {}", .{ tv.ty.fmt(mod), tv.val.fmtValue(tv.ty, mod) });

    const target = bin_file.options.target;
    const ptr_bits = target.ptrBitWidth();
    const ptr_bytes: u64 = @divExact(ptr_bits, 8);

    const decl = mod.declPtr(decl_index);

    if (!decl.ty.isFnOrHasRuntimeBitsIgnoreComptime(mod)) {
        const imm: u64 = switch (ptr_bytes) {
            1 => 0xaa,
            2 => 0xaaaa,
            4 => 0xaaaaaaaa,
            8 => 0xaaaaaaaaaaaaaaaa,
            else => unreachable,
        };
        return GenResult.mcv(.{ .immediate = imm });
    }

    // TODO this feels clunky. Perhaps we should check for it in `genTypedValue`?
    if (tv.ty.castPtrToFn(mod)) |fn_ty| {
        if (mod.typeToFunc(fn_ty).?.is_generic) {
            return GenResult.mcv(.{ .immediate = fn_ty.abiAlignment(mod) });
        }
    } else if (tv.ty.zigTypeTag(mod) == .Pointer) {
        const elem_ty = tv.ty.elemType2(mod);
        if (!elem_ty.hasRuntimeBits(mod)) {
            return GenResult.mcv(.{ .immediate = elem_ty.abiAlignment(mod) });
        }
    }

    try mod.markDeclAlive(decl);

    const is_threadlocal = tv.val.isPtrToThreadLocal(mod) and !bin_file.options.single_threaded;

    if (bin_file.cast(link.File.Elf)) |elf_file| {
        const atom_index = try elf_file.getOrCreateAtomForDecl(decl_index);
        const atom = elf_file.getAtom(atom_index);
        _ = try atom.getOrCreateOffsetTableEntry(elf_file);
        return GenResult.mcv(.{ .memory = atom.getOffsetTableAddress(elf_file) });
    } else if (bin_file.cast(link.File.MachO)) |macho_file| {
        const atom_index = try macho_file.getOrCreateAtomForDecl(decl_index);
        const sym_index = macho_file.getAtom(atom_index).getSymbolIndex().?;
        if (is_threadlocal) {
            return GenResult.mcv(.{ .load_tlv = sym_index });
        }
        return GenResult.mcv(.{ .load_got = sym_index });
    } else if (bin_file.cast(link.File.Coff)) |coff_file| {
        const atom_index = try coff_file.getOrCreateAtomForDecl(decl_index);
        const sym_index = coff_file.getAtom(atom_index).getSymbolIndex().?;
        return GenResult.mcv(.{ .load_got = sym_index });
    } else if (bin_file.cast(link.File.Plan9)) |p9| {
        const atom_index = try p9.seeDecl(decl_index);
        const atom = p9.getAtom(atom_index);
        return GenResult.mcv(.{ .memory = atom.getOffsetTableAddress(p9) });
    } else {
        return GenResult.fail(bin_file.allocator, src_loc, "TODO genDeclRef for target {}", .{target});
    }
}

fn genUnnamedConst(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    tv: TypedValue,
    owner_decl_index: Module.Decl.Index,
) CodeGenError!GenResult {
    const mod = bin_file.options.module.?;
    log.debug("genUnnamedConst: ty = {}, val = {}", .{ tv.ty.fmt(mod), tv.val.fmtValue(tv.ty, mod) });

    const target = bin_file.options.target;
    const local_sym_index = bin_file.lowerUnnamedConst(tv, owner_decl_index) catch |err| {
        return GenResult.fail(bin_file.allocator, src_loc, "lowering unnamed constant failed: {s}", .{@errorName(err)});
    };
    if (bin_file.cast(link.File.Elf)) |elf_file| {
        return GenResult.mcv(.{ .memory = elf_file.getSymbol(local_sym_index).st_value });
    } else if (bin_file.cast(link.File.MachO)) |_| {
        return GenResult.mcv(.{ .load_direct = local_sym_index });
    } else if (bin_file.cast(link.File.Coff)) |_| {
        return GenResult.mcv(.{ .load_direct = local_sym_index });
    } else if (bin_file.cast(link.File.Plan9)) |_| {
        const atom_index = local_sym_index; // plan9 returns the atom_index
        return GenResult.mcv(.{ .load_direct = atom_index });
    } else {
        return GenResult.fail(bin_file.allocator, src_loc, "TODO genUnnamedConst for target {}", .{target});
    }
}

pub fn genTypedValue(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    arg_tv: TypedValue,
    owner_decl_index: Module.Decl.Index,
) CodeGenError!GenResult {
    const mod = bin_file.options.module.?;
    var typed_value = arg_tv;
    switch (mod.intern_pool.indexToKey(typed_value.val.toIntern())) {
        .runtime_value => |rt| typed_value.val = rt.val.toValue(),
        else => {},
    }

    log.debug("genTypedValue: ty = {}, val = {}", .{
        typed_value.ty.fmt(mod),
        typed_value.val.fmtValue(typed_value.ty, mod),
    });

    if (typed_value.val.isUndef(mod))
        return GenResult.mcv(.undef);

    const target = bin_file.options.target;
    const ptr_bits = target.ptrBitWidth();

    if (!typed_value.ty.isSlice(mod)) switch (mod.intern_pool.indexToKey(typed_value.val.toIntern())) {
        .ptr => |ptr| switch (ptr.addr) {
            .decl => |decl| return genDeclRef(bin_file, src_loc, typed_value, decl),
            .mut_decl => |mut_decl| return genDeclRef(bin_file, src_loc, typed_value, mut_decl.decl),
            else => {},
        },
        else => {},
    };

    switch (typed_value.ty.zigTypeTag(mod)) {
        .Void => return GenResult.mcv(.none),
        .Pointer => switch (typed_value.ty.ptrSize(mod)) {
            .Slice => {},
            else => switch (typed_value.val.toIntern()) {
                .null_value => {
                    return GenResult.mcv(.{ .immediate = 0 });
                },
                .none => {},
                else => switch (mod.intern_pool.indexToKey(typed_value.val.toIntern())) {
                    .int => {
                        return GenResult.mcv(.{ .immediate = typed_value.val.toUnsignedInt(mod) });
                    },
                    else => {},
                },
            },
        },
        .Int => {
            const info = typed_value.ty.intInfo(mod);
            if (info.bits <= ptr_bits) {
                const unsigned = switch (info.signedness) {
                    .signed => @bitCast(u64, typed_value.val.toSignedInt(mod)),
                    .unsigned => typed_value.val.toUnsignedInt(mod),
                };
                return GenResult.mcv(.{ .immediate = unsigned });
            }
        },
        .Bool => {
            return GenResult.mcv(.{ .immediate = @intFromBool(typed_value.val.toBool()) });
        },
        .Optional => {
            if (typed_value.ty.isPtrLikeOptional(mod)) {
                return genTypedValue(bin_file, src_loc, .{
                    .ty = typed_value.ty.optionalChild(mod),
                    .val = typed_value.val.optionalValue(mod) orelse return GenResult.mcv(.{ .immediate = 0 }),
                }, owner_decl_index);
            } else if (typed_value.ty.abiSize(mod) == 1) {
                return GenResult.mcv(.{ .immediate = @intFromBool(!typed_value.val.isNull(mod)) });
            }
        },
        .Enum => {
            const enum_tag = mod.intern_pool.indexToKey(typed_value.val.toIntern()).enum_tag;
            const int_tag_ty = mod.intern_pool.typeOf(enum_tag.int);
            return genTypedValue(bin_file, src_loc, .{
                .ty = int_tag_ty.toType(),
                .val = enum_tag.int.toValue(),
            }, owner_decl_index);
        },
        .ErrorSet => {
            const err_name = mod.intern_pool.indexToKey(typed_value.val.toIntern()).err.name;
            const error_index = mod.global_error_set.getIndex(err_name).?;
            return GenResult.mcv(.{ .immediate = error_index });
        },
        .ErrorUnion => {
            const err_type = typed_value.ty.errorUnionSet(mod);
            const payload_type = typed_value.ty.errorUnionPayload(mod);
            if (!payload_type.hasRuntimeBitsIgnoreComptime(mod)) {
                // We use the error type directly as the type.
                switch (mod.intern_pool.indexToKey(typed_value.val.toIntern()).error_union.val) {
                    .err_name => |err_name| return genTypedValue(bin_file, src_loc, .{
                        .ty = err_type,
                        .val = (try mod.intern(.{ .err = .{
                            .ty = err_type.toIntern(),
                            .name = err_name,
                        } })).toValue(),
                    }, owner_decl_index),
                    .payload => return genTypedValue(bin_file, src_loc, .{
                        .ty = Type.err_int,
                        .val = try mod.intValue(Type.err_int, 0),
                    }, owner_decl_index),
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

    return genUnnamedConst(bin_file, src_loc, typed_value, owner_decl_index);
}

pub fn errUnionPayloadOffset(payload_ty: Type, mod: *Module) u64 {
    if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) return 0;
    const payload_align = payload_ty.abiAlignment(mod);
    const error_align = Type.anyerror.abiAlignment(mod);
    if (payload_align >= error_align or !payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        return 0;
    } else {
        return mem.alignForward(u64, Type.anyerror.abiSize(mod), payload_align);
    }
}

pub fn errUnionErrorOffset(payload_ty: Type, mod: *Module) u64 {
    if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) return 0;
    const payload_align = payload_ty.abiAlignment(mod);
    const error_align = Type.anyerror.abiAlignment(mod);
    if (payload_align >= error_align and payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        return mem.alignForward(u64, payload_ty.abiSize(mod), error_align);
    } else {
        return 0;
    }
}
