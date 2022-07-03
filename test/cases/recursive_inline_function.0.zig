pub fn main() void {
    const y = fibonacci(7);
    if (y - 21 != 0) unreachable;
}

inline fn fibonacci(n: usize) usize {
    if (n <= 2) return n;
    return fibonacci(n - 2) + fibonacci(n - 1);
}

// run
// target=x86_64-linux,arm-linux,wasm32-wasi
//
