const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}

const Foo = union {
    float: f32,
    int: u32,
};

pub fn main() !void {
    var f = Foo { .int = 42 };
    bar(&f);
    return error.TestFailed;
}

fn bar(f: *Foo) void {
    f.float = 12.34;
}
// run
// backend=stage1
// target=native