const std = @import("std");

const link = @import("../link.zig");
const Module = @import("../Module.zig");

const Inst = @import("../ir.zig").Inst;
const Value = @import("../value.zig").Value;
const Type = @import("../type.zig").Type;

const C = link.File.C;
const Decl = Module.Decl;
const mem = std.mem;

/// Maps a name from Zig source to C. This will always give the same output for
/// any given input.
fn map(allocator: *std.mem.Allocator, name: []const u8) ![]const u8 {
    return allocator.dupe(u8, name);
}

fn renderType(file: *C, writer: std.ArrayList(u8).Writer, T: Type, src: usize) !void {
    if (T.tag() == .usize) {
        file.need_stddef = true;
        try writer.writeAll("size_t");
    } else {
        switch (T.zigTypeTag()) {
            .NoReturn => {
                file.need_noreturn = true;
                try writer.writeAll("noreturn void");
            },
            .Void => try writer.writeAll("void"),
            .Int => {
                if (T.tag() == .u8) {
                    file.need_stdint = true;
                    try writer.writeAll("uint8_t");
                } else {
                    return file.fail(src, "TODO implement int types", .{});
                }
            },
            else => |e| return file.fail(src, "TODO implement type {}", .{e}),
        }
    }
}

fn renderFunctionSignature(file: *C, writer: std.ArrayList(u8).Writer, decl: *Decl) !void {
    const tv = decl.typed_value.most_recent.typed_value;
    try renderType(file, writer, tv.ty.fnReturnType(), decl.src());
    const name = try map(file.allocator, mem.spanZ(decl.name));
    defer file.allocator.free(name);
    try writer.print(" {}(", .{name});
    if (tv.ty.fnParamLen() == 0)
        try writer.writeAll("void)")
    else
        return file.fail(decl.src(), "TODO implement parameters", .{});
}

pub fn generate(file: *C, decl: *Decl) !void {
    switch (decl.typed_value.most_recent.typed_value.ty.zigTypeTag()) {
        .Fn => try genFn(file, decl),
        .Array => try genArray(file, decl),
        else => |e| return file.fail(decl.src(), "TODO {}", .{e}),
    }
}

fn genArray(file: *C, decl: *Decl) !void {
    const tv = decl.typed_value.most_recent.typed_value;
    // TODO: prevent inline asm constants from being emitted
    const name = try map(file.allocator, mem.span(decl.name));
    defer file.allocator.free(name);
    if (tv.val.cast(Value.Payload.Bytes)) |payload|
        if (tv.ty.arraySentinel()) |sentinel|
            if (sentinel.toUnsignedInt() == 0)
                try file.constants.writer().print("const char *const {} = \"{}\";\n", .{ name, payload.data })
            else
                return file.fail(decl.src(), "TODO byte arrays with non-zero sentinels", .{})
        else
            return file.fail(decl.src(), "TODO byte arrays without sentinels", .{})
    else
        return file.fail(decl.src(), "TODO non-byte arrays", .{});
}

fn genFn(file: *C, decl: *Decl) !void {
    const writer = file.main.writer();
    const tv = decl.typed_value.most_recent.typed_value;

    try renderFunctionSignature(file, writer, decl);

    try writer.writeAll(" {");

    const func: *Module.Fn = tv.val.cast(Value.Payload.Function).?.func;
    const instructions = func.analysis.success.instructions;
    if (instructions.len > 0) {
        for (instructions) |inst| {
            try writer.writeAll("\n\t");
            switch (inst.tag) {
                .assembly => try genAsm(file, inst.castTag(.assembly).?, decl),
                .call => try genCall(file, inst.castTag(.call).?, decl),
                .ret => try genRet(file, inst.castTag(.ret).?, decl, tv.ty.fnReturnType()),
                .retvoid => try file.main.writer().print("return;", .{}),
                else => |e| return file.fail(decl.src(), "TODO implement C codegen for {}", .{e}),
            }
        }
        try writer.writeAll("\n");
    }

    try writer.writeAll("}\n\n");
}

