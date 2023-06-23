extern "c" fn write(c_int, usize, usize) usize;
extern "c" fn exit(c_int) noreturn;

pub export fn main() noreturn {
    print();

    exit(0);
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
