export fn entry() void {
    var v: @import("std").meta.Vector(4, i32) = [_]i32{ 1, 5, 3, undefined };

    var i: u32 = 0;
    storev(&v[i], 42);
}

fn storev(ptr: anytype, val: i32) void {
    ptr.* = val;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:9:8: error: unable to determine vector element index of type '*align(16:0:4:?) i32
