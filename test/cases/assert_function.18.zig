const builtin = @import("builtin");

extern "c" fn write(c_int, usize, usize) usize;

pub fn main() void {
    for ("hello") |_| print();
}

fn print() void {
    _ = write(1, @intFromPtr("hello\n"), 6);
}

// run
//
// hello
// hello
// hello
// hello
// hello
//
