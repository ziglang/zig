const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const leb = std.leb;
const mem = std.mem;

const Module = @import("../Module.zig");
const Decl = Module.Decl;
const Inst = @import("../ir.zig").Inst;
const Type = @import("../type.zig").Type;
const Value = @import("../value.zig").Value;

pub fn genValtype(ty: Type) u8 {
    return switch (ty.tag()) {
        .u32, .i32 => 0x7F,
        .u64, .i64 => 0x7E,
        .f32 => 0x7D,
        .f64 => 0x7C,
        else => @panic("TODO: Implement more types for wasm."),
    };
}

pub const Register = enum(u32) {
    _,

    pub fn allocIndex(self: Register) ?u4 {
        return null;
    }

    /// TODO implement support for DWARF
    pub fn dwarfLocOp(self: Register) u8 {
        return @truncate(u8, @enumToInt(self));
    }
};

/// Wasm doesn't really have registers. For now just create a fake registry with length 100
/// TODO: Allow non-registry based backends
pub const callee_preserved_regs = [_]Register{@intToEnum(Register, 0)} ** 100;
