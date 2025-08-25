const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Interner = @import("../../Interner.zig");
const Ir = @import("../../Ir.zig");
const BaseRenderer = Ir.Renderer;
const zig = @import("zig");
const abi = zig.arch.x86_64.abi;
const bits = zig.arch.x86_64.bits;

const Condition = bits.Condition;
const Immediate = bits.Immediate;
const Memory = bits.Memory;
const Register = bits.Register;
const RegisterLock = RegisterManager.RegisterLock;
const FrameIndex = bits.FrameIndex;

const RegisterManager = zig.RegisterManager(Renderer, Register, Ir.Ref, abi.allocatable_regs);

// Register classes
const RegisterBitSet = RegisterManager.RegisterBitSet;
const RegisterClass = struct {
    const gp: RegisterBitSet = blk: {
        var set = RegisterBitSet.initEmpty();
        for (abi.allocatable_regs, 0..) |reg, index| if (reg.class() == .general_purpose) set.set(index);
        break :blk set;
    };
    const x87: RegisterBitSet = blk: {
        var set = RegisterBitSet.initEmpty();
        for (abi.allocatable_regs, 0..) |reg, index| if (reg.class() == .x87) set.set(index);
        break :blk set;
    };
    const sse: RegisterBitSet = blk: {
        var set = RegisterBitSet.initEmpty();
        for (abi.allocatable_regs, 0..) |reg, index| if (reg.class() == .sse) set.set(index);
        break :blk set;
    };
};

const Renderer = @This();

base: *BaseRenderer,
interner: *Interner,

register_manager: RegisterManager = .{},

pub fn render(base: *BaseRenderer) !void {
    var renderer: Renderer = .{
        .base = base,
        .interner = base.ir.interner,
    };

    for (renderer.base.ir.decls.keys(), renderer.base.ir.decls.values()) |name, decl| {
        renderer.renderFn(name, decl) catch |e| switch (e) {
            error.OutOfMemory => return e,
            error.LowerFail => continue,
        };
    }
    if (renderer.base.errors.entries.len != 0) return error.LowerFail;
}

fn renderFn(r: *Renderer, name: []const u8, decl: Ir.Decl) !void {
    _ = decl;
    return r.base.fail(name, "TODO implement lowering functions", .{});
}
