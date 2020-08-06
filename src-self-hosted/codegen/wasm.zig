const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const leb = std.debug.leb;

const Decl = @import("../Module.zig").Decl;
const Type = @import("../type.zig").Type;

fn genValtype(ty: Type) u8 {
    return switch (ty.tag()) {
        .u32, .i32 => 0x7F,
        .u64, .i64 => 0x7E,
        .f32 => 0x7D,
        .f64 => 0x7C,
        else => @panic("TODO: Implement more types for wasm."),
    };
}

pub fn genFunctype(buf: *ArrayList(u8), decl: *Decl) !void {
    const ty = decl.typed_value.most_recent.typed_value.ty;
    const writer = buf.writer();

    // functype magic
    try writer.writeByte(0x60);

    // param types
    try leb.writeULEB128(writer, @intCast(u32, ty.fnParamLen()));
    if (ty.fnParamLen() != 0) {
        const params = try buf.allocator.alloc(Type, ty.fnParamLen());
        defer buf.allocator.free(params);
        ty.fnParamTypes(params);
        for (params) |param_type| try writer.writeByte(genValtype(param_type));
    }

    // return type
    const return_type = ty.fnReturnType();
    switch (return_type.tag()) {
        .void, .noreturn => try leb.writeULEB128(writer, @as(u32, 0)),
        else => {
            try leb.writeULEB128(writer, @as(u32, 1));
            try writer.writeByte(genValtype(return_type));
        },
    }
}

pub fn genCode(buf: *ArrayList(u8), decl: *Decl) !void {
    assert(buf.items.len == 0);
    const writer = buf.writer();

    // Reserve space to write the size after generating the code
    try writer.writeAll(&([1]u8{undefined} ** 5));

    // Write the size of the locals vec
    // TODO: implement locals
    try leb.writeULEB128(writer, @as(u32, 0));

    // Write instructions

    // TODO: actually implement codegen
    try writer.writeByte(0x41); // i32.const
    try leb.writeILEB128(writer, @as(i32, 42));

    // Write 'end' opcode
    try writer.writeByte(0x0B);

    // Fill in the size of the generated code to the reserved space at the
    // beginning of the buffer.
    leb.writeUnsignedFixed(5, buf.items[0..5], @intCast(u32, buf.items.len - 5));
}
