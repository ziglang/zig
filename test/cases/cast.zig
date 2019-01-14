const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const mem = std.mem;
const maxInt = std.math.maxInt;

test "peer type resolution: ?T and T" {
    assertOrPanic(peerTypeTAndOptionalT(true, false).? == 0);
    assertOrPanic(peerTypeTAndOptionalT(false, false).? == 3);
    comptime {
        assertOrPanic(peerTypeTAndOptionalT(true, false).? == 0);
        assertOrPanic(peerTypeTAndOptionalT(false, false).? == 3);
    }
}
fn peerTypeTAndOptionalT(c: bool, b: bool) ?usize {
    if (c) {
        return if (b) null else usize(0);
    }

    return usize(3);
}

test "implicitly cast from [N]T to ?[]const T" {
    assertOrPanic(mem.eql(u8, castToOptionalSlice().?, "hi"));
    comptime assertOrPanic(mem.eql(u8, castToOptionalSlice().?, "hi"));
}

fn castToOptionalSlice() ?[]const u8 {
    return "hi";
}

test "implicitly cast from [0]T to anyerror![]T" {
    testCastZeroArrayToErrSliceMut();
    comptime testCastZeroArrayToErrSliceMut();
}

fn testCastZeroArrayToErrSliceMut() void {
    assertOrPanic((gimmeErrOrSlice() catch unreachable).len == 0);
}

fn gimmeErrOrSlice() anyerror![]u8 {
    return []u8{};
}

test "peer type resolution: [0]u8, []const u8, and anyerror![]u8" {
    {
        var data = "hi";
        const slice = data[0..];
        assertOrPanic((try peerTypeEmptyArrayAndSliceAndError(true, slice)).len == 0);
        assertOrPanic((try peerTypeEmptyArrayAndSliceAndError(false, slice)).len == 1);
    }
    comptime {
        var data = "hi";
        const slice = data[0..];
        assertOrPanic((try peerTypeEmptyArrayAndSliceAndError(true, slice)).len == 0);
        assertOrPanic((try peerTypeEmptyArrayAndSliceAndError(false, slice)).len == 1);
    }
}
fn peerTypeEmptyArrayAndSliceAndError(a: bool, slice: []u8) anyerror![]u8 {
    if (a) {
        return []u8{};
    }

    return slice[0..1];
}

test "peer type resolution: error and [N]T" {
    // TODO: implicit error!T to error!U where T can implicitly cast to U
    //assertOrPanic(mem.eql(u8, try testPeerErrorAndArray(0), "OK"));
    //comptime assertOrPanic(mem.eql(u8, try testPeerErrorAndArray(0), "OK"));
    assertOrPanic(mem.eql(u8, try testPeerErrorAndArray2(1), "OKK"));
    comptime assertOrPanic(mem.eql(u8, try testPeerErrorAndArray2(1), "OKK"));
}

//fn testPeerErrorAndArray(x: u8) error![]const u8 {
//    return switch (x) {
//        0x00 => "OK",
//        else => error.BadValue,
//    };
//}
fn testPeerErrorAndArray2(x: u8) anyerror![]const u8 {
    return switch (x) {
        0x00 => "OK",
        0x01 => "OKK",
        else => error.BadValue,
    };
}

test "const slice widen cast" {
    const bytes align(4) = []u8{
        0x12,
        0x12,
        0x12,
        0x12,
    };

    const u32_value = @bytesToSlice(u32, bytes[0..])[0];
    assertOrPanic(u32_value == 0x12121212);

    assertOrPanic(@bitCast(u32, bytes) == 0x12121212);
}

test "@bytesToSlice keeps pointer alignment" {
    var bytes = []u8{ 0x01, 0x02, 0x03, 0x04 };
    const numbers = @bytesToSlice(u32, bytes[0..]);
    comptime assertOrPanic(@typeOf(numbers) == []align(@alignOf(@typeOf(bytes))) u32);
}

test "implicit ptr to *c_void" {
    var a: u32 = 1;
    var ptr: *c_void = &a;
    var b: *u32 = @ptrCast(*u32, ptr);
    assertOrPanic(b.* == 1);
    var ptr2: ?*c_void = &a;
    var c: *u32 = @ptrCast(*u32, ptr2.?);
    assertOrPanic(c.* == 1);
}

