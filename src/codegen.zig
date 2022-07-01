const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
const leb128 = std.leb;
const link = @import("link.zig");
const log = std.log.scoped(.codegen);
const mem = std.mem;
const math = std.math;
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
) GenerateSymbolError!FnResult {
    switch (bin_file.options.target.cpu.arch) {
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
        .sparc64 => return @import("arch/sparc64/CodeGen.zig").generate(bin_file, src_loc, func, air, liveness, code, debug_output),
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
        .wasm32,
        .wasm64,
        => return @import("arch/wasm/CodeGen.zig").generate(bin_file, src_loc, func, air, liveness, code, debug_output),
        else => @panic("Backend architectures that don't have good support yet are commented out, to improve compilation performance. If you are interested in one of these other backends feel free to uncomment them. Eventually these will be completed, but stage1 is slow and a memory hog."),
    }
}

fn writeFloat(comptime F: type, f: F, target: Target, endian: std.builtin.Endian, code: []u8) void {
    _ = target;
    const Int = @Type(.{ .Int = .{
        .signedness = .unsigned,
        .bits = @typeInfo(F).Float.bits,
    } });
    const int = @bitCast(Int, f);
    mem.writeInt(Int, code[0..@sizeOf(Int)], int, endian);
}

pub fn generateSymbol(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    typed_value: TypedValue,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
    reloc_info: RelocInfo,
) GenerateSymbolError!Result {
    const tracy = trace(@src());
    defer tracy.end();

    const target = bin_file.options.target;
    const endian = target.cpu.arch.endian();

    log.debug("generateSymbol: ty = {}, val = {}", .{
        typed_value.ty.fmtDebug(),
        typed_value.val.fmtDebug(),
    });

    if (typed_value.val.isUndefDeep()) {
        const abi_size = math.cast(usize, typed_value.ty.abiSize(target)) orelse return error.Overflow;
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
        .Float => {
            const float_bits = typed_value.ty.floatBits(target);
            switch (float_bits) {
                16 => writeFloat(f16, typed_value.val.toFloat(f16), target, endian, try code.addManyAsArray(2)),
                32 => writeFloat(f32, typed_value.val.toFloat(f32), target, endian, try code.addManyAsArray(4)),
                64 => writeFloat(f64, typed_value.val.toFloat(f64), target, endian, try code.addManyAsArray(8)),
                80 => return Result{
                    .fail = try ErrorMsg.create(
                        bin_file.allocator,
                        src_loc,
                        "TODO handle f80 in generateSymbol",
                        .{},
                    ),
                },
                128 => writeFloat(f128, typed_value.val.toFloat(f128), target, endian, try code.addManyAsArray(16)),
                else => unreachable,
            }
            return Result{ .appended = {} };
        },
        .Array => switch (typed_value.val.tag()) {
            .bytes => {
                const bytes = typed_value.val.castTag(.bytes).?.data;
                const len = @intCast(usize, typed_value.ty.arrayLenIncludingSentinel());
                // The bytes payload already includes the sentinel, if any
                try code.ensureUnusedCapacity(len);
                code.appendSliceAssumeCapacity(bytes[0..len]);
                return Result{ .appended = {} };
            },
            .str_lit => {
                const str_lit = typed_value.val.castTag(.str_lit).?.data;
                const mod = bin_file.options.module.?;
                const bytes = mod.string_literal_bytes.items[str_lit.index..][0..str_lit.len];
                try code.ensureUnusedCapacity(bytes.len + 1);
                code.appendSliceAssumeCapacity(bytes);
                if (typed_value.ty.sentinel()) |sent_val| {
                    const byte = @intCast(u8, sent_val.toUnsignedInt(target));
                    code.appendAssumeCapacity(byte);
                }
                return Result{ .appended = {} };
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
                    switch (try generateSymbol(bin_file, src_loc, .{
                        .ty = elem_ty,
                        .val = array,
                    }, code, debug_output, reloc_info)) {
                        .appended => {},
                        .externally_managed => |slice| {
                            code.appendSliceAssumeCapacity(slice);
                        },
                        .fail => |em| return Result{ .fail = em },
                    }
                }

                if (sentinel) |sentinel_val| {
                    switch (try generateSymbol(bin_file, src_loc, .{
                        .ty = elem_ty,
                        .val = sentinel_val,
                    }, code, debug_output, reloc_info)) {
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
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = elem_ty,
                    .val = sentinel_val,
                }, code, debug_output, reloc_info)) {
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
                return Result{ .appended = {} };
            },
            .variable => {
                const decl = typed_value.val.castTag(.variable).?.data.owner_decl;
                return lowerDeclRef(bin_file, src_loc, typed_value, decl, code, debug_output, reloc_info);
            },
            .decl_ref => {
                const decl = typed_value.val.castTag(.decl_ref).?.data;
                return lowerDeclRef(bin_file, src_loc, typed_value, decl, code, debug_output, reloc_info);
            },
            .slice => {
                const slice = typed_value.val.castTag(.slice).?.data;

                // generate ptr
                var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                const slice_ptr_field_type = typed_value.ty.slicePtrFieldType(&buf);
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = slice_ptr_field_type,
                    .val = slice.ptr,
                }, code, debug_output, reloc_info)) {
                    .appended => {},
                    .externally_managed => |external_slice| {
                        code.appendSliceAssumeCapacity(external_slice);
                    },
                    .fail => |em| return Result{ .fail = em },
                }

                // generate length
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = Type.initTag(.usize),
                    .val = slice.len,
                }, code, debug_output, reloc_info)) {
                    .appended => {},
                    .externally_managed => |external_slice| {
                        code.appendSliceAssumeCapacity(external_slice);
                    },
                    .fail => |em| return Result{ .fail = em },
                }

                return Result{ .appended = {} };
            },
            .field_ptr => {
                const field_ptr = typed_value.val.castTag(.field_ptr).?.data;
                const container_ptr = field_ptr.container_ptr;

                switch (container_ptr.tag()) {
                    .decl_ref => {
                        const decl_index = container_ptr.castTag(.decl_ref).?.data;
                        const mod = bin_file.options.module.?;
                        const decl = mod.declPtr(decl_index);
                        const addend = blk: {
                            switch (decl.ty.tag()) {
                                .@"struct" => {
                                    const addend = decl.ty.structFieldOffset(field_ptr.field_index, target);
                                    break :blk @intCast(u32, addend);
                                },
                                else => return Result{
                                    .fail = try ErrorMsg.create(
                                        bin_file.allocator,
                                        src_loc,
                                        "TODO implement generateSymbol for pointer type value: '{s}'",
                                        .{@tagName(typed_value.val.tag())},
                                    ),
                                },
                            }
                        };
                        return lowerDeclRef(bin_file, src_loc, typed_value, decl_index, code, debug_output, .{
                            .parent_atom_index = reloc_info.parent_atom_index,
                            .addend = (reloc_info.addend orelse 0) + addend,
                        });
                    },
                    .field_ptr => {
                        switch (try generateSymbol(bin_file, src_loc, .{
                            .ty = typed_value.ty,
                            .val = container_ptr,
                        }, code, debug_output, reloc_info)) {
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
                }
            },
            .elem_ptr => {
                const elem_ptr = typed_value.val.castTag(.elem_ptr).?.data;
                const elem_size = typed_value.ty.childType().abiSize(target);
                const addend = @intCast(u32, elem_ptr.index * elem_size);
                const array_ptr = elem_ptr.array_ptr;

                switch (array_ptr.tag()) {
                    .decl_ref => {
                        const decl_index = array_ptr.castTag(.decl_ref).?.data;
                        return lowerDeclRef(bin_file, src_loc, typed_value, decl_index, code, debug_output, .{
                            .parent_atom_index = reloc_info.parent_atom_index,
                            .addend = (reloc_info.addend orelse 0) + addend,
                        });
                    },
                    else => return Result{
                        .fail = try ErrorMsg.create(
                            bin_file.allocator,
                            src_loc,
                            "TODO implement generateSymbol for pointer type value: '{s}'",
                            .{@tagName(typed_value.val.tag())},
                        ),
                    },
                }
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
            const info = typed_value.ty.intInfo(target);
            if (info.bits <= 8) {
                const x: u8 = switch (info.signedness) {
                    .unsigned => @intCast(u8, typed_value.val.toUnsignedInt(target)),
                    .signed => @bitCast(u8, @intCast(i8, typed_value.val.toSignedInt())),
                };
                try code.append(x);
                return Result{ .appended = {} };
            }
            if (info.bits > 64) {
                var bigint_buffer: Value.BigIntSpace = undefined;
                const bigint = typed_value.val.toBigInt(&bigint_buffer, target);
                const abi_size = math.cast(usize, typed_value.ty.abiSize(target)) orelse return error.Overflow;
                const start = code.items.len;
                try code.resize(start + abi_size);
                bigint.writeTwosComplement(code.items[start..][0..abi_size], info.bits, abi_size, endian);
                return Result{ .appended = {} };
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
            var int_buffer: Value.Payload.U64 = undefined;
            const int_val = typed_value.enumToInt(&int_buffer);

            const info = typed_value.ty.intInfo(target);
            if (info.bits <= 8) {
                const x = @intCast(u8, int_val.toUnsignedInt(target));
                try code.append(x);
                return Result{ .appended = {} };
            }
            if (info.bits > 64) {
                return Result{
                    .fail = try ErrorMsg.create(
                        bin_file.allocator,
                        src_loc,
                        "TODO implement generateSymbol for big int enums ('{}')",
                        .{typed_value.ty.fmtDebug()},
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
            if (typed_value.ty.containerLayout() == .Packed) {
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
            const field_vals = typed_value.val.castTag(.aggregate).?.data;
            for (field_vals) |field_val, index| {
                const field_ty = typed_value.ty.structFieldType(index);
                if (!field_ty.hasRuntimeBits()) continue;

                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = field_ty,
                    .val = field_val,
                }, code, debug_output, reloc_info)) {
                    .appended => {},
                    .externally_managed => |external_slice| {
                        code.appendSliceAssumeCapacity(external_slice);
                    },
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

            return Result{ .appended = {} };
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
                    .appended => {},
                    .externally_managed => |external_slice| {
                        code.appendSliceAssumeCapacity(external_slice);
                    },
                    .fail => |em| return Result{ .fail = em },
                }
            }

            const union_ty = typed_value.ty.cast(Type.Payload.Union).?.data;
            const mod = bin_file.options.module.?;
            const field_index = union_ty.tag_ty.enumTagFieldIndex(union_obj.tag, mod).?;
            assert(union_ty.haveFieldTypes());
            const field_ty = union_ty.fields.values()[field_index].ty;
            if (!field_ty.hasRuntimeBits()) {
                try code.writer().writeByteNTimes(0xaa, math.cast(usize, layout.payload_size) orelse return error.Overflow);
            } else {
                switch (try generateSymbol(bin_file, src_loc, .{
                    .ty = field_ty,
                    .val = union_obj.val,
                }, code, debug_output, reloc_info)) {
                    .appended => {},
                    .externally_managed => |external_slice| {
                        code.appendSliceAssumeCapacity(external_slice);
                    },
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
                    .appended => {},
                    .externally_managed => |external_slice| {
                        code.appendSliceAssumeCapacity(external_slice);
                    },
                    .fail => |em| return Result{ .fail = em },
                }
            }

            return Result{ .appended = {} };
        },
        .Optional => {
            var opt_buf: Type.Payload.ElemType = undefined;
            const payload_type = typed_value.ty.optionalChild(&opt_buf);
            const is_pl = !typed_value.val.isNull();
            const abi_size = math.cast(usize, typed_value.ty.abiSize(target)) orelse return error.Overflow;
            const offset = abi_size - (math.cast(usize, payload_type.abiSize(target)) orelse return error.Overflow);

            if (!payload_type.hasRuntimeBits()) {
                try code.writer().writeByteNTimes(@boolToInt(is_pl), abi_size);
                return Result{ .appended = {} };
            }

            if (typed_value.ty.optionalReprIsPayload()) {
                if (typed_value.val.castTag(.opt_payload)) |payload| {
                    switch (try generateSymbol(bin_file, src_loc, .{
                        .ty = payload_type,
                        .val = payload.data,
                    }, code, debug_output, reloc_info)) {
                        .appended => {},
                        .externally_managed => |external_slice| {
                            code.appendSliceAssumeCapacity(external_slice);
                        },
                        .fail => |em| return Result{ .fail = em },
                    }
                } else if (!typed_value.val.isNull()) {
                    switch (try generateSymbol(bin_file, src_loc, .{
                        .ty = payload_type,
                        .val = typed_value.val,
                    }, code, debug_output, reloc_info)) {
                        .appended => {},
                        .externally_managed => |external_slice| {
                            code.appendSliceAssumeCapacity(external_slice);
                        },
                        .fail => |em| return Result{ .fail = em },
                    }
                } else {
                    try code.writer().writeByteNTimes(0, abi_size);
                }

                return Result{ .appended = {} };
            }

            const value = if (typed_value.val.castTag(.opt_payload)) |payload| payload.data else Value.initTag(.undef);
            try code.writer().writeByteNTimes(@boolToInt(is_pl), offset);
            switch (try generateSymbol(bin_file, src_loc, .{
                .ty = payload_type,
                .val = value,
            }, code, debug_output, reloc_info)) {
                .appended => {},
                .externally_managed => |external_slice| {
                    code.appendSliceAssumeCapacity(external_slice);
                },
                .fail => |em| return Result{ .fail = em },
            }

            return Result{ .appended = {} };
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
                    .appended => {},
                    .externally_managed => |external_slice| {
                        code.appendSliceAssumeCapacity(external_slice);
                    },
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
                    .appended => {},
                    .externally_managed => |external_slice| {
                        code.appendSliceAssumeCapacity(external_slice);
                    },
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
                    .appended => {},
                    .externally_managed => |external_slice| {
                        code.appendSliceAssumeCapacity(external_slice);
                    },
                    .fail => |em| return Result{ .fail = em },
                }
                const unpadded_end = code.items.len - begin;
                const padded_end = mem.alignForwardGeneric(u64, unpadded_end, abi_align);
                const padding = math.cast(usize, padded_end - unpadded_end) orelse return error.Overflow;

                if (padding > 0) {
                    try code.writer().writeByteNTimes(0, padding);
                }
            }

            return Result{ .appended = {} };
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

const RelocInfo = struct {
    parent_atom_index: u32,
    addend: ?u32 = null,
};

fn lowerDeclRef(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    typed_value: TypedValue,
    decl_index: Module.Decl.Index,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
    reloc_info: RelocInfo,
) GenerateSymbolError!Result {
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
            .appended => {},
            .externally_managed => |external_slice| {
                code.appendSliceAssumeCapacity(external_slice);
            },
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
            .appended => {},
            .externally_managed => |external_slice| {
                code.appendSliceAssumeCapacity(external_slice);
            },
            .fail => |em| return Result{ .fail = em },
        }

        return Result{ .appended = {} };
    }

    const ptr_width = target.cpu.arch.ptrBitWidth();
    const decl = module.declPtr(decl_index);
    const is_fn_body = decl.ty.zigTypeTag() == .Fn;
    if (!is_fn_body and !decl.ty.hasRuntimeBits()) {
        try code.writer().writeByteNTimes(0xaa, @divExact(ptr_width, 8));
        return Result{ .appended = {} };
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

    return Result{ .appended = {} };
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
