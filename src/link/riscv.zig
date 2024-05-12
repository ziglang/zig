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
    var data = Encoding.Data{
        .U = mem.bytesToValue(std.meta.TagPayload(
            Encoding.Data,
            Encoding.Data.U,
        ), code),
    };
    const compensated: u32 = @bitCast(@as(i32, @bitCast(value)) + 0x800);
    data.U.imm12_31 = bitSlice(compensated, 31, 12);
    mem.writeInt(u32, code, data.toU32(), .little);
}

pub fn writeInstI(code: *[4]u8, value: u32) void {
    var data = Encoding.Data{
        .I = mem.bytesToValue(std.meta.TagPayload(
            Encoding.Data,
            Encoding.Data.I,
        ), code),
    };
    data.I.imm0_11 = bitSlice(value, 11, 0);
    mem.writeInt(u32, code, data.toU32(), .little);
}

pub fn writeInstS(code: *[4]u8, value: u32) void {
    var data = Encoding.Data{
        .S = mem.bytesToValue(std.meta.TagPayload(
            Encoding.Data,
            Encoding.Data.S,
        ), code),
    };
    data.S.imm0_4 = bitSlice(value, 4, 0);
    data.S.imm5_11 = bitSlice(value, 11, 5);
    mem.writeInt(u32, code, data.toU32(), .little);
}

pub fn writeInstJ(code: *[4]u8, value: u32) void {
    var data = Encoding.Data{
        .J = mem.bytesToValue(std.meta.TagPayload(
            Encoding.Data,
            Encoding.Data.J,
        ), code),
    };
    data.J.imm1_10 = bitSlice(value, 10, 1);
    data.J.imm11 = bitSlice(value, 11, 11);
    data.J.imm12_19 = bitSlice(value, 19, 12);
    data.J.imm20 = bitSlice(value, 20, 20);
    mem.writeInt(u32, code, data.toU32(), .little);
}

pub fn writeInstB(code: *[4]u8, value: u32) void {
    var data = Encoding.Data{
        .B = mem.bytesToValue(std.meta.TagPayload(
            Encoding.Data,
            Encoding.Data.B,
        ), code),
    };
    data.B.imm1_4 = bitSlice(value, 4, 1);
    data.B.imm5_10 = bitSlice(value, 10, 5);
    data.B.imm11 = bitSlice(value, 11, 11);
    data.B.imm12 = bitSlice(value, 12, 12);
    mem.writeInt(u32, code, data.toU32(), .little);
}

fn bitSlice(
    value: anytype,
    comptime high: comptime_int,
    comptime low: comptime_int,
) std.math.IntFittingRange(0, 1 << high - low) {
    return @truncate((value >> low) & (1 << (high - low + 1)) - 1);
}

const encoder = @import("../arch/riscv64/encoder.zig");
const Encoding = @import("../arch/riscv64/Encoding.zig");
const mem = std.mem;
const std = @import("std");

pub const Instruction = encoder.Instruction;
