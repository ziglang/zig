const std = @import("std");
const aarch64 = @import("../../arch/aarch64/bits.zig");

const Relocation = @import("Relocation.zig");

pub inline fn calcStubHelperPreambleSize(cpu_arch: std.Target.Cpu.Arch) u5 {
    return switch (cpu_arch) {
        .x86_64 => 15,
        .aarch64 => 6 * @sizeOf(u32),
        else => unreachable, // unhandled architecture type
    };
}

pub inline fn calcStubHelperEntrySize(cpu_arch: std.Target.Cpu.Arch) u4 {
    return switch (cpu_arch) {
        .x86_64 => 10,
        .aarch64 => 3 * @sizeOf(u32),
        else => unreachable, // unhandled architecture type
    };
}

pub inline fn calcStubEntrySize(cpu_arch: std.Target.Cpu.Arch) u4 {
    return switch (cpu_arch) {
        .x86_64 => 6,
        .aarch64 => 3 * @sizeOf(u32),
        else => unreachable, // unhandled architecture type
    };
}

pub inline fn calcStubOffsetInStubHelper(cpu_arch: std.Target.Cpu.Arch) u4 {
    return switch (cpu_arch) {
        .x86_64 => 1,
        .aarch64 => 2 * @sizeOf(u32),
        else => unreachable,
    };
}

pub fn writeStubHelperPreambleCode(args: struct {
    cpu_arch: std.Target.Cpu.Arch,
    source_addr: u64,
    dyld_private_addr: u64,
    dyld_stub_binder_got_addr: u64,
}, writer: anytype) !void {
    switch (args.cpu_arch) {
        .x86_64 => {
            try writer.writeAll(&.{ 0x4c, 0x8d, 0x1d });
            {
                const disp = try Relocation.calcPcRelativeDisplacementX86(
                    args.source_addr + 3,
                    args.dyld_private_addr,
                    0,
                );
                try writer.writeIntLittle(i32, disp);
            }
            try writer.writeAll(&.{ 0x41, 0x53, 0xff, 0x25 });
            {
                const disp = try Relocation.calcPcRelativeDisplacementX86(
                    args.source_addr + 11,
                    args.dyld_stub_binder_got_addr,
                    0,
                );
                try writer.writeIntLittle(i32, disp);
            }
        },
        .aarch64 => {
            {
                const pages = Relocation.calcNumberOfPages(args.source_addr, args.dyld_private_addr);
                try writer.writeIntLittle(u32, aarch64.Instruction.adrp(.x17, pages).toU32());
            }
            {
                const off = try Relocation.calcPageOffset(args.dyld_private_addr, .arithmetic);
                try writer.writeIntLittle(u32, aarch64.Instruction.add(.x17, .x17, off, false).toU32());
            }
            try writer.writeIntLittle(u32, aarch64.Instruction.stp(
                .x16,
                .x17,
                aarch64.Register.sp,
                aarch64.Instruction.LoadStorePairOffset.pre_index(-16),
            ).toU32());
            {
                const pages = Relocation.calcNumberOfPages(args.source_addr + 12, args.dyld_stub_binder_got_addr);
                try writer.writeIntLittle(u32, aarch64.Instruction.adrp(.x16, pages).toU32());
            }
            {
                const off = try Relocation.calcPageOffset(args.dyld_stub_binder_got_addr, .load_store_64);
                try writer.writeIntLittle(u32, aarch64.Instruction.ldr(
                    .x16,
                    .x16,
                    aarch64.Instruction.LoadStoreOffset.imm(off),
                ).toU32());
            }
            try writer.writeIntLittle(u32, aarch64.Instruction.br(.x16).toU32());
        },
        else => unreachable,
    }
}

pub fn writeStubHelperCode(args: struct {
    cpu_arch: std.Target.Cpu.Arch,
    source_addr: u64,
    target_addr: u64,
}, writer: anytype) !void {
    switch (args.cpu_arch) {
        .x86_64 => {
            try writer.writeAll(&.{ 0x68, 0x0, 0x0, 0x0, 0x0, 0xe9 });
            {
                const disp = try Relocation.calcPcRelativeDisplacementX86(args.source_addr + 6, args.target_addr, 0);
                try writer.writeIntLittle(i32, disp);
            }
        },
        .aarch64 => {
            const stub_size: u4 = 3 * @sizeOf(u32);
            const literal = blk: {
                const div_res = try std.math.divExact(u64, stub_size - @sizeOf(u32), 4);
                break :blk std.math.cast(u18, div_res) orelse return error.Overflow;
            };
            try writer.writeIntLittle(u32, aarch64.Instruction.ldrLiteral(
                .w16,
                literal,
            ).toU32());
            {
                const disp = try Relocation.calcPcRelativeDisplacementArm64(args.source_addr + 4, args.target_addr);
                try writer.writeIntLittle(u32, aarch64.Instruction.b(disp).toU32());
            }
            try writer.writeAll(&.{ 0x0, 0x0, 0x0, 0x0 });
        },
        else => unreachable,
    }
}

pub fn writeStubCode(args: struct {
    cpu_arch: std.Target.Cpu.Arch,
    source_addr: u64,
    target_addr: u64,
}, writer: anytype) !void {
    switch (args.cpu_arch) {
        .x86_64 => {
            try writer.writeAll(&.{ 0xff, 0x25 });
            {
                const disp = try Relocation.calcPcRelativeDisplacementX86(args.source_addr + 2, args.target_addr, 0);
                try writer.writeIntLittle(i32, disp);
            }
        },
        .aarch64 => {
            {
                const pages = Relocation.calcNumberOfPages(args.source_addr, args.target_addr);
                try writer.writeIntLittle(u32, aarch64.Instruction.adrp(.x16, pages).toU32());
            }
            {
                const off = try Relocation.calcPageOffset(args.target_addr, .load_store_64);
                try writer.writeIntLittle(u32, aarch64.Instruction.ldr(
                    .x16,
                    .x16,
                    aarch64.Instruction.LoadStoreOffset.imm(off),
                ).toU32());
            }
            try writer.writeIntLittle(u32, aarch64.Instruction.br(.x16).toU32());
        },
        else => unreachable,
    }
}
