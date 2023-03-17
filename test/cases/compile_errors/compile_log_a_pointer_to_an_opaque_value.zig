export fn entry() void {
    @compileLog(@as(*align(1) const anyopaque, @ptrCast(*const anyopaque, &entry)));
}

// error
// backend=stage2
// target=native
//
// :2:5: error: found compile log statement
//
// Compile Log Output:
// @as(*const anyopaque, (function 'entry'))
