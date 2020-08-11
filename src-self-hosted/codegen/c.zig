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

const Context = struct {
    file: *C,
    decl: *Decl,
    inst_map: std.AutoHashMap(*Inst, []u8),
    argdex: usize = 0,
    unnamed_index: usize = 0,

    fn name(self: *Context) ![]u8 {
        const val = try std.fmt.allocPrint(self.file.base.allocator, "__temp_{}", .{self.unnamed_index});
        self.unnamed_index += 1;
        return val;
    }

    fn deinit(self: *Context) void {
        for (self.inst_map.items()) |kv| {
            self.file.base.allocator.free(kv.value);
        }
        self.inst_map.deinit();
        self.* = undefined;
    }
};

fn genFn(file: *C, decl: *Decl) !void {
    const writer = file.main.writer();
    const tv = decl.typed_value.most_recent.typed_value;

    try renderFunctionSignature(file, writer, decl);

    try writer.writeAll(" {");

    var ctx = Context{
        .file = file,
        .decl = decl,
        .inst_map = std.AutoHashMap(*Inst, []u8).init(file.base.allocator),
    };
    defer ctx.deinit();

    const func: *Module.Fn = tv.val.cast(Value.Payload.Function).?.func;
    const instructions = func.analysis.success.instructions;
    if (instructions.len > 0) {
        try writer.writeAll("\n");
        for (instructions) |inst| {
            if (switch (inst.tag) {
                .assembly => try genAsm(&ctx, inst.castTag(.assembly).?),
                .call => try genCall(&ctx, inst.castTag(.call).?),
                .ret => try genRet(&ctx, inst.castTag(.ret).?),
                .retvoid => try genRetVoid(&ctx),
                .arg => try genArg(&ctx),
                .dbg_stmt => try genDbgStmt(&ctx, inst.castTag(.dbg_stmt).?),
                .breakpoint => try genBreak(&ctx, inst.castTag(.breakpoint).?),
                .unreach => try genUnreach(&ctx, inst.castTag(.unreach).?),
                .intcast => try genIntCast(&ctx, inst.castTag(.intcast).?),
                else => |e| return file.fail(decl.src(), "TODO implement C codegen for {}", .{e}),
            }) |name| {
                try ctx.inst_map.putNoClobber(inst, name);
            }
        }
    }

    try writer.writeAll("}\n\n");
}

fn genArg(ctx: *Context) !?[]u8 {
    const name = try std.fmt.allocPrint(ctx.file.base.allocator, "arg{}", .{ctx.argdex});
    ctx.argdex += 1;
    return name;
}

fn genRetVoid(ctx: *Context) !?[]u8 {
    try ctx.file.main.writer().print("    return;\n", .{});
    return null;
}

fn genRet(ctx: *Context, inst: *Inst.UnOp) !?[]u8 {
    return ctx.file.fail(ctx.decl.src(), "TODO return", .{});
}

fn genIntCast(ctx: *Context, inst: *Inst.UnOp) !?[]u8 {
    if (inst.base.isUnused())
        return null;
    const op = inst.operand;
    const writer = ctx.file.main.writer();
    const name = try ctx.name();
    const from = ctx.inst_map.get(op) orelse
        return ctx.file.fail(ctx.decl.src(), "Internal error in C backend: intCast argument not found in inst_map", .{});
    try writer.writeAll("    const ");
    try renderType(ctx.file, writer, inst.base.ty, ctx.decl.src());
    try writer.print(" {} = (", .{name});
    try renderType(ctx.file, writer, inst.base.ty, ctx.decl.src());
    try writer.print("){};\n", .{from});
    return name;
}

fn genCall(ctx: *Context, inst: *Inst.Call) !?[]u8 {
    const writer = ctx.file.main.writer();
    const header = ctx.file.header.writer();
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
            if (ctx.file.called.get(tname) == null) {
                try ctx.file.called.put(tname, void{});
                try renderFunctionSignature(ctx.file, header, target);
                try header.writeAll(";\n");
            }
            try writer.print("{}(", .{tname});
            if (inst.args.len != 0) {
                for (inst.args) |arg, i| {
                    if (i > 0) {
                        try writer.writeAll(", ");
                    }
                    if (arg.cast(Inst.Constant)) |con| {
                        try renderValue(ctx.file, writer, con.val, ctx.decl.src());
                    } else {
                        return ctx.file.fail(ctx.decl.src(), "TODO call pass arg {}", .{arg});
                    }
                }
            }
            try writer.writeAll(");\n");
        } else {
            return ctx.file.fail(ctx.decl.src(), "TODO non-function call target?", .{});
        }
    } else {
        return ctx.file.fail(ctx.decl.src(), "TODO non-constant call inst?", .{});
    }
    return null;
}

fn genDbgStmt(ctx: *Context, inst: *Inst.NoOp) !?[]u8 {
    // TODO emit #line directive here with line number and filename
    return null;
}

fn genBreak(ctx: *Context, inst: *Inst.NoOp) !?[]u8 {
    // TODO ??
    return null;
}

fn genUnreach(ctx: *Context, inst: *Inst.NoOp) !?[]u8 {
    try ctx.file.main.writer().writeAll("    zig_unreachable();\n");
    return null;
}

fn genAsm(ctx: *Context, as: *Inst.Assembly) !?[]u8 {
    const writer = ctx.file.main.writer();
    try writer.writeAll("    ");
    for (as.inputs) |i, index| {
        if (i[0] == '{' and i[i.len - 1] == '}') {
            const reg = i[1 .. i.len - 1];
            const arg = as.args[index];
            try writer.writeAll("register ");
            try renderType(ctx.file, writer, arg.ty, ctx.decl.src());
            try writer.print(" {}_constant __asm__(\"{}\") = ", .{ reg, reg });
            // TODO merge constant handling into inst_map as well
            if (arg.castTag(.constant)) |c| {
                try renderValue(ctx.file, writer, c.val, ctx.decl.src());
                try writer.writeAll(";\n    ");
            } else {
                const gop = try ctx.inst_map.getOrPut(arg);
                if (!gop.found_existing) {
                    return ctx.file.fail(ctx.decl.src(), "Internal error in C backend: asm argument not found in inst_map", .{});
                }
                try writer.print("{};\n    ", .{gop.entry.value});
            }
        } else {
            return ctx.file.fail(ctx.decl.src(), "TODO non-explicit inline asm regs", .{});
        }
    }
    try writer.print("__asm {} (\"{}\"", .{ if (as.is_volatile) @as([]const u8, "volatile") else "", as.asm_source });
    if (as.output) |o| {
        return ctx.file.fail(ctx.decl.src(), "TODO inline asm output", .{});
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
                try writer.print("\"\"({}_constant)", .{reg});
            } else {
                // This is blocked by the earlier test
                unreachable;
            }
        }
    }
    try writer.writeAll(");\n");
    return null;
}
