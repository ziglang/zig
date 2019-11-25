const std = @import("std");
const mem = std.mem;
const expect = std.testing.expect;

test "comptime code should not modify constant data" {
    testCastPtrOfArrayToSliceAndPtr();
    comptime testCastPtrOfArrayToSliceAndPtr();
}

fn testCastPtrOfArrayToSliceAndPtr() void {
    {
        var array = "aoeu".*;
        const x: [*]u8 = &array;
        x[0] += 1;
        expect(mem.eql(u8, array[0..], "boeu"));
    }
    {
        var array: [4]u8 = "aoeu".*;
        const x: [*]u8 = &array;
        x[0] += 1;
        expect(mem.eql(u8, array[0..], "boeu"));
    }
}
