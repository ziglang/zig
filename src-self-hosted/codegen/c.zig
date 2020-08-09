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
                try writer.writeAll("zig_noreturn void");
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

fn renderValue(file: *C, writer: std.ArrayList(u8).Writer, val: Value, src: usize) !void {
    switch (val.tag()) {
        .int_u64 => return writer.print("{}", .{val.toUnsignedInt()}),
        else => |e| return file.fail(src, "TODO implement value {}", .{e}),
    }
}

fn renderFunctionSignature(file: *C, writer: std.ArrayList(u8).Writer, decl: *Decl) !void {
    const tv = decl.typed_value.most_recent.typed_value;
    try renderType(file, writer, tv.ty.fnReturnType(), decl.src());
    const name = try map(file.base.allocator, mem.spanZ(decl.name));
    defer file.base.allocator.free(name);
    try writer.print(" {}(", .{name});
    var param_len = tv.ty.fnParamLen();
    if (param_len == 0)
        try writer.writeAll("void")
    else {
        var index: usize = 0;
        while (index < param_len) : (index += 1) {
            if (index > 0) {
                try writer.writeAll(", ");
            }
            try renderType(file, writer, tv.ty.fnParamType(index), decl.src());
            try writer.print(" arg{}", .{index});
        }
    }
    try writer.writeByte(')');
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
    const name = try map(file.base.allocator, mem.span(decl.name));
    defer file.base.allocator.free(name);
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
    var argdex: usize = 0;
    if (instructions.len > 0) {
        try writer.writeAll("\n");
        for (instructions) |inst| {
            switch (inst.tag) {
                .assembly => try genAsm(file, inst.castTag(.assembly).?, decl, &argdex),
                .call => try genCall(file, inst.castTag(.call).?, decl),
                .ret => try genRet(file, inst.castTag(.ret).?, decl, tv.ty.fnReturnType()),
                .retvoid => try file.main.writer().print("    return;\n", .{}),
                .arg => {},
                .dbg_stmt => try genDbgStmt(file, inst.castTag(.dbg_stmt).?, decl),
                .breakpoint => try genBreak(file, inst.castTag(.breakpoint).?, decl),
                .unreach => try genUnreach(file, inst.castTag(.unreach).?, decl),
                else => |e| return file.fail(decl.src(), "TODO implement C codegen for {}", .{e}),
            }
        }
    }

    try writer.writeAll("}\n\n");
}

fn genRet(file: *C, inst: *Inst.UnOp, decl: *Decl, expected_return_type: Type) !void {
    return file.fail(decl.src(), "TODO return {}", .{expected_return_type});
}

fn genCall(file: *C, inst: *Inst.Call, decl: *Decl) !void {
    const writer = file.main.writer();
    const header = file.header.writer();
    try writer.writeAll("    ");
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
            try writer.print("{}(", .{tname});
            if (inst.args.len != 0) {
                for (inst.args) |arg, i| {
                    if (i > 0) {
                        try writer.writeAll(", ");
                    }
                    if (arg.cast(Inst.Constant)) |con| {
                        try renderValue(file, writer, con.val, decl.src());
                    } else {
                        return file.fail(decl.src(), "TODO call pass arg {}", .{arg});
                    }
                }
            }
            try writer.writeAll(");\n");
        } else {
            return file.fail(decl.src(), "TODO non-function call target?", .{});
        }
    } else {
        return file.fail(decl.src(), "TODO non-constant call inst?", .{});
    }
}

fn genDbgStmt(file: *C, inst: *Inst.NoOp, decl: *Decl) !void {
    // TODO emit #line directive here with line number and filename
}

fn genBreak(file: *C, inst: *Inst.NoOp, decl: *Decl) !void {
    // TODO ??
}

fn genUnreach(file: *C, inst: *Inst.NoOp, decl: *Decl) !void {
    try file.main.writer().writeAll("    zig_unreachable();\n");
}

fn genAsm(file: *C, as: *Inst.Assembly, decl: *Decl, argdex: *usize) !void {
    const writer = file.main.writer();
    try writer.writeAll("    ");
    for (as.inputs) |i, index| {
        if (i[0] == '{' and i[i.len - 1] == '}') {
            const reg = i[1 .. i.len - 1];
            const arg = as.args[index];
            try writer.writeAll("register ");
            try renderType(file, writer, arg.ty, decl.src());
            try writer.print(" {}_constant __asm__(\"{}\") = ", .{ reg, reg });
            if (arg.castTag(.constant)) |c| {
                try renderValue(file, writer, c.val, decl.src());
            } else if (arg.castTag(.arg)) |inst| {
                try writer.print("arg{}", .{argdex.*});
                argdex.* += 1;
            } else {
                return file.fail(decl.src(), "TODO non-constant inline asm args ({})", .{arg.tag});
            }
            try writer.writeAll(";\n    ");
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
                try writer.writeAll("\"\"(");
                if (arg.tag == .constant or arg.tag == .arg) {
                    try writer.print("{}_constant", .{reg});
                } else {
                    // This is blocked by the earlier test
                    unreachable;
                }
                try writer.writeByte(')');
            } else {
                // This is blocked by the earlier test
                unreachable;
            }
        }
    }
    try writer.writeAll(");\n");
}
