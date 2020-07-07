const link = @import("link.zig");
const Module = @import("Module.zig");
const ir = @import("ir.zig");
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const std = @import("std");

const C = link.File.C;
const Decl = Module.Decl;
const CStandard = Module.CStandard;
const mem = std.mem;

/// Maps a name from Zig source to C. This will always give the same output for
/// any given input.
fn map(name: []const u8) ![]const u8 {
    return name;
}

fn renderFunctionSignature(writer: std.ArrayList(u8).Writer, decl: *Decl) !void {
    const tv = decl.typed_value.most_recent.typed_value;
    switch (tv.ty.fnReturnType().zigTypeTag()) {
        .NoReturn => {
            try writer.writeAll("_Noreturn void ");
        },
        else => return error.Unimplemented,
    }
    const name = try map(mem.spanZ(decl.name));
    try writer.print("{}(", .{name});
    if (tv.ty.fnParamLen() == 0) {
        try writer.writeAll("void)");
    } else {
        return error.Unimplemented;
    }
}

pub fn generate(file: *C, decl: *Decl, standard: CStandard) !void {
    const writer = file.main.writer();
    const header = file.header.writer();
    const tv = decl.typed_value.most_recent.typed_value;
    switch (tv.ty.zigTypeTag()) {
        .Fn => {
            try renderFunctionSignature(writer, decl);
            try writer.writeAll(" {");

            const func: *Module.Fn = tv.val.cast(Value.Payload.Function).?.func;
            const instructions = func.analysis.success.instructions;
            if (instructions.len > 0) {
                for (instructions) |inst| {
                    try writer.writeAll("\n\t");
                    switch (inst.tag) {
                        .call => {
                            const call = inst.cast(ir.Inst.Call).?.args;
                            if (call.func.cast(ir.Inst.Constant)) |func_inst| {
                                if (func_inst.val.cast(Value.Payload.Function)) |func_val| {
                                    const target = func_val.func.owner_decl;
                                    const tname = mem.spanZ(target.name);
                                    if (file.called.get(tname) == null) {
                                        try file.called.put(tname, void{});
                                        try renderFunctionSignature(header, target);
                                        try header.writeAll(";\n");
                                    }
                                    try writer.print("{}();", .{tname});
                                } else {
                                    return error.Unimplemented;
                                }
                                if (call.args.len != 0) {
                                    return error.Unimplemented;
                                }
                            } else {
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
        else => return error.Unimplemented,
    }
}
