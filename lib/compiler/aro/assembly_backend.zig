const std = @import("std");

const aro = @import("aro");

pub const x86_64 = @import("assembly_backend/x86_64.zig");

pub fn genAsm(target: std.Target, tree: *const aro.Tree) aro.Compilation.Error!aro.Assembly {
    return switch (target.cpu.arch) {
        .x86_64 => x86_64.genAsm(tree),
        else => std.debug.panic("genAsm not implemented: {s}", .{@tagName(target.cpu.arch)}),
    };
}
