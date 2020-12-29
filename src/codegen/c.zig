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
const log = std.log.scoped(.c);

const Writer = std.ArrayList(u8).Writer;

/// Maps a name from Zig source to C. Currently, this will always give the same
/// output for any given input, sometimes resulting in broken identifiers.
fn map(allocator: *std.mem.Allocator, name: []const u8) ![]const u8 {
    return allocator.dupe(u8, name);
}

fn renderType(
    ctx: *Context,
    writer: Writer,
    t: Type,
) error{ OutOfMemory, AnalysisFail }!void {
    switch (t.zigTypeTag()) {
        .NoReturn => {
            try writer.writeAll("zig_noreturn void");
        },
        .Void => try writer.writeAll("void"),
        .Bool => try writer.writeAll("bool"),
        .Int => {
            switch (t.tag()) {
                .u8 => try writer.writeAll("uint8_t"),
                .i8 => try writer.writeAll("int8_t"),
                .u16 => try writer.writeAll("uint16_t"),
                .i16 => try writer.writeAll("int16_t"),
                .u32 => try writer.writeAll("uint32_t"),
                .i32 => try writer.writeAll("int32_t"),
                .u64 => try writer.writeAll("uint64_t"),
                .i64 => try writer.writeAll("int64_t"),
                .usize => try writer.writeAll("uintptr_t"),
                .isize => try writer.writeAll("intptr_t"),
                .c_short => try writer.writeAll("short"),
                .c_ushort => try writer.writeAll("unsigned short"),
                .c_int => try writer.writeAll("int"),
                .c_uint => try writer.writeAll("unsigned int"),
                .c_long => try writer.writeAll("long"),
                .c_ulong => try writer.writeAll("unsigned long"),
                .c_longlong => try writer.writeAll("long long"),
                .c_ulonglong => try writer.writeAll("unsigned long long"),
                .int_signed, .int_unsigned => {
                    const info = t.intInfo(ctx.target);
                    const sign_prefix = switch (info.signedness) {
                        .signed => "i",
                        .unsigned => "",
                    };
                    inline for (.{ 8, 16, 32, 64, 128 }) |nbits| {
                        if (info.bits <= nbits) {
                            try writer.print("{s}int{d}_t", .{ sign_prefix, nbits });
                            break;
                        }
                    } else {
                        return ctx.fail(ctx.decl.src(), "TODO: C backend: implement integer types larger than 128 bits", .{});
                    }
                },
                else => unreachable,
            }
        },
        .Pointer => {
            if (t.isSlice()) {
                return ctx.fail(ctx.decl.src(), "TODO: C backend: implement slices", .{});
            } else {
                if (t.isConstPtr()) {
                    try writer.writeAll("const ");
                }
                if (t.isVolatilePtr()) {
                    try writer.writeAll("volatile ");
                }
                try renderType(ctx, writer, t.elemType());
                try writer.writeAll(" *");
            }
        },
        .Array => {
            try renderType(ctx, writer, t.elemType());
            try writer.writeAll(" *");
        },
        else => |e| return ctx.fail(ctx.decl.src(), "TODO: C backend: implement type {s}", .{
            @tagName(e),
        }),
    }
}

fn renderValue(
    ctx: *Context,
    writer: Writer,
    t: Type,
    val: Value,
) error{ OutOfMemory, AnalysisFail }!void {
    switch (t.zigTypeTag()) {
        .Int => {
            if (t.isSignedInt())
                return writer.print("{d}", .{val.toSignedInt()});
            return writer.print("{d}", .{val.toUnsignedInt()});
        },
        .Pointer => switch (val.tag()) {
            .undef, .zero => try writer.writeAll("0"),
            .one => try writer.writeAll("1"),
            .decl_ref => {
                const decl_ref_payload = val.cast(Value.Payload.DeclRef).?;

                // Determine if we must pointer cast.
                const decl_tv = decl_ref_payload.decl.typed_value.most_recent.typed_value;
                if (t.eql(decl_tv.ty)) {
                    try writer.print("&{s}", .{decl_ref_payload.decl.name});
                } else {
                    try writer.writeAll("(");
                    try renderType(ctx, writer, t);
                    try writer.print(")&{s}", .{decl_ref_payload.decl.name});
                }
            },
            .function => {
                const payload = val.cast(Value.Payload.Function).?;
                try writer.print("{s}", .{payload.func.owner_decl.name});
            },
            .extern_fn => {
                const payload = val.cast(Value.Payload.ExternFn).?;
                try writer.print("{s}", .{payload.decl.name});
            },
            else => |e| return ctx.fail(
                ctx.decl.src(),
                "TODO: C backend: implement Pointer value {s}",
                .{@tagName(e)},
            ),
        },
        .Array => {
            // First try specific tag representations for more efficiency.
            switch (val.tag()) {
                .undef, .empty_struct_value, .empty_array => try writer.writeAll("{}"),
                .bytes => {
                    const bytes = val.cast(Value.Payload.Bytes).?.data;
                    // TODO: make our own C string escape instead of using {Z}
                    try writer.print("\"{Z}\"", .{bytes});
                },
                else => {
                    // Fall back to generic implementation.
                    try writer.writeAll("{");
                    var index: usize = 0;
                    const len = t.arrayLen();
                    const elem_ty = t.elemType();
                    while (index < len) : (index += 1) {
                        if (index != 0) try writer.writeAll(",");
                        const elem_val = try val.elemValue(&ctx.arena.allocator, index);
                        try renderValue(ctx, writer, elem_ty, elem_val);
                    }
                    if (t.sentinel()) |sentinel_val| {
                        if (index != 0) try writer.writeAll(",");
                        try renderValue(ctx, writer, elem_ty, sentinel_val);
                    }
                    try writer.writeAll("}");
                },
            }
        },
        else => |e| return ctx.fail(ctx.decl.src(), "TODO: C backend: implement value {s}", .{
            @tagName(e),
        }),
    }
}

