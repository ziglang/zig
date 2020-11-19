const std = @import("std");

const link = @import("../link.zig");
const Module = @import("../Module.zig");
const Compilation = @import("../Compilation.zig");

const Inst = @import("../ir.zig").Inst;
const Value = @import("../value.zig").Value;
const Type = @import("../type.zig").Type;

const C = link.File.C;
const Decl = Module.Decl;
const mem = std.mem;

const indentation = "    ";

/// Maps a name from Zig source to C. Currently, this will always give the same
/// output for any given input, sometimes resulting in broken identifiers.
fn map(allocator: *std.mem.Allocator, name: []const u8) ![]const u8 {
    return allocator.dupe(u8, name);
}

fn renderType(ctx: *Context, header: *C.Header, writer: std.ArrayList(u8).Writer, T: Type) !void {
    switch (T.zigTypeTag()) {
        .NoReturn => {
            try writer.writeAll("zig_noreturn void");
        },
        .Void => try writer.writeAll("void"),
        .Bool => try writer.writeAll("bool"),
        .Int => {
            if (T.tag() == .u8) {
                header.need_stdint = true;
                try writer.writeAll("uint8_t");
            } else if (T.tag() == .u32) {
                header.need_stdint = true;
                try writer.writeAll("uint32_t");
            } else if (T.tag() == .usize) {
                header.need_stddef = true;
                try writer.writeAll("size_t");
            } else {
                return ctx.fail(ctx.decl.src(), "TODO implement int type {}", .{T});
            }
        },
        else => |e| return ctx.fail(ctx.decl.src(), "TODO implement type {}", .{e}),
    }
}

fn renderValue(ctx: *Context, writer: std.ArrayList(u8).Writer, T: Type, val: Value) !void {
    switch (T.zigTypeTag()) {
        .Int => {
            if (T.isSignedInt())
                return writer.print("{}", .{val.toSignedInt()});
            return writer.print("{}", .{val.toUnsignedInt()});
        },
        else => |e| return ctx.fail(ctx.decl.src(), "TODO implement value {}", .{e}),
    }
}

