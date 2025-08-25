export fn entry() void {
    const fn_ptr: *align(1) fn () void = @ptrFromInt(0xffd2);
    comptime fn_ptr();
}

// error
//
// :3:14: error: unable to resolve comptime value
// :3:5: note: 'comptime' keyword forces comptime evaluation