fn renderFunctionSignature(
    ctx: *Context,
    writer: Writer,
    decl: *Decl,
) !void {
    const tv = decl.typed_value.most_recent.typed_value;
    try renderType(ctx, writer, tv.ty.fnReturnType());
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
            try renderType(ctx, writer, tv.ty.fnParamType(index));
            try writer.print(" arg{}", .{index});
        }
    }
    try writer.writeByte(')');
}

fn indent(file: *C) !void {
    const indent_size = 4;
    const indent_level = 1;
    const indent_amt = indent_size * indent_level;
    try file.main.writer().writeByteNTimes(' ', indent_amt);
}

pub fn generate(file: *C, decl: *Decl) !void {
    const tv = decl.typed_value.most_recent.typed_value;

    var arena = std.heap.ArenaAllocator.init(file.base.allocator);
    defer arena.deinit();
    var inst_map = std.AutoHashMap(*Inst, []u8).init(&arena.allocator);
    defer inst_map.deinit();
    var ctx = Context{
        .decl = decl,
        .arena = &arena,
        .inst_map = &inst_map,
        .target = file.base.options.target,
        .header = &file.header,
    };
    defer {
        file.error_msg = ctx.error_msg;
        ctx.deinit();
    }

    if (tv.val.cast(Value.Payload.Function)) |func_payload| {
        const writer = file.main.writer();
        try renderFunctionSignature(&ctx, writer, decl);

        try writer.writeAll(" {");

        const func: *Module.Fn = func_payload.func;
        const instructions = func.analysis.success.instructions;
        if (instructions.len > 0) {
            try writer.writeAll("\n");
            for (instructions) |inst| {
                if (switch (inst.tag) {
                    .assembly => try genAsm(&ctx, file, inst.castTag(.assembly).?),
                    .call => try genCall(&ctx, file, inst.castTag(.call).?),
                    .add => try genBinOp(&ctx, file, inst.cast(Inst.BinOp).?, "+"),
                    .sub => try genBinOp(&ctx, file, inst.cast(Inst.BinOp).?, "-"),
                    .ret => try genRet(&ctx, file, inst.castTag(.ret).?),
                    .retvoid => try genRetVoid(file),
                    .arg => try genArg(&ctx),
                    .dbg_stmt => try genDbgStmt(&ctx, inst.castTag(.dbg_stmt).?),
                    .breakpoint => try genBreakpoint(file, inst.castTag(.breakpoint).?),
                    .unreach => try genUnreach(file, inst.castTag(.unreach).?),
                    .intcast => try genIntCast(&ctx, file, inst.castTag(.intcast).?),
                    else => |e| return ctx.fail(decl.src(), "TODO: C backend: implement codegen for {}", .{e}),
                }) |name| {
                    try ctx.inst_map.putNoClobber(inst, name);
                }
            }
        }

        try writer.writeAll("}\n\n");
    } else if (tv.val.tag() == .extern_fn) {
        return; // handled when referenced
    } else {
        const writer = file.constants.writer();
        try writer.writeAll("static ");

        // TODO ask the Decl if it is const
        // https://github.com/ziglang/zig/issues/7582

        var suffix = std.ArrayList(u8).init(file.base.allocator);
        defer suffix.deinit();

        var render_ty = tv.ty;
        while (render_ty.zigTypeTag() == .Array) {
            const sentinel_bit = @boolToInt(render_ty.sentinel() != null);
            const c_len = render_ty.arrayLen() + sentinel_bit;
            try suffix.writer().print("[{d}]", .{c_len});
            render_ty = render_ty.elemType();
        }

        try renderType(&ctx, writer, render_ty);
        try writer.print(" {s}{s}", .{ decl.name, suffix.items });

        try writer.writeAll(" = ");
        try renderValue(&ctx, writer, tv.ty, tv.val);
        try writer.writeAll(";\n");
    }
}

