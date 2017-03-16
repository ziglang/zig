const assert = @import("std").debug.assert;

const module = this;

fn Point(comptime T: type) -> type {
    struct {
        const Self = this;
        x: T,
        y: T,

        fn addOne(self: &Self) {
            self.x += 1;
            self.y += 1;
        }
    }
}

fn add(x: i32, y: i32) -> i32 {
    x + y
}

fn factorial(x: i32) -> i32 {
    const selfFn = this;
    if (x == 0) {
        1
    } else {
        x * selfFn(x - 1)
    }
}

test "thisReferToModuleCallPrivateFn" {
    assert(module.add(1, 2) == 3);
}

test "thisReferToContainer" {
    var pt = Point(i32) {
        .x = 12,
        .y = 34,
    };
    pt.addOne();
    assert(pt.x == 13);
    assert(pt.y == 35);
}

test "thisReferToFn" {
    assert(factorial(5) == 120);
}
