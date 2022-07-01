extern "c" fn write(usize, usize, usize) usize;

pub fn main() void {
    comptime var i: u64 = 2;
    inline while (i < 6) : (i += 1) {
        print(i);
    }
}
fn print(len: usize) void {
    _ = write(1, @ptrToInt("Hello"), len);
}

// run
//
// HeHelHellHello