fn genRet(file: *C, inst: *Inst.UnOp, decl: *Decl, expected_return_type: Type) !void {
    const writer = file.main.writer();
    const ret_value = inst.operand;
    const value = ret_value.value().?;
    if (expected_return_type.eql(ret_value.ty))
        return file.fail(decl.src(), "TODO return {}", .{expected_return_type})
    else if (expected_return_type.isInt() and ret_value.ty.tag() == .comptime_int)
        if (value.intFitsInType(expected_return_type, file.options.target))
            if (expected_return_type.intInfo(file.options.target).bits <= 64)
                try writer.print("return {};", .{value.toUnsignedInt()})
            else
                return file.fail(decl.src(), "TODO return ints > 64 bits", .{})
        else
            return file.fail(decl.src(), "comptime int {} does not fit in {}", .{ value.toUnsignedInt(), expected_return_type })
    else
        return file.fail(decl.src(), "return type mismatch: expected {}, found {}", .{ expected_return_type, ret_value.ty });
}

fn genCall(file: *C, inst: *Inst.Call, decl: *Decl) !void {
    const writer = file.main.writer();
    const header = file.header.writer();
    if (inst.func.castTag(.constant)) |func_inst| {
        if (func_inst.val.cast(Value.Payload.Function)) |func_val| {
            const target = func_val.func.owner_decl;
            const target_ty = target.typed_value.most_recent.typed_value.ty;
            const ret_ty = target_ty.fnReturnType().tag();
            if (target_ty.fnReturnType().hasCodeGenBits() and inst.base.isUnused()) {
                try writer.print("(void)", .{});
            }
            const tname = mem.spanZ(target.name);
            if (file.called.get(tname) == null) {
                try file.called.put(tname, void{});
                try renderFunctionSignature(file, header, target);
                try header.writeAll(";\n");
            }
            try writer.print("{}();", .{tname});
        } else {
            return file.fail(decl.src(), "TODO non-function call target?", .{});
        }
        if (inst.args.len != 0) {
            return file.fail(decl.src(), "TODO function arguments", .{});
        }
    } else {
        return file.fail(decl.src(), "TODO non-constant call inst?", .{});
    }
}

fn genAsm(file: *C, as: *Inst.Assembly, decl: *Decl) !void {
    const writer = file.main.writer();
    for (as.inputs) |i, index| {
        if (i[0] == '{' and i[i.len - 1] == '}') {
            const reg = i[1 .. i.len - 1];
            const arg = as.args[index];
            if (arg.castTag(.constant)) |c| {
                if (c.val.tag() == .int_u64) {
                    try writer.writeAll("register ");
                    try renderType(file, writer, arg.ty, decl.src());
                    try writer.print(" {}_constant __asm__(\"{}\") = {};\n\t", .{ reg, reg, c.val.toUnsignedInt() });
                } else {
                    return file.fail(decl.src(), "TODO inline asm {} args", .{c.val.tag()});
                }
            } else {
                return file.fail(decl.src(), "TODO non-constant inline asm args", .{});
            }
        } else {
            return file.fail(decl.src(), "TODO non-explicit inline asm regs", .{});
        }
    }
    try writer.print("__asm {} (\"{}\"", .{ if (as.is_volatile) @as([]const u8, "volatile") else "", as.asm_source });
    if (as.output) |o| {
        return file.fail(decl.src(), "TODO inline asm output", .{});
    }
    if (as.inputs.len > 0) {
        if (as.output == null) {
            try writer.writeAll(" :");
        }
        try writer.writeAll(": ");
        for (as.inputs) |i, index| {
            if (i[0] == '{' and i[i.len - 1] == '}') {
                const reg = i[1 .. i.len - 1];
                const arg = as.args[index];
                if (index > 0) {
                    try writer.writeAll(", ");
                }
                if (arg.castTag(.constant)) |c| {
                    try writer.print("\"\"({}_constant)", .{reg});
                } else {
                    // This is blocked by the earlier test
                    unreachable;
                }
            } else {
                // This is blocked by the earlier test
                unreachable;
            }
        }
    }
    try writer.writeAll(");");
}
