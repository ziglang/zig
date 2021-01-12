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
    try buf.resize(5);

    // Calculate the locals of the body
    // We must calculate the occurance of each value type and emit the count of it
    const tv = decl.typed_value.most_recent.typed_value;
    const mod_fn = tv.val.castTag(.function).?.data;

    var locals: [4]u8 = [_]u8{0} ** 4;
    for (mod_fn.body.instructions) |inst| {
        if (inst.tag != .alloc) continue;

        const alloc = inst.castTag(.alloc).?;
        const elem_type = alloc.base.ty.elemType();

        switch (genValtype(elem_type)) {
            0x7F => locals[0] += 1,
            0x7E => locals[1] += 1,
            0x7D => locals[2] += 1,
            0x7C => locals[3] += 1,
            else => unreachable,
        }
    }

    // Calculate the total different types
    var total_types: u32 = 0;
    for (locals) |local_type| {
        if (local_type != 0) total_types += 1;
    }
    try leb.writeULEB128(writer, total_types);

    // emit the actual locals amount per type
    if (total_types != 0) {
        for (locals) |local_count, i| {
            if (local_count != 0) {
                try leb.writeULEB128(writer, local_count);
                try writer.writeByte(switch (i) {
                    0 => 0x7F,
                    1 => 0x7E,
                    2 => 0x7D,
                    3 => 0x7C,
                    else => unreachable,
                });
            }
        }
    }

    // Write instructions
    // TODO: check for and handle death of instructions
    for (mod_fn.body.instructions) |inst| {
        // skip load as they should be triggered by other instructions
        if (inst.tag != .load) {
            try genInst(buf, decl, inst);
        }
    }

    try writer.writeByte(0x0B); // end

    // Fill in the size of the generated code to the reserved space at the
    // beginning of the buffer.
    const size = buf.items.len - 5 + decl.fn_link.wasm.?.idx_refs.items.len * 5;
    leb.writeUnsignedFixed(5, buf.items[0..5], @intCast(u32, size));
}

fn genInst(buf: *ArrayList(u8), decl: *Decl, inst: *Inst) !void {
    return switch (inst.tag) {
        .call => genCall(buf, decl, inst.castTag(.call).?),
        .constant => genConstant(buf, decl, inst.castTag(.constant).?),
        .dbg_stmt => {},
        .ret => genRet(buf, decl, inst.castTag(.ret).?),
        .retvoid => {},
        .alloc => genAlloc(buf, decl, inst.castTag(.alloc).?),
        .store => genStore(buf, decl, inst.castTag(.store).?),
        .load => genLoad(buf, decl, inst.castTag(.load).?),
        else => error.TODOImplementMoreWasmCodegen,
    };
}

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

fn genRet(buf: *ArrayList(u8), decl: *Decl, inst: *Inst.UnOp) !void {
    try genInst(buf, decl, inst.operand);
}

fn genCall(buf: *ArrayList(u8), decl: *Decl, inst: *Inst.Call) !void {
    const func_inst = inst.func.castTag(.constant).?;
    const func = func_inst.val.castTag(.function).?.data;
    const target = func.owner_decl;
    const target_ty = target.typed_value.most_recent.typed_value.ty;

    if (inst.args.len != 0) return error.TODOImplementMoreWasmCodegen;

    try buf.append(0x10); // call

    // The function index immediate argument will be filled in using this data
    // in link.Wasm.flush().
    try decl.fn_link.wasm.?.idx_refs.append(buf.allocator, .{
        .offset = @intCast(u32, buf.items.len),
        .decl = target,
    });
}

fn genStore(buf: *ArrayList(u8), decl: *Decl, inst: *Inst.BinOp) !void {
    const idx = decl.fn_link.wasm.?.getLocalidx(inst.lhs).?;

    const writer = buf.writer();

    // generate codegen for rhs before we store it
    try genInst(buf, decl, inst.rhs);

    try writer.writeByte(0x21); // local.set
    try leb.writeULEB128(writer, idx);
}

fn genLoad(buf: *ArrayList(u8), decl: *Decl, inst: *Inst.UnOp) !void {
    const idx = decl.fn_link.wasm.?.getLocalidx(inst.operand).?;
    const writer = buf.writer();

    try writer.writeByte(0x20); // local.get
    try leb.writeULEB128(writer, idx);
}

fn genAlloc(buf: *ArrayList(u8), decl: *Decl, inst: *Inst.NoOp) !void {
    try decl.fn_link.wasm.?.locals.append(buf.allocator, &inst.base);
}
