const print = @import("std").debug.print;

pub fn main() void {
    var x: u32 = undefined;

    const tuple = .{ 1, 2, 3 };

    x, var y : u32, const z = tuple;

    print("x = {}, y = {}, z = {}\n", .{x, y, z});

    // y is mutable
    y = 100;

    // You can use _ to throw away unwanted values.
    _, x, _ = tuple;

    print("x = {}", .{x});
}

// exe=succeed
