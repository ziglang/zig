export fn entry() void {
    @compileLog(@ptrCast(*const anyopaque, &entry));
}

// error
// backend=stage2
// target=native
//
// :2:5: error: found compile log statement
