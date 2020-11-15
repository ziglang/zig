const std = @import("std");
const Value = @import("../value.zig").Value;
const Type = @import("../type.zig").Type;
const Module = @import("../Module.zig");
const Scope = Module.Scope;

base: Type.Payload = .{ .tag = .@"enum" },

analysis: union(enum) {
    queued: Zir,
    in_progress,
    resolved: Size,
    failed,
},

pub const Field = struct {
    value: Value,
};

pub const Zir = struct {
    body: zir.Module.Body,
    inst: *zir.Inst,
    arena: std.heap.ArenaAllocator.State,
};

pub const Size = struct {
    is_zero_bits: bool,
    alignment: u32,
    size: u32,
    fields: std.AutoArrayHashMap([]const u8, Field),
};

pub fn resolve(self: *Enum, mod: *Module, scope: *Scope) !void {
    const zir = switch (self.analysis) {
        .failed => return error.AnalysisFail,
        .resolved => return,
        .in_progress => {
            return mod.fail(scope, src, "enum '{}' depends on itself", .{enum_name});
        },
        .queued => |zir| zir,
    };
    self.analysis = .in_progress;

    // TODO
}

// TODO should this resolve the type or assert that it has already been resolved?
pub fn abiAlignment(self: *Enum) u32 {
    switch (self.analysis) {
        .queued => unreachable, // alignment has not been resolved
        .in_progress => unreachable, // alignment has not been resolved
        .failed => unreachable, // type resolution failed
        .resolved => |r| return r.tag_type.abiAlignment(),
    }
}
