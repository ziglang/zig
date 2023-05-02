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
    func: *Module.Fn,
    air: Air,
    liveness: Liveness,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
) CodeGenError!Result {
    switch (bin_file.options.target.cpu.arch) {
        .arm,
        .armeb,
        => return @import("arch/arm/CodeGen.zig").generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        .aarch64,
        .aarch64_be,
        .aarch64_32,
        => return @import("arch/aarch64/CodeGen.zig").generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        .riscv64 => return @import("arch/riscv64/CodeGen.zig").generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        .sparc64 => return @import("arch/sparc64/CodeGen.zig").generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        .x86_64 => return @import("arch/x86_64/CodeGen.zig").generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        .wasm32,
        .wasm64,
        => return @import("arch/wasm/CodeGen.zig").generate(bin_file, src_loc, func, air, liveness, code, debug_output),
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

    if (lazy_sym.ty.isAnyError()) {
        alignment.* = 4;
        const err_names = mod.error_name_list.items;
        mem.writeInt(u32, try code.addManyAsArray(4), @intCast(u32, err_names.len), endian);
        var offset = code.items.len;
        try code.resize((1 + err_names.len + 1) * 4);
        for (err_names) |err_name| {
            mem.writeInt(u32, code.items[offset..][0..4], @intCast(u32, code.items.len), endian);
            offset += 4;
            try code.ensureUnusedCapacity(err_name.len + 1);
            code.appendSliceAssumeCapacity(err_name);
            code.appendAssumeCapacity(0);
        }
        mem.writeInt(u32, code.items[offset..][0..4], @intCast(u32, code.items.len), endian);
        return Result.ok;
    } else if (lazy_sym.ty.zigTypeTag() == .Enum) {
        alignment.* = 1;
        for (lazy_sym.ty.enumFields().keys()) |tag_name| {
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

    var typed_value = arg_tv;
    if (arg_tv.val.castTag(.runtime_value)) |rt| {
        typed_value.val = rt.data;
    }

    const target = bin_file.options.target;
    const endian = target.cpu.arch.endian();

    const mod = bin_file.options.module.?;
    log.debug("generateSymbol: ty = {}, val = {}", .{
        typed_value.ty.fmt(mod),
        typed_value.val.fmtValue(typed_value.ty, mod),
    });

    if (typed_value.val.isUndefDeep()) {
        const abi_size = math.cast(usize, typed_value.ty.abiSize(target)) orelse return error.Overflow;
        try code.appendNTimes(0xaa, abi_size);
        return Result.ok;
    }

    switch (typed_value.ty.zigTypeTag()) {
        .Fn => {
            return Result{
                .fail = try ErrorMsg.create(
                    bin_file.allocator,
                    src_loc,
                    "TODO implement generateSymbol function pointers",
                    .{},
                ),
            };
        },
        .Float => {
            switch (typed_value.ty.floatBits(target)) {
                16 => writeFloat(f16, typed_value.val.toFloat(f16), target, endian, try code.addManyAsArray(2)),
                32 => writeFloat(f32, typed_value.val.toFloat(f32), target, endian, try code.addManyAsArray(4)),
                64 => writeFloat(f64, typed_value.val.toFloat(f64), target, endian, try code.addManyAsArray(8)),
                80 => {
                    writeFloat(f80, typed_value.val.toFloat(f80), target, endian, try code.addManyAsArray(10));
                    const abi_size = math.cast(usize, typed_value.ty.abiSize(target)) orelse return error.Overflow;
                    try code.appendNTimes(0, abi_size - 10);
                },
                128 => writeFloat(f128, typed_value.val.toFloat(f128), target, endian, try code.addManyAsArray(16)),
                else => unreachable,
            }
            return Result.ok;
        },
        .Array => switch (typed_value.val.tag()) {
            .bytes => {
                const bytes = typed_value.val.castTag(.bytes).?.data;
                const len = @intCast(usize, typed_value.ty.arrayLenIncludingSentinel());
                // The bytes payload already includes the sentinel, if any
                try code.ensureUnusedCapacity(len);
                code.appendSliceAssumeCapacity(bytes[0..len]);
                return Result.ok;
            },
            .str_lit => {
                const str_lit = typed_value.val.castTag(.str_lit).?.data;
                const bytes = mod.string_literal_bytes.items[str_lit.index..][0..str_lit.len];
                try code.ensureUnusedCapacity(bytes.len + 1);
                code.appendSliceAssumeCapacity(bytes);
                if (typed_value.ty.sentinel()) |sent_val| {
                    const byte = @intCast(u8, sent_val.toUnsignedInt(target));
                    code.appendAssumeCapacity(byte);
                }
                return Result.ok;
            },
            .aggregate => {
                const elem_vals = typed_value.val.castTag(.aggregate).?.data;
                const elem_ty = typed_value.ty.elemType();
                const len = @intCast(usize, typed_value.ty.arrayLenIncludingSentinel());
                for (elem_vals[0..len]) |elem_val| {
                    switch (try generateSymbol(bin_file, src_loc, .{
                        .ty = elem_ty,
                        .val = elem_val,
                    }, code, debug_output, reloc_info)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }
                }
                return Result.ok;
            },
            .repeated => {
                const array = typed_value.val.castTag(.repeated).?.data;
                const elem_ty = typed_value.ty.childType();
                const sentinel = typed_value.ty.sentinel();
                const len = typed_value.ty.arrayLen();

                var index: u64 = 0;
                while (index < len) : (index += 1) {
                    switch (try generateSymbol(bin_file, src_loc, .{
                        .ty = elem_ty,
                        .val = array,
                    }, code, debug_output, reloc_info)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }
                }

                if (sentinel) |sentinel_val| {
                    switch (try generateSymbol(bin_file, src_loc, .{
                        .ty = elem_ty,
                        .val = sentinel_val,
                    }, code, debug_output, reloc_info)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }
                }

                return Result.ok;
            },
            .empty_array_sentinel => {
                const elem_ty = typed_value.ty.childType();
                const sentinel_val = typed_value.ty.sentinel().?;
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = elem_ty,
                    .val = sentinel_val,
                }, code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }
                return Result.ok;
            },
            else => return Result{
                .fail = try ErrorMsg.create(
                    bin_file.allocator,
                    src_loc,
                    "TODO implement generateSymbol for array type value: {s}",
                    .{@tagName(typed_value.val.tag())},
                ),
            },
        },
        .Pointer => switch (typed_value.val.tag()) {
            .null_value => {
                switch (target.cpu.arch.ptrBitWidth()) {
                    32 => {
                        mem.writeInt(u32, try code.addManyAsArray(4), 0, endian);
                        if (typed_value.ty.isSlice()) try code.appendNTimes(0xaa, 4);
                    },
                    64 => {
                        mem.writeInt(u64, try code.addManyAsArray(8), 0, endian);
                        if (typed_value.ty.isSlice()) try code.appendNTimes(0xaa, 8);
                    },
                    else => unreachable,
                }
                return Result.ok;
            },
            .zero, .one, .int_u64, .int_big_positive => {
                switch (target.cpu.arch.ptrBitWidth()) {
                    32 => {
                        const x = typed_value.val.toUnsignedInt(target);
                        mem.writeInt(u32, try code.addManyAsArray(4), @intCast(u32, x), endian);
                    },
                    64 => {
                        const x = typed_value.val.toUnsignedInt(target);
                        mem.writeInt(u64, try code.addManyAsArray(8), x, endian);
                    },
                    else => unreachable,
                }
                return Result.ok;
            },
            .variable, .decl_ref, .decl_ref_mut => |tag| return lowerDeclRef(
                bin_file,
                src_loc,
                typed_value,
                switch (tag) {
                    .variable => typed_value.val.castTag(.variable).?.data.owner_decl,
                    .decl_ref => typed_value.val.castTag(.decl_ref).?.data,
                    .decl_ref_mut => typed_value.val.castTag(.decl_ref_mut).?.data.decl_index,
                    else => unreachable,
                },
                code,
                debug_output,
                reloc_info,
            ),
            .slice => {
                const slice = typed_value.val.castTag(.slice).?.data;

                // generate ptr
                var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                const slice_ptr_field_type = typed_value.ty.slicePtrFieldType(&buf);
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = slice_ptr_field_type,
                    .val = slice.ptr,
                }, code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }

                // generate length
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = Type.initTag(.usize),
                    .val = slice.len,
                }, code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }

                return Result.ok;
            },
            .field_ptr, .elem_ptr => return lowerParentPtr(
                bin_file,
                src_loc,
                typed_value,
                typed_value.val,
                code,
                debug_output,
                reloc_info,
            ),
            else => return Result{
                .fail = try ErrorMsg.create(
                    bin_file.allocator,
                    src_loc,
                    "TODO implement generateSymbol for pointer type value: '{s}'",
                    .{@tagName(typed_value.val.tag())},
                ),
            },
        },
        .Int => {
            const info = typed_value.ty.intInfo(target);
            if (info.bits <= 8) {
                const x: u8 = switch (info.signedness) {
                    .unsigned => @intCast(u8, typed_value.val.toUnsignedInt(target)),
                    .signed => @bitCast(u8, @intCast(i8, typed_value.val.toSignedInt(target))),
                };
                try code.append(x);
                return Result.ok;
            }
            if (info.bits > 64) {
                var bigint_buffer: Value.BigIntSpace = undefined;
                const bigint = typed_value.val.toBigInt(&bigint_buffer, target);
                const abi_size = math.cast(usize, typed_value.ty.abiSize(target)) orelse return error.Overflow;
                const start = code.items.len;
                try code.resize(start + abi_size);
                bigint.writeTwosComplement(code.items[start..][0..abi_size], endian);
                return Result.ok;
            }
            switch (info.signedness) {
                .unsigned => {
                    if (info.bits <= 16) {
                        const x = @intCast(u16, typed_value.val.toUnsignedInt(target));
                        mem.writeInt(u16, try code.addManyAsArray(2), x, endian);
                    } else if (info.bits <= 32) {
                        const x = @intCast(u32, typed_value.val.toUnsignedInt(target));
                        mem.writeInt(u32, try code.addManyAsArray(4), x, endian);
                    } else {
                        const x = typed_value.val.toUnsignedInt(target);
                        mem.writeInt(u64, try code.addManyAsArray(8), x, endian);
                    }
                },
                .signed => {
                    if (info.bits <= 16) {
                        const x = @intCast(i16, typed_value.val.toSignedInt(target));
                        mem.writeInt(i16, try code.addManyAsArray(2), x, endian);
                    } else if (info.bits <= 32) {
                        const x = @intCast(i32, typed_value.val.toSignedInt(target));
                        mem.writeInt(i32, try code.addManyAsArray(4), x, endian);
                    } else {
                        const x = typed_value.val.toSignedInt(target);
                        mem.writeInt(i64, try code.addManyAsArray(8), x, endian);
                    }
                },
            }
            return Result.ok;
        },
        .Enum => {
            var int_buffer: Value.Payload.U64 = undefined;
            const int_val = typed_value.enumToInt(&int_buffer);

            const info = typed_value.ty.intInfo(target);
            if (info.bits <= 8) {
                const x = @intCast(u8, int_val.toUnsignedInt(target));
                try code.append(x);
                return Result.ok;
            }
            if (info.bits > 64) {
                return Result{
                    .fail = try ErrorMsg.create(
                        bin_file.allocator,
                        src_loc,
                        "TODO implement generateSymbol for big int enums ('{}')",
                        .{typed_value.ty.fmt(mod)},
                    ),
                };
            }
            switch (info.signedness) {
                .unsigned => {
                    if (info.bits <= 16) {
                        const x = @intCast(u16, int_val.toUnsignedInt(target));
                        mem.writeInt(u16, try code.addManyAsArray(2), x, endian);
                    } else if (info.bits <= 32) {
                        const x = @intCast(u32, int_val.toUnsignedInt(target));
                        mem.writeInt(u32, try code.addManyAsArray(4), x, endian);
                    } else {
                        const x = int_val.toUnsignedInt(target);
                        mem.writeInt(u64, try code.addManyAsArray(8), x, endian);
                    }
                },
                .signed => {
                    if (info.bits <= 16) {
                        const x = @intCast(i16, int_val.toSignedInt(target));
                        mem.writeInt(i16, try code.addManyAsArray(2), x, endian);
                    } else if (info.bits <= 32) {
                        const x = @intCast(i32, int_val.toSignedInt(target));
                        mem.writeInt(i32, try code.addManyAsArray(4), x, endian);
                    } else {
                        const x = int_val.toSignedInt(target);
                        mem.writeInt(i64, try code.addManyAsArray(8), x, endian);
                    }
                },
            }
            return Result.ok;
        },
        .Bool => {
            const x: u8 = @boolToInt(typed_value.val.toBool());
            try code.append(x);
            return Result.ok;
        },
        .Struct => {
            if (typed_value.ty.containerLayout() == .Packed) {
                const struct_obj = typed_value.ty.castTag(.@"struct").?.data;
                const fields = struct_obj.fields.values();
                const field_vals = typed_value.val.castTag(.aggregate).?.data;
                const abi_size = math.cast(usize, typed_value.ty.abiSize(target)) orelse return error.Overflow;
                const current_pos = code.items.len;
                try code.resize(current_pos + abi_size);
                var bits: u16 = 0;

                for (field_vals, 0..) |field_val, index| {
                    const field_ty = fields[index].ty;
                    // pointer may point to a decl which must be marked used
                    // but can also result in a relocation. Therefore we handle those seperately.
                    if (field_ty.zigTypeTag() == .Pointer) {
                        const field_size = math.cast(usize, field_ty.abiSize(target)) orelse return error.Overflow;
                        var tmp_list = try std.ArrayList(u8).initCapacity(code.allocator, field_size);
                        defer tmp_list.deinit();
                        switch (try generateSymbol(bin_file, src_loc, .{
                            .ty = field_ty,
                            .val = field_val,
                        }, &tmp_list, debug_output, reloc_info)) {
                            .ok => @memcpy(code.items[current_pos..][0..tmp_list.items.len], tmp_list.items),
                            .fail => |em| return Result{ .fail = em },
                        }
                    } else {
                        field_val.writeToPackedMemory(field_ty, mod, code.items[current_pos..], bits) catch unreachable;
                    }
                    bits += @intCast(u16, field_ty.bitSize(target));
                }

                return Result.ok;
            }

            const struct_begin = code.items.len;
            const field_vals = typed_value.val.castTag(.aggregate).?.data;
            for (field_vals, 0..) |field_val, index| {
                const field_ty = typed_value.ty.structFieldType(index);
                if (!field_ty.hasRuntimeBits()) continue;

                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = field_ty,
                    .val = field_val,
                }, code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }
                const unpadded_field_end = code.items.len - struct_begin;

                // Pad struct members if required
                const padded_field_end = typed_value.ty.structFieldOffset(index + 1, target);
                const padding = math.cast(usize, padded_field_end - unpadded_field_end) orelse return error.Overflow;

                if (padding > 0) {
                    try code.writer().writeByteNTimes(0, padding);
                }
            }

            return Result.ok;
        },
        .Union => {
            const union_obj = typed_value.val.castTag(.@"union").?.data;
            const layout = typed_value.ty.unionGetLayout(target);

            if (layout.payload_size == 0) {
                return generateSymbol(bin_file, src_loc, .{
                    .ty = typed_value.ty.unionTagType().?,
                    .val = union_obj.tag,
                }, code, debug_output, reloc_info);
            }

            // Check if we should store the tag first.
            if (layout.tag_align >= layout.payload_align) {
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = typed_value.ty.unionTagType().?,
                    .val = union_obj.tag,
                }, code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }
            }

            const union_ty = typed_value.ty.cast(Type.Payload.Union).?.data;
            const field_index = typed_value.ty.unionTagFieldIndex(union_obj.tag, mod).?;
            assert(union_ty.haveFieldTypes());
            const field_ty = union_ty.fields.values()[field_index].ty;
            if (!field_ty.hasRuntimeBits()) {
                try code.writer().writeByteNTimes(0xaa, math.cast(usize, layout.payload_size) orelse return error.Overflow);
            } else {
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = field_ty,
                    .val = union_obj.val,
                }, code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }

                const padding = math.cast(usize, layout.payload_size - field_ty.abiSize(target)) orelse return error.Overflow;
                if (padding > 0) {
                    try code.writer().writeByteNTimes(0, padding);
                }
            }

            if (layout.tag_size > 0) {
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = union_ty.tag_ty,
                    .val = union_obj.tag,
                }, code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }
            }

            return Result.ok;
        },
        .Optional => {
            var opt_buf: Type.Payload.ElemType = undefined;
            const payload_type = typed_value.ty.optionalChild(&opt_buf);
            const is_pl = !typed_value.val.isNull();
            const abi_size = math.cast(usize, typed_value.ty.abiSize(target)) orelse return error.Overflow;

            if (!payload_type.hasRuntimeBits()) {
                try code.writer().writeByteNTimes(@boolToInt(is_pl), abi_size);
                return Result.ok;
            }

            if (typed_value.ty.optionalReprIsPayload()) {
                if (typed_value.val.castTag(.opt_payload)) |payload| {
                    switch (try generateSymbol(bin_file, src_loc, .{
                        .ty = payload_type,
                        .val = payload.data,
                    }, code, debug_output, reloc_info)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }
                } else if (!typed_value.val.isNull()) {
                    switch (try generateSymbol(bin_file, src_loc, .{
                        .ty = payload_type,
                        .val = typed_value.val,
                    }, code, debug_output, reloc_info)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }
                } else {
                    try code.writer().writeByteNTimes(0, abi_size);
                }

                return Result.ok;
            }

            const padding = abi_size - (math.cast(usize, payload_type.abiSize(target)) orelse return error.Overflow) - 1;
            const value = if (typed_value.val.castTag(.opt_payload)) |payload| payload.data else Value.initTag(.undef);
            switch (try generateSymbol(bin_file, src_loc, .{
                .ty = payload_type,
                .val = value,
            }, code, debug_output, reloc_info)) {
                .ok => {},
                .fail => |em| return Result{ .fail = em },
            }
            try code.writer().writeByte(@boolToInt(is_pl));
            try code.writer().writeByteNTimes(0, padding);

            return Result.ok;
        },
        .ErrorUnion => {
            const error_ty = typed_value.ty.errorUnionSet();
            const payload_ty = typed_value.ty.errorUnionPayload();
            const is_payload = typed_value.val.errorUnionIsPayload();

            if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
                const err_val = if (is_payload) Value.initTag(.zero) else typed_value.val;
                return generateSymbol(bin_file, src_loc, .{
                    .ty = error_ty,
                    .val = err_val,
                }, code, debug_output, reloc_info);
            }

            const payload_align = payload_ty.abiAlignment(target);
            const error_align = Type.anyerror.abiAlignment(target);
            const abi_align = typed_value.ty.abiAlignment(target);

            // error value first when its type is larger than the error union's payload
            if (error_align > payload_align) {
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = error_ty,
                    .val = if (is_payload) Value.initTag(.zero) else typed_value.val,
                }, code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }
            }

            // emit payload part of the error union
            {
                const begin = code.items.len;
                const payload_val = if (typed_value.val.castTag(.eu_payload)) |val| val.data else Value.initTag(.undef);
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = payload_ty,
                    .val = payload_val,
                }, code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }
                const unpadded_end = code.items.len - begin;
                const padded_end = mem.alignForwardGeneric(u64, unpadded_end, abi_align);
                const padding = math.cast(usize, padded_end - unpadded_end) orelse return error.Overflow;

                if (padding > 0) {
                    try code.writer().writeByteNTimes(0, padding);
                }
            }

            // Payload size is larger than error set, so emit our error set last
            if (error_align <= payload_align) {
                const begin = code.items.len;
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = error_ty,
                    .val = if (is_payload) Value.initTag(.zero) else typed_value.val,
                }, code, debug_output, reloc_info)) {
                    .ok => {},
                    .fail => |em| return Result{ .fail = em },
                }
                const unpadded_end = code.items.len - begin;
                const padded_end = mem.alignForwardGeneric(u64, unpadded_end, abi_align);
                const padding = math.cast(usize, padded_end - unpadded_end) orelse return error.Overflow;

                if (padding > 0) {
                    try code.writer().writeByteNTimes(0, padding);
                }
            }

            return Result.ok;
        },
        .ErrorSet => {
            switch (typed_value.val.tag()) {
                .@"error" => {
                    const name = typed_value.val.getError().?;
                    const kv = try bin_file.options.module.?.getErrorValue(name);
                    try code.writer().writeInt(u32, kv.value, endian);
                },
                else => {
                    try code.writer().writeByteNTimes(0, @intCast(usize, Type.anyerror.abiSize(target)));
                },
            }
            return Result.ok;
        },
        .Vector => switch (typed_value.val.tag()) {
            .bytes => {
                const bytes = typed_value.val.castTag(.bytes).?.data;
                const len = @intCast(usize, typed_value.ty.arrayLen());
                try code.ensureUnusedCapacity(len);
                code.appendSliceAssumeCapacity(bytes[0..len]);
                return Result.ok;
            },
            .aggregate => {
                const elem_vals = typed_value.val.castTag(.aggregate).?.data;
                const elem_ty = typed_value.ty.elemType();
                const len = @intCast(usize, typed_value.ty.arrayLen());
                for (elem_vals[0..len]) |elem_val| {
                    switch (try generateSymbol(bin_file, src_loc, .{
                        .ty = elem_ty,
                        .val = elem_val,
                    }, code, debug_output, reloc_info)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }
                }
                return Result.ok;
            },
            .repeated => {
                const array = typed_value.val.castTag(.repeated).?.data;
                const elem_ty = typed_value.ty.childType();
                const len = typed_value.ty.arrayLen();

                var index: u64 = 0;
                while (index < len) : (index += 1) {
                    switch (try generateSymbol(bin_file, src_loc, .{
                        .ty = elem_ty,
                        .val = array,
                    }, code, debug_output, reloc_info)) {
                        .ok => {},
                        .fail => |em| return Result{ .fail = em },
                    }
                }
                return Result.ok;
            },
            .str_lit => {
                const str_lit = typed_value.val.castTag(.str_lit).?.data;
                const bytes = mod.string_literal_bytes.items[str_lit.index..][0..str_lit.len];
                try code.ensureUnusedCapacity(str_lit.len);
                code.appendSliceAssumeCapacity(bytes);
                return Result.ok;
            },
            else => unreachable,
        },
        else => |tag| return Result{ .fail = try ErrorMsg.create(
            bin_file.allocator,
            src_loc,
            "TODO implement generateSymbol for type '{s}'",
            .{@tagName(tag)},
        ) },
    }
}

