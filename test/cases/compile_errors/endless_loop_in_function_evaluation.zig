const seventh_fib_number = fibonacci(7);
fn fibonacci(x: i32) i32 {
    return fibonacci(x - 1) + fibonacci(x - 2);
}

export fn entry() usize { return @sizeOf(@TypeOf(seventh_fib_number)); }

// error
// backend=stage2
// target=native
//
// :3:21: error: evaluation exceeded 1000 backwards branches
// :3:21: note: called from here (999 times)
// :1:37: note: called from here
