pub const encoding = @import("../codegen.zig").aarch64.encoding;

pub fn writeAddImmInst(value: u12, code: *[4]u8) void {
    var inst: encoding.Instruction = .read(code);
    inst.data_processing_immediate.add_subtract_immediate.group.imm12 = value;
    inst.write(code);
}

pub fn writeLoadStoreRegInst(value: u12, code: *[4]u8) void {
    var inst: encoding.Instruction = .read(code);
    inst.load_store.register_unsigned_immediate.group.imm12 = value;
    inst.write(code);
}

pub fn calcNumberOfPages(saddr: i64, taddr: i64) error{Overflow}!i33 {
    return math.cast(i21, (taddr >> 12) - (saddr >> 12)) orelse error.Overflow;
}

pub fn writeAdrInst(imm: i33, code: *[4]u8) void {
    var inst: encoding.Instruction = .read(code);
    inst.data_processing_immediate.pc_relative_addressing.group.immhi = @intCast(imm >> 2);
    inst.data_processing_immediate.pc_relative_addressing.group.immlo = @bitCast(@as(i2, @truncate(imm)));
    inst.write(code);
}

pub fn writeBranchImm(disp: i28, code: *[4]u8) void {
    var inst: encoding.Instruction = .read(code);
    inst.branch_exception_generating_system.unconditional_branch_immediate.group.imm26 = @intCast(@shrExact(disp, 2));
    inst.write(code);
}

const assert = std.debug.assert;
const builtin = @import("builtin");
const math = std.math;
const mem = std.mem;
const std = @import("std");
