const std = @import("std");
const zir = @import("../zir.zig");
const Value = @import("../value.zig").Value;
const Type = @import("../type.zig").Type;
const Module = @import("../Module.zig");
const Scope = Module.Scope;
const Struct = @This();

base: Type.Payload = .{ .tag = .@"struct" },

analysis: union(enum) {
    queued: Zir,
    zero_bits_in_progress,
    zero_bits: Zero,
    in_progress,
    // alignment: Align,
    resolved: Size,
    failed,
},
scope: Scope.Container,

pub const Field = struct {
    value: Value,
};

pub const Zir = struct {
    body: zir.Body,
    inst: *zir.Inst,
};

pub const Zero = struct {
    is_zero_bits: bool,
    fields: std.StringArrayHashMapUnmanaged(Field),
};

pub const Size = struct {
    is_zero_bits: bool,
    alignment: u32,
    size: u32,
    fields: std.StringArrayHashMapUnmanaged(Field),
};

pub fn resolveZeroBits(self: *Struct, mod: *Module, scope: *Scope) !void {
    const zir = switch (self.analysis) {
        .failed => return error.AnalysisFail,
        .zero_bits_in_progress => {
            return mod.fail(scope, src, "struct '{}' depends on itself", .{});
        },
        .queued => |zir| zir,
        else => return,
    };

    self.analysis = .zero_bits_in_progress;

    // TODO
}
