const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;
const Air = @import("Air.zig");
const Zir = @import("Zir.zig");
const Liveness = @import("Liveness.zig");
const Type = @import("type.zig").Type;
const Value = @import("value.zig").Value;
const TypedValue = @import("TypedValue.zig");
const link = @import("link.zig");
const Module = @import("Module.zig");
const Compilation = @import("Compilation.zig");
const ErrorMsg = Module.ErrorMsg;
const Target = std.Target;
const Allocator = mem.Allocator;
const trace = @import("tracy.zig").trace;
const DW = std.dwarf;
const leb128 = std.leb;
const log = std.log.scoped(.codegen);
const build_options = @import("build_options");
const RegisterManager = @import("register_manager.zig").RegisterManager;

pub const FnResult = union(enum) {
    /// The `code` parameter passed to `generateSymbol` has the value appended.
    appended: void,
    fail: *ErrorMsg,
};
pub const Result = union(enum) {
    /// The `code` parameter passed to `generateSymbol` has the value appended.
    appended: void,
    /// The value is available externally, `code` is unused.
    externally_managed: []const u8,
    fail: *ErrorMsg,
};

pub const GenerateSymbolError = error{
    OutOfMemory,
    Overflow,
    /// A Decl that this symbol depends on had a semantic analysis failure.
    AnalysisFail,
};

pub const DebugInfoOutput = union(enum) {
    dwarf: struct {
        dbg_line: *std.ArrayList(u8),
        dbg_info: *std.ArrayList(u8),
        dbg_info_type_relocs: *link.File.DbgInfoTypeRelocsTable,
    },
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
) GenerateSymbolError!FnResult {
    switch (bin_file.options.target.cpu.arch) {
        .wasm32 => unreachable, // has its own code path
        .wasm64 => unreachable, // has its own code path
        .arm,
        .armeb,
        => return @import("arch/arm/CodeGen.zig").generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        .aarch64,
        .aarch64_be,
        .aarch64_32,
        => return @import("arch/aarch64/CodeGen.zig").generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.arc => return Function(.arc).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.avr => return Function(.avr).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.bpfel => return Function(.bpfel).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.bpfeb => return Function(.bpfeb).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.hexagon => return Function(.hexagon).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.mips => return Function(.mips).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.mipsel => return Function(.mipsel).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.mips64 => return Function(.mips64).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.mips64el => return Function(.mips64el).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.msp430 => return Function(.msp430).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.powerpc => return Function(.powerpc).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.powerpc64 => return Function(.powerpc64).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.powerpc64le => return Function(.powerpc64le).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.r600 => return Function(.r600).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.amdgcn => return Function(.amdgcn).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.riscv32 => return Function(.riscv32).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        .riscv64 => return @import("arch/riscv64/CodeGen.zig").generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.sparc => return Function(.sparc).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.sparcv9 => return Function(.sparcv9).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.sparcel => return Function(.sparcel).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.s390x => return Function(.s390x).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.tce => return Function(.tce).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.tcele => return Function(.tcele).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.thumb => return Function(.thumb).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.thumbeb => return Function(.thumbeb).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.i386 => return Function(.i386).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        .x86_64 => return @import("arch/x86_64/CodeGen.zig").generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.xcore => return Function(.xcore).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.nvptx => return Function(.nvptx).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.nvptx64 => return Function(.nvptx64).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.le32 => return Function(.le32).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.le64 => return Function(.le64).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.amdil => return Function(.amdil).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.amdil64 => return Function(.amdil64).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.hsail => return Function(.hsail).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.hsail64 => return Function(.hsail64).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.spir => return Function(.spir).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.spir64 => return Function(.spir64).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.kalimba => return Function(.kalimba).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.shave => return Function(.shave).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.lanai => return Function(.lanai).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.renderscript32 => return Function(.renderscript32).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.renderscript64 => return Function(.renderscript64).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        //.ve => return Function(.ve).generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        else => @panic("Backend architectures that don't have good support yet are commented out, to improve compilation performance. If you are interested in one of these other backends feel free to uncomment them. Eventually these will be completed, but stage1 is slow and a memory hog."),
    }
}

