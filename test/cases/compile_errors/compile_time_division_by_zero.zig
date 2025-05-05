const y = foo(0);
fn foo(x: u32) u32 {
    return 1 / x;
}

export fn entry() usize {
    return @sizeOf(@TypeOf(y));
}

// error
//
// :3:16: error: division by zero here causes illegal behavior
// :1:14: note: called from here
