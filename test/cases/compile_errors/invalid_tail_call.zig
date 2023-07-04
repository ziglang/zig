fn myFn(_: usize) void {
    return;
}
pub export fn entry() void {
    @call(.always_tail, myFn, .{0});
}

// error
// backend=llvm
// target=native
//
// :5:5: error: unable to perform tail call: type of function being called 'fn (usize) void' does not match type of calling function 'fn () callconv(.C) void'