fn lowerParentPtr(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    typed_value: TypedValue,
    parent_ptr: Value,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
    reloc_info: RelocInfo,
) CodeGenError!Result {
    const target = bin_file.options.target;

    switch (parent_ptr.tag()) {
        .field_ptr => {
            const field_ptr = parent_ptr.castTag(.field_ptr).?.data;
            return lowerParentPtr(
                bin_file,
                src_loc,
                typed_value,
                field_ptr.container_ptr,
                code,
                debug_output,
                reloc_info.offset(@intCast(u32, switch (field_ptr.container_ty.zigTypeTag()) {
                    .Pointer => offset: {
                        assert(field_ptr.container_ty.isSlice());
                        var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                        break :offset switch (field_ptr.field_index) {
                            0 => 0,
                            1 => field_ptr.container_ty.slicePtrFieldType(&buf).abiSize(target),
                            else => unreachable,
                        };
                    },
                    .Struct, .Union => field_ptr.container_ty.structFieldOffset(
                        field_ptr.field_index,
                        target,
                    ),
                    else => return Result{ .fail = try ErrorMsg.create(
                        bin_file.allocator,
                        src_loc,
                        "TODO implement lowerParentPtr for field_ptr with a container of type {}",
                        .{field_ptr.container_ty.fmt(bin_file.options.module.?)},
                    ) },
                })),
            );
        },
        .elem_ptr => {
            const elem_ptr = parent_ptr.castTag(.elem_ptr).?.data;
            return lowerParentPtr(
                bin_file,
                src_loc,
                typed_value,
                elem_ptr.array_ptr,
                code,
                debug_output,
                reloc_info.offset(@intCast(u32, elem_ptr.index * elem_ptr.elem_ty.abiSize(target))),
            );
        },
        .variable, .decl_ref, .decl_ref_mut => |tag| return lowerDeclRef(
            bin_file,
            src_loc,
            typed_value,
            switch (tag) {
                .variable => parent_ptr.castTag(.variable).?.data.owner_decl,
                .decl_ref => parent_ptr.castTag(.decl_ref).?.data,
                .decl_ref_mut => parent_ptr.castTag(.decl_ref_mut).?.data.decl_index,
                else => unreachable,
            },
            code,
            debug_output,
            reloc_info,
        ),
        else => |tag| return Result{ .fail = try ErrorMsg.create(
            bin_file.allocator,
            src_loc,
            "TODO implement lowerParentPtr for type '{s}'",
            .{@tagName(tag)},
        ) },
    }
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
    typed_value: TypedValue,
    decl_index: Module.Decl.Index,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
    reloc_info: RelocInfo,
) CodeGenError!Result {
    const target = bin_file.options.target;
    const module = bin_file.options.module.?;
    if (typed_value.ty.isSlice()) {
        // generate ptr
        var buf: Type.SlicePtrFieldTypeBuffer = undefined;
        const slice_ptr_field_type = typed_value.ty.slicePtrFieldType(&buf);
        switch (try generateSymbol(bin_file, src_loc, .{
            .ty = slice_ptr_field_type,
            .val = typed_value.val,
        }, code, debug_output, reloc_info)) {
            .ok => {},
            .fail => |em| return Result{ .fail = em },
        }

        // generate length
        var slice_len: Value.Payload.U64 = .{
            .base = .{ .tag = .int_u64 },
            .data = typed_value.val.sliceLen(module),
        };
        switch (try generateSymbol(bin_file, src_loc, .{
            .ty = Type.usize,
            .val = Value.initPayload(&slice_len.base),
        }, code, debug_output, reloc_info)) {
            .ok => {},
            .fail => |em| return Result{ .fail = em },
        }

        return Result.ok;
    }

    const ptr_width = target.cpu.arch.ptrBitWidth();
    const decl = module.declPtr(decl_index);
    const is_fn_body = decl.ty.zigTypeTag() == .Fn;
    if (!is_fn_body and !decl.ty.hasRuntimeBits()) {
        try code.writer().writeByteNTimes(0xaa, @divExact(ptr_width, 8));
        return Result.ok;
    }

    module.markDeclAlive(decl);

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
    const module = bin_file.options.module.?;
    log.debug("genDeclRef: ty = {}, val = {}", .{ tv.ty.fmt(module), tv.val.fmtValue(tv.ty, module) });

    const target = bin_file.options.target;
    const ptr_bits = target.cpu.arch.ptrBitWidth();
    const ptr_bytes: u64 = @divExact(ptr_bits, 8);

    const decl = module.declPtr(decl_index);

    if (!decl.ty.isFnOrHasRuntimeBitsIgnoreComptime()) {
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
    if (tv.ty.castPtrToFn()) |fn_ty| {
        if (fn_ty.fnInfo().is_generic) {
            return GenResult.mcv(.{ .immediate = fn_ty.abiAlignment(target) });
        }
    } else if (tv.ty.zigTypeTag() == .Pointer) {
        const elem_ty = tv.ty.elemType2();
        if (!elem_ty.hasRuntimeBits()) {
            return GenResult.mcv(.{ .immediate = elem_ty.abiAlignment(target) });
        }
    }

    module.markDeclAlive(decl);

    const is_threadlocal = tv.val.isPtrToThreadLocal(module) and !bin_file.options.single_threaded;

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
        const decl_block_index = try p9.seeDecl(decl_index);
        const decl_block = p9.getDeclBlock(decl_block_index);
        const got_addr = p9.bases.data + decl_block.got_index.? * ptr_bytes;
        return GenResult.mcv(.{ .memory = got_addr });
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
    } else if (bin_file.cast(link.File.Plan9)) |p9| {
        const ptr_bits = target.cpu.arch.ptrBitWidth();
        const ptr_bytes: u64 = @divExact(ptr_bits, 8);
        const got_index = local_sym_index; // the plan9 backend returns the got_index
        const got_addr = p9.bases.data + got_index * ptr_bytes;
        return GenResult.mcv(.{ .memory = got_addr });
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
    var typed_value = arg_tv;
    if (typed_value.val.castTag(.runtime_value)) |rt| {
        typed_value.val = rt.data;
    }

    const mod = bin_file.options.module.?;
    log.debug("genTypedValue: ty = {}, val = {}", .{
        typed_value.ty.fmt(mod),
        typed_value.val.fmtValue(typed_value.ty, mod),
    });

    if (typed_value.val.isUndef())
        return GenResult.mcv(.undef);

    const target = bin_file.options.target;
    const ptr_bits = target.cpu.arch.ptrBitWidth();

    if (!typed_value.ty.isSlice()) {
        if (typed_value.val.castTag(.variable)) |payload| {
            return genDeclRef(bin_file, src_loc, typed_value, payload.data.owner_decl);
        }
        if (typed_value.val.castTag(.decl_ref)) |payload| {
            return genDeclRef(bin_file, src_loc, typed_value, payload.data);
        }
        if (typed_value.val.castTag(.decl_ref_mut)) |payload| {
            return genDeclRef(bin_file, src_loc, typed_value, payload.data.decl_index);
        }
    }

    switch (typed_value.ty.zigTypeTag()) {
        .Void => return GenResult.mcv(.none),
        .Pointer => switch (typed_value.ty.ptrSize()) {
            .Slice => {},
            else => {
                switch (typed_value.val.tag()) {
                    .null_value => {
                        return GenResult.mcv(.{ .immediate = 0 });
                    },
                    .int_u64 => {
                        return GenResult.mcv(.{ .immediate = typed_value.val.toUnsignedInt(target) });
                    },
                    else => {},
                }
            },
        },
        .Int => {
            const info = typed_value.ty.intInfo(target);
            if (info.bits <= ptr_bits) {
                const unsigned = switch (info.signedness) {
                    .signed => @bitCast(u64, typed_value.val.toSignedInt(target)),
                    .unsigned => typed_value.val.toUnsignedInt(target),
                };
                return GenResult.mcv(.{ .immediate = unsigned });
            }
        },
        .Bool => {
            return GenResult.mcv(.{ .immediate = @boolToInt(typed_value.val.toBool()) });
        },
        .Optional => {
            if (typed_value.ty.isPtrLikeOptional()) {
                if (typed_value.val.tag() == .null_value) return GenResult.mcv(.{ .immediate = 0 });

                var buf: Type.Payload.ElemType = undefined;
                return genTypedValue(bin_file, src_loc, .{
                    .ty = typed_value.ty.optionalChild(&buf),
                    .val = if (typed_value.val.castTag(.opt_payload)) |pl| pl.data else typed_value.val,
                }, owner_decl_index);
            } else if (typed_value.ty.abiSize(target) == 1) {
                return GenResult.mcv(.{ .immediate = @boolToInt(!typed_value.val.isNull()) });
            }
        },
        .Enum => {
            if (typed_value.val.castTag(.enum_field_index)) |field_index| {
                switch (typed_value.ty.tag()) {
                    .enum_simple => {
                        return GenResult.mcv(.{ .immediate = field_index.data });
                    },
                    .enum_full, .enum_nonexhaustive => {
                        const enum_full = typed_value.ty.cast(Type.Payload.EnumFull).?.data;
                        if (enum_full.values.count() != 0) {
                            const tag_val = enum_full.values.keys()[field_index.data];
                            return genTypedValue(bin_file, src_loc, .{
                                .ty = enum_full.tag_ty,
                                .val = tag_val,
                            }, owner_decl_index);
                        } else {
                            return GenResult.mcv(.{ .immediate = field_index.data });
                        }
                    },
                    else => unreachable,
                }
            } else {
                var int_tag_buffer: Type.Payload.Bits = undefined;
                const int_tag_ty = typed_value.ty.intTagType(&int_tag_buffer);
                return genTypedValue(bin_file, src_loc, .{
                    .ty = int_tag_ty,
                    .val = typed_value.val,
                }, owner_decl_index);
            }
        },
        .ErrorSet => {
            switch (typed_value.val.tag()) {
                .@"error" => {
                    const err_name = typed_value.val.castTag(.@"error").?.data.name;
                    const module = bin_file.options.module.?;
                    const global_error_set = module.global_error_set;
                    const error_index = global_error_set.get(err_name).?;
                    return GenResult.mcv(.{ .immediate = error_index });
                },
                else => {
                    // In this case we are rendering an error union which has a 0 bits payload.
                    return GenResult.mcv(.{ .immediate = 0 });
                },
            }
        },
        .ErrorUnion => {
            const error_type = typed_value.ty.errorUnionSet();
            const payload_type = typed_value.ty.errorUnionPayload();
            const is_pl = typed_value.val.errorUnionIsPayload();

            if (!payload_type.hasRuntimeBitsIgnoreComptime()) {
                // We use the error type directly as the type.
                const err_val = if (!is_pl) typed_value.val else Value.initTag(.zero);
                return genTypedValue(bin_file, src_loc, .{
                    .ty = error_type,
                    .val = err_val,
                }, owner_decl_index);
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

pub fn errUnionPayloadOffset(payload_ty: Type, target: std.Target) u64 {
    const payload_align = payload_ty.abiAlignment(target);
    const error_align = Type.anyerror.abiAlignment(target);
    if (payload_align >= error_align) {
        return 0;
    } else {
        return mem.alignForwardGeneric(u64, Type.anyerror.abiSize(target), payload_align);
    }
}

pub fn errUnionErrorOffset(payload_ty: Type, target: std.Target) u64 {
    const payload_align = payload_ty.abiAlignment(target);
    const error_align = Type.anyerror.abiAlignment(target);
    if (payload_align >= error_align) {
        return mem.alignForwardGeneric(u64, payload_ty.abiSize(target), error_align);
    } else {
        return 0;
    }
}
