const std = @import("std");

const MyStruct = struct {
    foobar: u8,
};

var my_struct1 = MyStruct{ .foobar = 1 };
var my_struct2 = MyStruct{ .foobar = 2 };
var my_struct3 = MyStruct{ .foobar = 3 };
var my_struct4 = MyStruct{ .foobar = 4 };
const foo: []const *MyStruct = &[_]*MyStruct{ &my_struct1, &my_struct2, &my_struct3, &my_struct4 };
const bar: []const *MyStruct = foo[0..2] ++ foo[2..];

pub fn main() !void {
    try std.testing.expect(bar[0].*.foobar == 1 and
        bar[1].*.foobar == 2 and
        bar[2].*.foobar == 3 and
        bar[3].*.foobar == 4);
}

// run
//
