const std = @import("std");
const expect = std.testing.expect;
const builtin = @import("builtin");
const native_arch = builtin.target.cpu.arch;

test "page aligned array on stack" {
    // Large alignment value to make it hard to accidentally pass.
    var array align(0x1000) = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var number1: u8 align(16) = 42;
    var number2: u8 align(16) = 43;

    try expect(@ptrToInt(&array[0]) & 0xFFF == 0);
    try expect(array[3] == 4);

    try expect(@truncate(u4, @ptrToInt(&number1)) == 0);
    try expect(@truncate(u4, @ptrToInt(&number2)) == 0);
    try expect(number1 == 42);
    try expect(number2 == 43);
}
