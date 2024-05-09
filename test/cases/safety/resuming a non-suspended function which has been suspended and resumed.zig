const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
fn foo() void {
    suspend {
        global_frame = @frame();
    }
    var f = async bar(@frame());
    _ = &f;
    std.process.exit(1);
}

fn bar(frame: anyframe) void {
    suspend {
        resume frame;
    }
    std.process.exit(1);
}

var global_frame: anyframe = undefined;
pub fn main() !void {
    _ = async foo();
    resume global_frame;
    std.process.exit(1);
}
// run
// backend=stage1
// target=native
