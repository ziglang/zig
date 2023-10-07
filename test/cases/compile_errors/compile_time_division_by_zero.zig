const y = foo(0);
fn foo(x: u32) u32 {
    return 1 / x;
}

export fn entry() usize {
    return @sizeOf(@TypeOf(y));
}

// error
// backend=llvm
// target=native
//
// :3:16: error: division by zero here causes undefined behavior
// :1:14: note: called from here
