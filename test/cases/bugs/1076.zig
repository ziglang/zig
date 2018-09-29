const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

test "comptime code should not modify constant data" {
    testCastPtrOfArrayToSliceAndPtr();
    comptime testCastPtrOfArrayToSliceAndPtr();
}

fn testCastPtrOfArrayToSliceAndPtr() void {
    var array = "aoeu";
    const x: [*]u8 = &array;
    x[0] += 1;
    assert(mem.eql(u8, array[0..], "boeu"));
}

