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
    src_loc: Module.SrcLoc,
    typed_value: TypedValue,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
) GenerateSymbolError!Result {
    const tracy = trace(@src());
    defer tracy.end();

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
        .Array => {
            // TODO populate .debug_info for the array
            if (typed_value.val.castTag(.bytes)) |payload| {
                if (typed_value.ty.sentinel()) |sentinel| {
                    try code.ensureUnusedCapacity(payload.data.len + 1);
                    code.appendSliceAssumeCapacity(payload.data);
                    switch (try generateSymbol(bin_file, src_loc, .{
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
            }
            return Result{
                .fail = try ErrorMsg.create(
                    bin_file.allocator,
                    src_loc,
                    "TODO implement generateSymbol for more kinds of arrays",
                    .{},
                ),
            };
        },
        .Pointer => switch (typed_value.ty.ptrSize()) {
            .Slice => {
                return Result{
                    .fail = try ErrorMsg.create(
                        bin_file.allocator,
                        src_loc,
                        "TODO implement generateSymbol for slice {}",
                        .{typed_value.val},
                    ),
                };
            },
            else => {
                // TODO populate .debug_info for the pointer
                if (typed_value.val.castTag(.decl_ref)) |payload| {
                    const decl = payload.data;
                    if (decl.analysis != .complete) return error.AnalysisFail;
                    decl.alive = true;
                    // TODO handle the dependency of this symbol on the decl's vaddr.
                    // If the decl changes vaddr, then this symbol needs to get regenerated.
                    const vaddr = bin_file.getDeclVAddr(decl);
                    const endian = bin_file.options.target.cpu.arch.endian();
                    switch (bin_file.options.target.cpu.arch.ptrBitWidth()) {
                        16 => {
                            try code.resize(2);
                            mem.writeInt(u16, code.items[0..2], @intCast(u16, vaddr), endian);
                        },
                        32 => {
                            try code.resize(4);
                            mem.writeInt(u32, code.items[0..4], @intCast(u32, vaddr), endian);
                        },
                        64 => {
                            try code.resize(8);
                            mem.writeInt(u64, code.items[0..8], vaddr, endian);
                        },
                        else => unreachable,
                    }
                    return Result{ .appended = {} };
                }
                return Result{
                    .fail = try ErrorMsg.create(
                        bin_file.allocator,
                        src_loc,
                        "TODO implement generateSymbol for pointer {}",
                        .{typed_value.val},
                    ),
                };
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
        .Struct => {
            const field_vals = typed_value.val.castTag(.@"struct").?.data;
            _ = field_vals; // TODO write the fields for real
            const target = bin_file.options.target;
            try code.writer().writeByteNTimes(0xaa, typed_value.ty.abiSize(target));
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
