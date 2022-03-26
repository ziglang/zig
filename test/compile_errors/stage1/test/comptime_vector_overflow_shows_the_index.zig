comptime {
    var a: @import("std").meta.Vector(4, u8) = [_]u8{ 1, 2, 255, 4 };
    var b: @import("std").meta.Vector(4, u8) = [_]u8{ 5, 6, 1, 8 };
    var x = a + b;
    _ = x;
}

// comptime vector overflow shows the index
//
// tmp.zig:4:15: error: operation caused overflow
// tmp.zig:4:15: note: when computing vector element at index 2
