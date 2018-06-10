const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;

pub fn main() !void {
    var direct = std.heap.DirectAllocator.init();
    defer direct.deinit();

    const bytes = try std.io.readFileAlloc(&direct.allocator, "zig-cache/liblib.a");
    defer direct.allocator.free(bytes);

    // Verify that it is a wasm file and has the symbol "add" somewhere in it.
    assert(mem.indexOf(u8, bytes, "\x00asm").? == 0);
    assert(mem.indexOf(u8, bytes, "\x03add") != null);
}
