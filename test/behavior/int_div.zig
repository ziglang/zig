const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "integer division" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testDivision();
    try comptime testDivision();
}
fn testDivision() !void {
    try expect(div(u32, 13, 3) == 4);
    try expect(div(u64, 13, 3) == 4);
    try expect(div(u8, 13, 3) == 4);

    try expect(divExact(u32, 55, 11) == 5);
    try expect(divExact(i32, -55, 11) == -5);
    try expect(divExact(i64, -55, 11) == -5);
    try expect(divExact(i16, -55, 11) == -5);

    try expect(divFloor(i8, 5, 3) == 1);
    try expect(divFloor(i16, -5, 3) == -2);
    try expect(divFloor(i64, -0x80000000, -2) == 0x40000000);
    try expect(divFloor(i32, 0, -0x80000000) == 0);
    try expect(divFloor(i64, -0x40000001, 0x40000000) == -2);
    try expect(divFloor(i32, -0x80000000, 1) == -0x80000000);
    try expect(divFloor(i32, 10, 12) == 0);
    try expect(divFloor(i32, -14, 12) == -2);
    try expect(divFloor(i32, -2, 12) == -1);

    try expect(divTrunc(i32, 5, 3) == 1);
    try expect(divTrunc(i32, -5, 3) == -1);
    try expect(divTrunc(i32, 9, -10) == 0);
    try expect(divTrunc(i32, -9, 10) == 0);
    try expect(divTrunc(i32, 10, 12) == 0);
    try expect(divTrunc(i32, -14, 12) == -1);
    try expect(divTrunc(i32, -2, 12) == 0);

    try expect(mod(u32, 10, 12) == 10);
    try expect(mod(i32, 10, 12) == 10);
    try expect(mod(i64, -14, 12) == 10);
    try expect(mod(i16, -2, 12) == 10);
    try expect(mod(i8, -2, 12) == 10);

    try expect(rem(i32, 10, 12) == 10);
    try expect(rem(i32, -14, 12) == -2);
    try expect(rem(i32, -2, 12) == -2);

    comptime {
        try expect(
            1194735857077236777412821811143690633098347576 % 508740759824825164163191790951174292733114988 == 177254337427586449086438229241342047632117600,
        );
        try expect(
            @rem(-1194735857077236777412821811143690633098347576, 508740759824825164163191790951174292733114988) == -177254337427586449086438229241342047632117600,
        );
        try expect(
            1194735857077236777412821811143690633098347576 / 508740759824825164163191790951174292733114988 == 2,
        );
        try expect(
            @divTrunc(-1194735857077236777412821811143690633098347576, 508740759824825164163191790951174292733114988) == -2,
        );
        try expect(
            @divTrunc(1194735857077236777412821811143690633098347576, -508740759824825164163191790951174292733114988) == -2,
        );
        try expect(
            @divTrunc(-1194735857077236777412821811143690633098347576, -508740759824825164163191790951174292733114988) == 2,
        );
        try expect(
            4126227191251978491697987544882340798050766755606969681711 % 10 == 1,
        );
    }
}
fn div(comptime T: type, a: T, b: T) T {
    return a / b;
}
fn divExact(comptime T: type, a: T, b: T) T {
    return @divExact(a, b);
}
fn divFloor(comptime T: type, a: T, b: T) T {
    return @divFloor(a, b);
}
fn divTrunc(comptime T: type, a: T, b: T) T {
    return @divTrunc(a, b);
}
fn mod(comptime T: type, a: T, b: T) T {
    return @mod(a, b);
}
fn rem(comptime T: type, a: T, b: T) T {
    return @rem(a, b);
}

test "large integer division" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    {
        var numerator: u256 = 99999999999999999997315645440;
        var divisor: u256 = 10000000000000000000000000000;
        _ = .{ &numerator, &divisor };
        try expect(numerator / divisor == 9);
    }
    {
        var numerator: u256 = 99999999999999999999000000000000000000000;
        var divisor: u256 = 10000000000000000000000000000000000000000;
        _ = .{ &numerator, &divisor };
        try expect(numerator / divisor == 9);
    }
}
