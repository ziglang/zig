const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const mem = std.mem;
const cstr = std.cstr;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;

test "volatile load and store" {
    var number: i32 = 1234;
    const ptr = (*volatile i32)(&number);
    ptr.* += 1;
    assertOrPanic(ptr.* == 1235);
}

test "slice string literal has type []const u8" {
    comptime {
        assertOrPanic(@typeOf("aoeu"[0..]) == []const u8);
        const array = []i32{
            1,
            2,
            3,
            4,
        };
        assertOrPanic(@typeOf(array[0..]) == []const i32);
    }
}

test "pointer child field" {
    assertOrPanic((*u32).Child == u32);
}

test "struct inside function" {
    testStructInFn();
    comptime testStructInFn();
}

fn testStructInFn() void {
    const BlockKind = u32;

    const Block = struct {
        kind: BlockKind,
    };

    var block = Block{ .kind = 1234 };

    block.kind += 1;

    assertOrPanic(block.kind == 1235);
}
