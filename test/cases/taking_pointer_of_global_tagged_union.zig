const std = @import("std");

const A = union(enum) { hello: usize, merp: void };

var global_a: A = .{ .hello = 12 };
var global_usize: usize = 0;

fn doSomethingWithUsize(ptr: *usize) usize {
    ptr.* = ptr.* + 1;
    return ptr.*;
}

pub fn main() !void {
    try std.testing.expect(doSomethingWithUsize(&global_usize) == 1);

    switch (global_a) {
        .merp => return,
        .hello => |*value| {
            try std.testing.expect(doSomethingWithUsize(value) == 13);
        },
    }
}

// run
// backend=llvm
// target=native
