extern "c" fn write(c_int, usize, usize) usize;

pub fn main() void {
    foo(true);
}

fn foo(x: bool) void {
    if (x) {
        print();
        print();
    } else {
        print();
    }
}

fn print() void {
    const str = "Hello, World!\n";
    _ = write(1, @intFromPtr(str.ptr), ptr.len);
}

// run
//
// Hello, World!
// Hello, World!
//
