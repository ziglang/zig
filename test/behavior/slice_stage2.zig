const std = @import("std");
const expect = std.testing.expect;

const x = @intToPtr([*]i32, 0x1000)[0..0x500];
const y = x[0x100..];
test "compile time slice of pointer to hard coded address" {
    try expect(@ptrToInt(x) == 0x1000);
    try expect(x.len == 0x500);

    try expect(@ptrToInt(y) == 0x1400);
    try expect(y.len == 0x400);
}
