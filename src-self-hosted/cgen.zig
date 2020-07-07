const link = @import("link.zig");
const Module = @import("Module.zig");
const std = @import("std");
const Value = @import("value.zig").Value;

const C = link.File.C;
const Decl = Module.Decl;
const CStandard = Module.CStandard;
const mem = std.mem;

/// Maps a name from Zig source to C. This will always give the same output for
/// any given input.
fn map(name: []const u8) ![]const u8 {
    return name;
}

pub fn generate(file: *C, decl: *Decl, standard: CStandard) !void {
    const writer = file.file.?.writer();
    const tv = decl.typed_value.most_recent.typed_value;
    switch (tv.ty.zigTypeTag()) {
        .Fn => {
            const return_type = tv.ty.fnReturnType();
            switch (return_type.zigTypeTag()) {
                .NoReturn => try writer.writeAll("_Noreturn void "),
                else => return error.Unimplemented,
            }

            const name = try map(mem.spanZ(decl.name));
            try writer.print("{} (", .{name});
            if (tv.ty.fnParamLen() == 0) {
                try writer.writeAll("void){");
            } else {
                return error.Unimplemented;
            }

            const func: *Module.Fn = tv.val.cast(Value.Payload.Function).?.func;
            const instructions = func.analysis.success.instructions;
            if (instructions.len > 0) {
                try writer.writeAll("\n\t");
                for (instructions) |inst| {
                    std.debug.warn("\nTranslating {}\n", .{inst.*});
                }
                try writer.writeAll("\n");
            }

            try writer.writeAll("}\n");
        },
        else => return error.Unimplemented,
    }
}
