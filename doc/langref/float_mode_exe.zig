const print = @import("std").debug.print;

extern fn foo_strict(x: f64) f64;
extern fn foo_optimized(x: f64) f64;

pub fn main() void {
    const x = 0.001;
    print("optimized = {}\n", .{foo_optimized(x)});
    print("strict = {}\n", .{foo_strict(x)});
}

// syntax
// This file requires the object file of float_mode_obj.zig
// Currently the automatic generation of the langref runs each file independently
// and does therefore not support this use case
// The output for this snippet is written into the langref manually as a workaround
