pub fn main() void {
    assert(fib(0) == 0);
    assert(fib(1) == 1);
    assert(fib(2) == 1);
    assert(fib(3) == 2);
    assert(fib(10) == 55);
    assert(fib(20) == 6765);
}

fn fib(n: u32) u32 {
    if (n < 2) {
        return n;
    } else {
        return fib(n - 2) + fib(n - 1);
    }
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// run
// target=x86_64-linux,x86_64-macos,wasm32-wasi
//
