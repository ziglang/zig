const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "sentinel mismatch: expected tmp.main.S{ .a = 1 }, found tmp.main.S{ .a = 2 }")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    const S = struct { a: u32 };
    var arr = [_]S{ .{ .a = 1 }, .{ .a = 2 } };
    const s = arr[0..1 :.{ .a = 1 }];
    _ = s;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native
