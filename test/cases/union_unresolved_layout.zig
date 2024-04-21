const std = @import("std");

const U = union(enum) {
    foo: u8,
    bar: f64,
};

pub fn main() !void {
    const t = U.foo;
    _ = t;
}

// run
// backend=llvm
//
