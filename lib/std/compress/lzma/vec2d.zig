const std = @import("../../std.zig");
const math = std.math;
const mem = std.mem;
const Allocator = std.mem.Allocator;

pub fn Vec2D(comptime T: type) type {
    return struct {
        data: []T,
        cols: usize,

        const Self = @This();

        pub fn init(allocator: Allocator, value: T, size: struct { usize, usize }) !Self {
            const len = try math.mul(usize, size[0], size[1]);
            const data = try allocator.alloc(T, len);
            @memset(data, value);
            return Self{
                .data = data,
                .cols = size[1],
            };
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            allocator.free(self.data);
            self.* = undefined;
        }

        pub fn fill(self: *Self, value: T) void {
            @memset(self.data, value);
        }

        inline fn _get(self: Self, row: usize) ![]T {
            const start_row = try math.mul(usize, row, self.cols);
            const end_row = try math.add(usize, start_row, self.cols);
            return self.data[start_row..end_row];
        }

        pub fn get(self: Self, row: usize) ![]const T {
            return self._get(row);
        }

        pub fn getMut(self: *Self, row: usize) ![]T {
            return self._get(row);
        }
    };
}

const testing = std.testing;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectError = std.testing.expectError;

test "init" {
    const allocator = testing.allocator;
    var vec2d = try Vec2D(i32).init(allocator, 1, .{ 2, 3 });
    defer vec2d.deinit(allocator);

    try expectEqualSlices(i32, &.{ 1, 1, 1 }, try vec2d.get(0));
    try expectEqualSlices(i32, &.{ 1, 1, 1 }, try vec2d.get(1));
}

test "init overflow" {
    const allocator = testing.allocator;
    try expectError(
        error.Overflow,
        Vec2D(i32).init(allocator, 1, .{ math.maxInt(usize), math.maxInt(usize) }),
    );
}

test "fill" {
    const allocator = testing.allocator;
    var vec2d = try Vec2D(i32).init(allocator, 0, .{ 2, 3 });
    defer vec2d.deinit(allocator);

    vec2d.fill(7);

    try expectEqualSlices(i32, &.{ 7, 7, 7 }, try vec2d.get(0));
    try expectEqualSlices(i32, &.{ 7, 7, 7 }, try vec2d.get(1));
}

test "get" {
    var data = [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const vec2d = Vec2D(i32){
        .data = &data,
        .cols = 2,
    };

    try expectEqualSlices(i32, &.{ 0, 1 }, try vec2d.get(0));
    try expectEqualSlices(i32, &.{ 2, 3 }, try vec2d.get(1));
    try expectEqualSlices(i32, &.{ 4, 5 }, try vec2d.get(2));
    try expectEqualSlices(i32, &.{ 6, 7 }, try vec2d.get(3));
}

test "getMut" {
    var data = [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7 };
    var vec2d = Vec2D(i32){
        .data = &data,
        .cols = 2,
    };

    const row = try vec2d.getMut(1);
    row[1] = 9;

    try expectEqualSlices(i32, &.{ 0, 1 }, try vec2d.get(0));
    // (1, 1) should be 9.
    try expectEqualSlices(i32, &.{ 2, 9 }, try vec2d.get(1));
    try expectEqualSlices(i32, &.{ 4, 5 }, try vec2d.get(2));
    try expectEqualSlices(i32, &.{ 6, 7 }, try vec2d.get(3));
}

test "get multiplication overflow" {
    const allocator = testing.allocator;
    var matrix = try Vec2D(i32).init(allocator, 0, .{ 3, 4 });
    defer matrix.deinit(allocator);

    const row = (math.maxInt(usize) / 4) + 1;
    try expectError(error.Overflow, matrix.get(row));
    try expectError(error.Overflow, matrix.getMut(row));
}

test "get addition overflow" {
    const allocator = testing.allocator;
    var matrix = try Vec2D(i32).init(allocator, 0, .{ 3, 5 });
    defer matrix.deinit(allocator);

    const row = math.maxInt(usize) / 5;
    try expectError(error.Overflow, matrix.get(row));
    try expectError(error.Overflow, matrix.getMut(row));
}
