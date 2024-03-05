pub inline fn isArithmeticOp(inst: *const [4]u8) bool {
    const group_decode = @as(u5, @truncate(inst[3]));
    return ((group_decode >> 2) == 4);
}

pub const PageOffsetInstKind = enum {
    arithmetic,
    load_store_8,
    load_store_16,
    load_store_32,
    load_store_64,
    load_store_128,
};

pub fn classifyInst(code: *const [4]u8) PageOffsetInstKind {
    if (isArithmeticOp(code)) return .arithmetic;
    const inst = Instruction{
        .load_store_register = mem.bytesToValue(std.meta.TagPayload(
            Instruction,
            Instruction.load_store_register,
        ), code),
    };
    return switch (inst.load_store_register.size) {
        0 => if (inst.load_store_register.v == 1) .load_store_128 else .load_store_8,
        1 => .load_store_16,
        2 => .load_store_32,
        3 => .load_store_64,
    };
}

pub fn calcPageOffset(kind: PageOffsetInstKind, taddr: u64) !u12 {
    const narrowed = @as(u12, @truncate(taddr));
    return switch (kind) {
        .arithmetic, .load_store_8 => narrowed,
        .load_store_16 => try math.divExact(u12, narrowed, 2),
        .load_store_32 => try math.divExact(u12, narrowed, 4),
        .load_store_64 => try math.divExact(u12, narrowed, 8),
        .load_store_128 => try math.divExact(u12, narrowed, 16),
    };
}

pub fn writePageOffset(kind: PageOffsetInstKind, taddr: u64, code: *[4]u8) !void {
    const value = try calcPageOffset(kind, taddr);
    switch (kind) {
        .arithmetic => {
            var inst = Instruction{
                .add_subtract_immediate = mem.bytesToValue(std.meta.TagPayload(
                    Instruction,
                    Instruction.add_subtract_immediate,
                ), code),
            };
            inst.add_subtract_immediate.imm12 = value;
            mem.writeInt(u32, code, inst.toU32(), .little);
        },
        else => {
            var inst: Instruction = .{
                .load_store_register = mem.bytesToValue(std.meta.TagPayload(
                    Instruction,
                    Instruction.load_store_register,
                ), code),
            };
            inst.load_store_register.offset = value;
            mem.writeInt(u32, code, inst.toU32(), .little);
        },
    }
}

pub fn calcNumberOfPages(saddr: u64, taddr: u64) error{Overflow}!i21 {
    const spage = math.cast(i32, saddr >> 12) orelse return error.Overflow;
    const tpage = math.cast(i32, taddr >> 12) orelse return error.Overflow;
    const pages = math.cast(i21, tpage - spage) orelse return error.Overflow;
    return pages;
}

pub fn writePages(pages: u21, code: *[4]u8) !void {
    var inst = Instruction{
        .pc_relative_address = mem.bytesToValue(std.meta.TagPayload(
            Instruction,
            Instruction.pc_relative_address,
        ), code),
    };
    inst.pc_relative_address.immhi = @as(u19, @truncate(pages >> 2));
    inst.pc_relative_address.immlo = @as(u2, @truncate(pages));
    mem.writeInt(u32, code, inst.toU32(), .little);
}

pub fn writeBranchImm(disp: i28, code: *[4]u8) !void {
    var inst = Instruction{
        .unconditional_branch_immediate = mem.bytesToValue(std.meta.TagPayload(
            Instruction,
            Instruction.unconditional_branch_immediate,
        ), code),
    };
    inst.unconditional_branch_immediate.imm26 = @as(u26, @truncate(@as(u28, @bitCast(disp >> 2))));
    mem.writeInt(u32, code, inst.toU32(), .little);
}

const assert = std.debug.assert;
const bits = @import("../arch/aarch64/bits.zig");
const builtin = @import("builtin");
const math = std.math;
const mem = std.mem;
const std = @import("std");

pub const Instruction = bits.Instruction;
pub const Register = bits.Register;
