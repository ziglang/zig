const std = @import("std");

test "sizeOf, variant 1" { // breaks in master
    const T = packed struct {
        one: u8,
        three: [3]u8,
    };
    std.testing.expectEqual(@as(usize, 4), @sizeOf(T));
}

test "sizeOf, variant 2" { // doesn't break in master
    const T = packed struct {
        three: [3]u8,
        one: u8,
    };
    std.testing.expectEqual(@as(usize, 4), @sizeOf(T));
}

test "daurnimator (original)" { // breaks in master
    const T = packed struct {
        _1: u1,
        x: u7,
        _: u24,
    };
    std.testing.expectEqual(@as(usize, 4), @sizeOf(T));
}

test "daurnimator (variant 1)" { // doesn't break in master
    const T = packed struct {
        _1: u1,
        x: u7,
        _2: u8,
        _3: u16,
    };
    std.testing.expectEqual(@as(usize, 4), @sizeOf(T));
}

test "daurnimator (variant 2)" { // doesn't break in master
    const T = packed struct {
        _1: u1,
        x: u7,
        _2: u16,
        _3: u8,
    };
    std.testing.expectEqual(@as(usize, 4), @sizeOf(T));
}

test "MasterQ32'1" {
    const Flags1 = packed struct {
        // byte 0
        b0_0: u1,
        b0_1: u1,
        b0_2: u1,
        b0_3: u1,
        b0_4: u1,
        b0_5: u1,
        b0_6: u1,
        b0_7: u1,

        // partial byte 1 (but not 8 bits)
        b1_0: u1,
        b1_1: u1,
        b1_2: u1,
        b1_3: u1,
        b1_4: u1,
        b1_5: u1,
        b1_6: u1,

        // some padding to fill to size 3
        _: u9,
    };
    // TODO: This still breaks
    // std.testing.expectEqual(@as(usize, 4), @sizeOf(Flags1));
}


test "MasterQ32'2" {
    const Flags2 = packed struct {
        // byte 0
        b0_0: u1,
        b0_1: u1,
        b0_2: u1,
        b0_3: u1,
        b0_4: u1,
        b0_5: u1,
        b0_6: u1,
        b0_7: u1,

        // partial byte 1 (but not 8 bits)
        b1_0: u1,
        b1_1: u1,
        b1_2: u1,
        b1_3: u1,
        b1_4: u1,
        b1_5: u1,
        b1_6: u1,

        // some padding that should yield @sizeOf(Flags2) == 4
        _: u10, // this *was* originally 17, but the error happens with 10 as well
    };
    std.testing.expectEqual(@as(usize, 4), @sizeOf(Flags2));
}


test "MasterQ32'3" {
    const Flags3 = packed struct {
        // byte 0
        b0_0: u1,
        b0_1: u1,
        b0_2: u1,
        b0_3: u1,
        b0_4: u1,
        b0_5: u1,
        b0_6: u1,
        b0_7: u1,

        // byte 1
        b1_0: u1,
        b1_1: u1,
        b1_2: u1,
        b1_3: u1,
        b1_4: u1,
        b1_5: u1,
        b1_6: u1,
        b1_7: u1,

        // some padding that should yield @sizeOf(Flags2) == 4
        _: u16, // it works, if the padding is 8-based
    };
    std.testing.expectEqual(@as(usize, 4), @sizeOf(Flags3));
}

test "fix for #3651" {
    const T1 = packed struct {
        array: [3][3]u8, // also with align(1)
    };

    const T2 = packed struct {
        array: [9]u8,
    };
    std.testing.expectEqual(@as(usize, 9), @sizeOf(T1));
    std.testing.expectEqual(@as(usize, 9), @sizeOf(T2));
}
