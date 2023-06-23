extern "c" fn write(c_int, usize, usize) usize;

pub fn main() void {
    print();
}

fn print() void {
    const msg = @intFromPtr("Hello, World!\n");
    const len = 14;
    _ = write(1, msg, len);
}

// run
//
// Hello, World!
//
