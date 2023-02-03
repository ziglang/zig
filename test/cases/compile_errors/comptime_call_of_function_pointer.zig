export fn entry() void {
    const fn_ptr = @intToPtr(*align(1) fn () void, 0xffd2);
    comptime fn_ptr();
}

// error
// backend=stage2
// target=native
//
// :3:20: error: comptime call of function pointer
