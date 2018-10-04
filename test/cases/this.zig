const assert = @import("std").debug.assert;

const module = @This();

fn Point(comptime T: type) type {
    return struct.{
        const Self = @This();
        x: T,
        y: T,

        fn addOne(self: *Self) void {
            self.x += 1;
            self.y += 1;
        }
    };
}

fn add(x: i32, y: i32) i32 {
    return x + y;
}

test "this refer to module call private fn" {
    assert(module.add(1, 2) == 3);
}

test "this refer to container" {
    var pt = Point(i32).{
        .x = 12,
        .y = 34,
    };
    pt.addOne();
    assert(pt.x == 13);
    assert(pt.y == 35);
}
