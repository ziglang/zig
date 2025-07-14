const std = @import("std");
const mem = std.mem;

pub fn page(val: u64) u64 {
    return val & ~0xfff;
}

pub fn hi20(val: u64, pc: u64) i20 {
    return @bitCast(@as(i20, @truncate((@as(i64, @intCast(val)) - @as(i64, @intCast(pc)) + 0x800) >> 12)));
}

pub fn lo12(val: u64, pc: u64) i12 {
    return @bitCast(@as(i12, @truncate((@as(i64, @intCast(val)) - @as(i64, @intCast(pc))) & 0xfff)));
}

pub fn notZero(val: anytype) ?@TypeOf(val) {
    return if (val != 0) val else null;
}

pub const ImmOffset = enum(u5) {
    d = 0,
    j = 5,
    k = 10,
    a = 15,
    m = 16,
    n = 18,

    pub inline fn offset(off: ImmOffset) u5 {
        return @intFromEnum(off);
    }
};

pub fn relocImm(inst: u32, comptime slot: ImmOffset, T: type, val: T) u32 {
    const uT = std.meta.Int(.unsigned, @bitSizeOf(T));
    const off = slot.offset();
    const slot_size: u5 = @intCast(@typeInfo(T).int.bits);
    const mask: u32 = (~((@as(u32, 1) << (off + slot_size)) - 1)) | ((1 << off) - 1);
    const val_u32: u32 = @as(uT, @bitCast(val));
    return (inst & mask) | (val_u32 << off);
}
