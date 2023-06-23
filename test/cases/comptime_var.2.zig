extern "c" fn write(c_int, usize, usize) usize;

pub fn main() void {
    comptime var len: u32 = 5;
    print(len);
    len += 9;
    print(len);
}

fn print(len: usize) void {
    _ = write(1, @intFromPtr("Hello, World!\n"), len);
}

// run
//
// HelloHello, World!
//
