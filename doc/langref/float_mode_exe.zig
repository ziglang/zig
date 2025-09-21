const print = @import("std").debug.print;

extern fn fooStrict(x: f64) f64;
extern fn fooOptimized(x: f64) f64;

pub fn main() void {
    const x = 0.001;
    print("optimized = {}\n", .{fooOptimized(x)});
    print("strict = {}\n", .{fooStrict(x)});
}

// syntax
