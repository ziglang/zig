pub fn writeSetSub6(comptime op: enum { set, sub }, code: *[1]u8, addend: anytype) void {
    const mask: u8 = 0b11_000000;
    const actual: i8 = @truncate(addend);
    var value: u8 = mem.readInt(u8, code, .little);
    switch (op) {
        .set => value = (value & mask) | @as(u8, @bitCast(actual & ~mask)),
        .sub => value = (value & mask) | (@as(u8, @bitCast(@as(i8, @bitCast(value)) -| actual)) & ~mask),
    }
    mem.writeInt(u8, code, value, .little);
}

pub fn writeAddend(
    comptime Int: type,
    comptime op: enum { add, sub },
    code: *[@typeInfo(Int).Int.bits / 8]u8,
    value: anytype,
) void {
    var V: Int = mem.readInt(Int, code, .little);
    const addend: Int = @truncate(value);
    switch (op) {
        .add => V +|= addend, // TODO: I think saturating arithmetic is correct here
        .sub => V -|= addend,
    }
    mem.writeInt(Int, code, V, .little);
}

pub fn writeInstU(code: *[4]u8, value: u32) void {
    var inst = Instruction{
        .U = mem.bytesToValue(std.meta.TagPayload(
            Instruction,
            Instruction.U,
        ), code),
    };
    const compensated: u32 = @bitCast(@as(i32, @bitCast(value)) + 0x800);
    inst.U.imm12_31 = bitSlice(compensated, 31, 12);
    mem.writeInt(u32, code, inst.toU32(), .little);
}

pub fn writeInstI(code: *[4]u8, value: u32) void {
    var inst = Instruction{
        .I = mem.bytesToValue(std.meta.TagPayload(
            Instruction,
            Instruction.I,
        ), code),
    };
    inst.I.imm0_11 = bitSlice(value, 11, 0);
    mem.writeInt(u32, code, inst.toU32(), .little);
}

pub fn writeInstS(code: *[4]u8, value: u32) void {
    var inst = Instruction{
        .S = mem.bytesToValue(std.meta.TagPayload(
            Instruction,
            Instruction.S,
        ), code),
    };
    inst.S.imm0_4 = bitSlice(value, 4, 0);
    inst.S.imm5_11 = bitSlice(value, 11, 5);
    mem.writeInt(u32, code, inst.toU32(), .little);
}

fn bitSlice(
    value: anytype,
    comptime high: comptime_int,
    comptime low: comptime_int,
) std.math.IntFittingRange(0, 1 << high - low) {
    return @truncate((value >> low) & (1 << (high - low + 1)) - 1);
}

const bits = @import("../arch/riscv64/bits.zig");
const mem = std.mem;
const std = @import("std");

pub const Instruction = bits.Instruction;
