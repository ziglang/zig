const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const mem = std.mem;
const cstr = std.cstr;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;

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