pub fn generateHeader(
    comp: *Compilation,
    module: *Module,
    header: *C.Header,
    decl: *Decl,
) error{ AnalysisFail, OutOfMemory }!void {
    switch (decl.typed_value.most_recent.typed_value.ty.zigTypeTag()) {
        .Fn => {
            var inst_map = std.AutoHashMap(*Inst, []u8).init(comp.gpa);
            defer inst_map.deinit();

            var arena = std.heap.ArenaAllocator.init(comp.gpa);
            defer arena.deinit();

            var ctx = Context{
                .decl = decl,
                .arena = &arena,
                .inst_map = &inst_map,
                .target = comp.getTarget(),
                .header = header,
            };
            const writer = header.buf.writer();
            renderFunctionSignature(&ctx, writer, decl) catch |err| {
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

const Context = struct {
    decl: *Decl,
    inst_map: *std.AutoHashMap(*Inst, []u8),
    arena: *std.heap.ArenaAllocator,
    argdex: usize = 0,
    unnamed_index: usize = 0,
    error_msg: *Compilation.ErrorMsg = undefined,
    target: std.Target,
    header: *C.Header,

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

fn genArg(ctx: *Context) !?[]u8 {
    const name = try std.fmt.allocPrint(&ctx.arena.allocator, "arg{}", .{ctx.argdex});
    ctx.argdex += 1;
    return name;
}

fn genRetVoid(file: *C) !?[]u8 {
    try indent(file);
    try file.main.writer().print("return;\n", .{});
    return null;
}

fn genRet(ctx: *Context, file: *C, inst: *Inst.UnOp) !?[]u8 {
    try indent(file);
    const writer = file.main.writer();
    try writer.writeAll("return ");
    try genValue(ctx, writer, inst.operand);
    try writer.writeAll(";\n");
    return null;
}

fn genValue(ctx: *Context, writer: Writer, inst: *Inst) !void {
    if (inst.value()) |val| {
        try renderValue(ctx, writer, inst.ty, val);
        return;
    }
    return ctx.fail(ctx.decl.src(), "TODO: C backend: genValue for non-constant value", .{});
}

fn genIntCast(ctx: *Context, file: *C, inst: *Inst.UnOp) !?[]u8 {
    if (inst.base.isUnused())
        return null;
    try indent(file);
    const op = inst.operand;
    const writer = file.main.writer();
    const name = try ctx.name();
    const from = try ctx.resolveInst(inst.operand);
    try writer.writeAll("const ");
    try renderType(ctx, writer, inst.base.ty);
    try writer.print(" {} = (", .{name});
    try renderType(ctx, writer, inst.base.ty);
    try writer.print("){};\n", .{from});
    return name;
}

fn genBinOp(ctx: *Context, file: *C, inst: *Inst.BinOp, comptime operator: []const u8) !?[]u8 {
    if (inst.base.isUnused())
        return null;
    try indent(file);
    const lhs = ctx.resolveInst(inst.lhs);
    const rhs = ctx.resolveInst(inst.rhs);
    const writer = file.main.writer();
    const name = try ctx.name();
    try writer.writeAll("const ");
    try renderType(ctx, writer, inst.base.ty);
    try writer.print(" {} = {} " ++ operator ++ " {};\n", .{ name, lhs, rhs });
    return name;
}

fn genCall(ctx: *Context, file: *C, inst: *Inst.Call) !?[]u8 {
    try indent(file);
    const writer = file.main.writer();
    const header = file.header.buf.writer();
    if (inst.func.castTag(.constant)) |func_inst| {
        const fn_decl = if (func_inst.val.cast(Value.Payload.ExternFn)) |extern_fn|
            extern_fn.decl
        else if (func_inst.val.cast(Value.Payload.Function)) |func_val|
            func_val.func.owner_decl
        else
            unreachable;

        const fn_ty = fn_decl.typed_value.most_recent.typed_value.ty;
        const ret_ty = fn_ty.fnReturnType().tag();
        if (fn_ty.fnReturnType().hasCodeGenBits() and inst.base.isUnused()) {
            try writer.print("(void)", .{});
        }
        const fn_name = mem.spanZ(fn_decl.name);
        if (file.called.get(fn_name) == null) {
            try file.called.put(fn_name, void{});
            try renderFunctionSignature(ctx, header, fn_decl);
            try header.writeAll(";\n");
        }
        try writer.print("{s}(", .{fn_name});
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
        return ctx.fail(ctx.decl.src(), "TODO: C backend: implement function pointers", .{});
    }
    return null;
}

fn genDbgStmt(ctx: *Context, inst: *Inst.NoOp) !?[]u8 {
    // TODO emit #line directive here with line number and filename
    return null;
}

fn genBreakpoint(file: *C, inst: *Inst.NoOp) !?[]u8 {
    try indent(file);
    try file.main.writer().writeAll("zig_breakpoint();\n");
    return null;
}

fn genUnreach(file: *C, inst: *Inst.NoOp) !?[]u8 {
    try indent(file);
    try file.main.writer().writeAll("zig_unreachable();\n");
    return null;
}

fn genAsm(ctx: *Context, file: *C, as: *Inst.Assembly) !?[]u8 {
    try indent(file);
    const writer = file.main.writer();
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
