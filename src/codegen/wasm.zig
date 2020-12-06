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

pub const Register = enum {
    temp,

    pub fn allocIndex(self: Register) ?u4 {
        return null;
    }
};

pub const callee_preserved_regs = [_]Register{};

fn genConstant(buf: *ArrayList(u8), decl: *Decl, inst: *Inst.Constant) !void {
    const writer = buf.writer();
    switch (inst.base.ty.tag()) {
        .u32 => {
            try writer.writeByte(0x41); // i32.const
            try leb.writeILEB128(writer, inst.val.toUnsignedInt());
        },
        .i32 => {
            try writer.writeByte(0x41); // i32.const
            try leb.writeILEB128(writer, inst.val.toSignedInt());
        },
        .u64 => {
            try writer.writeByte(0x42); // i64.const
            try leb.writeILEB128(writer, inst.val.toUnsignedInt());
        },
        .i64 => {
            try writer.writeByte(0x42); // i64.const
            try leb.writeILEB128(writer, inst.val.toSignedInt());
        },
        .f32 => {
            try writer.writeByte(0x43); // f32.const
            // TODO: enforce LE byte order
            try writer.writeAll(mem.asBytes(&inst.val.toFloat(f32)));
        },
        .f64 => {
            try writer.writeByte(0x44); // f64.const
            // TODO: enforce LE byte order
            try writer.writeAll(mem.asBytes(&inst.val.toFloat(f64)));
        },
        .void => {},
        else => return error.TODOImplementMoreWasmCodegen,
    }
}
