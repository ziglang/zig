const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    switch (cause) {
        .inactive_union_field => |info| {
            if (std.mem.eql(u8, info.active, "int") and
                std.mem.eql(u8, info.accessed, "float"))
            {
                std.process.exit(0);
            }
        },
        else => {},
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
