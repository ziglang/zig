const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const leb = std.debug.leb;
const mem = std.mem;

const Decl = @import("../Module.zig").Decl;
const Inst = @import("../ir.zig").Inst;
const Type = @import("../type.zig").Type;
const Value = @import("../value.zig").Value;

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
    // TODO: check for and handle death of instructions
    const tv = decl.typed_value.most_recent.typed_value;
    const mod_fn = tv.val.cast(Value.Payload.Function).?.func;
    for (mod_fn.analysis.success.instructions) |inst| try genInst(writer, inst);

    // Write 'end' opcode
    try writer.writeByte(0x0B);

    // Fill in the size of the generated code to the reserved space at the
    // beginning of the buffer.
    leb.writeUnsignedFixed(5, buf.items[0..5], @intCast(u32, buf.items.len - 5));
}

fn genInst(writer: ArrayList(u8).Writer, inst: *Inst) !void {
    return switch (inst.tag) {
        .dbg_stmt => {},
        .ret => genRet(writer, inst.castTag(.ret).?),
        else => error.TODOImplementMoreWasmCodegen,
    };
}

fn genRet(writer: ArrayList(u8).Writer, inst: *Inst.UnOp) !void {
    switch (inst.operand.tag) {
        .constant => {
            const constant = inst.operand.castTag(.constant).?;
            switch (inst.operand.ty.tag()) {
                .u32 => {
                    try writer.writeByte(0x41); // i32.const
                    try leb.writeILEB128(writer, constant.val.toUnsignedInt());
                },
                .i32 => {
                    try writer.writeByte(0x41); // i32.const
                    try leb.writeILEB128(writer, constant.val.toSignedInt());
                },
                .u64 => {
                    try writer.writeByte(0x42); // i64.const
                    try leb.writeILEB128(writer, constant.val.toUnsignedInt());
                },
                .i64 => {
                    try writer.writeByte(0x42); // i64.const
                    try leb.writeILEB128(writer, constant.val.toSignedInt());
                },
                .f32 => {
                    try writer.writeByte(0x43); // f32.const
                    // TODO: enforce LE byte order
                    try writer.writeAll(mem.asBytes(&constant.val.toFloat(f32)));
                },
                .f64 => {
                    try writer.writeByte(0x44); // f64.const
                    // TODO: enforce LE byte order
                    try writer.writeAll(mem.asBytes(&constant.val.toFloat(f64)));
                },
                else => return error.TODOImplementMoreWasmCodegen,
            }
        },
        else => return error.TODOImplementMoreWasmCodegen,
    }
}
