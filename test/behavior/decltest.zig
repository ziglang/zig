const builtin = @import("builtin");

pub fn the_add_function(a: u32, b: u32) u32 {
    return a + b;
}

test the_add_function {
    if (the_add_function(1, 2) != 3) unreachable;
}
