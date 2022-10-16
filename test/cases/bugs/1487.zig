const std = @import("std");
const assert = std.debug.assert;

var a = &init().field;

const Foo = struct {
    field: i32,
};

fn init() Foo {
    return Foo{ .field = 1234 };
}

test "oaeu" {
    assert(a.* == 1234);
    a.* += 1;
    assert(a.* == 1235);
}

// error
// is_test=1
// backend=llvm
//
// :16:9: error: cannot assign to constant
