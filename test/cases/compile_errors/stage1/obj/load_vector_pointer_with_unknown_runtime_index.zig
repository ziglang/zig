export fn entry() void {
    var v: @Vector(4, i32) = [_]i32{ 1, 5, 3, undefined };

    var i: u32 = 0;
    var x = loadv(&v[i]);
    _ = x;
}

fn loadv(ptr: anytype) i32 {
    return ptr.*;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:10:12: error: unable to determine vector element index of type '*align(16:0:4:?) i32
