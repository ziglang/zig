const std = @import("std");
const debug = std.debug;
const assert = debug.assert;
const builtin = @import("builtin");

test "allocator correctly allocates aligned memory"
{
    if (builtin.arch != builtin.Arch.x86_64) {
        return error.SkipZigTest;
    }

    assert(@sizeOf(u24) == 3);
    assert(@alignOf(u24) == 4);
    assert(@alignedSizeOf(u24) == 4);

    var two_u24 = try debug.global_allocator.alloc(u24, 2);
    assert(two_u24.len == 2); // should give us two u24s
    var two_u24_bytes = @sliceToBytes(two_u24);
    assert(two_u24_bytes.len == 8); // bug was that it was assigning 6 bytes instead of 8

    two_u24[0] = 0xFFFFFF;
    two_u24[1] = 0xFFFFFF;

    // operate on bytes
    for(@alignCast(1, two_u24_bytes)) |*b| b.* = 0x00;

    assert(two_u24[0] == 0x00);
    assert(two_u24[1] == 0x00);
}
