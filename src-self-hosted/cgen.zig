const link = @import("link.zig");
const Module = @import("Module.zig");
const ir = @import("ir.zig");
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const std = @import("std");

const C = link.File.C;
const Decl = Module.Decl;
const mem = std.mem;

/// Maps a name from Zig source to C. This will always give the same output for
/// any given input.
fn map(name: []const u8) ![]const u8 {
    return name;
}

fn renderType(file: *C, writer: std.ArrayList(u8).Writer, T: Type) !void {
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
            else => return error.Unimplemented,
        }
    }
}

fn renderFunctionSignature(file: *C, writer: std.ArrayList(u8).Writer, decl: *Decl) !void {
    const tv = decl.typed_value.most_recent.typed_value;
    try renderType(file, writer, tv.ty.fnReturnType());
    const name = try map(mem.spanZ(decl.name));
    try writer.print(" {}(", .{name});
    if (tv.ty.fnParamLen() == 0) {
        try writer.writeAll("void)");
    } else {
        return error.Unimplemented;
    }
}

pub fn generate(file: *C, decl: *Decl) !void {
    const writer = file.main.writer();
    const header = file.header.writer();
    const tv = decl.typed_value.most_recent.typed_value;
    switch (tv.ty.zigTypeTag()) {
        .Fn => {
            try renderFunctionSignature(file, writer, decl);

            try writer.writeAll(" {");

            const func: *Module.Fn = tv.val.cast(Value.Payload.Function).?.func;
            const instructions = func.analysis.success.instructions;
            if (instructions.len > 0) {
                for (instructions) |inst| {
                    try writer.writeAll("\n\t");
                    switch (inst.tag) {
                        .assembly => {
                            const as = inst.cast(ir.Inst.Assembly).?.args;
                            for (as.inputs) |i, index| {
                                if (i[0] == '{' and i[i.len - 1] == '}') {
                                    const reg = i[1 .. i.len - 1];
                                    const arg = as.args[index];
                                    if (arg.cast(ir.Inst.Constant)) |c| {
                                        if (c.val.tag() == .int_u64) {
                                            try writer.writeAll("register ");
                                            try renderType(file, writer, arg.ty);
                                            try writer.print(" {}_constant __asm__(\"{}\") = {};\n\t", .{ reg, reg, c.val.toUnsignedInt() });
                                        } else {
                                            return error.Unimplemented;
                                        }
                                    } else {
                                        return error.Unimplemented;
                                    }
                                } else {
                                    return error.Unimplemented;
                                }
                            }
                            try writer.print("__asm {} (\"{}\"", .{ if (as.is_volatile) @as([]const u8, "volatile") else "", as.asm_source });
                            if (as.output) |o| {
                                return error.Unimplemented;
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
                                        if (arg.cast(ir.Inst.Constant)) |c| {
                                            try writer.print("\"\"({}_constant)", .{reg});
                                        } else {
                                            return error.Unimplemented;
                                        }
                                    } else {
                                        return error.Unimplemented;
                                    }
                                }
                            }
                            try writer.writeAll(");");
                        },
                        .call => {
                            const call = inst.cast(ir.Inst.Call).?.args;
                            if (call.func.cast(ir.Inst.Constant)) |func_inst| {
                                if (func_inst.val.cast(Value.Payload.Function)) |func_val| {
                                    const target = func_val.func.owner_decl;
                                    const tname = mem.spanZ(target.name);
                                    if (file.called.get(tname) == null) {
                                        try file.called.put(tname, void{});
                                        try renderFunctionSignature(file, header, target);
                                        try header.writeAll(";\n");
                                    }
                                    try writer.print("{}();", .{tname});
                                } else {
                                    std.debug.warn("non-function call target?\n", .{});
                                    return error.Unimplemented;
                                }
                                if (call.args.len != 0) {
                                    std.debug.warn("parameters\n", .{});
                                    return error.Unimplemented;
                                }
                            } else {
                                std.debug.warn("non-constant call inst?\n", .{});
                                return error.Unimplemented;
                            }
                        },
                        else => {
                            std.debug.warn("\nTranslating {}\n", .{inst.*});
                        },
                    }
                }
                try writer.writeAll("\n");
            }

            try writer.writeAll("}\n\n");
        },
        .Array => {
            if (mem.indexOf(u8, mem.span(decl.name), "$") == null) {
                // TODO: prevent inline asm constants from being emitted
                if (tv.val.cast(Value.Payload.Bytes)) |payload| {
                    try writer.print("const char *const {} = \"{}\";\n", .{ decl.name, payload.data });
                    std.debug.warn("\n\nARRAYTRANS\n", .{});
                    if (tv.ty.arraySentinel()) |sentinel| {}
                } else {
                    return error.Unimplemented;
                }
            }
        },
        else => |e| {
            std.debug.warn("\nTODO implement {}\n", .{e});
            return error.Unimplemented;
        },
    }
}
