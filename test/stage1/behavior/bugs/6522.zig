const std = @import("std");

const TestStruct = struct {
    pub const Array = [_][]const u8{
        "foo", "bar", "baz",
    };
};

test "slicing array to smaller pointer to array at comptime" {
    const slice = TestStruct.Array[0..2];
    _ = slice[0];
}
