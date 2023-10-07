const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "access of union field 'float' while field 'int' is active")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

const Foo = union {
    float: f32,
    int: u32,
};

pub fn main() !void {
    var f = Foo{ .int = 42 };
    bar(&f);
    return error.TestFailed;
}

fn bar(f: *Foo) void {
    f.float = 12.34;
}
// run
// backend=llvm
// target=native