fn renderFunctionSignature(ctx: *Context, header: *C.Header, writer: std.ArrayList(u8).Writer, decl: *Decl) !void {
    const tv = decl.typed_value.most_recent.typed_value;
    try renderType(ctx, header, writer, tv.ty.fnReturnType());
    // Use the child allocator directly, as we know the name can be freed before
    // the rest of the arena.
    const name = try map(ctx.arena.child_allocator, mem.spanZ(decl.name));
    defer ctx.arena.child_allocator.free(name);
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
            try renderType(ctx, header, writer, tv.ty.fnParamType(index));
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

pub fn generateHeader(
    arena: *std.heap.ArenaAllocator,
    module: *Module,
    header: *C.Header,
    decl: *Decl,
) error{ AnalysisFail, OutOfMemory }!void {
    switch (decl.typed_value.most_recent.typed_value.ty.zigTypeTag()) {
        .Fn => {
            var inst_map = std.AutoHashMap(*Inst, []u8).init(&arena.allocator);
            defer inst_map.deinit();
            var ctx = Context{
                .decl = decl,
                .arena = arena,
                .inst_map = &inst_map,
            };
            const writer = header.buf.writer();
            renderFunctionSignature(&ctx, header, writer, decl) catch |err| {
                if (err == error.AnalysisFail) {
                    try module.failed_decls.put(module.gpa, decl, ctx.error_msg);
                }
                return err;
            };
            try writer.writeAll(";\n");
        },
        else => {},
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
                // TODO: static by default
                try file.constants.writer().print("const char *const {} = \"{}\";\n", .{ name, payload.data })
            else
                return file.fail(decl.src(), "TODO byte arrays with non-zero sentinels", .{})
        else
            return file.fail(decl.src(), "TODO byte arrays without sentinels", .{})
    else
        return file.fail(decl.src(), "TODO non-byte arrays", .{});
}

const Context = struct {
    decl: *Decl,
    inst_map: *std.AutoHashMap(*Inst, []u8),
    arena: *std.heap.ArenaAllocator,
    argdex: usize = 0,
    unnamed_index: usize = 0,
    error_msg: *Compilation.ErrorMsg = undefined,

    fn resolveInst(self: *Context, inst: *Inst) ![]u8 {
        if (inst.cast(Inst.Constant)) |const_inst| {
            var out = std.ArrayList(u8).init(&self.arena.allocator);
            try renderValue(self, out.writer(), inst.ty, const_inst.val);
            return out.toOwnedSlice();
        }
        if (self.inst_map.get(inst)) |val| {
            return val;
        }
        unreachable;
    }

    fn name(self: *Context) ![]u8 {
        const val = try std.fmt.allocPrint(&self.arena.allocator, "__temp_{}", .{self.unnamed_index});
        self.unnamed_index += 1;
        return val;
    }

    fn fail(self: *Context, src: usize, comptime format: []const u8, args: anytype) error{ AnalysisFail, OutOfMemory } {
        self.error_msg = try Compilation.ErrorMsg.create(self.arena.child_allocator, src, format, args);
        return error.AnalysisFail;
    }

    fn deinit(self: *Context) void {
        self.* = undefined;
    }
};

fn genFn(file: *C, decl: *Decl) !void {
    const writer = file.main.writer();
    const tv = decl.typed_value.most_recent.typed_value;

    var arena = std.heap.ArenaAllocator.init(file.base.allocator);
    defer arena.deinit();
    var inst_map = std.AutoHashMap(*Inst, []u8).init(&arena.allocator);
    defer inst_map.deinit();
    var ctx = Context{
        .decl = decl,
        .arena = &arena,
        .inst_map = &inst_map,
    };
    defer {
        file.error_msg = ctx.error_msg;
        ctx.deinit();
    }

    try renderFunctionSignature(&ctx, &file.header, writer, decl);

    try writer.writeAll(" {");

    const func: *Module.Fn = tv.val.cast(Value.Payload.Function).?.func;
    const instructions = func.analysis.success.instructions;
    if (instructions.len > 0) {
        try writer.writeAll("\n");
        for (instructions) |inst| {
            if (switch (inst.tag) {
                .assembly => try genAsm(&ctx, file, inst.castTag(.assembly).?),
                .call => try genCall(&ctx, file, inst.castTag(.call).?),
                .add => try genBinOp(&ctx, file, inst.cast(Inst.BinOp).?, "+"),
                .sub => try genBinOp(&ctx, file, inst.cast(Inst.BinOp).?, "-"),
                .ret => try genRet(&ctx, inst.castTag(.ret).?),
                .retvoid => try genRetVoid(file),
                .arg => try genArg(&ctx),
                .dbg_stmt => try genDbgStmt(&ctx, inst.castTag(.dbg_stmt).?),
                .breakpoint => try genBreak(&ctx, inst.castTag(.breakpoint).?),
                .unreach => try genUnreach(file, inst.castTag(.unreach).?),
                .intcast => try genIntCast(&ctx, file, inst.castTag(.intcast).?),
                else => |e| return ctx.fail(decl.src(), "TODO implement C codegen for {}", .{e}),
            }) |name| {
                try ctx.inst_map.putNoClobber(inst, name);
            }
        }
    }

    try writer.writeAll("}\n\n");
}

fn genArg(ctx: *Context) !?[]u8 {
    const name = try std.fmt.allocPrint(&ctx.arena.allocator, "arg{}", .{ctx.argdex});
    ctx.argdex += 1;
    return name;
}

fn genRetVoid(file: *C) !?[]u8 {
    try file.main.writer().print(indentation ++ "return;\n", .{});
    return null;
}

fn genRet(ctx: *Context, inst: *Inst.UnOp) !?[]u8 {
    return ctx.fail(ctx.decl.src(), "TODO return", .{});
}

fn genIntCast(ctx: *Context, file: *C, inst: *Inst.UnOp) !?[]u8 {
    if (inst.base.isUnused())
        return null;
    const op = inst.operand;
    const writer = file.main.writer();
    const name = try ctx.name();
    const from = try ctx.resolveInst(inst.operand);
    try writer.writeAll(indentation ++ "const ");
    try renderType(ctx, &file.header, writer, inst.base.ty);
    try writer.print(" {} = (", .{name});
    try renderType(ctx, &file.header, writer, inst.base.ty);
    try writer.print("){};\n", .{from});
    return name;
}

fn genBinOp(ctx: *Context, file: *C, inst: *Inst.BinOp, comptime operator: []const u8) !?[]u8 {
    if (inst.base.isUnused())
        return null;
    const lhs = ctx.resolveInst(inst.lhs);
    const rhs = ctx.resolveInst(inst.rhs);
    const writer = file.main.writer();
    const name = try ctx.name();
    try writer.writeAll(indentation ++ "const ");
    try renderType(ctx, &file.header, writer, inst.base.ty);
    try writer.print(" {} = {} " ++ operator ++ " {};\n", .{ name, lhs, rhs });
    return name;
}

fn genCall(ctx: *Context, file: *C, inst: *Inst.Call) !?[]u8 {
    const writer = file.main.writer();
    const header = file.header.buf.writer();
    try writer.writeAll(indentation);
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
                try renderFunctionSignature(ctx, &file.header, header, target);
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
                        const val = try ctx.resolveInst(arg);
                        try writer.print("{}", .{val});
                    }
                }
            }
            try writer.writeAll(");\n");
        } else {
            return ctx.fail(ctx.decl.src(), "TODO non-function call target?", .{});
        }
    } else {
        return ctx.fail(ctx.decl.src(), "TODO non-constant call inst?", .{});
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

fn genUnreach(file: *C, inst: *Inst.NoOp) !?[]u8 {
    try file.main.writer().writeAll(indentation ++ "zig_unreachable();\n");
    return null;
}

fn genAsm(ctx: *Context, file: *C, as: *Inst.Assembly) !?[]u8 {
    const writer = file.main.writer();
    try writer.writeAll(indentation);
    for (as.inputs) |i, index| {
        if (i[0] == '{' and i[i.len - 1] == '}') {
            const reg = i[1 .. i.len - 1];
            const arg = as.args[index];
            try writer.writeAll("register ");
            try renderType(ctx, &file.header, writer, arg.ty);
            try writer.print(" {}_constant __asm__(\"{}\") = ", .{ reg, reg });
            // TODO merge constant handling into inst_map as well
            if (arg.castTag(.constant)) |c| {
                try renderValue(ctx, writer, arg.ty, c.val);
                try writer.writeAll(";\n    ");
            } else {
                const gop = try ctx.inst_map.getOrPut(arg);
                if (!gop.found_existing) {
                    return ctx.fail(ctx.decl.src(), "Internal error in C backend: asm argument not found in inst_map", .{});
                }
                try writer.print("{};\n    ", .{gop.entry.value});
            }
        } else {
            return ctx.fail(ctx.decl.src(), "TODO non-explicit inline asm regs", .{});
        }
    }
    try writer.print("__asm {} (\"{}\"", .{ if (as.is_volatile) @as([]const u8, "volatile") else "", as.asm_source });
    if (as.output) |o| {
        return ctx.fail(ctx.decl.src(), "TODO inline asm output", .{});
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
