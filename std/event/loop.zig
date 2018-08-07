const std = @import("../index.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const mem = std.mem;
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;
const fs = std.event.fs;
const os = std.os;
const posix = os.posix;
const windows = os.windows;

pub use switch (builtin.os) {
    builtin.Os.linux => @import("loop/linux.zig"),
    builtin.Os.macosx => @import("loop/darwin.zig"),
    builtin.Os.windows => @import("loop/windows.zig"),
    else => @compileError("Unsupported OS"),
};

test "std.event.Loop - basic" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    const allocator = &da.allocator;

    var loop: Loop = undefined;
    try loop.initMultiThreaded(allocator);
    defer loop.deinit();

    loop.run();
}

test "std.event.Loop - call" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    const allocator = &da.allocator;

    var loop: Loop = undefined;
    try loop.initMultiThreaded(allocator);
    defer loop.deinit();

    var did_it = false;
    const handle = try loop.call(testEventLoop);
    const handle2 = try loop.call(testEventLoop2, handle, &did_it);
    defer cancel handle2;

    loop.run();

    assert(did_it);
}

async fn testEventLoop() i32 {
    return 1234;
}

async fn testEventLoop2(h: promise->i32, did_it: *bool) void {
    const value = await h;
    assert(value == 1234);
    did_it.* = true;
}
