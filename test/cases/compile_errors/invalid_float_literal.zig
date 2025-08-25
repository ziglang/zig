const std = @import("std");

pub fn main() void {
    var bad_float :f32 = 0.0;
    bad_float = bad_float + .20;
    std.debug.assert(bad_float < 1.0);
}

// error
// backend=stage2
// target=native
//
// :5:29: error: expected expression, found '.'