pub fn generateSymbol(
    bin_file: *link.File,
    parent_atom_index: u32,
    src_loc: Module.SrcLoc,
    typed_value: TypedValue,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
) GenerateSymbolError!Result {
    const tracy = trace(@src());
    defer tracy.end();

    log.debug("generateSymbol: ty = {}, val = {}", .{ typed_value.ty, typed_value.val });

    if (typed_value.val.isUndefDeep()) {
        const target = bin_file.options.target;
        const abi_size = try math.cast(usize, typed_value.ty.abiSize(target));
        try code.appendNTimes(0xaa, abi_size);
        return Result{ .appended = {} };
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
        .Array => switch (typed_value.val.tag()) {
            .bytes => {
                // TODO populate .debug_info for the array
                const payload = typed_value.val.castTag(.bytes).?;
                if (typed_value.ty.sentinel()) |sentinel| {
                    try code.ensureUnusedCapacity(payload.data.len + 1);
                    code.appendSliceAssumeCapacity(payload.data);
                    switch (try generateSymbol(bin_file, parent_atom_index, src_loc, .{
                        .ty = typed_value.ty.elemType(),
                        .val = sentinel,
                    }, code, debug_output)) {
                        .appended => return Result{ .appended = {} },
                        .externally_managed => |slice| {
                            code.appendSliceAssumeCapacity(slice);
                            return Result{ .appended = {} };
                        },
                        .fail => |em| return Result{ .fail = em },
                    }
                } else {
                    return Result{ .externally_managed = payload.data };
                }
            },
            .array => {
                // TODO populate .debug_info for the array
                const elem_vals = typed_value.val.castTag(.array).?.data;
                const elem_ty = typed_value.ty.elemType();
                for (elem_vals) |elem_val| {
                    switch (try generateSymbol(bin_file, parent_atom_index, src_loc, .{
                        .ty = elem_ty,
                        .val = elem_val,
                    }, code, debug_output)) {
                        .appended => {},
                        .externally_managed => |slice| {
                            code.appendSliceAssumeCapacity(slice);
                        },
                        .fail => |em| return Result{ .fail = em },
                    }
                }
                return Result{ .appended = {} };
            },
            .repeated => {
                const array = typed_value.val.castTag(.repeated).?.data;
                const elem_ty = typed_value.ty.childType();
                const sentinel = typed_value.ty.sentinel();
                const len = typed_value.ty.arrayLen();

                var index: u64 = 0;
                while (index < len) : (index += 1) {
                    switch (try generateSymbol(bin_file, parent_atom_index, src_loc, .{
                        .ty = elem_ty,
                        .val = array,
                    }, code, debug_output)) {
                        .appended => {},
                        .externally_managed => |slice| {
                            code.appendSliceAssumeCapacity(slice);
                        },
                        .fail => |em| return Result{ .fail = em },
                    }
                }

                if (sentinel) |sentinel_val| {
                    switch (try generateSymbol(bin_file, parent_atom_index, src_loc, .{
                        .ty = elem_ty,
                        .val = sentinel_val,
                    }, code, debug_output)) {
                        .appended => {},
                        .externally_managed => |slice| {
                            code.appendSliceAssumeCapacity(slice);
                        },
                        .fail => |em| return Result{ .fail = em },
                    }
                }

                return Result{ .appended = {} };
            },
            .empty_array_sentinel => {
                const elem_ty = typed_value.ty.childType();
                const sentinel_val = typed_value.ty.sentinel().?;
                switch (try generateSymbol(bin_file, parent_atom_index, src_loc, .{
                    .ty = elem_ty,
                    .val = sentinel_val,
                }, code, debug_output)) {
                    .appended => {},
                    .externally_managed => |slice| {
                        code.appendSliceAssumeCapacity(slice);
                    },
                    .fail => |em| return Result{ .fail = em },
                }
                return Result{ .appended = {} };
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
            .variable => {
                const decl = typed_value.val.castTag(.variable).?.data.owner_decl;
                return lowerDeclRef(bin_file, parent_atom_index, src_loc, typed_value, decl, code, debug_output);
            },
            .decl_ref => {
                const decl = typed_value.val.castTag(.decl_ref).?.data;
                return lowerDeclRef(bin_file, parent_atom_index, src_loc, typed_value, decl, code, debug_output);
            },
            .slice => {
                const slice = typed_value.val.castTag(.slice).?.data;

                // generate ptr
                var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                const slice_ptr_field_type = typed_value.ty.slicePtrFieldType(&buf);
                switch (try generateSymbol(bin_file, parent_atom_index, src_loc, .{
                    .ty = slice_ptr_field_type,
                    .val = slice.ptr,
                }, code, debug_output)) {
                    .appended => {},
                    .externally_managed => |external_slice| {
                        code.appendSliceAssumeCapacity(external_slice);
                    },
                    .fail => |em| return Result{ .fail = em },
                }

                // generate length
                switch (try generateSymbol(bin_file, parent_atom_index, src_loc, .{
                    .ty = Type.initTag(.usize),
                    .val = slice.len,
                }, code, debug_output)) {
                    .appended => {},
                    .externally_managed => |external_slice| {
                        code.appendSliceAssumeCapacity(external_slice);
                    },
                    .fail => |em| return Result{ .fail = em },
                }

                return Result{ .appended = {} };
            },
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
            // TODO populate .debug_info for the integer
            const endian = bin_file.options.target.cpu.arch.endian();
            const info = typed_value.ty.intInfo(bin_file.options.target);
            if (info.bits <= 8) {
                const x = @intCast(u8, typed_value.val.toUnsignedInt());
                try code.append(x);
                return Result{ .appended = {} };
            }
            if (info.bits > 64) {
                return Result{
                    .fail = try ErrorMsg.create(
                        bin_file.allocator,
                        src_loc,
                        "TODO implement generateSymbol for big ints ('{}')",
                        .{typed_value.ty},
                    ),
                };
            }
            switch (info.signedness) {
                .unsigned => {
                    if (info.bits <= 16) {
                        const x = @intCast(u16, typed_value.val.toUnsignedInt());
                        mem.writeInt(u16, try code.addManyAsArray(2), x, endian);
                    } else if (info.bits <= 32) {
                        const x = @intCast(u32, typed_value.val.toUnsignedInt());
                        mem.writeInt(u32, try code.addManyAsArray(4), x, endian);
                    } else {
                        const x = typed_value.val.toUnsignedInt();
                        mem.writeInt(u64, try code.addManyAsArray(8), x, endian);
                    }
                },
                .signed => {
                    if (info.bits <= 16) {
                        const x = @intCast(i16, typed_value.val.toSignedInt());
                        mem.writeInt(i16, try code.addManyAsArray(2), x, endian);
                    } else if (info.bits <= 32) {
                        const x = @intCast(i32, typed_value.val.toSignedInt());
                        mem.writeInt(i32, try code.addManyAsArray(4), x, endian);
                    } else {
                        const x = typed_value.val.toSignedInt();
                        mem.writeInt(i64, try code.addManyAsArray(8), x, endian);
                    }
                },
            }
            return Result{ .appended = {} };
        },
        .Enum => {
            // TODO populate .debug_info for the enum
            var int_buffer: Value.Payload.U64 = undefined;
            const int_val = typed_value.enumToInt(&int_buffer);

            const target = bin_file.options.target;
            const info = typed_value.ty.intInfo(target);
            if (info.bits <= 8) {
                const x = @intCast(u8, int_val.toUnsignedInt());
                try code.append(x);
                return Result{ .appended = {} };
            }
            if (info.bits > 64) {
                return Result{
                    .fail = try ErrorMsg.create(
                        bin_file.allocator,
                        src_loc,
                        "TODO implement generateSymbol for big int enums ('{}')",
                        .{typed_value.ty},
                    ),
                };
            }
            const endian = target.cpu.arch.endian();
            switch (info.signedness) {
                .unsigned => {
                    if (info.bits <= 16) {
                        const x = @intCast(u16, int_val.toUnsignedInt());
                        mem.writeInt(u16, try code.addManyAsArray(2), x, endian);
                    } else if (info.bits <= 32) {
                        const x = @intCast(u32, int_val.toUnsignedInt());
                        mem.writeInt(u32, try code.addManyAsArray(4), x, endian);
                    } else {
                        const x = int_val.toUnsignedInt();
                        mem.writeInt(u64, try code.addManyAsArray(8), x, endian);
                    }
                },
                .signed => {
                    if (info.bits <= 16) {
                        const x = @intCast(i16, int_val.toSignedInt());
                        mem.writeInt(i16, try code.addManyAsArray(2), x, endian);
                    } else if (info.bits <= 32) {
                        const x = @intCast(i32, int_val.toSignedInt());
                        mem.writeInt(i32, try code.addManyAsArray(4), x, endian);
                    } else {
                        const x = int_val.toSignedInt();
                        mem.writeInt(i64, try code.addManyAsArray(8), x, endian);
                    }
                },
            }
            return Result{ .appended = {} };
        },
        .Bool => {
            const x: u8 = @boolToInt(typed_value.val.toBool());
            try code.append(x);
            return Result{ .appended = {} };
        },
        .Struct => {
            const struct_obj = typed_value.ty.castTag(.@"struct").?.data;
            if (struct_obj.layout == .Packed) {
                return Result{
                    .fail = try ErrorMsg.create(
                        bin_file.allocator,
                        src_loc,
                        "TODO implement generateSymbol for packed struct",
                        .{},
                    ),
                };
            }

            const struct_begin = code.items.len;
            const field_vals = typed_value.val.castTag(.@"struct").?.data;
            for (field_vals) |field_val, index| {
                const field_ty = typed_value.ty.structFieldType(index);
                if (!field_ty.hasRuntimeBits()) continue;

                switch (try generateSymbol(bin_file, parent_atom_index, src_loc, .{
                    .ty = field_ty,
                    .val = field_val,
                }, code, debug_output)) {
                    .appended => {},
                    .externally_managed => |external_slice| {
                        code.appendSliceAssumeCapacity(external_slice);
                    },
                    .fail => |em| return Result{ .fail = em },
                }
                const unpadded_field_end = code.items.len - struct_begin;

                // Pad struct members if required
                const target = bin_file.options.target;
                const padded_field_end = typed_value.ty.structFieldOffset(index + 1, target);
                const padding = try math.cast(usize, padded_field_end - unpadded_field_end);

                if (padding > 0) {
                    try code.writer().writeByteNTimes(0, padding);
                }
            }

            return Result{ .appended = {} };
        },
        .Union => {
            // TODO generateSymbol for unions
            const target = bin_file.options.target;
            const abi_size = try math.cast(usize, typed_value.ty.abiSize(target));
            try code.writer().writeByteNTimes(0xaa, abi_size);

            return Result{ .appended = {} };
        },
        .Optional => {
            // TODO generateSymbol for optionals
            const target = bin_file.options.target;
            const abi_size = try math.cast(usize, typed_value.ty.abiSize(target));
            try code.writer().writeByteNTimes(0xaa, abi_size);

            return Result{ .appended = {} };
        },
        .ErrorUnion => {
            const error_ty = typed_value.ty.errorUnionSet();
            const payload_ty = typed_value.ty.errorUnionPayload();
            const is_payload = typed_value.val.errorUnionIsPayload();

            const target = bin_file.options.target;
            const abi_align = typed_value.ty.abiAlignment(target);

            {
                const error_val = if (!is_payload) typed_value.val else Value.initTag(.zero);
                const begin = code.items.len;
                switch (try generateSymbol(bin_file, parent_atom_index, src_loc, .{
                    .ty = error_ty,
                    .val = error_val,
                }, code, debug_output)) {
                    .appended => {},
                    .externally_managed => |external_slice| {
                        code.appendSliceAssumeCapacity(external_slice);
                    },
                    .fail => |em| return Result{ .fail = em },
                }
                const unpadded_end = code.items.len - begin;
                const padded_end = mem.alignForwardGeneric(u64, unpadded_end, abi_align);
                const padding = try math.cast(usize, padded_end - unpadded_end);

                if (padding > 0) {
                    try code.writer().writeByteNTimes(0, padding);
                }
            }

            if (payload_ty.hasRuntimeBits()) {
                const payload_val = if (typed_value.val.castTag(.eu_payload)) |val| val.data else Value.initTag(.undef);
                const begin = code.items.len;
                switch (try generateSymbol(bin_file, parent_atom_index, src_loc, .{
                    .ty = payload_ty,
                    .val = payload_val,
                }, code, debug_output)) {
                    .appended => {},
                    .externally_managed => |external_slice| {
                        code.appendSliceAssumeCapacity(external_slice);
                    },
                    .fail => |em| return Result{ .fail = em },
                }
                const unpadded_end = code.items.len - begin;
                const padded_end = mem.alignForwardGeneric(u64, unpadded_end, abi_align);
                const padding = try math.cast(usize, padded_end - unpadded_end);

                if (padding > 0) {
                    try code.writer().writeByteNTimes(0, padding);
                }
            }

            return Result{ .appended = {} };
        },
        .ErrorSet => {
            const target = bin_file.options.target;
            switch (typed_value.val.tag()) {
                .@"error" => {
                    const name = typed_value.val.getError().?;
                    const kv = try bin_file.options.module.?.getErrorValue(name);
                    const endian = target.cpu.arch.endian();
                    try code.writer().writeInt(u32, kv.value, endian);
                },
                else => {
                    try code.writer().writeByteNTimes(0, @intCast(usize, typed_value.ty.abiSize(target)));
                },
            }
            return Result{ .appended = {} };
        },
        else => |t| {
            return Result{
                .fail = try ErrorMsg.create(
                    bin_file.allocator,
                    src_loc,
                    "TODO implement generateSymbol for type '{s}'",
                    .{@tagName(t)},
                ),
            };
        },
    }
}

fn lowerDeclRef(
    bin_file: *link.File,
    parent_atom_index: u32,
    src_loc: Module.SrcLoc,
    typed_value: TypedValue,
    decl: *Module.Decl,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
) GenerateSymbolError!Result {
    if (typed_value.ty.isSlice()) {
        // generate ptr
        var buf: Type.SlicePtrFieldTypeBuffer = undefined;
        const slice_ptr_field_type = typed_value.ty.slicePtrFieldType(&buf);
        switch (try generateSymbol(bin_file, parent_atom_index, src_loc, .{
            .ty = slice_ptr_field_type,
            .val = typed_value.val,
        }, code, debug_output)) {
            .appended => {},
            .externally_managed => |external_slice| {
                code.appendSliceAssumeCapacity(external_slice);
            },
            .fail => |em| return Result{ .fail = em },
        }

        // generate length
        var slice_len: Value.Payload.U64 = .{
            .base = .{ .tag = .int_u64 },
            .data = typed_value.val.sliceLen(),
        };
        switch (try generateSymbol(bin_file, parent_atom_index, src_loc, .{
            .ty = Type.initTag(.usize),
            .val = Value.initPayload(&slice_len.base),
        }, code, debug_output)) {
            .appended => {},
            .externally_managed => |external_slice| {
                code.appendSliceAssumeCapacity(external_slice);
            },
            .fail => |em| return Result{ .fail = em },
        }

        return Result{ .appended = {} };
    }

    const target = bin_file.options.target;
    const ptr_width = target.cpu.arch.ptrBitWidth();
    const is_fn_body = decl.ty.zigTypeTag() == .Fn;
    if (!is_fn_body and !decl.ty.hasRuntimeBits()) {
        try code.writer().writeByteNTimes(0xaa, @divExact(ptr_width, 8));
        return Result{ .appended = {} };
    }

    decl.markAlive();
    const vaddr = try bin_file.getDeclVAddr(decl, parent_atom_index, code.items.len);
    const endian = target.cpu.arch.endian();
    switch (ptr_width) {
        16 => mem.writeInt(u16, try code.addManyAsArray(2), @intCast(u16, vaddr), endian),
        32 => mem.writeInt(u32, try code.addManyAsArray(4), @intCast(u32, vaddr), endian),
        64 => mem.writeInt(u64, try code.addManyAsArray(8), vaddr, endian),
        else => unreachable,
    }

    return Result{ .appended = {} };
}
