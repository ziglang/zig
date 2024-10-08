const print = @import("std").debug.print;

pub fn main() void {
    var x: u32 = undefined;
    var y: u32 = undefined;
    var z: u32 = undefined;

    const tuple = .{ 1, 2, 3 };

    x, y, z = tuple;

    print("x = {}\n", .{x});
    print("y = {}\n", .{y});
    print("z = {}\n", .{z});
}

// exe=succeed
