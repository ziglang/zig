const std = @import("std");
const Value = @import("../value.zig").Value;
const Type = @import("../type.zig").Type;
const Module = @import("../Module.zig");
const Scope = Module.Scope;

base: Type.Payload = .{ .tag = .@"struct" },

analysis: union(enum) {
    queued: Zir,
    zero_bits_in_progress,
    zero_bits: Zero,
    in_progress,
    alignment: Align,
    resolved: Size,
    failed,
},
scope: Scope.Container,

pub const Field = struct {
    value: Value,
};

pub const Zir = struct {
    body: zir.Module.Body,
    inst: *zir.Inst,
    arena: std.heap.ArenaAllocator.State,
};

pub const Zero = struct {
    is_zero_bits: bool,
    fields: std.AutoArrayHashMap([]const u8, Field),
};

pub const Size = struct {
    is_zero_bits: bool,
    alignment: u32,
    size: u32,
    fields: std.AutoArrayHashMap([]const u8, Field),
};

pub fn resolveZeroBits(self: *Enum, mod: *Module, scope: *Scope) !void {
    const zir = switch (self.analysis) {
        .failed => return error.AnalysisFail,
        .zero_bits_in_progress => {
            return mod.fail(scope, src, "union '{}' depends on itself", .{});
        },
        .queued => |zir| zir,
        else => return,
    };

    self.analysis = .zero_bits_in_progress;

    // TODO
}

pub fn resolveSize(self: *Enum,)