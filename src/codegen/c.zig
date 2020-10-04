const std = @import("std");

const link = @import("../link.zig");
const Module = @import("../Module.zig");

const Inst = @import("../ir.zig").Inst;
const Value = @import("../value.zig").Value;
const Type = @import("../type.zig").Type;

const C = link.File.C;
const Decl = Module.Decl;
const mem = std.mem;

/// Maps a name from Zig source to C. Currently, this will always give the same
/// output for any given input, sometimes resulting in broken identifiers.
fn map(allocator: *std.mem.Allocator, name: []const u8) ![]const u8 {
    return allocator.dupe(u8, name);
}

fn renderType(ctx: *Context, writer: std.ArrayList(u8).Writer, T: Type) !void {
    switch (T.zigTypeTag()) {
        .NoReturn => {
            try writer.writeAll("zig_noreturn void");
        },
        .Void => try writer.writeAll("void"),
        .Int => {
            if (T.tag() == .u8) {
                ctx.file.need_stdint = true;
                try writer.writeAll("uint8_t");
            } else if (T.tag() == .usize) {
                ctx.file.need_stddef = true;
                try writer.writeAll("size_t");
            } else {
                return ctx.file.fail(ctx.decl.src(), "TODO implement int types", .{});
            }
        },
        else => |e| return ctx.file.fail(ctx.decl.src(), "TODO implement type {}", .{e}),
    }
}

fn renderValue(ctx: *Context, writer: std.ArrayList(u8).Writer, T: Type, val: Value) !void {
    switch (T.zigTypeTag()) {
        .Int => {
            if (T.isSignedInt())
                return writer.print("{}", .{val.toSignedInt()});
            return writer.print("{}", .{val.toUnsignedInt()});
        },
        else => |e| return ctx.file.fail(ctx.decl.src(), "TODO implement value {}", .{e}),
    }
}

fn renderFunctionSignature(ctx: *Context, writer: std.ArrayList(u8).Writer, decl: *Decl) !void {
    const tv = decl.typed_value.most_recent.typed_value;
    try renderType(ctx, writer, tv.ty.fnReturnType());
    const name = try map(ctx.file.base.allocator, mem.spanZ(decl.name));
    defer ctx.file.base.allocator.free(name);
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
            try renderType(ctx, writer, tv.ty.fnParamType(index));
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
        if (tv.ty.sentinel()) |sentinel|
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
        var it = self.inst_map.iterator();
        while (it.next()) |kv| {
            self.file.base.allocator.free(kv.value);
        }
        self.inst_map.deinit();
        self.* = undefined;
    }
};

fn genFn(file: *C, decl: *Decl) !void {
    const writer = file.main.writer();
    const tv = decl.typed_value.most_recent.typed_value;

    var ctx = Context{
        .file = file,
        .decl = decl,
        .inst_map = std.AutoHashMap(*Inst, []u8).init(file.base.allocator),
    };
    defer ctx.deinit();

    try renderFunctionSignature(&ctx, writer, decl);

    try writer.writeAll(" {");

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
    try renderType(ctx, writer, inst.base.ty);
    try writer.print(" {} = (", .{name});
    try renderType(ctx, writer, inst.base.ty);
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
                try renderFunctionSignature(ctx, header, target);
                try header.writeAll(";\n");
            }
            try writer.print("{}(", .{tname});
            if (inst.args.len != 0) {
                for (inst.args) |arg, i| {
                    if (i > 0) {
                        try writer.writeAll(", ");
                    }
                    if (arg.cast(Inst.Constant)) |con| {
                        try renderValue(ctx, writer, arg.ty, con.val);
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
            try renderType(ctx, writer, arg.ty);
            try writer.print(" {}_constant __asm__(\"{}\") = ", .{ reg, reg });
            // TODO merge constant handling into inst_map as well
            if (arg.castTag(.constant)) |c| {
                try renderValue(ctx, writer, arg.ty, c.val);
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
