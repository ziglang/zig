const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "casting integer address to function pointer" {
    addressToFunction();
    comptime addressToFunction();
}

fn addressToFunction() void {
    var addr: usize = 0xdeadbee0;
    _ = &addr;
    _ = @as(*const fn () void, @ptrFromInt(addr));
}

test "mutate through ptr initialized with constant ptrFromInt value" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    forceCompilerAnalyzeBranchHardCodedPtrDereference(false);
}

fn forceCompilerAnalyzeBranchHardCodedPtrDereference(x: bool) void {
    const hardCodedP = @as(*volatile u8, @ptrFromInt(0xdeadbeef));
    if (x) {
        hardCodedP.* = hardCodedP.* | 10;
    } else {
        return;
    }
}

test "@ptrFromInt creates null pointer" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTest(addr: usize) !void {
            const ptr: ?*u32 = @ptrFromInt(addr);
            try expectEqual(null, ptr);
        }
    };

    try S.doTest(0);
    comptime try S.doTest(0);
}

test "@ptrFromInt creates allowzero zero pointer" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTest(addr: usize) !void {
            const ptr: *allowzero const u32 = @ptrFromInt(addr);
            try expectEqual(addr, @intFromPtr(ptr));
        }
    };

    try S.doTest(0);
    comptime try S.doTest(0);
}

test "@ptrFromInt creates optional allowzero zero pointer" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTest(addr: usize) !void {
            const ptr: ?*allowzero const u32 = @ptrFromInt(addr);
            try expect(ptr != null);
        }
    };

    try S.doTest(0);
    comptime try S.doTest(0);
}
