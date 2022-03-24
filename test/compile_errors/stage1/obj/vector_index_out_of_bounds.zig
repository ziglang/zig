export fn entry() void {
    const x = @import("std").meta.Vector(3, f32){ 25, 75, 5, 0 };
    _ = x;
}

// vector index out of bounds
//
// tmp.zig:2:62: error: index 3 outside vector of size 3
