const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "@sizeOf(T) == 0 doesn't force resolving struct size" {
    const S = struct {
        const Foo = struct {
            y: if (@sizeOf(Foo) == 0) u64 else u32,
        };
        const Bar = struct {
            x: i32,
            y: if (0 == @sizeOf(Bar)) u64 else u32,
        };
    };

    try expect(@sizeOf(S.Foo) == 4);
    try expect(@sizeOf(S.Bar) == 8);
}

test "@TypeOf() has no runtime side effects" {
    const S = struct {
        fn foo(comptime T: type, ptr: *T) T {
            ptr.* += 1;
            return ptr.*;
        }
    };
    var data: i32 = 0;
    const T = @TypeOf(S.foo(i32, &data));
    comptime try expect(T == i32);
    try expect(data == 0);
}

test "branching logic inside @TypeOf" {
    const S = struct {
        var data: i32 = 0;
        fn foo() anyerror!i32 {
            data += 1;
            return undefined;
        }
    };
    const T = @TypeOf(S.foo() catch undefined);
    comptime try expect(T == i32);
    try expect(S.data == 0);
}

test "@bitSizeOf" {
    try expect(@bitSizeOf(u2) == 2);
    try expect(@bitSizeOf(u8) == @sizeOf(u8) * 8);
    try expect(@bitSizeOf(struct {
        a: u2,
    }) == 8);
    try expect(@bitSizeOf(packed struct {
        a: u2,
    }) == 2);
}

test "@sizeOf comparison against zero" {
    const S0 = struct {
        f: *@This(),
    };
    const U0 = union {
        f: *@This(),
    };
    const S1 = struct {
        fn H(comptime T: type) type {
            return struct {
                x: T,
            };
        }
        f0: H(*@This()),
        f1: H(**@This()),
        f2: H(***@This()),
    };
    const U1 = union {
        fn H(comptime T: type) type {
            return struct {
                x: T,
            };
        }
        f0: H(*@This()),
        f1: H(**@This()),
        f2: H(***@This()),
    };
    const S = struct {
        fn doTheTest(comptime T: type, comptime result: bool) !void {
            try expectEqual(result, @sizeOf(T) > 0);
        }
    };
    // Zero-sized type
    try S.doTheTest(u0, false);
    try S.doTheTest(*u0, false);
    // Non byte-sized type
    try S.doTheTest(u1, true);
    try S.doTheTest(*u1, true);
    // Regular type
    try S.doTheTest(u8, true);
    try S.doTheTest(*u8, true);
    try S.doTheTest(f32, true);
    try S.doTheTest(*f32, true);
    // Container with ptr pointing to themselves
    try S.doTheTest(S0, true);
    try S.doTheTest(U0, true);
    try S.doTheTest(S1, true);
    try S.doTheTest(U1, true);
}
