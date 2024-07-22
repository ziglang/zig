const std = @import("std");

export fn a() void {
    const T: type = @Vector(20, i16);
    _ = std.math.minInt(T);
}

// error
// backend=stage2
// target=native
//
// :?:?: error: Expected integer type, found '@Vector(20, i16)'
// 5:24: note: called from here
