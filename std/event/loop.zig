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

// 06:52 <kristate> andrewrk: thinking about breaking-up the loop into separate
//       files for each platform. importing event.loop will import the correct
//       implementation for each OS and we will test the unified API in several test
//       blocks inside of event.loop -- there is just too much custom code between the
//       platforms and with threads, I want to make sure we get this right.
// 06:53 <kristate> andrewrk: it's not as bad as you might imagine. only downside
//       is if we find a bug in one implementation, we will have to make sure to track
//       it down for each other files -- BUT, if we add the appropriate test case for
//       that bug, we should be able to run against all implementations and if the bug
//       does not show, then so be it 
// 06:54 <kristate> andrewrk: I think that this is going to be important as we go
//       forward -- defining the interface as tests in an index file, and then making
//       sure the tests pass in each implementation
// 07:20 <andrewrk> kristate, I implemented the darwin file system stuff (not the
//       watching yet) in my async-fs branch
// 07:20 <andrewrk> I went the other direction with it - not having different
//       files
// 07:20 <kristate> andrewrk: yes, I see that -- but when we add FS watching in,
//       things will get messy with CFLoopRun
// 07:20 <andrewrk> I think it's better to have the same function definitions and
//       types in one file, and that can switch out and import os-specific files if
//       necessary
// 07:23 <andrewrk> kristate, I see, alright my mind is open to your way
// 07:23 <andrewrk> sorry I gotta get some sleep, I'll be back in ~8 hours 
// 07:24 <kristate> okay, yeah -- please rest well. I will try to get something
//       hacked out with FS watch

pub use switch (builtin.os) {
    builtin.Os.linux => @import("loop/linux.zig"),
    builtin.Os.macosx => @import("loop/darwin.zig"),
    builtin.Os.windows => @import("loop/windows.zig"),
    else => @compileError("Unsupported OS"),
};

test "std.event.Loop - test API" {
  _ = Loop.NextTickNode;
  _ = Loop.ResumeNode;
  _ = Loop.ResumeNode;
  _ = Loop.OsEventHandle;
  _ = Loop.EventFlagType;
  _ = Loop.EventFlags.READ;
  _ = Loop.EventFlags.WRITE;
  _ = Loop.EventFlags.EXCEPT;
  _ = Loop.initSingleThreaded;
  _ = Loop.initMultiThreaded;

  _ = Loop.addEvHandle;
  _ = Loop.removeEvHandle;
  _ = Loop.waitEvHandle;
  _ = Loop.onNextTick;
  _ = Loop.cancelOnNextTick;
  _ = Loop.run;
  _ = Loop.call;
  _ = Loop.yield;
  _ = Loop.beginOneEvent;
  _ = Loop.finishOneEvent;

  //Test Posix functions
  if (comptime os.is_posix) {
    _ = Loop.posixFsRequest;
  }
}

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
