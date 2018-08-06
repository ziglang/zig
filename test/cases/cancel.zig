const std = @import("std");

var defer_f1: bool = false;
var defer_f2: bool = false;
var defer_f3: bool = false;

test "cancel forwards" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    const p = async<&da.allocator> f1() catch unreachable;
    cancel p;
    std.debug.assert(defer_f1);
    std.debug.assert(defer_f2);
    std.debug.assert(defer_f3);
}

async fn f1() void {
    defer {
        defer_f1 = true;
    }
    await (async f2() catch unreachable);
}

async fn f2() void {
    defer {
        defer_f2 = true;
    }
    await (async f3() catch unreachable);
}

async fn f3() void {
    defer {
        defer_f3 = true;
    }
    suspend;
}

var defer_b1: bool = false;
var defer_b2: bool = false;
var defer_b3: bool = false;
var defer_b4: bool = false;

test "cancel backwards" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    const p = async<&da.allocator> b1() catch unreachable;
    cancel p;
    std.debug.assert(defer_b1);
    std.debug.assert(defer_b2);
    std.debug.assert(defer_b3);
    std.debug.assert(defer_b4);
}

async fn b1() void {
    defer {
        defer_b1 = true;
    }
    await (async b2() catch unreachable);
}

var b4_handle: promise = undefined;

async fn b2() void {
    const b3_handle = async b3() catch unreachable;
    resume b4_handle;
    cancel b4_handle;
    defer {
        defer_b2 = true;
    }
    const value = await b3_handle;
    @panic("unreachable");
}

async fn b3() i32 {
    defer {
        defer_b3 = true;
    }
    await (async b4() catch unreachable);
    return 1234;
}

async fn b4() void {
    defer {
        defer_b4 = true;
    }
    suspend {
        b4_handle = @handle();
    }
    suspend;
}
