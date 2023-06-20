extern "c" fn write(c_int, usize, usize) usize;

pub fn main() void {
    foo(123);
}

fn foo(x: u64) void {
    if (x > 42) {
        print();
    }
}

fn print() void {
    const str = "Hello, World!\n";
    _ = write(1, @intFromPtr(str.ptr), ptr.len);
}

// run
// target=x86_64-linux,x86_64-macos
// link_libc=true
//
// Hello, World!
//
