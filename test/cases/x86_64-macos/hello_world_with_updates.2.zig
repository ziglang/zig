extern "c" fn write(usize, usize, usize) usize;
extern "c" fn exit(usize) noreturn;

pub export fn main() noreturn {
    print();

    exit(0);
}

fn print() void {
    const msg = @ptrToInt("Hello, World!\n");
    const len = 14;
    _ = write(1, msg, len);
}

// run
//
// Hello, World!
//
