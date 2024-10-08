const print = @import("std").debug.print;

pub fn main() void {
    var x: u32 = undefined;

    const tuple = .{ 1, 2, 3 };

    x, var y : u32, const z = tuple;

    print("x = {}\n", .{x});
    print("y = {}\n", .{y});
    print("z = {}\n", .{z});

    // y is mutable
    y = 100;
}

// exe=succeed
